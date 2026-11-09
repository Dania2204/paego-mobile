import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuración de Gemini (pantalla de Nutrición), leída del `.env`.
class GeminiConfig {
  GeminiConfig._();

  static const modeloPorDefecto = 'gemini-2.5-flash';

  static String? _leer(String nombre) {
    try {
      final valor = dotenv.env[nombre]?.trim();
      return (valor == null || valor.isEmpty) ? null : valor;
    } catch (_) {
      return null; // dotenv no se cargó.
    }
  }

  /// Clave `GEMINI_API_KEY`; vacía si no está configurada.
  static String get clave => _leer('GEMINI_API_KEY') ?? '';

  /// Modelo `GEMINI_MODEL`, o [modeloPorDefecto].
  static String get modelo => _leer('GEMINI_MODEL') ?? modeloPorDefecto;
}
