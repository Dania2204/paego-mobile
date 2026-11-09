import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';

import '../../core/config/api_config.dart';
import '../models/envio.dart';
import '../remote/api_client.dart';
import '../repositories/envio_repository.dart';

/// GPS del conductor.
///
/// Mientras la sesión de un conductor está abierta:
/// 1. Cada [ApiConfig.intervaloEnVivo] envía su posición a
///    `POST /api/monitoreo/mi-posicion/`; el administrador lo ve moverse en el
///    mapa "Hoy" de la web. Esta posición es efímera: sin red no se guarda.
/// 2. Si tiene un envío en tránsito, cada `intervalo_ubicacion_seg` (lo define
///    el servidor) guarda un punto del recorrido (RF-21) en la cola sin
///    conexión, así la ruta queda completa aunque se pierda la señal.
class RastreoService {
  RastreoService._();
  static final instance = RastreoService._();

  final _location = Location();

  /// Última posición conocida del teléfono.
  final posicion = ValueNotifier<LatLng?>(null);

  /// Mensaje de problema con el GPS (permiso negado, servicio apagado…).
  final problema = ValueNotifier<String?>(null);

  /// El conductor puede pausar la transmisión en vivo.
  final transmitiendo = ValueNotifier<bool>(false);

  /// Hora del último envío exitoso de la posición en vivo.
  final ultimoEnvio = ValueNotifier<DateTime?>(null);

  LocationData? _ultimo;
  StreamSubscription<LocationData>? _sub;
  Timer? _timerVivo;
  Timer? _timerRecorrido;
  bool _esConductor = false;
  bool _enviandoVivo = false;
  Duration _intervaloRecorrido = ApiConfig.intervaloRecorridoPorDefecto;

  /// Pide permisos y empieza a escuchar el GPS. Para conductores, además
  /// transmite la posición en vivo y los puntos del recorrido.
  Future<void> iniciar({required bool esConductor}) async {
    await detener();
    _esConductor = esConductor;
    if (!await _pedirPermisos()) return;

    try {
      await _location.changeSettings(
        accuracy: LocationAccuracy.high,
        interval: 2000,
        distanceFilter: 0,
      );
    } catch (_) {
      // En web no todas las opciones aplican.
    }

    try {
      _aplicar(await _location.getLocation());
    } catch (_) {
      problema.value = 'No se pudo leer la ubicación actual.';
    }
    _sub = _location.onLocationChanged.listen(
      _aplicar,
      onError: (_) =>
          problema.value = 'No se puede mantener la ubicación actualizada.',
    );

    if (!esConductor) return;
    transmitiendo.value = true;
    await _cargarConfiguracion();
    _timerVivo = Timer.periodic(
      ApiConfig.intervaloEnVivo,
      (_) => _enviarEnVivo(),
    );
    _timerRecorrido = Timer.periodic(
      _intervaloRecorrido,
      (_) => _guardarPuntoRecorrido(),
    );
    unawaited(_enviarEnVivo());
  }

  Future<void> detener() async {
    _timerVivo?.cancel();
    _timerRecorrido?.cancel();
    _timerVivo = null;
    _timerRecorrido = null;
    await _sub?.cancel();
    _sub = null;
    transmitiendo.value = false;
    _esConductor = false;
  }

  void pausarTransmision() => transmitiendo.value = false;

  void reanudarTransmision() {
    if (!_esConductor) return;
    transmitiendo.value = true;
    unawaited(_enviarEnVivo());
  }

  /// Vuelve a pedir los permisos (botón "Reintentar" en la UI).
  Future<void> reintentar() => iniciar(esConductor: _esConductor);

  Future<bool> _pedirPermisos() async {
    try {
      var servicio = await _location.serviceEnabled();
      if (!servicio) servicio = await _location.requestService();
      if (!servicio) {
        problema.value = 'El GPS del teléfono está apagado.';
        return false;
      }
      var permiso = await _location.hasPermission();
      if (permiso == PermissionStatus.denied) {
        permiso = await _location.requestPermission();
      }
      if (permiso != PermissionStatus.granted &&
          permiso != PermissionStatus.grantedLimited) {
        problema.value = 'Se necesita permiso de ubicación para el rastreo.';
        return false;
      }
      problema.value = null;
      return true;
    } catch (_) {
      problema.value = 'No se pudo acceder al GPS.';
      return false;
    }
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final conf = await ApiClient.instance.get(
        '/sincronizacion/configuracion/',
      );
      final seg = (conf as Map)['intervalo_ubicacion_seg'];
      if (seg is int && seg > 0) _intervaloRecorrido = Duration(seconds: seg);
    } catch (_) {
      // Sin red: se usa el intervalo por defecto.
    }
  }

  void _aplicar(LocationData d) {
    if (d.latitude == null || d.longitude == null) return;
    _ultimo = d;
    problema.value = null;
    posicion.value = LatLng(d.latitude!, d.longitude!);
  }

  Map<String, dynamic> _cuerpo(LocationData d) {
    final rumbo = d.heading;
    final velocidad = d.speed;
    final precision = d.accuracy;
    return {
      'latitud': d.latitude!.toStringAsFixed(6),
      'longitud': d.longitude!.toStringAsFixed(6),
      if (precision != null && precision >= 0 && precision < 99999)
        'precision_m': precision.toStringAsFixed(2),
      if (velocidad != null && velocidad >= 0)
        'velocidad_kmh': (velocidad * 3.6).toStringAsFixed(2),
      if (rumbo != null && rumbo >= 0) 'rumbo': rumbo.round() % 360,
    };
  }

  Future<void> _enviarEnVivo() async {
    final d = _ultimo;
    if (d == null || !transmitiendo.value || _enviandoVivo) return;
    _enviandoVivo = true;
    try {
      await ApiClient.instance.post(
        '/monitoreo/mi-posicion/',
        cuerpo: _cuerpo(d),
      );
      ultimoEnvio.value = DateTime.now();
    } catch (_) {
      // Sin red o sesión vencida: la posición en vivo simplemente no se actualiza.
    } finally {
      _enviandoVivo = false;
    }
  }

  Future<void> _guardarPuntoRecorrido() async {
    final d = _ultimo;
    if (d == null) return;
    final enCamino = EnvioRepository.instance.envios.value.where(
      (e) => e.estado == EstadoEnvio.enTransito && e.llegadaEn == null,
    );
    final cuerpo = _cuerpo(d);
    for (final envio in enCamino) {
      try {
        await EnvioRepository.instance.registrarUbicacion(
          envio.id,
          lat: d.latitude!,
          lng: d.longitude!,
          precision: cuerpo['precision_m'] == null
              ? null
              : double.parse(cuerpo['precision_m']),
          velocidadKmh: cuerpo['velocidad_kmh'] == null
              ? null
              : double.parse(cuerpo['velocidad_kmh']),
          rumbo: cuerpo['rumbo'] as int?,
        );
      } catch (_) {
        // La sesión se cerró mientras tanto.
      }
    }
  }
}
