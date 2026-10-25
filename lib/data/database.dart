import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

const defaultCategories = ['Petrol', 'Food', 'Travel', 'Parking', 'Personal Expense', 'Other'];
const defaultDbFileName = 'medical_shop.db';

/// Opens the SQLite database separated per Google Account ID.
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _db;
  String? _currentAccountId;

  static bool get _isDesktop => !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static void initFactory() {
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWebNoWebWorker;
    } else if (_isDesktop) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  String get currentAccountId => _currentAccountId ?? 'default';

  String _sanitize(String? id) {
    if (id == null || id.trim().isEmpty) return 'default';
    return id.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
  }

  String get dbFileName {
    final sanitized = _sanitize(_currentAccountId);
    if (sanitized == 'default') return defaultDbFileName;
    return 'medical_shop_$sanitized.db';
  }

  /// Switches active database to a specific Google account ID.
  Future<void> switchAccount(String? accountId) async {
    final newId = accountId?.trim();
    if (_currentAccountId == newId && _db != null && _db!.isOpen) return;
    await close();
    _currentAccountId = newId;
    await db; // Re-open
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

  Future<Database> get db async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = await dbPath;

    // If an account-specific DB does not exist yet, but legacy medical_shop.db does,
    // copy the legacy database over so existing local data is seamlessly preserved!
    if (!kIsWeb && dbFileName != defaultDbFileName) {
      final targetFile = File(path);
      if (!await targetFile.exists()) {
        final legacyDir = _isDesktop ? await getApplicationSupportDirectory() : Directory(await getDatabasesPath());
        final legacyFile = File(p.join(legacyDir.path, defaultDbFileName));
        if (await legacyFile.exists()) {
          try {
            await legacyFile.copy(path);
            debugPrint('[AppDatabase] Migrated existing data to $dbFileName');
          } catch (e) {
            debugPrint('[AppDatabase] Legacy copy error: $e');
          }
        }
      }
    }

    return openDatabase(
      path,
      version: 3,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onUpgrade: (d, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          try {
            await d.execute("ALTER TABLE medical_shops ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'");
          } catch (_) {}
          try {
            await d.execute("ALTER TABLE collections ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'");
          } catch (_) {}
          try {
            await d.execute("ALTER TABLE expenses ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'synced'");
          } catch (_) {}
          await d.execute('''
CREATE TABLE IF NOT EXISTS sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
)''');
        }

        if (oldVersion < 3) {
          // Add updated_at_ms and deleted soft-delete flag
          try {
            await d.execute("ALTER TABLE medical_shops ADD COLUMN updated_at_ms INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}
          try {
            await d.execute("ALTER TABLE medical_shops ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}

          try {
            await d.execute("ALTER TABLE collections ADD COLUMN updated_at_ms INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}
          try {
            await d.execute("ALTER TABLE collections ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}

          try {
            await d.execute("ALTER TABLE expenses ADD COLUMN updated_at_ms INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}
          try {
            await d.execute("ALTER TABLE expenses ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}

          try {
            await d.execute("ALTER TABLE expense_categories ADD COLUMN updated_at_ms INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}
          try {
            await d.execute("ALTER TABLE expense_categories ADD COLUMN deleted INTEGER NOT NULL DEFAULT 0");
          } catch (_) {}

          // Backfill updated_at_ms with current timestamp for existing rows that had 0
          final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
          try {
            await d.execute("UPDATE medical_shops SET updated_at_ms = $nowMs WHERE updated_at_ms = 0");
            await d.execute("UPDATE collections SET updated_at_ms = $nowMs WHERE updated_at_ms = 0");
            await d.execute("UPDATE expenses SET updated_at_ms = $nowMs WHERE updated_at_ms = 0");
            await d.execute("UPDATE expense_categories SET updated_at_ms = $nowMs WHERE updated_at_ms = 0");
          } catch (_) {}
        }
      },
      onCreate: (d, _) async {
        await d.execute('''
CREATE TABLE medical_shops (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  shop_name TEXT NOT NULL COLLATE NOCASE UNIQUE,
  address TEXT, phone TEXT, notes TEXT,
  is_active INTEGER NOT NULL DEFAULT 1,
  sync_status TEXT NOT NULL DEFAULT 'synced',
  deleted INTEGER NOT NULL DEFAULT 0,
  updated_at_ms INTEGER NOT NULL DEFAULT 0,
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
  sync_status TEXT NOT NULL DEFAULT 'synced',
  deleted INTEGER NOT NULL DEFAULT 0,
  updated_at_ms INTEGER NOT NULL DEFAULT 0,
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
  deleted INTEGER NOT NULL DEFAULT 0,
  updated_at_ms INTEGER NOT NULL DEFAULT 0,
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
  sync_status TEXT NOT NULL DEFAULT 'synced',
  deleted INTEGER NOT NULL DEFAULT 0,
  updated_at_ms INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now','localtime')),
  CONSTRAINT ck_expense_amount_positive CHECK (amount > 0)
)''');
        await d.execute('CREATE INDEX ix_expense_date_category ON expenses(expense_date, category)');
        await d.execute('''
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  action TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL,
  attempts INTEGER NOT NULL DEFAULT 0,
  last_error TEXT
)''');
        final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
        for (final c in defaultCategories) {
          await d.insert('expense_categories', {
            'name': c,
            'deleted': 0,
            'updated_at_ms': nowMs,
          });
        }
      },
    );
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
    }
    _db = null;
  }

  /// Consistent copy of the database into the backups folder.
  Future<File> backup() async {
    if (kIsWeb) {
      throw UnsupportedError('Database file backup is not supported in web browsers.');
    }
    final d = await db;
    try {
      await d.rawQuery('PRAGMA wal_checkpoint(FULL)');
    } catch (_) {}
    final dir = (await backupDir)!;
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp = '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
    final dest = File(p.join(dir.path, '${p.basenameWithoutExtension(dbFileName)}_$stamp.db'));
    return File(await dbPath).copy(dest.path);
  }

  /// Replaces the live database with [backupFile] (a safety backup is made first).
  Future<File> restore(File backupFile) async {
    if (kIsWeb) {
      throw UnsupportedError('Database restore is not supported in web browsers.');
    }
    final probe = await openDatabase(backupFile.path, readOnly: true);
    try {
      final tables = (await probe.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
          .map((r) => r['name'] as String)
          .toSet();
      final ok = (await probe.rawQuery('PRAGMA integrity_check')).first.values.first == 'ok';
      if (!ok || !{'collections', 'expenses', 'medical_shops'}.every(tables.contains)) {
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
