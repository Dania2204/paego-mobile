import 'package:flutter_test/flutter_test.dart';
import 'package:opaego/data/datasources/database_helper.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Set<String>> tablas(Database db) async => (await db.rawQuery(
  "SELECT name FROM sqlite_master WHERE type = 'table'",
)).map((f) => f['name'] as String).toSet();

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    DatabaseHelper.nombreArchivo = 'prueba_migracion.db';
    databaseFactory = databaseFactoryFfi;
  });

  test('al actualizar desde la versión 5 borra las tablas del modo local '
      'y conserva los datos de la API', () async {
    final ruta = p.join(await getDatabasesPath(), DatabaseHelper.nombreArchivo);
    await databaseFactory.deleteDatabase(ruta);
    final vieja = await openDatabase(
      ruta,
      version: 5,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE users (id INTEGER PRIMARY KEY)');
        await db.execute(
          'CREATE TABLE delivery_orders (id INTEGER PRIMARY KEY)',
        );
        await db.execute(
          'CREATE TABLE envios_cache (usuario_id INTEGER NOT NULL, '
          'id INTEGER NOT NULL, json TEXT NOT NULL, '
          'actualizado_en TEXT NOT NULL, PRIMARY KEY (usuario_id, id))',
        );
        await db.insert('envios_cache', {
          'usuario_id': 7,
          'id': 119,
          'json': '{}',
          'actualizado_en': '2026-11-09T10:00:00',
        });
      },
    );
    await vieja.close();

    final db = await DatabaseHelper.instance.database;
    expect(await db.getVersion(), 6);
    final nombres = await tablas(db);
    expect(nombres, isNot(contains('users')));
    expect(nombres, isNot(contains('delivery_orders')));
    expect(nombres, containsAll(['operaciones', 'envios_cache', 'app_texts']));
    // Los datos de la integración con la API no se pierden.
    expect(await db.query('envios_cache'), hasLength(1));
  });
}
