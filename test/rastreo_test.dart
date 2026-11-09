import 'dart:async';
import 'dart:convert';

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
  Future<PermissionStatus> requestPermission() async => permiso;

  @override
  Future<bool> changeSettings({
    LocationAccuracy? accuracy = LocationAccuracy.high,
    int? interval = 1000,
    double? distanceFilter = 0,
  }) async => true;

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
}
