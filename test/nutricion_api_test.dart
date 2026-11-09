import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opaego/data/remote/api_client.dart';
import 'package:opaego/data/remote/nutricion_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<http.Request> peticiones;

  Future<void> servidor(http.Response Function(http.Request) responder) async {
    SharedPreferences.setMockInitialValues({
      'paego_access': 'A',
      'paego_refresh': 'R',
    });
    peticiones = [];
    ApiClient.usarCliente(
      MockClient((r) async {
        peticiones.add(r);
        return responder(r);
      }),
    );
    await ApiClient.instance.cargarTokens();
  }

  http.Response json(Object cuerpo, [int codigo = 200]) => http.Response(
    jsonEncode(cuerpo),
    codigo,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test('pregunta al backend, no a Gemini, y sin clave propia', () async {
    await servidor((_) => json({'respuesta': ' Lentejas con arroz. '}));

    final texto = await NutricionApi.preguntar([
      (rol: 'asistente', texto: '¡Hola!'),
      (rol: 'usuario', texto: 'Dame una receta'),
    ], contexto: 'Arepa');

    expect(texto, 'Lentejas con arroz.');
    final r = peticiones.single;
    expect(r.url.path, '/api/nutricion/asistente/');
    expect(r.url.host, isNot(contains('googleapis')));
    expect(r.url.query, isEmpty);
    expect(r.headers['Authorization'], 'Bearer A');
    // El saludo inicial del asistente no se envía.
    expect(jsonDecode(r.body), {
      'mensajes': [
        {'rol': 'usuario', 'texto': 'Dame una receta'},
      ],
      'contexto': 'Arepa',
    });
  });

  test('envía solo los mensajes más recientes', () async {
    await servidor((_) => json({'respuesta': 'ok'}));
    await NutricionApi.preguntar([
      for (var i = 0; i < 40; i++) (rol: 'usuario', texto: 'm$i'),
    ]);
    final mensajes = jsonDecode(peticiones.single.body)['mensajes'] as List;
    expect(mensajes, hasLength(NutricionApi.maxMensajes));
    expect(mensajes.last['texto'], 'm39');
  });

  test('servidor sin clave: ApiException 503 con su mensaje', () async {
    await servidor(
      (_) => json({
        'detail': 'El asistente de nutrición no está configurado.',
      }, 503),
    );
    await expectLater(
      NutricionApi.preguntar([(rol: 'usuario', texto: 'hola')]),
      throwsA(
        isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 503)
            .having(
              (e) => e.mensaje,
              'mensaje',
              contains('no está configurado'),
            ),
      ),
    );
  });

  test('respuesta vacía: ApiException', () async {
    await servidor((_) => json({'respuesta': '  '}));
    await expectLater(
      NutricionApi.preguntar([(rol: 'usuario', texto: 'hola')]),
      throwsA(isA<ApiException>()),
    );
  });
}
