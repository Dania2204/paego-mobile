import 'api_client.dart';

/// Mensaje del chat de nutrición: `usuario` o `asistente`.
typedef MensajeNutricion = ({String rol, String texto});

/// Asistente de nutrición. La app no habla con Gemini: el backend
/// (`POST /api/nutricion/asistente/`) lo consulta con su propia clave, así
/// que ninguna clave viaja dentro del APK.
class NutricionApi {
  NutricionApi._();

  /// Máximo de mensajes que acepta el servidor; se envían los más recientes.
  static const maxMensajes = 30;

  /// Devuelve la respuesta del asistente para la conversación [mensajes]
  /// (el último debe ser del usuario). [contexto] resume lo que el usuario
  /// registró hoy. Lanza [ApiException] (p. ej. 503 si el servidor no tiene
  /// clave) o [SinConexionException].
  static Future<String> preguntar(
    List<MensajeNutricion> mensajes, {
    String contexto = '',
  }) async {
    var recientes = mensajes.length > maxMensajes
        ? mensajes.sublist(mensajes.length - maxMensajes)
        : mensajes;
    // Gemini espera que la conversación empiece por el usuario (el saludo
    // inicial del asistente no aporta).
    recientes = recientes.skipWhile((m) => m.rol == 'asistente').toList();
    final datos = await ApiClient.instance.post(
      '/nutricion/asistente/',
      cuerpo: {
        'mensajes': [
          for (final m in recientes) {'rol': m.rol, 'texto': m.texto},
        ],
        'contexto': contexto,
      },
    );
    final texto = (datos is Map ? datos['respuesta'] : null)?.toString();
    if (texto == null || texto.trim().isEmpty) {
      throw ApiException(502, 'El asistente no respondió.');
    }
    return texto.trim();
  }
}
