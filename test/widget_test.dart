import 'package:flutter_test/flutter_test.dart';
import 'package:opaego/data/models/envio.dart';
import 'package:opaego/data/models/user_model.dart';
import 'package:opaego/data/models/user_role.dart';

/// Respuesta real de `GET /api/envios/` (EnvioSerializer de oPAEGo).
Map<String, dynamic> envioJson({String estado = 'ASIGNADO'}) => {
  'id': 7,
  'codigo': 'ENV-2026-0007',
  'programado_para': '2026-11-09T12:30:00Z',
  'estado': estado,
  'estado_nombre': 'Asignado',
  'institucion': {
    'id': 3,
    'nombre': 'IEM Ciudad de Pasto',
    'sede': 'Principal',
    'direccion': 'Cra 27 # 10-20',
    'latitud': '1.214500',
    'longitud': '-77.281100',
    'contacto_telefono': '3001234567',
  },
  'conductor_id': 2,
  'conductor_nombre': 'Carlos Pérez',
  'conductor_telefono': '3110000000',
  'vehiculo_id': 1,
  'vehiculo_placa': 'NAR123',
  'observaciones': '',
  'codigo_verificacion': '482913',
  'items': [
    {
      'id': 11,
      'producto': 'Leche',
      'cantidad': '120.00',
      'unidad': 'UNIDAD',
      'unidad_nombre': 'Unidades',
      'cantidad_recibida': null,
    },
  ],
  'salida_en': null,
  'llegada_en': null,
  'entregado_en': null,
  'esta_retrasado': false,
  'evidencia': null,
};

void main() {
  group('Envio desde la API', () {
    test('lee estado, institución con coordenadas decimales e ítems', () {
      final e = Envio(envioJson());
      expect(e.estado, EstadoEnvio.asignado);
      expect(e.puedeSalir, isTrue);
      expect(e.institucion.latLng!.latitude, closeTo(1.2145, 1e-6));
      expect(e.items.single.cantidad, 120);
      expect(ItemEnvio.formatear(e.items.single.cantidad), '120');
      expect(e.codigoVerificacion, '482913');
    });

    test('los cambios optimistas no pierden el resto del JSON', () {
      final e = Envio(envioJson()).conCambios({
        'estado': 'EN_TRANSITO',
        'salida_en': '2026-11-09T12:00:00Z',
      });
      expect(e.estado, EstadoEnvio.enTransito);
      expect(e.puedeLlegar, isTrue);
      expect(e.puedeConfirmar, isTrue);
      expect(e.institucion.nombre, 'IEM Ciudad de Pasto');
    });

    test('estados desconocidos caen en asignado', () {
      expect(EstadoEnvioX.desdeApi('OTRO'), EstadoEnvio.asignado);
      expect(EstadoEnvioX.desdeApi('CON_NOVEDAD'), EstadoEnvio.conNovedad);
    });
  });

  group('Perfil de la API → AppUser', () {
    test('mapea los roles del backend', () {
      expect(UserRoleX.fromBackend('CONDUCTOR'), UserRole.driver);
      expect(UserRoleX.fromBackend('INSTITUCION'), UserRole.rector);
      expect(UserRoleX.fromBackend('ADMINISTRADOR'), UserRole.admin);
    });

    test('perfil de conductor y vuelta por la sesión guardada', () {
      final u = AppUser.fromPerfil({
        'id': 5,
        'email': 'conductor1@paego.local',
        'nombre': 'Carlos Pérez',
        'rol': 'CONDUCTOR',
        'telefono': '311',
        'acepto_tratamiento_datos_en': null,
        'conductor_id': 2,
        'institucion_id': null,
      });
      expect(u.role.canDriveRoute, isTrue);
      expect(u.role.canConfirmReception, isFalse);
      expect(u.aceptoTratamientoDatos, isFalse);
      final otra = AppUser.fromPerfil(u.toSesion());
      expect(otra.id, 5);
      expect(otra.role, UserRole.driver);
      expect(otra.conductorId, 2);
    });
  });
}
