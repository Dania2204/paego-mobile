import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:location/location.dart';
import 'package:opaego/data/remote/api_client.dart';
import 'package:opaego/data/services/rastreo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GPS simulado: se puede apagar/encender y negar/dar el permiso.
class _GpsFalso extends Fake implements Location {
  bool encendido = false;
  PermissionStatus permiso = PermissionStatus.granted;
  int dialogosServicio = 0;
  int dialogosPermiso = 0;

  /// Lo que responde el conductor si se le pide el permiso.
  PermissionStatus respuestaPermiso = PermissionStatus.denied;

  /// Segundo plano: si concede "Permitir todo el tiempo" y llamadas recibidas.
  bool permiteSegundoPlano = true;
  bool enSegundoPlano = false;
  final llamadasSegundoPlano = <bool>[];
  int dialogosSiempre = 0;
  String? iconoNotificacion;
  final _posiciones = StreamController<LocationData>.broadcast();

  static LocationData punto(double lat, double lng) =>
      LocationData.fromMap({'latitude': lat, 'longitude': lng});

  void mover(double lat, double lng) => _posiciones.add(punto(lat, lng));

  @override
  Future<bool> serviceEnabled() async => encendido;

  @override
  Future<bool> requestService() async {
    dialogosServicio++;
    return encendido; // El conductor dice "No, gracias".
  }

  @override
  Future<PermissionStatus> hasPermission() async => permiso;

  @override
  Future<PermissionStatus> requestPermission() async {
    dialogosPermiso++;
    if (respuestaPermiso == PermissionStatus.granted) {
      permiso = respuestaPermiso;
    }
    return permiso;
  }

  @override
  Future<bool> changeSettings({
    LocationAccuracy? accuracy = LocationAccuracy.high,
    int? interval = 1000,
    double? distanceFilter = 0,
  }) async => true;

  @override
  Future<bool> enableBackgroundMode({bool? enable = true}) async {
    llamadasSegundoPlano.add(enable ?? true);
    if (enable == true && !permiteSegundoPlano) {
      throw PlatformException(code: 'PERMISSION_DENIED');
    }
    return enSegundoPlano = enable ?? true;
  }

  @override
  // AndroidNotificationData no se exporta desde package:location.
  // ignore: prefer_void_to_null
  Future<Null> changeNotificationOptions({
    String? channelName,
    String? title,
    String? iconName,
    String? subtitle,
    String? description,
    Color? color,
    bool? onTapBringToFront,
  }) async {
    iconoNotificacion = iconName;
    return null;
  }

  @override
  Future<LocationData> getLocation() async => punto(1.2136, -77.2811);

  @override
  Stream<LocationData> get onLocationChanged => _posiciones.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final rastreo = RastreoService.instance;
  late _GpsFalso gps;
  late List<String> rutas;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'paego_access': 'A1',
      'paego_refresh': 'R1',
    });
    gps = _GpsFalso();
    rutas = [];
    rastreo
      ..soportaSegundoPlano = true
      ..pedirPermisoSiempre = () async {
        gps.dialogosSiempre++;
        return gps.permiteSegundoPlano;
      }
      ..usarLocation(gps)
      ..intervaloReintento = const Duration(milliseconds: 20);
    rastreo.posicion.value = null;
    rastreo.problema.value = null;
    ApiClient.usarCliente(
      MockClient((r) async {
        rutas.add(r.url.path);
        if (r.url.path.endsWith('/configuracion/')) {
          return http.Response(
            jsonEncode({'intervalo_ubicacion_seg': 15}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('', 204);
      }),
    );
    await ApiClient.instance.cargarTokens();
  });

  tearDown(() => rastreo.detener());

  Future<void> esperar(bool Function() condicion) async {
    for (var i = 0; i < 100 && !condicion(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  test('con el GPS apagado al iniciar, arranca solo al encenderlo', () async {
    await rastreo.iniciar(esConductor: true);
    expect(rastreo.escuchando, isFalse);
    expect(rastreo.problema.value, contains('apagado'));
    expect(rastreo.transmitiendo.value, isTrue);
    expect(gps.dialogosServicio, 1);

    gps.encendido = true; // El conductor activa la ubicación más tarde.
    await esperar(() => rutas.contains('/api/monitoreo/mi-posicion/'));

    expect(rastreo.escuchando, isTrue);
    expect(rastreo.problema.value, isNull);
    expect(rastreo.posicion.value?.latitude, 1.2136);
    expect(rutas, contains('/api/monitoreo/mi-posicion/'));
    // La revisión en segundo plano no vuelve a mostrar el diálogo.
    expect(gps.dialogosServicio, 1);

    gps.mover(1.2168, -77.2883);
    await esperar(() => rastreo.posicion.value?.latitude == 1.2168);
    expect(rastreo.posicion.value?.longitude, -77.2883);
  });

  test('también espera a que se conceda el permiso', () async {
    gps
      ..encendido = true
      ..permiso = PermissionStatus.denied;
    await rastreo.iniciar(esConductor: false);
    expect(rastreo.escuchando, isFalse);
    expect(rastreo.problema.value, contains('permiso'));

    gps.permiso = PermissionStatus.granted;
    await esperar(() => rastreo.escuchando);
    expect(rastreo.escuchando, isTrue);
    expect(rastreo.posicion.value, isNotNull);
  });

  test(
    'instalación nueva: al encender el GPS pide el permiso una vez',
    () async {
      gps
        ..permiso = PermissionStatus.denied
        ..respuestaPermiso = PermissionStatus.granted;
      await rastreo.iniciar(esConductor: true);
      // Con el GPS apagado no llega a pedir el permiso.
      expect(gps.dialogosPermiso, 0);

      gps.encendido = true;
      await esperar(() => rutas.contains('/api/monitoreo/mi-posicion/'));
      expect(gps.dialogosPermiso, 1);
      expect(rastreo.escuchando, isTrue);
      expect(rastreo.problema.value, isNull);
    },
  );

  test('si niega el permiso no vuelve a preguntar solo', () async {
    gps.permiso = PermissionStatus.denied;
    await rastreo.iniciar(esConductor: false);
    gps.encendido = true;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(gps.dialogosPermiso, 1);
    expect(rastreo.escuchando, isFalse);
    expect(rastreo.problema.value, contains('permiso'));
  });

  test('al cerrar sesión deja de esperar el GPS', () async {
    await rastreo.iniciar(esConductor: true);
    await rastreo.detener();
    gps.encendido = true;
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(rastreo.escuchando, isFalse);
    expect(rutas, isEmpty);
  });

  test('"Reanudar" arranca el GPS si nunca llegó a arrancar', () async {
    rastreo.intervaloReintento = const Duration(hours: 1);
    await rastreo.iniciar(esConductor: true);
    rastreo.pausarTransmision();
    gps.encendido = true;

    rastreo.reanudarTransmision();
    await esperar(() => rastreo.escuchando);
    expect(rastreo.escuchando, isTrue);
    expect(rastreo.transmitiendo.value, isTrue);
  });

  group('segundo plano', () {
    Future<void> conductorConGps() async {
      gps.encendido = true;
      await rastreo.iniciar(esConductor: true);
      await esperar(() => rutas.contains('/api/monitoreo/mi-posicion/'));
    }

    test('no se activa solo la primera vez', () async {
      await conductorConGps();
      expect(gps.llamadasSegundoPlano, isEmpty);
      expect(rastreo.segundoPlano.value, isFalse);
    });

    test(
      'el conductor lo activa y queda recordado para la próxima sesión',
      () async {
        await conductorConGps();
        expect(await rastreo.activarSegundoPlano(), isTrue);
        expect(rastreo.segundoPlano.value, isTrue);
        expect(gps.iconoNotificacion, 'ic_stat_paego');

        await rastreo.detener(); // Cerrar sesión apaga el servicio.
        expect(gps.enSegundoPlano, isFalse);
        expect(rastreo.segundoPlano.value, isFalse);

        gps.llamadasSegundoPlano.clear();
        await conductorConGps(); // Nueva sesión: se reactiva sin preguntar.
        expect(gps.llamadasSegundoPlano, [true]);
        expect(rastreo.segundoPlano.value, isTrue);
      },
    );

    test('si niega el permiso el rastreo sigue con la app abierta', () async {
      gps.permiteSegundoPlano = false;
      await conductorConGps();
      expect(await rastreo.activarSegundoPlano(), isFalse);
      expect(gps.dialogosSiempre, 1);
      expect(gps.llamadasSegundoPlano, isEmpty);
      expect(rastreo.segundoPlano.value, isFalse);
      expect(rastreo.escuchando, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('paego_segundo_plano'), isNull);
    });

    test('la institución no usa el segundo plano', () async {
      gps.encendido = true;
      await rastreo.iniciar(esConductor: false);
      await esperar(() => rastreo.escuchando);
      expect(await rastreo.activarSegundoPlano(), isFalse);
      expect(gps.llamadasSegundoPlano, isEmpty);
      expect(gps.dialogosSiempre, 0);
    });
  });
}
