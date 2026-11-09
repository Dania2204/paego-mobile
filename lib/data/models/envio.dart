import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/l10n/app_strings.dart';

/// Estados del envío tal como los define el backend (RF-18).
enum EstadoEnvio { asignado, enTransito, entregado, conNovedad, cancelado }

extension EstadoEnvioX on EstadoEnvio {
  static const _api = {
    EstadoEnvio.asignado: 'ASIGNADO',
    EstadoEnvio.enTransito: 'EN_TRANSITO',
    EstadoEnvio.entregado: 'ENTREGADO',
    EstadoEnvio.conNovedad: 'CON_NOVEDAD',
    EstadoEnvio.cancelado: 'CANCELADO',
  };

  String get api => _api[this]!;

  static EstadoEnvio desdeApi(String? valor) => _api.entries
      .firstWhere((e) => e.value == valor, orElse: () => _api.entries.first)
      .key;

  String get label {
    switch (this) {
      case EstadoEnvio.asignado:
        return S.text('envio.estado.asignado', 'Asignado', 'Assigned');
      case EstadoEnvio.enTransito:
        return S.text('envio.estado.en_transito', 'En tránsito', 'In transit');
      case EstadoEnvio.entregado:
        return S.text('envio.estado.entregado', 'Entregado', 'Delivered');
      case EstadoEnvio.conNovedad:
        return S.text('envio.estado.con_novedad', 'Con novedad', 'With issue');
      case EstadoEnvio.cancelado:
        return S.text('envio.estado.cancelado', 'Cancelado', 'Cancelled');
    }
  }

  Color get color {
    switch (this) {
      case EstadoEnvio.asignado:
        return PaeColors.statusAssigned;
      case EstadoEnvio.enTransito:
        return PaeColors.statusEnRoute;
      case EstadoEnvio.entregado:
        return PaeColors.statusDelivered;
      case EstadoEnvio.conNovedad:
        return PaeColors.warning;
      case EstadoEnvio.cancelado:
        return PaeColors.inactive;
    }
  }

  bool get esActivo =>
      this == EstadoEnvio.asignado || this == EstadoEnvio.enTransito;
}

/// Tipos de novedad del backend (`Novedad.Tipo`).
enum TipoNovedad { retraso, dano, faltante, incidente, entregaIncompleta }

extension TipoNovedadX on TipoNovedad {
  String get api => const {
    TipoNovedad.retraso: 'RETRASO',
    TipoNovedad.dano: 'DANO',
    TipoNovedad.faltante: 'FALTANTE',
    TipoNovedad.incidente: 'INCIDENTE',
    TipoNovedad.entregaIncompleta: 'ENTREGA_INCOMPLETA',
  }[this]!;

  String get label {
    switch (this) {
      case TipoNovedad.retraso:
        return S.text('novedad.tipo.retraso', 'Retraso', 'Delay');
      case TipoNovedad.dano:
        return S.text('novedad.tipo.dano', 'Daño', 'Damage');
      case TipoNovedad.faltante:
        return S.text('novedad.tipo.faltante', 'Faltante', 'Missing items');
      case TipoNovedad.incidente:
        return S.text('novedad.tipo.incidente', 'Incidente', 'Incident');
      case TipoNovedad.entregaIncompleta:
        return S.text(
          'novedad.tipo.entrega_incompleta',
          'Entrega incompleta',
          'Incomplete delivery',
        );
    }
  }
}

double? _num(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _fecha(dynamic v) =>
    v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

class InstitucionResumen {
  InstitucionResumen({
    required this.id,
    required this.nombre,
    this.sede = '',
    this.direccion = '',
    this.latitud,
    this.longitud,
    this.telefono = '',
  });

  final int id;
  final String nombre;
  final String sede;
  final String direccion;
  final double? latitud;
  final double? longitud;
  final String telefono;

  LatLng? get latLng =>
      latitud != null && longitud != null ? LatLng(latitud!, longitud!) : null;

  String get nombreCompleto => sede.isEmpty ? nombre : '$nombre · $sede';

  factory InstitucionResumen.fromJson(Map<String, dynamic> j) =>
      InstitucionResumen(
        id: j['id'] as int,
        nombre: j['nombre'] as String? ?? '',
        sede: j['sede'] as String? ?? '',
        direccion: j['direccion'] as String? ?? '',
        latitud: _num(j['latitud']),
        longitud: _num(j['longitud']),
        telefono: j['contacto_telefono'] as String? ?? '',
      );
}

class ItemEnvio {
  ItemEnvio({
    required this.id,
    required this.producto,
    required this.cantidad,
    required this.unidad,
    required this.unidadNombre,
    this.cantidadRecibida,
  });

  final int id;
  final String producto;
  final double cantidad;
  final String unidad;
  final String unidadNombre;
  final double? cantidadRecibida;

  /// Cantidad como texto sin decimales innecesarios ("12" en vez de "12.00").
  static String formatear(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  factory ItemEnvio.fromJson(Map<String, dynamic> j) => ItemEnvio(
    id: j['id'] as int,
    producto: j['producto'] as String? ?? '',
    cantidad: _num(j['cantidad']) ?? 0,
    unidad: j['unidad'] as String? ?? '',
    unidadNombre: j['unidad_nombre'] as String? ?? '',
    cantidadRecibida: _num(j['cantidad_recibida']),
  );
}

/// Envío tal como lo devuelve `GET /api/envios/` (EnvioSerializer).
/// Se guarda el JSON completo en caché para trabajar sin conexión.
class Envio {
  Envio(this.json)
    : id = json['id'] as int,
      codigo = json['codigo'] as String? ?? '',
      estado = EstadoEnvioX.desdeApi(json['estado'] as String?),
      programadoPara = _fecha(json['programado_para']),
      institucion = InstitucionResumen.fromJson(
        (json['institucion'] as Map).cast<String, dynamic>(),
      ),
      conductorId = json['conductor_id'] as int?,
      conductorNombre = json['conductor_nombre'] as String? ?? '',
      conductorTelefono = json['conductor_telefono'] as String? ?? '',
      vehiculoPlaca = json['vehiculo_placa'] as String?,
      observaciones = json['observaciones'] as String? ?? '',
      codigoVerificacion = json['codigo_verificacion'] as String?,
      items = ((json['items'] as List?) ?? const [])
          .map((e) => ItemEnvio.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      salidaEn = _fecha(json['salida_en']),
      llegadaEn = _fecha(json['llegada_en']),
      entregadoEn = _fecha(json['entregado_en']),
      estaRetrasado = json['esta_retrasado'] as bool? ?? false;

  final Map<String, dynamic> json;
  final int id;
  final String codigo;
  final EstadoEnvio estado;
  final DateTime? programadoPara;
  final InstitucionResumen institucion;
  final int? conductorId;
  final String conductorNombre;
  final String conductorTelefono;
  final String? vehiculoPlaca;
  final String observaciones;

  /// Solo lo ve el conductor (y el administrador); la institución debe digitarlo.
  final String? codigoVerificacion;
  final List<ItemEnvio> items;
  final DateTime? salidaEn;
  final DateTime? llegadaEn;
  final DateTime? entregadoEn;
  final bool estaRetrasado;

  bool get puedeSalir => estado == EstadoEnvio.asignado;
  bool get puedeLlegar => estado == EstadoEnvio.enTransito && llegadaEn == null;
  bool get puedeConfirmar => estado == EstadoEnvio.enTransito;

  /// Copia con cambios locales (optimistas) mientras la operación se sincroniza.
  Envio conCambios(Map<String, dynamic> cambios) =>
      Envio({...json, ...cambios});
}
