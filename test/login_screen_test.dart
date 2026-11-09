import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opaego/core/l10n/app_strings.dart';
import 'package:opaego/core/router/app_router.dart';
import 'package:opaego/data/models/user_model.dart';
import 'package:opaego/data/remote/api_client.dart';
import 'package:opaego/features/auth/login/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() => S.guardarTextosNuevos = false);

  late List<String> rutas;

  Future<void> abrirLogin(
    WidgetTester tester,
    Future<http.Response> Function(http.Request) servidor,
  ) async {
    SharedPreferences.setMockInitialValues({});
    rutas = [];
    ApiClient.usarCliente(
      MockClient((r) {
        rutas.add(r.url.path);
        return servidor(r);
      }),
    );
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: const LoginScreen(),
        onGenerateRoute: (ajustes) => MaterialPageRoute(
          builder: (_) =>
              Text('Inicio de ${(ajustes.arguments as AppUser?)?.fullName}'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> ingresar(WidgetTester tester, String email, String clave) async {
    await tester.enterText(find.byType(TextFormField).at(0), email);
    await tester.enterText(find.byType(TextFormField).at(1), clave);
    await tester.tap(find.text('Iniciar sesión'));
    await tester.pumpAndSettle();
  }

  http.Response json(Object cuerpo, [int codigo = 200]) => http.Response(
    jsonEncode(cuerpo),
    codigo,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  testWidgets('sin datos no llama al servidor', (tester) async {
    await abrirLogin(tester, (_) async => json({}));
    await ingresar(tester, '', '');
    expect(find.text('Este campo es obligatorio'), findsNWidgets(2));
    expect(rutas, isEmpty);
  });

  testWidgets('credenciales malas: muestra el error y se queda', (
    tester,
  ) async {
    await abrirLogin(
      tester,
      (_) async => json({'detail': 'No active account'}, 401),
    );
    await ingresar(tester, 'conductor1@paego.local', 'mala');
    expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('ingreso correcto: entra al inicio con el usuario', (
    tester,
  ) async {
    await abrirLogin(
      tester,
      (r) async => json({
        'access': 'A1',
        'refresh': 'R1',
        'usuario': {
          'id': 5,
          'email': 'conductor1@paego.local',
          'nombre': 'Carlos Pérez',
          'rol': 'CONDUCTOR',
        },
      }),
    );
    await ingresar(tester, 'conductor1@paego.local', 'Paego2026!');
    expect(rutas, ['/api/auth/token/']);
    expect(find.text('Inicio de Carlos Pérez'), findsOneWidget);
    expect(AppRouter.home, '/home');
  });
}
