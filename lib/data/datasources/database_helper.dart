import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/delivery_model.dart';
import '../models/report_model.dart';
import '../models/user_model.dart';

/// Single SQLite source of truth for all offline-first data.
class DatabaseHelper {
  DatabaseHelper._();
  static final instance = DatabaseHelper._();
  static Database? _db;

  Future<Database> get database async {
    _db ??= await _initDB('paego.db');
    return _db!;
  }

  Future<Database> _initDB(String name) async {
    final path = kIsWeb ? name : join(await getDatabasesPath(), name);
    return openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name      TEXT NOT NULL,
        email          TEXT NOT NULL UNIQUE,
        phone          TEXT NOT NULL,
        id_number      TEXT NOT NULL UNIQUE,
        role           TEXT NOT NULL,
        institution    TEXT,
        photo_path     TEXT,
        password_hash  TEXT,
        created_at     TEXT,
        synced_at      TEXT,
        is_synced      INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE school_locations (
        id                 INTEGER PRIMARY KEY AUTOINCREMENT,
        name               TEXT NOT NULL,
        address            TEXT NOT NULL,
        latitude           REAL NOT NULL,
        longitude          REAL NOT NULL,
        added_by_user_id   INTEGER NOT NULL,
        is_synced          INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE delivery_orders (
        id                   INTEGER PRIMARY KEY AUTOINCREMENT,
        school_id            INTEGER NOT NULL,
        school_name          TEXT NOT NULL,
        school_lat           REAL NOT NULL,
        school_lng           REAL NOT NULL,
        pickup_lat           REAL NOT NULL,
        pickup_lng           REAL NOT NULL,
        assigned_driver_id   INTEGER,
        assigned_driver_name TEXT,
        status               TEXT NOT NULL DEFAULT 'pending',
        created_at           TEXT,
        is_synced            INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE delivery_reports (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id              INTEGER NOT NULL,
        school_name           TEXT NOT NULL,
        submitted_by_user_id  INTEGER NOT NULL,
        submitted_by_name     TEXT NOT NULL,
        condition             TEXT NOT NULL DEFAULT 'good',
        notes                 TEXT NOT NULL DEFAULT '',
        photo_paths           TEXT NOT NULL DEFAULT '',
        created_at            TEXT,
        is_synced             INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE tracking_points (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id   INTEGER NOT NULL,
        driver_id  INTEGER NOT NULL,
        latitude   REAL NOT NULL,
        longitude  REAL NOT NULL,
        recorded_at TEXT NOT NULL,
        is_synced  INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await _createAppTextsTable(db);
    await _createSyncTables(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await _createAppTextsTable(db);
    }
    if (oldVersion < 4) {
      await _migrateAppTextsSyncColumns(db);
    }
    if (oldVersion < 5) {
      // La autenticación pasa a la API de oPAEGo: se elimina el admin local.
      await db.delete('users', where: 'LOWER(email) = ?', whereArgs: ['admin']);
      await _createSyncTables(db);
    }
  }

  Future<void> _createAppTextsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_texts (
        key         TEXT NOT NULL,
        locale      TEXT NOT NULL,
        value       TEXT NOT NULL,
        updated_at  TEXT,
        synced_at   TEXT,
        is_synced   INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (key, locale)
      )
    ''');
    await _migrateAppTextsSyncColumns(db);
  }

  Future<void> _migrateAppTextsSyncColumns(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(app_texts)');
    final names = columns.map((c) => c['name']).whereType<String>().toSet();

    if (!names.contains('synced_at')) {
      await db.execute('ALTER TABLE app_texts ADD COLUMN synced_at TEXT');
    }
    if (!names.contains('is_synced')) {
      await db.execute(
        'ALTER TABLE app_texts ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0',
      );
    }
  }

  /// Tablas de la integración con la API de oPAEGo (RF-38):
  /// - `envios_cache`: últimos envíos descargados, para trabajar sin conexión.
  /// - `operaciones`: cola de operaciones capturadas en el teléfono. Cada una
  ///   lleva un `uuid` (uuid_cliente) que hace idempotente su envío al servidor.
  Future<void> _createSyncTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS envios_cache (
        usuario_id     INTEGER NOT NULL,
        id             INTEGER NOT NULL,
        json           TEXT NOT NULL,
        actualizado_en TEXT NOT NULL,
        PRIMARY KEY (usuario_id, id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operaciones (
        uuid         TEXT PRIMARY KEY,
        usuario_id   INTEGER NOT NULL,
        tipo         TEXT NOT NULL,
        envio_id     INTEGER,
        ocurrido_en  TEXT NOT NULL,
        datos        TEXT NOT NULL,
        resumen      TEXT NOT NULL DEFAULT '',
        estado       TEXT NOT NULL DEFAULT 'pendiente',
        respuesta    TEXT,
        intentos     INTEGER NOT NULL DEFAULT 0,
        creado_en    TEXT NOT NULL,
        enviado_en   TEXT
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS operaciones_usuario_estado '
      'ON operaciones (usuario_id, estado, ocurrido_en)',
    );
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<int> insertUser(AppUser u) async {
    final db = await database;
    return db.insert(
      'users',
      u.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  Future<AppUser?> getUserByEmail(String email) async {
    return getUserByIdentifier(email);
  }

  Future<AppUser?> getUserByIdentifier(String identifier) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [identifier.toLowerCase().trim()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<AppUser?> getUserById(int id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<List<AppUser>> getAllUsers() async {
    final db = await database;
    final rows = await db.query('users', orderBy: 'full_name ASC');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<int> updateUser(AppUser u) async {
    final db = await database;
    return db.update('users', u.toMap(), where: 'id = ?', whereArgs: [u.id]);
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ── School Locations ──────────────────────────────────────────────────────

  Future<int> insertSchool(SchoolLocation s) async {
    final db = await database;
    return db.insert('school_locations', s.toMap());
  }

  Future<List<SchoolLocation>> getSchools() async {
    final db = await database;
    final rows = await db.query('school_locations', orderBy: 'name ASC');
    return rows.map(SchoolLocation.fromMap).toList();
  }

  Future<int> deleteSchool(int id) async {
    final db = await database;
    return db.delete('school_locations', where: 'id = ?', whereArgs: [id]);
  }

  // ── Delivery Orders ───────────────────────────────────────────────────────

  Future<int> insertOrder(DeliveryOrder o) async {
    final db = await database;
    return db.insert('delivery_orders', o.toMap());
  }

  Future<List<DeliveryOrder>> getOrders() async {
    final db = await database;
    final rows = await db.query('delivery_orders', orderBy: 'created_at DESC');
    return rows.map(DeliveryOrder.fromMap).toList();
  }

  Future<int> updateOrderStatus(
    int id,
    DeliveryStatus status, {
    int? driverId,
    String? driverName,
  }) async {
    final db = await database;
    final map = <String, dynamic>{'status': status.name};
    if (driverId != null) map['assigned_driver_id'] = driverId;
    if (driverName != null) map['assigned_driver_name'] = driverName;
    return db.update('delivery_orders', map, where: 'id = ?', whereArgs: [id]);
  }

  // ── Reports ───────────────────────────────────────────────────────────────

  Future<int> insertReport(DeliveryReport r) async {
    final db = await database;
    return db.insert('delivery_reports', r.toMap());
  }

  Future<List<DeliveryReport>> getReports() async {
    final db = await database;
    final rows = await db.query('delivery_reports', orderBy: 'created_at DESC');
    return rows.map(DeliveryReport.fromMap).toList();
  }

  // ── Tracking ──────────────────────────────────────────────────────────────

  Future<void> insertTrackingPoint({
    required int orderId,
    required int driverId,
    required double lat,
    required double lng,
  }) async {
    final db = await database;
    await db.insert('tracking_points', {
      'order_id': orderId,
      'driver_id': driverId,
      'latitude': lat,
      'longitude': lng,
      'recorded_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    });
  }

  Future<List<Map<String, dynamic>>> getTrackingForOrder(int orderId) async {
    final db = await database;
    return db.query(
      'tracking_points',
      where: 'order_id = ?',
      whereArgs: [orderId],
      orderBy: 'recorded_at ASC',
    );
  }

  // ── Pending sync counts ───────────────────────────────────────────────────

  Future<int> pendingSyncCount() async {
    final db = await database;
    int count = 0;
    for (final table in [
      'users',
      'school_locations',
      'delivery_orders',
      'delivery_reports',
      'tracking_points',
      'app_texts',
    ]) {
      final r = await db.rawQuery(
        'SELECT COUNT(*) as c FROM $table WHERE is_synced = 0',
      );
      count += (r.first['c'] as int? ?? 0);
    }
    return count;
  }

  Future<Map<String, Map<String, String>>> getAppTexts() async {
    final db = await database;
    final rows = await db.query('app_texts');
    final texts = <String, Map<String, String>>{};
    for (final row in rows) {
      final key = row['key'] as String;
      final locale = row['locale'] as String;
      final value = row['value'] as String;
      texts.putIfAbsent(key, () => <String, String>{})[locale] = value;
    }
    return texts;
  }

  Future<List<Map<String, dynamic>>> getAppTextRows() async {
    final db = await database;
    final rows = await db.query('app_texts', orderBy: 'key ASC, locale ASC');
    return rows
        .map(
          (row) => {
            'key': row['key'] as String,
            'locale': row['locale'] as String,
            'value': row['value'] as String,
            'updated_at': row['updated_at'] as String?,
          },
        )
        .toList();
  }

  Future<void> upsertAppTextRows(
    List<Map<String, String>> rows, {
    bool markSynced = false,
  }) async {
    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    for (final row in rows) {
      batch.insert('app_texts', {
        'key': row['key'],
        'locale': row['locale'],
        'value': row['value'],
        'updated_at': now,
        'synced_at': markSynced ? now : null,
        'is_synced': markSynced ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await batch.commit(noResult: true);
  }

  Future<void> markAllAppTextsSynced() async {
    final db = await database;
    await db.update('app_texts', {
      'synced_at': DateTime.now().toIso8601String(),
      'is_synced': 1,
    });
  }

  Future<void> upsertAppText({
    required String key,
    required String locale,
    required String value,
  }) async {
    final db = await database;
    await db.insert('app_texts', {
      'key': key,
      'locale': locale,
      'value': value,
      'updated_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }
}
