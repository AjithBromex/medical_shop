import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

const defaultCategories = ['Petrol', 'Food', 'Travel', 'Parking', 'Personal Expense', 'Other'];
const dbFileName = 'medical_shop.db';

/// Opens the SQLite database. Same schema and constraints as the Flask app.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;

  static bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static void initFactory() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
    } else if (_isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  Future<String> get dbPath async {
    if (kIsWeb) {
      return dbFileName;
    }
    final dir = _isDesktop ? await getApplicationSupportDirectory() : Directory(await getDatabasesPath());
    await dir.create(recursive: true);
    return p.join(dir.path, dbFileName);
  }

  Future<Directory?> get backupDir async {
    if (kIsWeb) return null;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'medical_shop_backups'));
    await dir.create(recursive: true);
    return dir;
  }

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = await dbPath;
    return openDatabase(
      path,
      version: 1,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, _) async {
        await d.execute('''
CREATE TABLE medical_shops (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  shop_name TEXT NOT NULL COLLATE NOCASE UNIQUE,
  address TEXT, phone TEXT, notes TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
)''');
        await d.execute('''
CREATE TABLE collections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  receipt_number TEXT NOT NULL COLLATE NOCASE UNIQUE,
  medical_shop_id INTEGER NOT NULL REFERENCES medical_shops(id) ON DELETE RESTRICT,
  collection_date TEXT NOT NULL,
  cash_amount INTEGER NOT NULL DEFAULT 0,
  gpay_amount INTEGER NOT NULL DEFAULT 0,
  cheque_amount INTEGER NOT NULL DEFAULT 0,
  total_amount INTEGER NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  CONSTRAINT ck_collection_amounts_non_negative CHECK (cash_amount >= 0 AND gpay_amount >= 0 AND cheque_amount >= 0),
  CONSTRAINT ck_collection_total_matches CHECK (total_amount = cash_amount + gpay_amount + cheque_amount)
)''');
        await d.execute('CREATE INDEX ix_collection_date_shop ON collections(collection_date, medical_shop_id)');
        await d.execute('''
CREATE TABLE expense_categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL COLLATE NOCASE UNIQUE,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
)''');
        await d.execute('''
CREATE TABLE expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  expense_date TEXT NOT NULL,
  category TEXT NOT NULL COLLATE NOCASE,
  description TEXT NOT NULL,
  amount INTEGER NOT NULL,
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  CONSTRAINT ck_expense_amount_positive CHECK (amount > 0)
)''');
        await d.execute('CREATE INDEX ix_expense_date_category ON expenses(expense_date, category)');
        await d.execute('''
CREATE TABLE admin_users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  username TEXT NOT NULL COLLATE NOCASE UNIQUE,
  password_hash TEXT NOT NULL,
  salt TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime'))
)''');
        for (final c in defaultCategories) {
          await d.insert('expense_categories', {'name': c});
        }
      },
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  /// Consistent copy of the database into the backups folder.
  Future<File> backup() async {
    if (kIsWeb) {
      throw UnsupportedError('Database file backup is not supported in web browsers.');
    }
    final d = await db;
    await d.execute('PRAGMA wal_checkpoint(FULL)');
    final dir = (await backupDir)!;
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final dest = File(p.join(dir.path, 'medical_shop_$stamp.db'));
    return File(await dbPath).copy(dest.path);
  }

  /// Replaces the live database with [backupFile] (a safety backup is made first).
  Future<File> restore(File backupFile) async {
    if (kIsWeb) {
      throw UnsupportedError('Database restore is not supported in web browsers.');
    }
    // validate before touching anything
    final probe = await openDatabase(backupFile.path, readOnly: true);
    try {
      final tables = (await probe.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
          .map((r) => r['name'] as String)
          .toSet();
      final ok = (await probe.rawQuery('PRAGMA integrity_check')).first.values.first == 'ok';
      if (!ok || !{'collections', 'expenses', 'medical_shops', 'admin_users'}.every(tables.contains)) {
        throw const FormatException('That file is not a valid Medical Shop Manager backup.');
      }
    } finally {
      await probe.close();
    }
    final safety = await backup();
    await close();
    await backupFile.copy(await dbPath);
    await db; // reopen
    return safety;
  }
}
