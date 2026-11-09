import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estilos de mapa base disponibles.
///
/// Los de ArcGIS salen del servicio "Static Basemap Tiles" de ArcGIS Location
/// Platform (teselas PNG de 512 px), que se dibujan con `flutter_map`, la
/// librería de mapas de código abierto que ya usa la app. Se necesita una
/// clave `ARCGIS_API_KEY` en `.env`; sin ella la app usa OpenStreetMap.
enum EstiloMapa {
  navegacion('arcgis/navigation', 'Navegación', 'Navigation'),
  calles('arcgis/streets', 'Calles', 'Streets'),
  exterior('arcgis/outdoor', 'Relieve', 'Outdoor'),
  grisClaro('arcgis/light-gray', 'Gris claro', 'Light gray'),
  nocturno('arcgis/navigation-night', 'Nocturno', 'Night'),
  openStreetMap(null, 'OpenStreetMap', 'OpenStreetMap');

  const EstiloMapa(this.rutaArcgis, this.nombreEs, this.nombreEn);

  /// `{familia}/{estilo}` en la URL del servicio; null para OpenStreetMap.
  final String? rutaArcgis;
  final String nombreEs;
  final String nombreEn;

  bool get esArcgis => rutaArcgis != null;
}

/// Mapa base de la app: qué estilo usar, su capa de teselas y su atribución.
class MapaBase {
  MapaBase._();

  static const _kEstilo = 'paego_estilo_mapa';
  static const _servicio =
      'https://static-map-tiles-api.arcgis.com/arcgis/rest/services/'
      'static-basemap-tiles-service/v1';

  /// Estilo elegido por el usuario (se recuerda entre sesiones).
  static final estilo = ValueNotifier<EstiloMapa>(_porDefecto);

  static EstiloMapa get _porDefecto =>
      hayArcgis ? EstiloMapa.navegacion : EstiloMapa.openStreetMap;

  /// Clave de ArcGIS Location Platform, o null si no está configurada.
  static String? get claveArcgis {
    try {
      final valor = dotenv.env['ARCGIS_API_KEY']?.trim();
      return (valor == null || valor.isEmpty) ? null : valor;
    } catch (_) {
      return null; // dotenv no se cargó (por ejemplo en pruebas).
    }
  }

  static bool get hayArcgis => claveArcgis != null;

  /// Estilos que se pueden elegir con la configuración actual.
  static List<EstiloMapa> get disponibles =>
      hayArcgis ? EstiloMapa.values : const [EstiloMapa.openStreetMap];

  /// Lee el estilo guardado. Si era de ArcGIS y ya no hay clave, vuelve a OSM.
  static Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = EstiloMapa.values
        .where((e) => e.name == prefs.getString(_kEstilo))
        .firstOrNull;
    estilo.value = (guardado != null && disponibles.contains(guardado))
        ? guardado
        : _porDefecto;
  }

  static Future<void> elegir(EstiloMapa nuevo) async {
    if (!disponibles.contains(nuevo)) return;
    estilo.value = nuevo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEstilo, nuevo.name);
  }

  /// URL de una tesela de ArcGIS (z/y/x: el servicio pide fila antes que columna).
  @visibleForTesting
  static String plantillaArcgis(String ruta) =>
      '$_servicio/$ruta/static/tile/{z}/{y}/{x}?token={token}';

  /// Capa de teselas del estilo indicado.
  static TileLayer capa(EstiloMapa e) {
    final clave = claveArcgis;
    if (!e.esArcgis || clave == null) {
      return TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.paego.app',
      );
    }
    return TileLayer(
      // Las teselas de ArcGIS miden 512 px: con zoomOffset -1 se ven a la
      // misma escala que las de 256 px y se piden 4 veces menos teselas
      // (cuenta para el límite gratuito de 2 millones al mes).
      urlTemplate: plantillaArcgis(e.rutaArcgis!),
      additionalOptions: {'token': clave},
      tileSize: 512,
      zoomOffset: -1,
      maxNativeZoom: 22,
      userAgentPackageName: 'com.paego.app',
    );
  }

  /// Atribución obligatoria del proveedor del mapa base.
  static List<SourceAttribution> atribuciones(EstiloMapa e) =>
      e.esArcgis && hayArcgis
      ? const [
          TextSourceAttribution('Powered by Esri'),
          TextSourceAttribution('Esri y sus proveedores de datos'),
        ]
      : const [TextSourceAttribution('© OpenStreetMap contributors')];
}
