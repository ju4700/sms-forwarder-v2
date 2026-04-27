import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/queued_sms.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();
  static const String table = 'sms_queue';

  Database? _db;

  Future<Database> get database async {
    if (_db != null) {
      return _db!;
    }
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final String dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'sms_forwarder.db'),
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $table(
            id TEXT PRIMARY KEY,
            sender TEXT NOT NULL,
            message_body TEXT NOT NULL,
            amount REAL NOT NULL,
            transaction_id TEXT NOT NULL,
            reference TEXT NOT NULL,
            transaction_local_time TEXT NOT NULL,
            transaction_utc_time TEXT NOT NULL,
            fee REAL NOT NULL,
            balance REAL NOT NULL,
            status TEXT NOT NULL,
            attempt_count INTEGER NOT NULL,
            next_retry_at INTEGER,
            last_error TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_queue_status_retry ON $table(status, next_retry_at)',
        );
      },
    );
  }

  Future<void> insert(QueuedSms sms) async {
    final Database db = await database;
    await db.insert(
      table,
      sms.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<QueuedSms>> fetchAll() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      table,
      orderBy: 'created_at DESC',
    );
    return rows.map(QueuedSms.fromMap).toList();
  }

  Future<List<QueuedSms>> fetchPending(int nowEpochMs) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: "status IN ('pending', 'retry_scheduled') AND (next_retry_at IS NULL OR next_retry_at <= ?)",
      whereArgs: <Object?>[nowEpochMs],
      orderBy: 'created_at ASC',
    );
    return rows.map(QueuedSms.fromMap).toList();
  }

  Future<void> update(QueuedSms sms) async {
    final Database db = await database;
    await db.update(
      table,
      sms.toMap(),
      where: 'id = ?',
      whereArgs: <Object>[sms.id],
    );
  }

  Future<int> countByStatus(String status) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM $table WHERE status = ?',
      <Object>[status],
    );
    return (rows.first['total'] as int?) ?? 0;
  }

  Future<void> rescheduleDeadLetters() async {
    final Database db = await database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      table,
      <String, Object?>{
        'status': 'retry_scheduled',
        'next_retry_at': now,
        'updated_at': now,
      },
      where: "status = 'dead_letter'",
    );
  }
}
