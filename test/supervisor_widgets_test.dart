import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opaego/core/l10n/app_strings.dart';
import 'package:opaego/data/datasources/database_helper.dart';
import 'package:opaego/data/remote/api_client.dart';
import 'package:opaego/data/repositories/estudiantes_repository.dart';
import 'package:opaego/data/services/rostro/cofre.dart';
import 'package:opaego/data/services/rostro/extractor.dart';
import 'package:opaego/data/sync/sync_service.dart';
import 'package:opaego/features/supervisor/supervisor_screens.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'estudiantes_test.dart' show estudianteJson;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final repo = EstudiantesRepository.instance;

  setUpAll(() async {
    S.guardarTextosNuevos = false;
    await initializeDateFormatting('es');
    sqfliteFfiInit();
    DatabaseHelper.nombreArchivo = 'prueba_supervisor_ui.db';
    databaseFactory = databaseFactoryFfi;
    await databaseFactory.deleteDatabase(
      p.join(await getDatabasesPath(), DatabaseHelper.nombreArchivo),
    );
    // Sin modelo (como en web): todo el registro es manual.
    extractorRostro = const ExtractorNoDisponible();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'paego_access': 'A',
      'paego_refresh': 'R',
    });
    ApiClient.usarCliente(
      MockClient((r) async {
        // Sin red: la app trabaja con lo guardado y encola.
        throw http.ClientException('sin red');
      }),
    );
    await ApiClient.instance.cargarTokens();
    final db = await DatabaseHelper.instance.database;
    await db.delete('operaciones');
    await db.delete('estudiantes_cache');
    final ahora = DateTime.now().toUtc().toIso8601String();
    for (final id in [1, 2]) {
      await db.insert('estudiantes_cache', {
        'usuario_id': 8,
        'id': id,
        'json': jsonEncode(estudianteJson(id)),
        'actualizado_en': ahora,
      });
    }
    repo.cofre = Cofre(AlmacenClaveEnMemoria());
    await SyncService.instance.iniciar(8);
    await repo.iniciar(8);
  });

  tearDown(() async {
    await repo.detener();
    await SyncService.instance.detener();
  });

  testWidgets('sin cámara: registra la entrega manual con motivo', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: CursoScreen(grado: '7', grupo: 'B'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Apellido1, Nombre1'), findsOneWidget);
      expect(find.text('Pendiente'), findsNWidgets(2));
      // Sin modelo no se ofrece el reconocimiento.
      expect(find.byKey(const Key('reconocer')), findsNothing);

      await tester.tap(find.text('Apellido1, Nombre1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('accion_manual')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sin cámara o poca luz'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('guardar_manual')));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.textContaining('Recibió'), findsOneWidget);
      final ops = await SyncService.instance.pendientes();
      expect(ops.single.tipo, 'estudiante.entregar');
      expect(ops.single.datos['motivo'], 'Sin cámara o poca luz');
    });
  });

  testWidgets('la autorización exige confirmar el formato firmado', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: InscribirScreen(estudiante: repo.porId(2)!, facial: false),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('acudiente_nombre')),
        'Rosa Pérez',
      );
      await tester.enterText(find.byKey(const Key('acudiente_documento')), '1');
      await tester.enterText(find.byKey(const Key('parentesco')), 'Madre');
      final boton = find.byKey(const Key('guardar_autorizacion'));
      expect(tester.widget<FilledButton>(boton).onPressed, isNull);
      await tester.tap(find.byKey(const Key('confirmo')));
      await tester.pump();
      await tester.tap(boton);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(repo.porId(2)!.autorizacionVigente, isTrue);
      final op = (await SyncService.instance.pendientes()).single;
      expect(op.datos['acudiente_nombre'], 'Rosa Pérez');
    });
  });
}
