import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../datasources/database_helper.dart';
import '../models/estudiante.dart';
import '../remote/api_client.dart';
import '../services/rostro/cofre.dart';
import '../sync/sync_service.dart';

/// Parámetros de la biometría que publica el servidor
/// (`GET /api/sincronizacion/configuracion/`).
class ConfigBiometria {
  const ConfigBiometria({
    this.disponible = true,
    this.umbral = 0.80,
    this.muestrasMin = 3,
    this.muestrasMax = 5,
  });

  factory ConfigBiometria.fromJson(Map<String, dynamic> j) => ConfigBiometria(
    disponible: j['biometria_disponible'] != false,
    umbral: (j['umbral_similitud_facial'] as num?)?.toDouble() ?? 0.80,
    muestrasMin: (j['muestras_rostro_min'] as num?)?.toInt() ?? 3,
    muestrasMax: (j['muestras_rostro_max'] as num?)?.toInt() ?? 5,
  );

  /// El servidor puede inscribir rostros (tiene `BIOMETRIA_CLAVE`).
  final bool disponible;
  final double umbral;
  final int muestrasMin;
  final int muestrasMax;

  Map<String, dynamic> toJson() => {
    'biometria_disponible': disponible,
    'umbral_similitud_facial': umbral,
    'muestras_rostro_min': muestrasMin,
    'muestras_rostro_max': muestrasMax,
  };
}

/// Estudiantes de la institución del supervisor PAE, con caché para trabajar
/// sin conexión (igual que [EnvioRepository] con los envíos).
///
/// Autorizar, inscribir el rostro, entregar y revocar se encolan en
/// [SyncService] (`estudiante.*`) y se reflejan al instante en la lista; el
/// servidor aplica las mismas reglas al sincronizar (una entrega por día,
/// nada de biometría sin autorización del acudiente).
class EstudiantesRepository {
  EstudiantesRepository._();
  static final instance = EstudiantesRepository._();

  static const _kConfig = 'paego_config_biometria';

  final estudiantes = ValueNotifier<List<Estudiante>>(const []);
  final config = ValueNotifier<ConfigBiometria>(const ConfigBiometria());

  /// Hora de la última descarga completa (null: nunca o solo caché).
  DateTime? descargadoEn;

  int? _usuarioId;
  StreamSubscription<List<Operacion>>? _sub;
  Cofre _cofre = Cofre();

  @visibleForTesting
  set cofre(Cofre c) => _cofre = c;

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<void> iniciar(int usuarioId) async {
    await _sub?.cancel();
    _usuarioId = usuarioId;
    await _cargarConfigGuardada();
    estudiantes.value = await _desdeCache();
    _sub = SyncService.instance.onAplicadas.listen((ops) {
      if (ops.any((o) => o.tipo.startsWith('estudiante.'))) {
        descargar().then((_) {}, onError: (_) {});
      }
    });
  }

  Future<void> detener() async {
    await _sub?.cancel();
    _sub = null;
    _usuarioId = null;
    estudiantes.value = const [];
    descargadoEn = null;
  }

  /// Borra del teléfono los datos de los estudiantes y sus plantillas (al
  /// cerrar sesión). La cola de operaciones pendientes se conserva.
  Future<void> borrarDatos() async {
    final db = await _db;
    await db.delete('estudiantes_cache');
    await db.delete('plantillas_cache');
    await _cofre.destruirClave();
    estudiantes.value = const [];
  }

  // ── Lectura ───────────────────────────────────────────────────────────────

  /// Descarga la institución completa (estado de hoy) y la configuración.
  /// Lanza [SinConexionException]/[ApiException]; la caché queda intacta.
  Future<List<Estudiante>> descargar() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) return const [];
    unawaited(_descargarConfig());
    final lista = await ApiClient.instance.getTodos(
      '/estudiantes/',
      query: {'page_size': '500'},
      maxPaginas: 20,
    );
    final db = await _db;
    final ahora = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'estudiantes_cache',
        where: 'usuario_id = ?',
        whereArgs: [usuarioId],
      );
      final batch = txn.batch();
      for (final j in lista) {
        batch.insert('estudiantes_cache', {
          'usuario_id': usuarioId,
          'id': j['id'],
          'json': jsonEncode(j),
          'actualizado_en': ahora,
        });
      }
      await batch.commit(noResult: true);
    });
    descargadoEn = DateTime.now();
    final resultado = await _aplicarPendientes(
      lista.map(Estudiante.fromJson).toList(),
    );
    estudiantes.value = resultado;
    return resultado;
  }

  List<CursoResumen> cursos() => CursoResumen.de(estudiantes.value);

  List<Estudiante> delCurso(String grado, String grupo) {
    final lista = estudiantes.value
        .where((e) => e.grado == grado && e.grupo == grupo)
        .toList();
    lista.sort((a, b) {
      final c = a.apellidos.compareTo(b.apellidos);
      return c != 0 ? c : a.nombres.compareTo(b.nombres);
    });
    return lista;
  }

  Estudiante? porId(int id) {
    for (final e in estudiantes.value) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Plantillas del curso (estudiante → muestras) para reconocer sin red.
  /// Con red se descargan y se guardan cifradas; sin red se usa la caché.
  /// Incluye las inscripciones hechas en este teléfono que aún no se envían.
  Future<Map<int, List<List<double>>>> plantillasDelCurso(
    String grado,
    String grupo,
  ) async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) return const {};
    final curso = '$grado|$grupo';
    final db = await _db;
    Map<int, List<List<double>>> plantillas;
    try {
      final r = await ApiClient.instance.get(
        '/estudiantes/plantillas/',
        query: {'grado': grado, 'grupo': grupo},
      );
      plantillas = {
        for (final p in ((r as Map)['plantillas'] as List).cast<Map>())
          p['estudiante'] as int: _vectores(p['vectores']),
      };
      await db.insert('plantillas_cache', {
        'usuario_id': usuarioId,
        'curso': curso,
        'cifrado': await _cofre.cifrar({
          for (final e in plantillas.entries) '${e.key}': e.value,
        }),
        'actualizado_en': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } on SinConexionException {
      plantillas = await _plantillasEnCache(usuarioId, curso);
    }
    // Cambios aún en la cola (se aplican en orden).
    for (final op in await SyncService.instance.pendientes()) {
      final id = op.datos['estudiante'];
      if (id is! int) continue;
      if (op.tipo == 'estudiante.inscribir' && op.datos['vectores'] is List) {
        final e = porId(id);
        if (e != null && e.grado == grado && e.grupo == grupo) {
          plantillas[id] = _vectores(op.datos['vectores']);
        }
      } else if (op.tipo == 'estudiante.revocar') {
        plantillas.remove(id);
      }
    }
    return plantillas;
  }

  Future<Map<int, List<List<double>>>> _plantillasEnCache(
    int usuarioId,
    String curso,
  ) async {
    final db = await _db;
    final filas = await db.query(
      'plantillas_cache',
      where: 'usuario_id = ? AND curso = ?',
      whereArgs: [usuarioId, curso],
    );
    if (filas.isEmpty) return {};
    try {
      final datos =
          (await _cofre.descifrar(filas.first['cifrado'] as String)) as Map;
      return {
        for (final e in datos.entries)
          int.parse(e.key as String): _vectores(e.value),
      };
    } catch (_) {
      // Clave distinta (otra sesión) o dato alterado: no se usa.
      return {};
    }
  }

  static List<List<double>> _vectores(dynamic v) => [
    for (final m in v as List)
      [for (final x in m as List) (x as num).toDouble()],
  ];

  // ── Acciones (cola sin conexión) ──────────────────────────────────────────

  Future<void> autorizar(
    Estudiante e, {
    required String acudienteNombre,
    required String acudienteDocumento,
    required String parentesco,
  }) => _encolar(
    'estudiante.autorizar',
    e,
    {
      'acudiente_nombre': acudienteNombre.trim(),
      'acudiente_documento': acudienteDocumento.trim(),
      'parentesco': parentesco.trim(),
    },
    'Autorización del acudiente · ${e.nombreCompleto} · ${e.curso}',
  );

  Future<void> inscribir(
    Estudiante e, {
    required List<List<double>> vectores,
    required String modelo,
  }) => _encolar('estudiante.inscribir', e, {
    'vectores': vectores,
    'modelo': modelo,
  }, 'Rostro inscrito · ${e.nombreCompleto} · ${e.curso}');

  Future<void> entregar(
    Estudiante e, {
    required String metodo,
    double? similitud,
    String motivo = '',
  }) {
    if (e.recibioHoy) {
      throw StateError('${e.nombreCompleto} ya recibió el PAE hoy.');
    }
    return _encolar(
      'estudiante.entregar',
      e,
      {
        'metodo': metodo,
        'fecha': fechaDeHoy(),
        if (similitud != null)
          'similitud': double.parse(similitud.toStringAsFixed(4)),
        if (motivo.isNotEmpty) 'motivo': motivo,
      },
      '${metodo == 'FACIAL' ? 'Entrega (rostro)' : 'Entrega (manual)'} · '
          '${e.nombreCompleto} · ${e.curso}',
    );
  }

  Future<void> revocar(Estudiante e, {String motivo = ''}) => _encolar(
    'estudiante.revocar',
    e,
    {'motivo': motivo},
    'Autorización revocada · ${e.nombreCompleto} · ${e.curso}',
  );

  Future<void> _encolar(
    String tipo,
    Estudiante e,
    Map<String, dynamic> datos,
    String resumen,
  ) async {
    await SyncService.instance.encolar(
      tipo: tipo,
      datos: {'estudiante': e.id, ...datos},
      resumen: resumen,
    );
    estudiantes.value = await _aplicarPendientes(
      await _desdeCacheSinPendientes(),
    );
  }

  // ── Caché + pendientes ────────────────────────────────────────────────────

  Future<List<Estudiante>> _desdeCache() async =>
      _aplicarPendientes(await _desdeCacheSinPendientes());

  Future<List<Estudiante>> _desdeCacheSinPendientes() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) return const [];
    final db = await _db;
    final filas = await db.query(
      'estudiantes_cache',
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
    );
    return [
      for (final f in filas)
        Estudiante.fromJson(
          (jsonDecode(f['json'] as String) as Map).cast<String, dynamic>(),
        ),
    ];
  }

  /// Refleja en la lista las operaciones que aún no llegan al servidor.
  Future<List<Estudiante>> _aplicarPendientes(List<Estudiante> lista) async {
    final pendientes = await SyncService.instance.pendientes();
    final cambios = pendientes.where((o) => o.tipo.startsWith('estudiante.'));
    if (cambios.isEmpty) return lista;
    final porId = {for (final e in lista) e.id: e};
    for (final op in cambios) {
      final id = op.datos['estudiante'];
      final e = porId[id];
      if (e == null) continue;
      porId[id as int] = switch (op.tipo) {
        'estudiante.autorizar' => e.copyWith(autorizacionVigente: true),
        'estudiante.inscribir' => e.copyWith(rostroInscrito: true),
        'estudiante.revocar' => e.copyWith(
          autorizacionVigente: false,
          rostroInscrito: false,
        ),
        'estudiante.entregar' when op.datos['fecha'] == fechaDeHoy() =>
          e.copyWith(
            entregaFecha: op.datos['fecha'] as String,
            entregaMetodo: op.datos['metodo'] as String?,
            entregaHora: op.ocurridoEn,
            entregaPendiente: true,
          ),
        _ => e,
      };
    }
    return lista.map((e) => porId[e.id]!).toList();
  }

  // ── Configuración ─────────────────────────────────────────────────────────

  Future<void> _cargarConfigGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    final texto = prefs.getString(_kConfig);
    if (texto == null) return;
    try {
      config.value = ConfigBiometria.fromJson(
        (jsonDecode(texto) as Map).cast<String, dynamic>(),
      );
    } catch (_) {}
  }

  Future<void> _descargarConfig() async {
    try {
      final r = await ApiClient.instance.get('/sincronizacion/configuracion/');
      final c = ConfigBiometria.fromJson((r as Map).cast<String, dynamic>());
      config.value = c;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kConfig, jsonEncode(c.toJson()));
    } catch (_) {
      // Sin red: se sigue con la última configuración conocida.
    }
  }
}
