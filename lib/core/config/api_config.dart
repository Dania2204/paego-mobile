import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Dirección de la API REST de la plataforma web PAEGo (repo `oPAEGo`).
///
/// Se configura con `PAEGO_API_URL` en `.env`. Ejemplos:
/// - Producción (Azure App Service): https://azwafmsbgbksw4m22.azurewebsites.net
/// - Alternativa (Railway): https://web-production-9a3cf.up.railway.app
/// - Emulador Android contra el runserver local: http://10.0.2.2:8000
/// - Chrome / escritorio contra el runserver local: http://localhost:8000
class ApiConfig {
  ApiConfig._();

  static const _porDefecto = 'https://azwafmsbgbksw4m22.azurewebsites.net';

  static String get baseUrl {
    String? valor;
    try {
      valor = dotenv.env['PAEGO_API_URL']?.trim();
    } catch (_) {
      // dotenv no se cargó (por ejemplo en pruebas).
    }
    final url = (valor == null || valor.isEmpty) ? _porDefecto : valor;
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static Uri uri(String ruta, [Map<String, String>? query]) {
    final limpia = ruta.startsWith('/') ? ruta : '/$ruta';
    return Uri.parse('$baseUrl/api$limpia').replace(queryParameters: query);
  }

  /// Cada cuánto el conductor transmite su posición en vivo (mapa "Hoy" de la web).
  static const intervaloEnVivo = Duration(seconds: 3);

  /// Intervalo por defecto de los puntos del recorrido (RF-21). El servidor lo
  /// puede cambiar en `/api/sincronizacion/configuracion/`.
  static const intervaloRecorridoPorDefecto = Duration(seconds: 15);
}
