// Prueba de punta a punta contra el backend real de oPAEGo (no simulado).
//
// Usa las mismas clases que la app (AuthService, SyncService con su cola en
// SQLite, EnvioRepository) y recorre el flujo completo de un envío:
//   administrador crea → conductor sale (sin red, queda en cola) → sincroniza →
//   recorrido y llegada → el administrador lo ve en el mapa → la institución
//   confirma con el código de 6 dígitos → ENTREGADO.
//
// Necesita un backend con `seed_demo`:
//   PAEGO_E2E_URL=http://127.0.0.1:8000 flutter test test/e2e
// Sin PAEGO_E2E_URL las pruebas se saltan.
@Tags(['e2e'])
library;

import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:opaego/data/datasources/database_helper.dart';
import 'package:opaego/data/models/envio.dart';
import 'package:opaego/data/models/user_model.dart';
import 'package:opaego/data/remote/api_client.dart';
import 'package:opaego/data/repositories/auth_service.dart';
import 'package:opaego/data/repositories/envio_repository.dart';
import 'package:opaego/data/sync/sync_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

final _url = Platform.environment['PAEGO_E2E_URL'];
const _clave = 'Paego2026!';

/// Cliente HTTP real que se puede "desconectar" para simular la falta de red.
class _ClienteConCorte extends http.BaseClient {
  final _real = http.Client();
  bool sinRed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (sinRed) throw http.ClientException('sin red (simulado)');
    return _real.send(request);
  }
}

void main() {
  if (_url == null) {
    test('flujo completo', () {}, skip: 'Defina PAEGO_E2E_URL para correrla');
    return;
  }
  final red = _ClienteConCorte();
  final repo = EnvioRepository.instance;
  final sync = SyncService.instance;
  late int envioId;
  late String codigo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // flutter_test bloquea el HTTP real (responde 400); esta prueba lo necesita.
    HttpOverrides.global = null;
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseHelper.nombreArchivo = 'e2e.db';
    await databaseFactory.deleteDatabase(
      p.join(await getDatabasesPath(), DatabaseHelper.nombreArchivo),
    );
    dotenv.testLoad(fileInput: 'PAEGO_API_URL=$_url');
    SharedPreferences.setMockInitialValues({});
    ApiClient.usarCliente(red);
  });

  tearDown(() async {
    await repo.detener();
    await sync.detener();
  });

  Future<AppUser> entrar(String email) async {
    final r = await AuthService.instance.login(email: email, password: _clave);
    expect(r.error, isNull, reason: 'login de $email');
    final user = r.user!;
    await sync.iniciar(user.id!);
    await repo.iniciar(user.id!);
    return user;
  }

  /// Envía la cola y exige que el servidor haya aplicado todo.
  Future<void> sincronizarTodo() async {
    await sync.sincronizar();
    final rechazadas = (await sync.historial())
        .where((o) => o.estado == 'rechazado')
        .map((o) => '${o.tipo}: ${o.motivoRechazo}');
    expect(rechazadas, isEmpty);
    expect(await sync.pendientes(), isEmpty);
  }

  Future<int> idDe(String ruta, String buscar) async {
    final lista = await ApiClient.instance.getTodos(
      ruta,
      query: {'search': buscar},
    );
    expect(
      lista,
      isNotEmpty,
      reason: '$ruta?search=$buscar (¿corrió seed_demo?)',
    );
    return lista.first['id'] as int;
  }

  test('el administrador programa un envío', () async {
    await ApiClient.instance.iniciarSesion('admin@paego.local', _clave);
    final institucion = await idDe('/instituciones/', 'Escuela Normal');
    final conductor = await idDe('/conductores/', '1085000001');
    final vehiculo = await idDe('/vehiculos/', 'ABC123');

    final r = await ApiClient.instance.post(
      '/sincronizacion/lote/',
      cuerpo: {
        'operaciones': [
          {
            'uuid_cliente': nuevoUuid(),
            'tipo': 'envio.crear',
            'ocurrido_en': DateTime.now().toUtc().toIso8601String(),
            'datos': {
              'institucion': institucion,
              'conductor': conductor,
              'vehiculo': vehiculo,
              'programado_para': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toUtc()
                  .toIso8601String(),
              'observaciones': 'Prueba E2E automática',
              'items': [
                {'producto': 'Leche', 'cantidad': '120', 'unidad': 'UNIDAD'},
                {'producto': 'Pan', 'cantidad': '120', 'unidad': 'UNIDAD'},
              ],
            },
          },
        ],
      },
    );
    final resultado = (r['resultados'] as List).single as Map;
    expect(resultado['resultado'], 'ok', reason: '$resultado');
    envioId = (resultado['respuesta'] as Map)['id'] as int;
    await ApiClient.instance.cerrarSesion();
  });

  test('el conductor sale sin red, sincroniza, recorre y llega', () async {
    await entrar('conductor1@paego.local');
    await repo.refrescar();
    final envio = repo.porId(envioId)!;
    expect(envio.estado, EstadoEnvio.asignado);
    expect(envio.codigoVerificacion, matches(RegExp(r'^\d{6}$')));
    codigo = envio.codigoVerificacion!;

    // Sin red: la salida se ve al instante y queda en la cola (RF-38).
    red.sinRed = true;
    await repo.registrarSalida(envio, lat: 1.2080, lng: -77.2770);
    expect(repo.porId(envioId)!.estado, EstadoEnvio.enTransito);
    expect(await sync.pendientes(), hasLength(1));

    // Vuelve la red: se aplica en el servidor.
    red.sinRed = false;
    await sincronizarTodo();
    await repo.refrescar();
    expect(repo.porId(envioId)!.salidaEn, isNotNull);

    for (var k = 1; k <= 3; k++) {
      await repo.registrarUbicacion(
        envioId,
        lat: 1.2080 + 0.002 * k,
        lng: -77.2770 - 0.003 * k,
        precision: 5,
        velocidadKmh: 30,
        rumbo: 300,
      );
    }
    // Posición en vivo (la que transmite RastreoService cada 3 s).
    await ApiClient.instance.post(
      '/monitoreo/mi-posicion/',
      cuerpo: {'latitud': '1.214000', 'longitud': '-77.286000'},
    );
    await repo.registrarLlegada(
      repo.porId(envioId)!,
      lat: 1.2168,
      lng: -77.2883,
    );
    await sincronizarTodo();
    final llegado = (await repo.refrescar()).firstWhere((e) => e.id == envioId);
    expect(llegado.estado, EstadoEnvio.enTransito);
    expect(llegado.llegadaEn, isNotNull);
  });

  test('el administrador lo ve en el mapa', () async {
    await ApiClient.instance.iniciarSesion('admin@paego.local', _clave);
    final enTransito =
        (await ApiClient.instance.get('/monitoreo/en-transito/') as List)
            .cast<Map<String, dynamic>>();
    final enMapa = enTransito.firstWhere((e) => e['id'] == envioId);
    // Punto de salida + 3 del recorrido + llegada.
    expect((enMapa['ruta'] as List).length, greaterThanOrEqualTo(4));

    final enVivo =
        (await ApiClient.instance.get('/monitoreo/conductores-en-vivo/')
                as List)
            .cast<Map<String, dynamic>>();
    expect(enVivo.map((c) => c['placa']), contains('ABC123'));
    await ApiClient.instance.cerrarSesion();
  });

  test(
    'la institución confirma la recepción con el código del conductor',
    () async {
      await entrar('institucion1@paego.local');
      await repo.refrescar();
      final envio = repo.porId(envioId)!;
      expect(envio.puedeConfirmar, isTrue);
      // La institución no ve el código: debe dárselo el conductor.
      expect(envio.codigoVerificacion, isNull);

      await repo.confirmarRecepcion(
        envio,
        recibidos: {for (final i in envio.items) i.id: i.cantidad},
        recibidoPorNombre: 'María Rosero',
        recibidoPorCargo: 'Almacenista',
        codigoVerificacion: codigo,
        lat: 1.2168,
        lng: -77.2883,
      );
      await sincronizarTodo();
      final entregado = (await repo.refrescar()).firstWhere(
        (e) => e.id == envioId,
      );
      expect(entregado.estado, EstadoEnvio.entregado);
      expect(entregado.entregadoEn, isNotNull);
      await AuthService.instance.logout();
    },
  );
}
