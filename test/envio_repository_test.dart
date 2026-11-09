import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opaego/data/datasources/database_helper.dart';
import 'package:opaego/data/models/envio.dart';
import 'package:opaego/data/remote/api_client.dart';
import 'package:opaego/data/repositories/envio_repository.dart';
import 'package:opaego/data/sync/sync_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'datos_prueba.dart';

http.Response _json(Object cuerpo) => http.Response(
  jsonEncode(cuerpo),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = EnvioRepository.instance;
  late List<Map<String, dynamic>> enServidor;
  late List<Map<String, dynamic>> lotes;
  late List<Uri> consultas;
  var hayRed = true;

  setUpAll(() async {
    sqfliteFfiInit();
    DatabaseHelper.nombreArchivo = 'prueba_envios.db';
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
    enServidor = [envioJson()];
    lotes = [];
    consultas = [];
    hayRed = true;
    ApiClient.usarCliente(
      MockClient((r) async {
        if (!hayRed) throw http.ClientException('sin red');
        if (r.url.path == '/api/envios/') {
          consultas.add(r.url);
          return _json({'count': 1, 'next': null, 'results': enServidor});
        }
        if (r.url.path == '/api/sincronizacion/lote/') {
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
    await db.delete('envios_cache');
    await SyncService.instance.iniciar(5);
    await repo.iniciar(5);
  });

  tearDown(() async {
    await repo.detener();
    await SyncService.instance.detener();
  });

  test('descarga los envíos de 30 días y los deja en caché', () async {
    final lista = await repo.refrescar();
    expect(lista.single.codigo, 'ENV-2026-0007');
    expect(repo.porId(7)?.estado, EstadoEnvio.asignado);
    expect(repo.porId(99), isNull);
    final q = consultas.single.queryParameters;
    expect(q['ordering'], '-programado_para');
    expect(q['fecha_desde'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

    // Otra sesión sin red: abre desde la caché del teléfono.
    await repo.detener();
    hayRed = false;
    await repo.iniciar(5);
    expect(repo.envios.value.single.id, 7);
    // Cada usuario ve solo su caché.
    await repo.iniciar(6);
    expect(repo.envios.value, isEmpty);
  });

  test('sin red la salida se ve al instante y queda en cola', () async {
    await repo.refrescar();
    hayRed = false;
    await repo.registrarSalida(repo.porId(7)!, lat: 1.2136, lng: -77.2811);

    final envio = repo.porId(7)!;
    expect(envio.estado, EstadoEnvio.enTransito);
    expect(envio.salidaEn, isNotNull);
    final pendiente = (await SyncService.instance.pendientes()).single;
    expect(pendiente.tipo, 'envio.salida');
    expect(pendiente.datos, {
      'latitud': '1.213600',
      'longitud': '-77.281100',
      'envio': 7,
    });

    // El servidor todavía no lo sabe: al recargar se mantiene el cambio local.
    hayRed = true;
    final otraVez = await repo.refrescar();
    expect(otraVez.single.estado, EstadoEnvio.enTransito);
  });

  test('al aplicarse el lote recarga el estado real del servidor', () async {
    await repo.refrescar();
    // El servidor ya registró la llegada cuando aplique el lote.
    enServidor = [
      envioJson(estado: 'EN_TRANSITO')..['llegada_en'] = '2026-11-09T13:00:00Z',
    ];
    await repo.registrarLlegada(repo.porId(7)!, lat: 1.2145, lng: -77.2811);
    await SyncService.instance.sincronizar();
    // La llegada optimista no cambia el estado (sigue ASIGNADO en caché):
    // EN_TRANSITO solo puede venir de la recarga tras aplicarse el lote.
    for (
      var i = 0;
      i < 100 && repo.porId(7)!.estado != EstadoEnvio.enTransito;
      i++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(lotes, isNotEmpty);
    expect(await SyncService.instance.pendientes(), isEmpty);
    expect(repo.porId(7)!.estado, EstadoEnvio.enTransito);
    expect(repo.porId(7)!.llegadaEn, isNotNull);
  });

  test(
    'confirmar recepción envía ítems, código, evidencia y novedad',
    () async {
      await repo.refrescar();
      hayRed = false;
      await repo.confirmarRecepcion(
        repo.porId(7)!,
        recibidos: {11: 118},
        recibidoPorNombre: 'Rectora',
        recibidoPorCargo: 'Rectora',
        codigoVerificacion: '482913',
        fotoBase64: 'data:image/jpeg;base64,AAAA',
        lat: 1.2145,
        lng: -77.2811,
        tipoNovedad: TipoNovedad.values.first,
        descripcionNovedad: '  Faltaron dos  ',
      );
      expect(repo.porId(7)!.estado, EstadoEnvio.entregado);
      final datos = (await SyncService.instance.pendientes()).single.datos;
      expect(datos['items'], [
        {'item': 11, 'cantidad_recibida': '118.00'},
      ]);
      expect(datos['codigo_verificacion'], '482913');
      expect(datos['foto'], startsWith('data:image/jpeg'));
      expect(datos['novedad'], {
        'tipo': TipoNovedad.values.first.api,
        'descripcion': 'Faltaron dos',
      });
    },
  );

  test(
    'sin descripción no manda novedad; novedad suelta y punto de ruta',
    () async {
      await repo.refrescar();
      hayRed = false;
      final envio = repo.porId(7)!;
      await repo.confirmarRecepcion(
        envio,
        recibidos: {11: 120},
        recibidoPorNombre: 'Rectora',
        codigoVerificacion: '482913',
        descripcionNovedad: '   ',
      );
      await repo.reportarNovedad(
        envio,
        tipo: TipoNovedad.values.last,
        descripcion: 'Vía cerrada',
      );
      await repo.registrarUbicacion(
        7,
        lat: 1.21,
        lng: -77.28,
        precision: 5,
        velocidadKmh: 30,
        rumbo: 90,
      );
      final ops = await SyncService.instance.pendientes();
      final porTipo = {for (final o in ops) o.tipo: o.datos};
      expect(porTipo['envio.confirmar']!.containsKey('novedad'), isFalse);
      expect(porTipo['envio.novedad']!['descripcion'], 'Vía cerrada');
      expect(porTipo['envio.ubicacion'], {
        'envio': 7,
        'latitud': '1.210000',
        'longitud': '-77.280000',
        'precision_m': '5.00',
        'velocidad_kmh': '30.00',
        'rumbo': 90,
      });
    },
  );
}
