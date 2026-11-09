import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:shared_preferences/shared_preferences.dart';

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
/// 3. Con el modo en segundo plano (Android: servicio en primer plano con
///    notificación, permiso "Permitir todo el tiempo") sigue rastreando con la
///    pantalla bloqueada o en otra app. Lo activa el conductor una vez desde el
///    mapa; después se reactiva solo en cada sesión.
class RastreoService {
  RastreoService._();
  static final instance = RastreoService._();

  Location _location = Location();

  /// Cada cuánto se revisa, sin mostrar diálogos, si ya se puede usar el GPS
  /// cuando al iniciar estaba apagado o sin permiso.
  @visibleForTesting
  Duration intervaloReintento = const Duration(seconds: 5);

  @visibleForTesting
  void usarLocation(Location location) => _location = location;

  /// Última posición conocida del teléfono.
  final posicion = ValueNotifier<LatLng?>(null);

  /// Mensaje de problema con el GPS (permiso negado, servicio apagado…).
  final problema = ValueNotifier<String?>(null);

  /// El conductor puede pausar la transmisión en vivo.
  final transmitiendo = ValueNotifier<bool>(false);

  /// Hora del último envío exitoso de la posición en vivo.
  final ultimoEnvio = ValueNotifier<DateTime?>(null);

  /// El rastreo sigue con la pantalla bloqueada (modo en segundo plano).
  final segundoPlano = ValueNotifier<bool>(false);

  /// El conductor ya aceptó el modo en segundo plano alguna vez.
  static const _kSegundoPlano = 'paego_segundo_plano';

  /// En web no hay servicio en segundo plano.
  bool get soportaSegundoPlano => _soportaSegundoPlano;
  bool _soportaSegundoPlano = !kIsWeb;
  @visibleForTesting
  set soportaSegundoPlano(bool valor) => _soportaSegundoPlano = valor;

  /// Pide "Permitir todo el tiempo". Android 11+ exige pedirlo solo, después
  /// del permiso normal (el plugin location los pide juntos y el sistema lo
  /// ignora); en Android abre los ajustes de ubicación de la app.
  @visibleForTesting
  Future<bool> Function() pedirPermisoSiempre = () async {
    final estado = await ph.Permission.locationAlways.request();
    // Android 13+: sin este permiso la notificación del servicio no se ve.
    await ph.Permission.notification.request();
    return estado.isGranted;
  };

  LocationData? _ultimo;
  StreamSubscription<LocationData>? _sub;
  Timer? _timerVivo;
  Timer? _timerRecorrido;
  Timer? _timerReintento;
  bool _esConductor = false;
  bool _enviandoVivo = false;
  bool _revisando = false;

  /// Ya se mostró el diálogo de permiso en este intento de arranque.
  bool _permisoPedido = false;
  Duration _intervaloRecorrido = ApiConfig.intervaloRecorridoPorDefecto;

  /// Cambia en cada iniciar/detener: invalida los arranques que estaban en
  /// curso (por ejemplo, si se cierra la sesión mientras se espera el GPS).
  int _generacion = 0;

  /// El GPS está entregando posiciones.
  bool get escuchando => _sub != null;

  /// Pide permisos y empieza a escuchar el GPS. Para conductores, además
  /// transmite la posición en vivo y los puntos del recorrido.
  ///
  /// Si el GPS está apagado o falta el permiso, no se rinde: revisa cada
  /// [intervaloReintento] y arranca solo en cuanto el conductor lo active.
  Future<void> iniciar({required bool esConductor}) async {
    await detener();
    final gen = ++_generacion;
    _esConductor = esConductor;
    if (esConductor) transmitiendo.value = true;
    _permisoPedido = false;
    if (!await _pedirPermisos(pedirServicio: true, pedirPermiso: true)) {
      if (gen == _generacion) _esperarGps(gen);
      return;
    }
    if (gen != _generacion) return;
    await _arrancar(gen);
  }

  void _esperarGps(int gen) {
    _timerReintento?.cancel();
    _timerReintento = Timer.periodic(intervaloReintento, (t) async {
      if (gen != _generacion) {
        t.cancel();
        return;
      }
      if (_revisando) return;
      _revisando = true;
      try {
        // No insiste con "activar GPS", pero si el GPS ya está encendido y el
        // permiso nunca se pidió (estaba apagado al iniciar), lo pide una vez.
        final listo = await _pedirPermisos(
          pedirServicio: false,
          pedirPermiso: !_permisoPedido,
        );
        if (listo && gen == _generacion) {
          t.cancel();
          _timerReintento = null;
          await _arrancar(gen);
        }
      } finally {
        _revisando = false;
      }
    });
  }

  Future<void> _arrancar(int gen) async {
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
    if (gen != _generacion) return;
    _sub = _location.onLocationChanged.listen(
      _aplicar,
      onError: (_) =>
          problema.value = 'No se puede mantener la ubicación actualizada.',
    );

    if (!_esConductor) return;
    if (await _aceptoSegundoPlano() && gen == _generacion) {
      await _activarSegundoPlano(); // Permiso ya concedido: no muestra diálogos.
    }
    if (gen != _generacion) return;
    await _cargarConfiguracion();
    if (gen != _generacion) return;
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
    _generacion++;
    _timerVivo?.cancel();
    _timerRecorrido?.cancel();
    _timerReintento?.cancel();
    _timerVivo = null;
    _timerRecorrido = null;
    _timerReintento = null;
    await _sub?.cancel();
    _sub = null;
    if (segundoPlano.value) {
      segundoPlano.value = false;
      try {
        await _location.enableBackgroundMode(enable: false);
      } catch (_) {}
    }
    transmitiendo.value = false;
    _esConductor = false;
  }

  void pausarTransmision() => transmitiendo.value = false;

  void reanudarTransmision() {
    if (!_esConductor) return;
    transmitiendo.value = true;
    // Si el GPS nunca arrancó, "Reanudar" vuelve a pedirlo de inmediato.
    if (!escuchando) {
      unawaited(reintentar());
      return;
    }
    unawaited(_enviarEnVivo());
  }

  /// El conductor pide seguir rastreando con la pantalla bloqueada (botón del
  /// mapa). Android muestra el permiso "Permitir todo el tiempo".
  Future<bool> activarSegundoPlano() async {
    if (!_esConductor || !escuchando || !soportaSegundoPlano) return false;
    try {
      if (!await pedirPermisoSiempre()) return false;
    } catch (_) {
      return false;
    }
    final ok = await _activarSegundoPlano();
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSegundoPlano, true);
    }
    return ok;
  }

  Future<bool> _aceptoSegundoPlano() async {
    if (!soportaSegundoPlano) return false;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSegundoPlano) ?? false;
  }

  Future<bool> _activarSegundoPlano() async {
    if (!soportaSegundoPlano) return false;
    try {
      await _location.changeNotificationOptions(
        channelName: 'Rastreo del recorrido',
        title: 'PAEGo está compartiendo tu ubicación',
        subtitle: 'El recorrido del envío sigue registrándose.',
        iconName: 'ic_stat_paego',
        onTapBringToFront: true,
      );
      segundoPlano.value = await _location.enableBackgroundMode(enable: true);
    } catch (_) {
      // Permiso negado: el rastreo sigue, pero solo con la app abierta.
      segundoPlano.value = false;
    }
    return segundoPlano.value;
  }

  /// Vuelve a pedir los permisos (botón "Reintentar" en la UI).
  Future<void> reintentar() => iniciar(esConductor: _esConductor);

  /// [pedirServicio] y [pedirPermiso] muestran los diálogos del sistema
  /// (activar GPS, conceder permiso); sin ellos solo se consulta el estado,
  /// para revisar en segundo plano sin interrumpir al conductor.
  Future<bool> _pedirPermisos({
    required bool pedirServicio,
    required bool pedirPermiso,
  }) async {
    try {
      var servicio = await _location.serviceEnabled();
      if (!servicio && pedirServicio) {
        servicio = await _location.requestService();
      }
      if (!servicio) {
        problema.value = 'El GPS del teléfono está apagado.';
        return false;
      }
      var permiso = await _location.hasPermission();
      if (permiso == PermissionStatus.denied && pedirPermiso) {
        _permisoPedido = true;
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
