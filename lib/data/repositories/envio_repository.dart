import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../datasources/database_helper.dart';
import '../models/envio.dart';
import '../remote/api_client.dart';
import '../sync/sync_service.dart';

/// Envíos del usuario (conductor: los suyos; institución: los que van hacia
/// ella; administrador: todos) con caché local para trabajar sin conexión.
///
/// Las acciones (salida, llegada, novedad, confirmar) se encolan en
/// [SyncService] y se reflejan de inmediato en la caché ("optimistas"); el
/// servidor es quien decide y, al sincronizar, se recargan sus datos reales.
class EnvioRepository {
  EnvioRepository._();
  static final instance = EnvioRepository._();

  /// Envíos actuales (caché + cambios locales pendientes).
  final envios = ValueNotifier<List<Envio>>(const []);

  int? _usuarioId;
  StreamSubscription<List<Operacion>>? _sub;

  Future<Database> get _db => DatabaseHelper.instance.database;

  Future<void> iniciar(int usuarioId) async {
    await _sub?.cancel();
    _usuarioId = usuarioId;
    envios.value = await _desdeCache();
    // Cuando el servidor aplica operaciones, se trae el estado real.
    _sub = SyncService.instance.onAplicadas.listen((_) {
      refrescar().then((_) {}, onError: (_) {});
    });
  }

  Future<void> detener() async {
    await _sub?.cancel();
    _sub = null;
    _usuarioId = null;
    envios.value = const [];
  }

  Envio? porId(int id) {
    for (final e in envios.value) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Descarga los envíos de los últimos 30 días. Sin conexión deja la caché.
  /// Lanza [SinConexionException] o [ApiException] para que la UI informe.
  Future<List<Envio>> refrescar() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) return const [];
    final desde = DateTime.now().subtract(const Duration(days: 30));
    final fecha =
        '${desde.year.toString().padLeft(4, '0')}-'
        '${desde.month.toString().padLeft(2, '0')}-${desde.day.toString().padLeft(2, '0')}';
    final lista = await ApiClient.instance.getTodos(
      '/envios/',
      query: {'fecha_desde': fecha, 'ordering': '-programado_para'},
    );
    final db = await _db;
    final ahora = DateTime.now().toUtc().toIso8601String();
    await db.transaction((txn) async {
      await txn.delete(
        'envios_cache',
        where: 'usuario_id = ?',
        whereArgs: [usuarioId],
      );
      final batch = txn.batch();
      for (final j in lista) {
        batch.insert('envios_cache', {
          'usuario_id': usuarioId,
          'id': j['id'],
          'json': jsonEncode(j),
          'actualizado_en': ahora,
        });
      }
      await batch.commit(noResult: true);
    });
    final resultado = await _aplicarPendientes(lista.map(Envio.new).toList());
    envios.value = resultado;
    return resultado;
  }

  Future<List<Envio>> _desdeCache() async {
    final usuarioId = _usuarioId;
    if (usuarioId == null) return const [];
    final db = await _db;
    final filas = await db.query(
      'envios_cache',
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
    );
    final lista =
        filas
            .map(
              (f) => Envio(
                (jsonDecode(f['json'] as String) as Map)
                    .cast<String, dynamic>(),
              ),
            )
            .toList()
          ..sort(
            (a, b) => (b.programadoPara ?? DateTime(0)).compareTo(
              a.programadoPara ?? DateTime(0),
            ),
          );
    return _aplicarPendientes(lista);
  }

  /// Refleja en la lista las operaciones que aún no llegan al servidor.
  Future<List<Envio>> _aplicarPendientes(List<Envio> lista) async {
    final pendientes = await SyncService.instance.pendientes();
    if (pendientes.isEmpty) return lista;
    final porId = {for (final e in lista) e.id: e};
    for (final op in pendientes) {
      final envio = porId[op.envioId];
      if (envio == null) continue;
      final cambios = _cambiosOptimistas(op);
      if (cambios != null) porId[envio.id] = envio.conCambios(cambios);
    }
    return lista.map((e) => porId[e.id]!).toList();
  }

  static Map<String, dynamic>? _cambiosOptimistas(Operacion op) {
    final cuando = op.ocurridoEn.toUtc().toIso8601String();
    switch (op.tipo) {
      case 'envio.salida':
        return {'estado': 'EN_TRANSITO', 'salida_en': cuando};
      case 'envio.llegada':
        return {'llegada_en': cuando};
      case 'envio.confirmar':
        return {'estado': 'ENTREGADO', 'entregado_en': cuando};
      default:
        return null;
    }
  }

  Future<void> _encolarYReflejar({
    required Envio envio,
    required String tipo,
    required Map<String, dynamic> datos,
    required String resumen,
  }) async {
    await SyncService.instance.encolar(
      tipo: tipo,
      datos: {...datos, 'envio': envio.id},
      envioId: envio.id,
      resumen: resumen,
    );
    envios.value = await _desdeCache();
  }

  static String _coord(double v) => v.toStringAsFixed(6);

  // ── Conductor ─────────────────────────────────────────────────────────────

  /// RF-20: registra la salida con la ubicación actual.
  Future<void> registrarSalida(
    Envio envio, {
    required double lat,
    required double lng,
  }) => _encolarYReflejar(
    envio: envio,
    tipo: 'envio.salida',
    datos: {'latitud': _coord(lat), 'longitud': _coord(lng)},
    resumen: 'Salida hacia ${envio.institucion.nombre}',
  );

  /// RF-22: registra la llegada a la institución.
  Future<void> registrarLlegada(
    Envio envio, {
    required double lat,
    required double lng,
  }) => _encolarYReflejar(
    envio: envio,
    tipo: 'envio.llegada',
    datos: {'latitud': _coord(lat), 'longitud': _coord(lng)},
    resumen: 'Llegada a ${envio.institucion.nombre}',
  );

  /// RF-21: punto del recorrido (lo llama el servicio de rastreo).
  Future<void> registrarUbicacion(
    int envioId, {
    required double lat,
    required double lng,
    double? precision,
    double? velocidadKmh,
    int? rumbo,
  }) => SyncService.instance.encolar(
    tipo: 'envio.ubicacion',
    envioId: envioId,
    datos: {
      'envio': envioId,
      'latitud': _coord(lat),
      'longitud': _coord(lng),
      if (precision != null) 'precision_m': precision.toStringAsFixed(2),
      if (velocidadKmh != null)
        'velocidad_kmh': velocidadKmh.toStringAsFixed(2),
      'rumbo': ?rumbo,
    },
  );

  // ── Conductor e institución ───────────────────────────────────────────────

  /// RF-23 / RF-28: novedad con foto opcional (data URL base64).
  Future<void> reportarNovedad(
    Envio envio, {
    required TipoNovedad tipo,
    required String descripcion,
    String? fotoBase64,
    double? lat,
    double? lng,
  }) => _encolarYReflejar(
    envio: envio,
    tipo: 'envio.novedad',
    datos: {
      'tipo': tipo.api,
      'descripcion': descripcion,
      'foto': ?fotoBase64,
      if (lat != null) 'latitud': _coord(lat),
      if (lng != null) 'longitud': _coord(lng),
    },
    resumen: 'Novedad (${tipo.label}) · ${envio.codigo}',
  );

  // ── Institución ───────────────────────────────────────────────────────────

  /// RF-25 a RF-28: confirma la recepción con las cantidades recibidas, el
  /// código que muestra el conductor y la evidencia.
  Future<void> confirmarRecepcion(
    Envio envio, {
    required Map<int, double> recibidos,
    required String recibidoPorNombre,
    String recibidoPorCargo = '',
    required String codigoVerificacion,
    String? fotoBase64,
    double? lat,
    double? lng,
    TipoNovedad? tipoNovedad,
    String? descripcionNovedad,
  }) => _encolarYReflejar(
    envio: envio,
    tipo: 'envio.confirmar',
    datos: {
      'items': [
        for (final e in recibidos.entries)
          {'item': e.key, 'cantidad_recibida': e.value.toStringAsFixed(2)},
      ],
      'recibido_por_nombre': recibidoPorNombre,
      'recibido_por_cargo': recibidoPorCargo,
      'codigo_verificacion': codigoVerificacion,
      'foto': ?fotoBase64,
      if (lat != null) 'latitud': _coord(lat),
      if (lng != null) 'longitud': _coord(lng),
      if (descripcionNovedad != null && descripcionNovedad.trim().isNotEmpty)
        'novedad': {
          if (tipoNovedad != null) 'tipo': tipoNovedad.api,
          'descripcion': descripcionNovedad.trim(),
        },
    },
    resumen: 'Recepción de ${envio.codigo}',
  );
}
