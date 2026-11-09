import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opaego/data/remote/api_client.dart';
import 'package:opaego/data/repositories/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AuthResult> ingresarCon(int codigo, Object cuerpo) {
    ApiClient.usarCliente(
      MockClient(
        (_) async => http.Response(
          jsonEncode(cuerpo),
          codigo,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    return AuthService.instance.login(email: 'a@b.co', password: 'x');
  }

  test('credenciales malas: mensaje claro', () async {
    final r = await ingresarCon(401, {'detail': 'No active account'});
    expect(r.isSuccess, isFalse);
    expect(r.error, 'Correo o contraseña incorrectos.');
  });

  test('demasiados intentos (429): pide esperar', () async {
    final r = await ingresarCon(429, {
      'detail': 'Solicitud fue regulada (throttled).',
    });
    expect(r.isSuccess, isFalse);
    expect(r.error, contains('Demasiados intentos'));
  });
}
