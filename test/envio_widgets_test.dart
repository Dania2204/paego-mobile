import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opaego/core/l10n/app_strings.dart';
import 'package:opaego/data/models/envio.dart';
import 'package:opaego/data/models/user_model.dart';
import 'package:opaego/features/envios/envio_widgets.dart';

import 'datos_prueba.dart';

AppUser _usuario(String rol) =>
    AppUser.fromPerfil({'id': 5, 'email': 'u@paego.local', 'rol': rol});

Envio _envio(String estado, {String? llegada}) =>
    Envio(envioJson(estado: estado)..['llegada_en'] = llegada);

const _salida = 'Registrar salida';
const _llegada = 'Registrar llegada';
const _confirmar = 'Confirmar recepción';
const _novedad = 'Reportar novedad';

void main() {
  setUpAll(() => S.guardarTextosNuevos = false);

  Future<void> mostrarAcciones(
    WidgetTester tester,
    Envio envio,
    AppUser user,
  ) => tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) =>
              ListView(children: accionesEnvio(context, envio, user)),
        ),
      ),
    ),
  );

  group('acciones según rol y estado', () {
    testWidgets('conductor con envío asignado: puede salir', (tester) async {
      await mostrarAcciones(tester, _envio('ASIGNADO'), _usuario('CONDUCTOR'));
      expect(find.text(_salida), findsOneWidget);
      expect(find.text(_novedad), findsOneWidget);
      expect(find.text(_llegada), findsNothing);
      expect(find.text(_confirmar), findsNothing);
    });

    testWidgets('conductor en tránsito: registra la llegada una sola vez', (
      tester,
    ) async {
      final user = _usuario('CONDUCTOR');
      await mostrarAcciones(tester, _envio('EN_TRANSITO'), user);
      expect(find.text(_llegada), findsOneWidget);
      expect(find.text(_salida), findsNothing);

      await mostrarAcciones(
        tester,
        _envio('EN_TRANSITO', llegada: '2026-11-09T13:00:00Z'),
        user,
      );
      expect(find.text(_llegada), findsNothing);
      // El conductor nunca confirma la recepción.
      expect(find.text(_confirmar), findsNothing);
    });

    testWidgets('institución: confirma solo lo que está en tránsito', (
      tester,
    ) async {
      final user = _usuario('INSTITUCION');
      await mostrarAcciones(tester, _envio('ASIGNADO'), user);
      expect(find.text(_confirmar), findsNothing);
      expect(find.text(_salida), findsNothing);

      await mostrarAcciones(tester, _envio('EN_TRANSITO'), user);
      expect(find.text(_confirmar), findsOneWidget);
      expect(find.text(_novedad), findsOneWidget);
    });

    testWidgets('envío cancelado: no hay acciones', (tester) async {
      await mostrarAcciones(tester, _envio('CANCELADO'), _usuario('CONDUCTOR'));
      expect(find.byType(OutlinedButton), findsNothing);
      expect(find.text(_salida), findsNothing);
    });

    testWidgets('el administrador solo consulta', (tester) async {
      await mostrarAcciones(
        tester,
        _envio('EN_TRANSITO'),
        _usuario('ADMINISTRADOR'),
      );
      for (final t in [_salida, _llegada, _confirmar, _novedad]) {
        expect(find.text(t), findsNothing);
      }
    });
  });

  testWidgets(
    'confirmar recepción exige el código de 6 dígitos y quién recibe',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      await mostrarAcciones(
        tester,
        _envio('EN_TRANSITO'),
        _usuario('INSTITUCION'),
      );
      await tester.tap(find.text(_confirmar));
      await tester.pumpAndSettle();

      // El formulario abre con lo enviado (120 unidades de leche).
      expect(find.textContaining('Enviado: 120'), findsOneWidget);
      final guardar = find.text(_confirmar).last;

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Código que muestra el conductor'),
        '12345',
      );
      await tester.ensureVisible(guardar);
      await tester.tap(guardar);
      await tester.pump();
      expect(find.text('Digite los 6 dígitos.'), findsOneWidget);
      expect(find.text('Obligatorio'), findsOneWidget);

      // Recibir menos de lo enviado avisa que quedará con novedad.
      expect(find.textContaining('Hay diferencias'), findsNothing);
      await tester.enterText(find.widgetWithText(TextFormField, '120'), '100');
      await tester.pump();
      expect(find.textContaining('Hay diferencias'), findsOneWidget);
    },
  );

  testWidgets('el conductor ve el código para la institución', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CodigoVerificacion(codigo: '482913')),
      ),
    );
    expect(find.textContaining('482913'), findsOneWidget);
  });
}
