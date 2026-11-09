import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/api_config.dart';

/// Error devuelto por la API (4xx/5xx) con el mensaje ya legible.
class ApiException implements Exception {
  ApiException(this.statusCode, this.mensaje, [this.cuerpo]);

  final int statusCode;
  final String mensaje;
  final dynamic cuerpo;

  @override
  String toString() => mensaje;
}

/// No hay conexión con el servidor (sin internet, DNS, timeout…).
class SinConexionException implements Exception {
  SinConexionException([this.causa]);
  final Object? causa;

  @override
  String toString() => 'Sin conexión con el servidor';
}

/// La sesión venció (el refresh token expiró o fue revocado): hay que volver
/// a ingresar. Las operaciones pendientes se conservan en el teléfono.
class SesionVencidaException implements Exception {
  @override
  String toString() => 'La sesión venció. Ingrese de nuevo para sincronizar.';
}

/// Cliente HTTP de la API de PAEGo con autenticación JWT (RF-01, RNF-08).
///
/// Guarda access y refresh en SharedPreferences y renueva el access de forma
/// transparente cuando el servidor responde 401. El refresh rota en cada uso
/// (ROTATE_REFRESH_TOKENS), así que siempre se guarda el nuevo.
class ApiClient {
  ApiClient._({http.Client? cliente}) : _http = cliente ?? http.Client();

  static ApiClient instance = ApiClient._();

  /// Solo para pruebas: reemplaza el cliente HTTP.
  static void usarCliente(http.Client cliente) {
    instance = ApiClient._(cliente: cliente);
  }

  static const _kAccess = 'paego_access';
  static const _kRefresh = 'paego_refresh';
  static const _timeout = Duration(seconds: 20);

  final http.Client _http;
  String? _access;
  String? _refresh;
  Future<bool>? _renovando;

  /// Se dispara cuando el refresh deja de servir.
  final StreamController<void> _sesionVencida = StreamController.broadcast();
  Stream<void> get onSesionVencida => _sesionVencida.stream;

  bool get tieneSesion => _refresh != null;

  Future<void> cargarTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _access = prefs.getString(_kAccess);
    _refresh = prefs.getString(_kRefresh);
  }

  Future<void> _guardarTokens({String? access, String? refresh}) async {
    final prefs = await SharedPreferences.getInstance();
    if (access != null) {
      _access = access;
      await prefs.setString(_kAccess, access);
    }
    if (refresh != null) {
      _refresh = refresh;
      await prefs.setString(_kRefresh, refresh);
    }
  }

  Future<void> borrarTokens() async {
    _access = null;
    _refresh = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAccess);
    await prefs.remove(_kRefresh);
  }

  // ── Autenticación ─────────────────────────────────────────────────────────

  /// RF-01: devuelve el perfil del usuario (`usuario` en la respuesta).
  Future<Map<String, dynamic>> iniciarSesion(
    String email,
    String password,
  ) async {
    final respuesta = await _enviar(
      'POST',
      '/auth/token/',
      cuerpo: {'email': email.trim().toLowerCase(), 'password': password},
      autenticado: false,
    );
    final datos = respuesta as Map<String, dynamic>;
    await _guardarTokens(
      access: datos['access'] as String,
      refresh: datos['refresh'] as String,
    );
    return datos['usuario'] as Map<String, dynamic>;
  }

  /// RF-02: revoca el refresh en el servidor. Si no hay red, solo se borra local.
  Future<void> cerrarSesion() async {
    final refresh = _refresh;
    if (refresh != null) {
      try {
        await _enviar('POST', '/auth/logout/', cuerpo: {'refresh': refresh});
      } catch (_) {
        // Sin red o sesión ya vencida: igual se cierra en el teléfono.
      }
    }
    await borrarTokens();
  }

  Future<bool> _renovarAccess() {
    // Una sola renovación a la vez: el refresh rota y el viejo queda en lista negra.
    return _renovando ??= _hacerRenovacion().whenComplete(
      () => _renovando = null,
    );
  }

  Future<bool> _hacerRenovacion() async {
    final refresh = _refresh;
    if (refresh == null) return false;
    http.Response r;
    try {
      r = await _http
          .post(
            ApiConfig.uri('/auth/token/refresh/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(_timeout);
    } on TimeoutException catch (e) {
      throw SinConexionException(e);
    } on http.ClientException catch (e) {
      throw SinConexionException(e);
    }
    if (r.statusCode == 200) {
      final datos =
          jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
      await _guardarTokens(
        access: datos['access'] as String?,
        refresh: datos['refresh'] as String?,
      );
      return true;
    }
    if (r.statusCode == 401 || r.statusCode == 400) {
      await borrarTokens();
      _sesionVencida.add(null);
      return false;
    }
    throw ApiException(
      r.statusCode,
      'No se pudo renovar la sesión (${r.statusCode}).',
    );
  }

  // ── Peticiones ────────────────────────────────────────────────────────────

  Future<dynamic> get(String ruta, {Map<String, String>? query}) =>
      _enviar('GET', ruta, query: query);

  Future<dynamic> post(
    String ruta, {
    Object? cuerpo,
    Map<String, String>? cabeceras,
  }) => _enviar('POST', ruta, cuerpo: cuerpo, cabeceras: cabeceras);

  /// Recorre la paginación de DRF (`results` / `next`) y devuelve todos los elementos.
  Future<List<Map<String, dynamic>>> getTodos(
    String ruta, {
    Map<String, String>? query,
    int maxPaginas = 10,
  }) async {
    final elementos = <Map<String, dynamic>>[];
    var pagina = 1;
    while (pagina <= maxPaginas) {
      final datos = await get(ruta, query: {...?query, 'page': '$pagina'});
      if (datos is List) {
        elementos.addAll(datos.cast<Map<String, dynamic>>());
        break;
      }
      final mapa = datos as Map<String, dynamic>;
      elementos.addAll((mapa['results'] as List).cast<Map<String, dynamic>>());
      if (mapa['next'] == null) break;
      pagina++;
    }
    return elementos;
  }

  Future<dynamic> _enviar(
    String metodo,
    String ruta, {
    Object? cuerpo,
    Map<String, String>? query,
    Map<String, String>? cabeceras,
    bool autenticado = true,
    bool reintento = false,
  }) async {
    if (autenticado && _access == null) {
      if (_refresh == null) throw SesionVencidaException();
      if (!await _renovarAccess()) throw SesionVencidaException();
    }

    final headers = <String, String>{
      'Accept': 'application/json',
      if (cuerpo != null) 'Content-Type': 'application/json',
      if (autenticado && _access != null) 'Authorization': 'Bearer $_access',
      ...?cabeceras,
    };
    final uri = ApiConfig.uri(ruta, query);

    http.Response r;
    try {
      final peticion = http.Request(metodo, uri)..headers.addAll(headers);
      if (cuerpo != null) peticion.body = jsonEncode(cuerpo);
      r = await http.Response.fromStream(
        await _http.send(peticion).timeout(_timeout),
      );
    } on TimeoutException catch (e) {
      throw SinConexionException(e);
    } on http.ClientException catch (e) {
      throw SinConexionException(e);
    } catch (e) {
      // SocketException (móvil) / errores de red del navegador.
      if (e is ApiException) rethrow;
      throw SinConexionException(e);
    }

    if (r.statusCode == 401 && autenticado && !reintento) {
      if (await _renovarAccess()) {
        return _enviar(
          metodo,
          ruta,
          cuerpo: cuerpo,
          query: query,
          cabeceras: cabeceras,
          reintento: true,
        );
      }
      throw SesionVencidaException();
    }

    final texto = utf8.decode(r.bodyBytes);
    final datos = texto.isEmpty ? null : _decodificar(texto);
    if (r.statusCode >= 200 && r.statusCode < 300) return datos;
    throw ApiException(
      r.statusCode,
      mensajeDeError(datos, r.statusCode),
      datos,
    );
  }

  static dynamic _decodificar(String texto) {
    try {
      return jsonDecode(texto);
    } catch (_) {
      return texto;
    }
  }

  /// Convierte el error de DRF ({"campo": ["msg"]} o {"detail": "..."}) en texto.
  static String mensajeDeError(dynamic datos, [int? codigo]) {
    String aplanar(dynamic v) {
      if (v is String) return v;
      if (v is List) return v.map(aplanar).join(' ');
      if (v is Map) {
        return v.entries
            .map((e) {
              final campo = e.key.toString();
              final texto = aplanar(e.value);
              const genericos = {'detail', 'detalle', 'non_field_errors'};
              return genericos.contains(campo) ? texto : '$campo: $texto';
            })
            .join('\n');
      }
      return v?.toString() ?? '';
    }

    final texto = aplanar(datos).trim();
    if (texto.isNotEmpty && texto.length < 500) return texto;
    if (codigo == 401) return 'Correo o contraseña incorrectos.';
    if (codigo == 403) return 'No tiene permiso para esta acción.';
    if (codigo == 404) return 'El registro no existe.';
    return 'Error del servidor${codigo != null ? ' ($codigo)' : ''}.';
  }
}
