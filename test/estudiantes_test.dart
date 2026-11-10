import 'dart:convert';
import 'dart:math';
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:opaego/data/datasources/database_helper.dart';
import 'package:opaego/data/models/estudiante.dart';
import 'package:opaego/data/models/user_role.dart';
import 'package:opaego/data/remote/api_client.dart';
import 'package:opaego/data/repositories/estudiantes_repository.dart';
import 'package:opaego/data/services/rostro/cofre.dart';
import 'package:opaego/data/services/rostro/comparador.dart';
import 'package:opaego/data/services/rostro/preprocesado.dart';
import 'package:opaego/data/sync/sync_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

http.Response _json(Object cuerpo) => http.Response(
  jsonEncode(cuerpo),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Vector "facial" falso y determinista (192 dimensiones, como MobileFaceNet).
List<double> vectorDe(int semilla, {double ruido = 0}) {
  final base = Random(semilla);
  final r = Random(semilla * 7919 + 1);
  return normalizar([
    for (var i = 0; i < 192; i++)
      base.nextDouble() * 2 - 1 + (r.nextDouble() * 2 - 1) * ruido,
  ]);
}

Map<String, dynamic> estudianteJson(
  int id, {
  String grado = '7',
  String grupo = 'B',
  bool autorizado = false,
  bool rostro = false,
  Map<String, dynamic>? entrega,
}) => {
  'id': id,
  'tipo_documento': 'TI',
  'numero_documento': '10$id',
  'nombres': 'Nombre$id',
  'apellidos': 'Apellido$id',
  'nombre_completo': 'Nombre$id Apellido$id',
  'grado': grado,
  'grado_etiqueta': '$grado°',
  'grupo': grupo,
  'curso': '$grado° $grupo',
  'jornada': 'MAÑANA',
  'autorizacion_vigente': autorizado,
  'rostro_inscrito': rostro,
  'entrega_del_dia': entrega,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('comparador', () {
    test('reconoce a la persona correcta entre las del curso', () {
      final plantillas = {
        for (var id = 1; id <= 35; id++)
          id: [vectorDe(id, ruido: 0.05), vectorDe(id, ruido: 0.1)],
      };
      final c = identificar(vectorDe(17, ruido: 0.15), plantillas, umbral: 0.8);
      expect(c?.estudianteId, 17);
      expect(c!.similitud, greaterThan(0.8));
      expect(c.ambigua(), isFalse);
    });

    test('un desconocido no alcanza el umbral', () {
      final plantillas = {
        for (var id = 1; id <= 35; id++) id: [vectorDe(id)],
      };
      expect(identificar(vectorDe(999), plantillas, umbral: 0.8), isNull);
    });

    test('las muestras de otra persona no son consistentes', () {
      expect(
        muestrasConsistentes([
          vectorDe(1, ruido: 0.1),
          vectorDe(1, ruido: 0.2),
        ]),
        isTrue,
      );
      expect(muestrasConsistentes([vectorDe(1), vectorDe(2)]), isFalse);
      expect(() => normalizar([0, 0, 0]), throwsArgumentError);
    });
  });

  group('preprocesado', () {
    test('la entrada del modelo queda en [-1, 1] y del tamaño pedido', () {
      final foto = img.Image(width: 400, height: 300);
      img.fill(foto, color: img.ColorRgb8(255, 0, 128));
      final recorte = recortarCara(
        foto,
        const Rect.fromLTWH(300, 200, 150, 150), // se sale de la foto
      );
      expect(recorte.width, recorte.height);
      expect(recorte.width, 115); // recortado al borde de la foto
      final t = tensorDeEntrada(recorte, 112);
      expect(t.first.length, 112);
      expect(t.first.first.length, 112);
      final px = t.first.first.first; // NHWC: [1][y][x][canal]
      expect(px[0], closeTo(1, 1e-6));
      expect(px[1], closeTo(-1, 1e-6));

      // Qualcomm MobileFaceNet: NCHW y píxeles en [0, 1].
      final nchw = tensorDeEntrada(
        recorte,
        112,
        canalesPrimero: true,
        minimo: 0,
        maximo: 1,
      );
      expect(nchw.first.length, 3);
      expect(nchw.first[0][5][7], closeTo(1, 1e-6)); // rojo
      expect(nchw.first[1][5][7], closeTo(0, 1e-6)); // verde
      expect(nchw.first[2][5][7], closeTo(128 / 255, 1e-6)); // azul
    });
  });

  group('cofre', () {
    test('cifra y descifra; sin la clave no se puede leer', () async {
      final almacen = AlmacenClaveEnMemoria();
      final cofre = Cofre(almacen);
      final texto = await cofre.cifrar({'7': vectorDe(1)});
      expect(texto, isNot(contains('0.')));
      expect(((await cofre.descifrar(texto)) as Map)['7'], hasLength(192));
      await cofre.destruirClave();
      expect(await almacen.leer(), isNull);
      // Clave nueva: lo anterior queda ilegible.
      await expectLater(cofre.descifrar(texto), throwsA(anything));
    });
  });

  test('rol SUPERVISOR del backend', () {
    final rol = UserRoleX.fromBackend('SUPERVISOR');
    expect(rol, UserRole.supervisor);
    expect(rol.canRegisterStudents, isTrue);
    expect(rol.canDriveRoute, isFalse);
    expect(UserRole.rector.canViewStudents, isTrue);
    expect(UserRole.driver.canViewStudents, isFalse);
  });

  group('repositorio', () {
    final repo = EstudiantesRepository.instance;
    late List<Map<String, dynamic>> enServidor;
    late List<Map<String, dynamic>> lotes;
    late Map<int, List<List<double>>> plantillasServidor;
    var hayRed = true;

    setUpAll(() async {
      sqfliteFfiInit();
      DatabaseHelper.nombreArchivo = 'prueba_estudiantes.db';
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.deleteDatabase(
        p.join(await getDatabasesPath(), DatabaseHelper.nombreArchivo),
      );
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'paego_access': 'A',
        'paego_refresh': 'R',
      });
      final hoy = fechaDeHoy();
      enServidor = [
        estudianteJson(1, autorizado: true, rostro: true),
        estudianteJson(2),
        estudianteJson(
          3,
          entrega: {
            'id': 9,
            'fecha': hoy,
            'metodo': 'MANUAL',
            'ocurrido_en': DateTime.now().toUtc().toIso8601String(),
          },
        ),
        estudianteJson(4, grado: '11', grupo: 'A'),
      ];
      plantillasServidor = {
        1: [vectorDe(1), vectorDe(1, ruido: 0.1)],
      };
      lotes = [];
      hayRed = true;
      ApiClient.usarCliente(
        MockClient((r) async {
          if (!hayRed) throw http.ClientException('sin red');
          switch (r.url.path) {
            case '/api/estudiantes/':
              return _json({'count': 4, 'next': null, 'results': enServidor});
            case '/api/estudiantes/plantillas/':
              return _json({
                'grado': r.url.queryParameters['grado'],
                'plantillas': [
                  for (final e in plantillasServidor.entries)
                    {'estudiante': e.key, 'vectores': e.value},
                ],
              });
            case '/api/sincronizacion/configuracion/':
              return _json({
                'biometria_disponible': true,
                'umbral_similitud_facial': 0.75,
                'muestras_rostro_min': 3,
                'muestras_rostro_max': 5,
              });
            case '/api/sincronizacion/lote/':
              final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
              lotes.add(cuerpo);
              return _json({
                'resultados': [
                  for (final op in cuerpo['operaciones'] as List)
                    {
                      'uuid_cliente': op['uuid_cliente'],
                      'tipo': op['tipo'],
                      'resultado': 'ok',
                      'respuesta': {'id': 1},
                    },
                ],
              });
          }
          return http.Response('', 404);
        }),
      );
      await ApiClient.instance.cargarTokens();
      final db = await DatabaseHelper.instance.database;
      await db.delete('operaciones');
      await db.delete('estudiantes_cache');
      await db.delete('plantillas_cache');
      repo.cofre = Cofre(AlmacenClaveEnMemoria());
      await SyncService.instance.iniciar(8);
      await repo.iniciar(8);
    });

    tearDown(() async {
      await repo.detener();
      await SyncService.instance.detener();
    });

    test('descarga la institución y arma el avance por curso', () async {
      await repo.descargar();
      final cursos = repo.cursos();
      expect(cursos.map((c) => c.curso), ['7° B', '11° A']);
      final septimo = cursos.first;
      expect(
        (septimo.activos, septimo.recibieron, septimo.conRostro),
        (3, 1, 1),
      );
      expect(repo.delCurso('7', 'B').map((e) => e.id), [1, 2, 3]);
      // La configuración del servidor queda guardada.
      await Future<void>.delayed(Duration.zero);
      expect(repo.config.value.umbral, 0.75);
    });

    test('sin red: la entrega se encola y se ve al instante', () async {
      await repo.descargar();
      hayRed = false;
      final ana = repo.porId(2)!;
      await repo.entregar(ana, metodo: 'MANUAL', motivo: 'Sin cámara');
      final despues = repo.porId(2)!;
      expect(despues.recibioHoy, isTrue);
      expect(despues.entregaPendiente, isTrue);
      expect(SyncService.instance.estado.value.pendientes, 1);
      // Una segunda entrega el mismo día se bloquea en el teléfono.
      expect(
        () => repo.entregar(despues, metodo: 'MANUAL', motivo: 'x'),
        throwsStateError,
      );
      // Vuelve la red: se envía con la fecha del día.
      hayRed = true;
      await SyncService.instance.sincronizar();
      final op = (lotes.last['operaciones'] as List).single as Map;
      expect(op['tipo'], 'estudiante.entregar');
      expect(op['datos'], {
        'estudiante': 2,
        'metodo': 'MANUAL',
        'fecha': fechaDeHoy(),
        'motivo': 'Sin cámara',
      });
    });

    test('autorizar e inscribir sin red; los vectores no quedan en la cola '
        'después de enviarse', () async {
      await repo.descargar();
      hayRed = false;
      final e = repo.porId(2)!;
      await repo.autorizar(
        e,
        acudienteNombre: ' Rosa Pérez ',
        acudienteDocumento: '123',
        parentesco: 'Madre',
      );
      await repo.inscribir(
        e,
        vectores: [
          vectorDe(2),
          vectorDe(2, ruido: 0.1),
          vectorDe(2, ruido: 0.1),
        ],
        modelo: 'mobilefacenet-tflite',
      );
      final local = repo.porId(2)!;
      expect(local.autorizacionVigente, isTrue);
      expect(local.rostroInscrito, isTrue);

      // Sin red, el curso se reconoce con la caché + lo inscrito en el teléfono.
      final plantillas = await repo.plantillasDelCurso('7', 'B');
      expect(plantillas.keys, contains(2));
      expect(
        identificar(
          vectorDe(2, ruido: 0.12),
          plantillas,
          umbral: 0.8,
        )?.estudianteId,
        2,
      );

      hayRed = true;
      await SyncService.instance.sincronizar();
      final tipos = [
        for (final op in lotes.last['operaciones'] as List) op['tipo'],
      ];
      expect(tipos, ['estudiante.autorizar', 'estudiante.inscribir']);
      final historial = await SyncService.instance.historial(
        prefijo: 'estudiante.',
      );
      expect(historial, hasLength(2));
      final inscripcion = historial.firstWhere(
        (o) => o.tipo == 'estudiante.inscribir',
      );
      expect(inscripcion.datos['vectores'], '(enviados)');
    });

    test(
      'las plantillas del curso se guardan cifradas para usarlas sin red',
      () async {
        await repo.descargar();
        final enLinea = await repo.plantillasDelCurso('7', 'B');
        expect(enLinea.keys, [1]);
        final db = await DatabaseHelper.instance.database;
        final fila = (await db.query('plantillas_cache')).single;
        expect(fila['cifrado'] as String, isNot(contains('[')));

        hayRed = false;
        final sinRed = await repo.plantillasDelCurso('7', 'B');
        expect(sinRed[1]!.first, enLinea[1]!.first);

        // Revocar (aún sin red) la quita de inmediato.
        await repo.revocar(repo.porId(1)!, motivo: 'Lo pidió el acudiente');
        expect(await repo.plantillasDelCurso('7', 'B'), isEmpty);
        expect(repo.porId(1)!.rostroInscrito, isFalse);
      },
    );

    test(
      'al cerrar sesión se borran los estudiantes y las plantillas',
      () async {
        await repo.descargar();
        await repo.plantillasDelCurso('7', 'B');
        await repo.borrarDatos();
        final db = await DatabaseHelper.instance.database;
        expect(await db.query('estudiantes_cache'), isEmpty);
        expect(await db.query('plantillas_cache'), isEmpty);
        expect(repo.estudiantes.value, isEmpty);
      },
    );

    test('la caché de ayer no cuenta como entrega de hoy', () {
      final e = Estudiante.fromJson(
        estudianteJson(
          5,
          entrega: {
            'id': 1,
            'fecha': '2020-01-01',
            'metodo': 'FACIAL',
            'ocurrido_en': '2020-01-01T12:00:00Z',
          },
        ),
      );
      expect(e.recibioHoy, isFalse);
      expect(CursoResumen.de([e]).single.recibieron, 0);
    });
  });
}
