import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opaego/data/datasources/database_helper.dart';
import 'package:opaego/data/remote/api_client.dart';
import 'package:opaego/data/sync/sync_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

http.Response json(Object cuerpo, [int codigo = 200]) => http.Response(
  jsonEncode(cuerpo),
  codigo,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    DatabaseHelper.nombreArchivo = 'prueba_sync.db';
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.deleteDatabase(
      p.join(await getDatabasesPath(), DatabaseHelper.nombreArchivo),
    );
  });

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ApiClient (JWT)', () {
    test('inicia sesión, guarda tokens y los usa como Bearer', () async {
      final vistos = <String?>[];
      ApiClient.usarCliente(
        MockClient((r) async {
          if (r.url.path == '/api/auth/token/') {
            expect(jsonDecode(r.body), {
              'email': 'conductor1@paego.local',
              'password': 'x',
            });
            return json({
              'access': 'A1',
              'refresh': 'R1',
              'usuario': {'id': 5, 'rol': 'CONDUCTOR'},
            });
          }
          vistos.add(r.headers['Authorization']);
          return json({'id': 5});
        }),
      );
      final perfil = await ApiClient.instance.iniciarSesion(
        ' Conductor1@paego.local ',
        'x',
      );
      expect(perfil['rol'], 'CONDUCTOR');
      await ApiClient.instance.get('/auth/yo/');
      expect(vistos, ['Bearer A1']);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('paego_refresh'), 'R1');
    });

    test('con 401 renueva el access (refresh rotado) y reintenta', () async {
      SharedPreferences.setMockInitialValues({
        'paego_access': 'viejo',
        'paego_refresh': 'R1',
      });
      var refrescos = 0;
      ApiClient.usarCliente(
        MockClient((r) async {
          if (r.url.path == '/api/auth/token/refresh/') {
            refrescos++;
            expect(jsonDecode(r.body), {'refresh': 'R1'});
            return json({'access': 'nuevo', 'refresh': 'R2'});
          }
          if (r.headers['Authorization'] == 'Bearer viejo') {
            return json({'detail': 'Token inválido'}, 401);
          }
          return json({'ok': true});
        }),
      );
      await ApiClient.instance.cargarTokens();
      final r = await ApiClient.instance.get('/envios/');
      expect(r, {'ok': true});
      expect(refrescos, 1);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('paego_refresh'), 'R2');
    });

    test('si el refresh venció avisa sesión vencida', () async {
      SharedPreferences.setMockInitialValues({
        'paego_access': 'viejo',
        'paego_refresh': 'R1',
      });
      ApiClient.usarCliente(
        MockClient((r) async => json({'detail': 'vencido'}, 401)),
      );
      await ApiClient.instance.cargarTokens();
      final aviso = expectLater(
        ApiClient.instance.onSesionVencida,
        emits(null),
      );
      await expectLater(
        ApiClient.instance.get('/envios/'),
        throwsA(isA<SesionVencidaException>()),
      );
      await aviso;
      expect(ApiClient.instance.tieneSesion, isFalse);
    });

    test('sin red lanza SinConexionException', () async {
      SharedPreferences.setMockInitialValues({
        'paego_access': 'A',
        'paego_refresh': 'R',
      });
      ApiClient.usarCliente(
        MockClient((r) async => throw http.ClientException('sin red')),
      );
      await ApiClient.instance.cargarTokens();
      expect(
        ApiClient.instance.get('/envios/'),
        throwsA(isA<SinConexionException>()),
      );
    });

    test('convierte los errores de DRF en texto legible', () {
      expect(
        ApiClient.mensajeDeError({
          'codigo_verificacion': ['El código no coincide.'],
        }),
        'codigo_verificacion: El código no coincide.',
      );
      expect(
        ApiClient.mensajeDeError({
          'detalle': {'estado': 'No está en tránsito.'},
        }),
        'estado: No está en tránsito.',
      );
      expect(
        ApiClient.mensajeDeError(null, 403),
        'No tiene permiso para esta acción.',
      );
    });
  });

  group('SyncService (cola sin conexión, RF-38)', () {
    late List<Map<String, dynamic>> lotes;
    var hayRed = false;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'paego_access': 'A',
        'paego_refresh': 'R',
      });
      lotes = [];
      hayRed = false;
      ApiClient.usarCliente(
        MockClient((r) async {
          if (!hayRed) throw http.ClientException('sin red');
          final cuerpo = jsonDecode(r.body) as Map<String, dynamic>;
          lotes.add(cuerpo);
          return json({
            'resultados': [
              for (final op in cuerpo['operaciones'] as List)
                {
                  'uuid_cliente': op['uuid_cliente'],
                  'tipo': op['tipo'],
                  'resultado': op['tipo'] == 'envio.llegada'
                      ? 'rechazado'
                      : 'ok',
                  'respuesta': op['tipo'] == 'envio.llegada'
                      ? {
                          'detalle': {
                            'estado':
                                'Debe registrar la salida antes de la llegada.',
                          },
                        }
                      : {'id': 1},
                },
            ],
          });
        }),
      );
      await ApiClient.instance.cargarTokens();
      final db = await DatabaseHelper.instance.database;
      await db.delete('operaciones');
      await SyncService.instance.iniciar(5);
    });

    tearDown(() => SyncService.instance.detener());

    test(
      'sin red guarda en el teléfono y al volver la red envía en orden',
      () async {
        final salida = DateTime.utc(2026, 11, 9, 12);
        await SyncService.instance.encolar(
          tipo: 'envio.ubicacion',
          envioId: 7,
          datos: {'envio': 7, 'latitud': '1.2', 'longitud': '-77.2'},
          ocurridoEn: salida.add(const Duration(seconds: 15)),
        );
        await SyncService.instance.encolar(
          tipo: 'envio.salida',
          envioId: 7,
          datos: {
            'envio': 7,
            'latitud': '1.2',
            'longitud': '-77.2',
            'foto': 'data:image/jpeg;base64,AAAA',
          },
          ocurridoEn: salida,
        );
        await SyncService.instance.sincronizar();
        expect(SyncService.instance.estado.value.enLinea, isFalse);
        expect(SyncService.instance.estado.value.pendientes, 2);
        expect(lotes, isEmpty);

        hayRed = true;
        await SyncService.instance.sincronizar();
        expect(lotes, hasLength(1));
        final ops = lotes.single['operaciones'] as List;
        // Orden cronológico por ocurrido_en, con uuid_cliente para idempotencia.
        expect(ops.map((o) => o['tipo']), ['envio.salida', 'envio.ubicacion']);
        expect(ops.first['uuid_cliente'], matches(RegExp(r'^[0-9a-f-]{36}$')));
        expect(SyncService.instance.estado.value.pendientes, 0);
        expect(SyncService.instance.estado.value.enLinea, isTrue);

        // La foto ya enviada no se vuelve a guardar en el teléfono.
        final historial = await SyncService.instance.historial();
        expect(historial.single.tipo, 'envio.salida');
        expect(historial.single.datos['foto'], '(enviada)');
      },
    );

    test(
      'las rechazadas quedan visibles con su motivo y se pueden descartar',
      () async {
        hayRed = true;
        await SyncService.instance.encolar(
          tipo: 'envio.llegada',
          envioId: 7,
          datos: {'envio': 7, 'latitud': '1.2', 'longitud': '-77.2'},
          resumen: 'Llegada',
        );
        await SyncService.instance.sincronizar();
        final h = await SyncService.instance.historial();
        expect(h.single.rechazada, isTrue);
        expect(h.single.motivoRechazo, contains('salida antes de la llegada'));
        expect(SyncService.instance.estado.value.rechazadas, 1);

        await SyncService.instance.descartar(h.single.uuid);
        expect(await SyncService.instance.historial(), isEmpty);
        expect(SyncService.instance.estado.value.rechazadas, 0);
      },
    );
  });
}
