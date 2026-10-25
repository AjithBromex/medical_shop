import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/dates.dart';
import '../core/money.dart';
import 'database.dart';
import 'drive_sync_service.dart';
import 'models.dart';
import 'sync_queue.dart';

/// Thrown for rule violations that should be shown to the person as-is.
class RuleException implements Exception {
  final String message;
  RuleException(this.message);
  @override
  String toString() => message;
}

const methodColumns = {'cash': 'cash_amount', 'gpay': 'gpay_amount', 'cheque': 'cheque_amount'};

/// Every total / report is calculated live from saved rows with SQL (nothing is stored twice).
class Repository {
  Repository._();
  static final Repository instance = Repository._();

  Future<Database> get _db => AppDatabase.instance.db;

  // ----------------------------------------------------------------- Device Node ID
  /// Returns a persistent 2-3 char identifier unique to this device/installation
  /// (e.g. "D1", "D2", "TAB") to prevent duplicate receipt collisions across offline devices.
  Future<String> getDeviceNodeId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var nodeId = prefs.getString('device_node_id')?.trim();
      if (nodeId == null || nodeId.isEmpty) {
        // Generate a random 2-character uppercase node identifier (e.g. D1, B7, X4)
        final randomNum = Random().nextInt(90) + 10;
        nodeId = 'D$randomNum';
        await prefs.setString('device_node_id', nodeId);
      }
      return nodeId;
    } catch (_) {
      return 'D1';
    }
  }

  Future<void> setDeviceNodeId(String id) async {
    final cleaned = id.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.isEmpty || cleaned.length > 6) {
      throw RuleException('Device ID must be 1 to 6 letters or numbers.');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_node_id', cleaned);
  }

  // ----------------------------------------------------------------- shops
  Future<List<MedicalShop>> shops({bool activeOnly = false, int? includeId}) async {
    final d = await _db;
    String where = 'deleted = 0';
    List<Object?>? args;
    if (activeOnly) {
      where = includeId == null ? 'deleted = 0 AND is_active = 1' : 'deleted = 0 AND (is_active = 1 OR id = ?)';
      args = includeId == null ? null : [includeId];
    }
    final rows = await d.query('medical_shops', where: where, whereArgs: args, orderBy: 'shop_name COLLATE NOCASE');
    return rows.map(MedicalShop.fromMap).toList();
  }

  Future<MedicalShop?> shopById(int id) async {
    final rows = await (await _db).query('medical_shops', where: 'id = ? AND deleted = 0', whereArgs: [id]);
    return rows.isEmpty ? null : MedicalShop.fromMap(rows.first);
  }

  Future<List<ShopRow>> shopRows(String? q) async {
    final d = await _db;
    final escQ = q == null || q.isEmpty ? '' : '%${_esc(q)}%';
    final qWhere = q == null || q.isEmpty
        ? 'WHERE s.deleted = 0'
        : "WHERE s.deleted = 0 AND (s.shop_name LIKE ? ESCAPE '\\' OR s.phone LIKE ? ESCAPE '\\' OR s.address LIKE ? ESCAPE '\\')";
    final rows = await d.rawQuery('''
SELECT s.*, COUNT(c.id) AS cnt, COALESCE(SUM(c.total_amount),0) AS tot
FROM medical_shops s LEFT JOIN collections c ON c.medical_shop_id = s.id AND c.deleted = 0
$qWhere GROUP BY s.id ORDER BY s.shop_name COLLATE NOCASE''', q == null || q.isEmpty ? null : [escQ, escQ, escQ]);
    return rows.map((r) => ShopRow(MedicalShop.fromMap(r), r['cnt'] as int, r['tot'] as int)).toList();
  }

  String _esc(String s) => s.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');

  Future<void> saveShop(MedicalShop s) async {
    final d = await _db;
    final dup = await d.query('medical_shops',
        where: s.id == null ? 'shop_name = ? COLLATE NOCASE AND deleted = 0' : 'shop_name = ? COLLATE NOCASE AND id != ? AND deleted = 0',
        whereArgs: s.id == null ? [s.name] : [s.name, s.id]);
    if (dup.isNotEmpty) throw RuleException('A shop named “${s.name}” already exists.');

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    int savedId;

    if (s.id == null) {
      final existingDeleted = await d.query(
        'medical_shops',
        columns: ['id'],
        where: 'shop_name = ? COLLATE NOCASE AND deleted = 1',
        whereArgs: [s.name],
        limit: 1,
      );

      if (existingDeleted.isNotEmpty) {
        savedId = existingDeleted.first['id'] as int;
        await d.update(
          'medical_shops',
          {
            ...s.toMap(),
            'id': savedId,
            'deleted': 0,
            'is_active': 1,
            'updated_at_ms': nowMs,
            'sync_status': 'pending',
          },
          where: 'id = ?',
          whereArgs: [savedId],
        );
      } else {
        savedId = await d.insert('medical_shops', {
          ...s.toMap(),
          'deleted': 0,
          'updated_at_ms': nowMs,
          'sync_status': 'pending',
        });
      }
    } else {
      await d.update(
        'medical_shops',
        {
          ...s.toMap(),
          'deleted': 0,
          'updated_at_ms': nowMs,
          'sync_status': 'pending',
        },
        where: 'id = ?',
        whereArgs: [s.id],
      );
      savedId = s.id!;
    }

    final updated = s.copyWith(id: savedId, updatedAtMs: nowMs, deleted: false, syncStatus: 'pending');
    await SyncQueueManager.instance.enqueue(
      entityType: 'shop',
      entityId: s.name,
      action: 'upsert',
      payload: updated.toMap(),
    );
    DriveSyncService.instance.scheduleDebouncedSync();
  }

  Future<void> toggleShop(MedicalShop s) async {
    final newActive = !s.isActive;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (await _db).update(
      'medical_shops',
      {
        'is_active': newActive ? 1 : 0,
        'updated_at_ms': nowMs,
        'sync_status': 'pending',
      },
      where: 'id = ?',
      whereArgs: [s.id],
    );
    final updated = s.copyWith(isActive: newActive, updatedAtMs: nowMs, syncStatus: 'pending');
    await SyncQueueManager.instance.enqueue(
      entityType: 'shop',
      entityId: s.name,
      action: 'upsert',
      payload: updated.toMap(),
    );
    DriveSyncService.instance.scheduleDebouncedSync();
  }

  Future<void> deleteShop(int id) async {
    final d = await _db;
    final shop = await shopById(id);
    final used = await d.query('collections', columns: ['id'], where: 'medical_shop_id = ? AND deleted = 0', whereArgs: [id], limit: 1);
    if (used.isNotEmpty) {
      throw RuleException('This shop has collection records and cannot be deleted. Deactivate it instead.');
    }

    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    // Soft delete locally
    await d.update(
      'medical_shops',
      {'deleted': 1, 'updated_at_ms': nowMs, 'sync_status': 'pending'},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (shop != null) {
      await SyncQueueManager.instance.enqueue(
        entityType: 'shop',
        entityId: shop.name,
        action: 'delete',
        payload: {'shop_name': shop.name, 'deleted': 1, 'updated_at_ms': nowMs},
      );
    }
    DriveSyncService.instance.scheduleDebouncedSync();
  }

  // ----------------------------------------------------------- collections
  /// Computes the next receipt number by continuing from the most recently entered/saved
  /// sequence (e.g. #14000 -> #14001, or #02000 -> #02001, or #D1-00001 -> #D1-00002).
  /// Safe across multiple devices by embedding the device node prefix.
  Future<String> nextReceiptNumber({String? baseReceipt}) async {
    final d = await _db;

    String? reference = baseReceipt?.trim();
    if (reference == null || reference.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        reference = prefs.getString('last_saved_receipt_number')?.trim();
      } catch (_) {}
    }

    if (reference == null || reference.isEmpty) {
      final rows = await d.rawQuery('SELECT receipt_number FROM collections WHERE deleted = 0 ORDER BY id DESC LIMIT 1');
      if (rows.isNotEmpty) {
        reference = (rows.first['receipt_number'] as String?)?.trim();
      }
    }

    String prefix = '#';
    int padLength = 5;
    int currentNum = 0;

    if (reference != null && reference.isNotEmpty) {
      final match = RegExp(r'^(.*?)(\d+)$').firstMatch(reference);
      if (match != null) {
        prefix = match.group(1) ?? '#';
        final digitsStr = match.group(2)!;
        currentNum = int.tryParse(digitsStr) ?? 0;
        if (prefix == '#' || prefix.isEmpty) {
          padLength = digitsStr.length > 5 && !digitsStr.startsWith('0') ? digitsStr.length : 5;
        } else {
          padLength = digitsStr.length;
        }
      }
    } else {
      // First receipt on fresh install: use Device Node ID prefix to guarantee collision-free offline receipts
      final nodeId = await getDeviceNodeId();
      prefix = '#$nodeId-';
      padLength = 5;
      currentNum = 0;
    }

    var nextNum = currentNum + 1;
    if (nextNum <= 0) nextNum = 1;

    while (true) {
      final candidate = '$prefix${nextNum.toString().padLeft(padLength, '0')}';
      final hit = await d.query(
        'collections',
        columns: ['id'],
        where: 'receipt_number = ? AND deleted = 0',
        whereArgs: [candidate],
        limit: 1,
      );
      if (hit.isEmpty) return candidate;
      nextNum++;
    }
  }

  Future<bool> receiptExists(String receipt, {int? exceptId}) async {
    final rows = await (await _db).query('collections',
        columns: ['id'],
        where: exceptId == null
            ? 'receipt_number = ? COLLATE NOCASE AND deleted = 0'
            : 'receipt_number = ? COLLATE NOCASE AND id != ? AND deleted = 0',
        whereArgs: exceptId == null ? [receipt] : [receipt, exceptId]);
    return rows.isNotEmpty;
  }

  /// Builds the shared WHERE for collection queries.
  ({String where, List<Object?> args}) _collectionWhere(Filters f) {
    final w = <String>['c.deleted = 0'];
    final a = <Object?>[];
    if (f.q != null && f.q!.isNotEmpty) {
      w.add("(c.receipt_number LIKE ? ESCAPE '\\' OR s.shop_name LIKE ? ESCAPE '\\')");
      a..add('%${_esc(f.q!)}%')..add('%${_esc(f.q!)}%');
    }
    if (f.dateFrom != null) {
      w.add('c.collection_date >= ?');
      a.add(isoDate(f.dateFrom!));
    }
    if (f.dateTo != null) {
      w.add('c.collection_date <= ?');
      a.add(isoDate(f.dateTo!));
    }
    if (f.shopId != null) {
      w.add('c.medical_shop_id = ?');
      a.add(f.shopId);
    }
    if (f.method != null) {
      if (f.method == 'gpay_cheque' || f.method == 'online') {
        w.add('(c.gpay_amount > 0 OR c.cheque_amount > 0)');
      } else if (methodColumns.containsKey(f.method)) {
        w.add('c.${methodColumns[f.method]} > 0');
      }
    }
    return (where: 'WHERE ${w.join(' AND ')}', args: a);
  }

  Future<int> saveCollection(Collection c) async {
    if (c.cash < 0 || c.gpay < 0 || c.cheque < 0) {
      throw RuleException('Collection amounts cannot be negative.');
    }
    if (c.gpay + c.cheque > c.total) {
      throw RuleException('GPay/cheque amount cannot exceed total collected amount.');
    }
    if (c.cash != c.total - (c.gpay + c.cheque)) {
      throw RuleException('Cash amount must equal Collected amount minus GPay/Cheque amount.');
    }

    final d = await _db;
    if (await receiptExists(c.receiptNumber, exceptId: c.id)) {
      throw RuleException('Receipt number “${c.receiptNumber}” is already used. Next free number: ${await nextReceiptNumber(baseReceipt: c.receiptNumber)}.');
    }
    try {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      int id;
      if (c.id == null) {
        // If a soft-deleted collection with this receipt number exists, reuse its record
        final existingDeleted = await d.query(
          'collections',
          columns: ['id'],
          where: 'receipt_number = ? COLLATE NOCASE AND deleted = 1',
          whereArgs: [c.receiptNumber],
          limit: 1,
        );

        if (existingDeleted.isNotEmpty) {
          id = existingDeleted.first['id'] as int;
          // In case multiple soft-deleted duplicates exist, remove other ones
          await d.delete(
            'collections',
            where: 'receipt_number = ? COLLATE NOCASE AND id != ? AND deleted = 1',
            whereArgs: [c.receiptNumber, id],
          );
          await d.update(
            'collections',
            {
              ...c.toMap(),
              'id': id,
              'deleted': 0,
              'updated_at_ms': nowMs,
              'sync_status': 'pending',
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [id],
          );
        } else {
          id = await d.insert(
            'collections',
            {
              ...c.toMap(),
              'deleted': 0,
              'updated_at_ms': nowMs,
              'sync_status': 'pending',
            },
            conflictAlgorithm: ConflictAlgorithm.abort,
          );
        }
      } else {
        // If editing an existing collection, clean up any conflicting soft-deleted row
        await d.delete(
          'collections',
          where: 'receipt_number = ? COLLATE NOCASE AND id != ? AND deleted = 1',
          whereArgs: [c.receiptNumber, c.id],
        );
        await d.update(
          'collections',
          {
            ...c.toMap(),
            'deleted': 0,
            'updated_at_ms': nowMs,
            'sync_status': 'pending',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [c.id],
        );
        id = c.id!;
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_saved_receipt_number', c.receiptNumber);
      } catch (_) {}

      final saved = await collectionById(id) ?? c.copyWith(id: id, updatedAtMs: nowMs, deleted: false, syncStatus: 'pending');
      await SyncQueueManager.instance.enqueue(
        entityType: 'collection',
        entityId: c.receiptNumber,
        action: 'upsert',
        payload: saved.toMap()..['shop_name'] = saved.shopName,
      );
      DriveSyncService.instance.scheduleDebouncedSync();
      return id;
    } on DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE')) throw RuleException('That receipt number already exists.');
      rethrow;
    }
  }

  Future<void> deleteCollection(int id) async {
    final c = await collectionById(id);
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    await (await _db).update(
      'collections',
      {'deleted': 1, 'updated_at_ms': nowMs, 'sync_status': 'pending'},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (c != null) {
      await SyncQueueManager.instance.enqueue(
        entityType: 'collection',
        entityId: c.receiptNumber,
        action: 'delete',
        payload: {'receipt_number': c.receiptNumber, 'deleted': 1, 'updated_at_ms': nowMs},
      );
    }
    DriveSyncService.instance.scheduleDebouncedSync();
  }

  Future<Collection?> collectionById(int id) async {
    final rows = await (await _db).rawQuery(
      'SELECT c.*, s.shop_name FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id WHERE c.id = ? AND c.deleted = 0',
      [id],
    );
    return rows.isEmpty ? null : Collection.fromMap(rows.first);
  }

  Future<List<Collection>> collections(Filters f, {int? limit, int offset = 0, bool oldestFirst = false}) async {
    final w = _collectionWhere(f);
    final order = oldestFirst ? 'c.collection_date ASC, c.id ASC' : 'c.collection_date DESC, c.id DESC';
    final rows = await (await _db).rawQuery(
      '''SELECT c.*, s.shop_name FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id
      ${w.where} ORDER BY $order ${limit != null ? 'LIMIT $limit OFFSET $offset' : ''}''',
      w.args,
    );
    return rows.map(Collection.fromMap).toList();
  }

  Future<List<Collection>> recentCollections([int n = 8]) async {
    final rows = await (await _db).rawQuery(
      'SELECT c.*, s.shop_name FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id WHERE c.deleted = 0 ORDER BY c.id DESC LIMIT $n',
    );
    return rows.map(Collection.fromMap).toList();
  }

  Totals _totals(Map<String, Object?> r) => Totals(r['c'] as int, r['g'] as int, r['q'] as int, r['n'] as int);

  /// Totals for the same filter used by the list (so list + totals always agree).
  Future<Totals> totalsFor(Filters f) async {
    final w = _collectionWhere(f);
    final rows = await (await _db).rawQuery('''
SELECT COALESCE(SUM(c.cash_amount),0) c, COALESCE(SUM(c.gpay_amount),0) g,
       COALESCE(SUM(c.cheque_amount),0) q, COUNT(c.id) n
FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id ${w.where}''', w.args);
    return _totals(rows.first);
  }

  Future<Totals> collectionTotals([DateTime? from, DateTime? to, int? shopId]) =>
      totalsFor(Filters(dateFrom: from, dateTo: to, shopId: shopId));

  /// Per-shop totals. Inactive shops are included so history stays complete.
  Future<List<ShopBreakdown>> shopBreakdown([DateTime? from, DateTime? to, int? shopId]) async {
    final w = _collectionWhere(Filters(dateFrom: from, dateTo: to, shopId: shopId));
    final rows = await (await _db).rawQuery('''
SELECT s.id, s.shop_name, s.is_active, COALESCE(SUM(c.cash_amount),0) c, COALESCE(SUM(c.gpay_amount),0) g,
       COALESCE(SUM(c.cheque_amount),0) q, COUNT(c.id) n
FROM medical_shops s JOIN collections c ON c.medical_shop_id = s.id ${w.where} AND s.deleted = 0 GROUP BY s.id''', w.args);
    final list = rows
        .map((r) => ShopBreakdown(r['id'] as int, r['shop_name'] as String, (r['is_active'] as int) == 1,
            r['c'] as int, r['g'] as int, r['q'] as int, r['n'] as int))
        .toList();
    list.sort((a, b) {
      final t = b.total.compareTo(a.total);
      return t != 0 ? t : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  /// kind: daily | weekly (Monday start) | monthly
  Future<List<PeriodRow>> periodBreakdown(String kind,
      {DateTime? from, DateTime? to, int? shopId, int? limit, bool newestFirst = true}) async {
    final key = switch (kind) {
      'daily' => 'c.collection_date',
      'weekly' => "date(c.collection_date, 'weekday 0', '-6 days')",
      _ => "strftime('%Y-%m', c.collection_date)",
    };
    final w = _collectionWhere(Filters(dateFrom: from, dateTo: to, shopId: shopId));
    final rows = await (await _db).rawQuery('''
SELECT $key AS k, COALESCE(SUM(c.cash_amount),0) c, COALESCE(SUM(c.gpay_amount),0) g,
       COALESCE(SUM(c.cheque_amount),0) q, COUNT(c.id) n
FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id ${w.where}
GROUP BY k ORDER BY k ${newestFirst ? 'DESC' : 'ASC'} ${limit != null ? 'LIMIT $limit' : ''}''', w.args);
    return rows.map((r) {
      final k = r['k'] as String;
      final label = switch (kind) {
        'monthly' => monthLabel(k),
        'daily' => dmy(parseIso(k)),
        _ => 'Week of ${dmy(parseIso(k))}',
      };
      return PeriodRow(k, label, r['c'] as int, r['g'] as int, r['q'] as int, r['n'] as int);
    }).toList();
  }

  /// Number of collections where each payment method was used (payment-method report).
  Future<Map<String, int>> methodCounts(Filters f) async {
    final w = _collectionWhere(f);
    final r = (await (await _db).rawQuery('''
SELECT COALESCE(SUM(c.cash_amount>0),0) c, COALESCE(SUM(c.gpay_amount>0),0) g, COALESCE(SUM(c.cheque_amount>0),0) q,
       COALESCE(SUM(c.gpay_amount>0 OR c.cheque_amount>0),0) o
FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id ${w.where}''', w.args)).first;
    return {'cash': r['c'] as int, 'gpay': r['g'] as int, 'cheque': r['q'] as int, 'gpay_cheque': r['o'] as int, 'online': r['o'] as int};
  }

  // -------------------------------------------------------------- expenses
  ({String where, List<Object?> args}) _expenseWhere(Filters f) {
    final w = <String>['deleted = 0'];
    final a = <Object?>[];
    if (f.q != null && f.q!.isNotEmpty) {
      w.add("(description LIKE ? ESCAPE '\\' OR notes LIKE ? ESCAPE '\\')");
      a..add('%${_esc(f.q!)}%')..add('%${_esc(f.q!)}%');
    }
    if (f.category != null) {
      w.add('category = ?');
      a.add(f.category);
    }
    if (f.dateFrom != null) {
      w.add('expense_date >= ?');
      a.add(isoDate(f.dateFrom!));
    }
    if (f.dateTo != null) {
      w.add('expense_date <= ?');
      a.add(isoDate(f.dateTo!));
    }
    return (where: 'WHERE ${w.join(' AND ')}', args: a);
  }

  Future<List<String>> categoryNames() async =>
      (await (await _db).query('expense_categories', where: 'deleted = 0', orderBy: 'name COLLATE NOCASE'))
          .map((r) => r['name'] as String)
          .toList();

  Future<void> addCategory(String name) async {
    name = name.trim().split(RegExp(r'\s+')).join(' ');
    if (name.isEmpty || name.length > 60) throw RuleException('Category name is required (maximum 60 characters).');
    final d = await _db;
    final hit = await d.query('expense_categories', where: 'name = ? COLLATE NOCASE AND deleted = 0', whereArgs: [name]);
    if (hit.isNotEmpty) {
      throw RuleException('Category “$name” already exists.');
    }
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    final existingDeleted = await d.query(
      'expense_categories',
      columns: ['id'],
      where: 'name = ? COLLATE NOCASE AND deleted = 1',
      whereArgs: [name],
      limit: 1,
    );
    if (existingDeleted.isNotEmpty) {
      await d.update(
        'expense_categories',
        {'deleted': 0, 'updated_at_ms': nowMs},
        where: 'id = ?',
        whereArgs: [existingDeleted.first['id']],
      );
    } else {
      await d.insert('expense_categories', {'name': name, 'deleted': 0, 'updated_at_ms': nowMs});
    }
    await SyncQueueManager.instance.enqueue(
      entityType: 'category',
      entityId: name,
      action: 'upsert',
      payload: {'name': name, 'deleted': 0, 'updated_at_ms': nowMs},
    );
    DriveSyncService.instance.scheduleDebouncedSync();
  }

  Future<void> saveExpense(Expense e) async {
    final d = await _db;
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    int id;
    if (e.id == null) {
      id = await d.insert('expenses', {
        ...e.toMap(),
        'deleted': 0,
        'updated_at_ms': nowMs,
        'sync_status': 'pending',
      });
    } else {
      await d.update(
        'expenses',
        {
          ...e.toMap(),
          'deleted': 0,
          'updated_at_ms': nowMs,
          'sync_status': 'pending',
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [e.id],
      );
      id = e.id!;
    }
    final saved = e.copyWith(id: id, updatedAtMs: nowMs, deleted: false, syncStatus: 'pending');
    await SyncQueueManager.instance.enqueue(
      entityType: 'expense',
      entityId: saved.displayId,
      action: 'upsert',
      payload: saved.toMap()..['display_id'] = saved.displayId,
    );
    DriveSyncService.instance.scheduleDebouncedSync();
  }

  Future<void> deleteExpense(int id) async {
    final rows = await (await _db).query('expenses', where: 'id = ? AND deleted = 0', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
      final exp = Expense.fromMap(rows.first);
      await (await _db).update(
        'expenses',
        {'deleted': 1, 'updated_at_ms': nowMs, 'sync_status': 'pending'},
        where: 'id = ?',
        whereArgs: [id],
      );
      await SyncQueueManager.instance.enqueue(
        entityType: 'expense',
        entityId: exp.displayId,
        action: 'delete',
        payload: {'display_id': exp.displayId, 'deleted': 1, 'updated_at_ms': nowMs},
      );
      DriveSyncService.instance.scheduleDebouncedSync();
    }
  }

  Future<List<Expense>> expenses(Filters f, {int? limit, int offset = 0, bool oldestFirst = false}) async {
    final w = _expenseWhere(f);
    final order = oldestFirst ? 'expense_date ASC, id ASC' : 'expense_date DESC, id DESC';
    final rows = await (await _db).rawQuery(
      "SELECT * FROM expenses ${w.where} ORDER BY $order ${limit != null ? 'LIMIT $limit OFFSET $offset' : ''}",
      w.args,
    );
    return rows.map(Expense.fromMap).toList();
  }

  Future<int> expenseCount(Filters f) async {
    final w = _expenseWhere(f);
    return Sqflite.firstIntValue(await (await _db).rawQuery('SELECT COUNT(*) FROM expenses ${w.where}', w.args)) ?? 0;
  }

  Future<int> collectionCount(Filters f) async => (await totalsFor(f)).count;

  Future<List<Expense>> recentExpenses([int n = 5]) async =>
      (await (await _db).query('expenses', where: 'deleted = 0', orderBy: 'id DESC', limit: n))
          .map(Expense.fromMap)
          .toList();

  Future<int> expenseTotal([DateTime? from, DateTime? to, String? category]) async {
    final w = _expenseWhere(Filters(dateFrom: from, dateTo: to, category: category));
    return Sqflite.firstIntValue(
            await (await _db).rawQuery('SELECT COALESCE(SUM(amount),0) FROM expenses ${w.where}', w.args)) ??
        0;
  }

  Future<List<CategoryTotal>> categoryTotals(Filters f) async {
    final w = _expenseWhere(f);
    final rows = await (await _db).rawQuery(
      'SELECT category, SUM(amount) t, COUNT(id) n FROM expenses ${w.where} GROUP BY category ORDER BY t DESC',
      w.args,
    );
    return rows.map((r) => CategoryTotal(r['category'] as String, r['t'] as int, r['n'] as int)).toList();
  }

  // ----------------------------------------------------------- daily money
  Future<List<DayRow>> dailySummaryRows([DateTime? from, DateTime? to, bool newestFirst = true]) async {
    final d = await _db;
    final cw = _collectionWhere(Filters(dateFrom: from, dateTo: to));
    final ew = _expenseWhere(Filters(dateFrom: from, dateTo: to));
    final cRows = await d.rawQuery('''
SELECT c.collection_date AS d, SUM(c.cash_amount) c, SUM(c.gpay_amount) g, SUM(c.cheque_amount) q
FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id ${cw.where} GROUP BY c.collection_date''', cw.args);
    final eRows = await d.rawQuery(
      'SELECT expense_date AS d, SUM(amount) a FROM expenses ${ew.where} GROUP BY expense_date',
      ew.args,
    );
    final days = <String, List<int>>{};
    for (final r in cRows) {
      days[r['d'] as String] = [r['c'] as int, r['g'] as int, r['q'] as int, 0];
    }
    for (final r in eRows) {
      days.putIfAbsent(r['d'] as String, () => [0, 0, 0, 0])[3] = r['a'] as int;
    }
    final list = days.entries.map((e) => DayRow(parseIso(e.key), e.value[0], e.value[1], e.value[2], e.value[3])).toList();
    list.sort((a, b) => newestFirst ? b.date.compareTo(a.date) : a.date.compareTo(b.date));
    return list;
  }

  Future<({Totals totals, int expenses, int remaining})> daySummary(DateTime day) async {
    final t = await collectionTotals(day, day);
    final e = await expenseTotal(day, day);
    return (totals: t, expenses: e, remaining: t.total - e);
  }

  // ------------------------------------------------------------ sample data
  static const sampleTag = '[SAMPLE]';

  Future<void> seedSample({bool force = false}) async {
    final d = await _db;
    final has = (Sqflite.firstIntValue(await d.rawQuery('SELECT (SELECT COUNT(*) FROM collections WHERE deleted = 0)+(SELECT COUNT(*) FROM expenses WHERE deleted = 0)')) ?? 0) > 0;
    if (has && !force) throw RuleException('Real data already exists. Sample data was not added.');
    final ids = <int>[];
    final nowMs = DateTime.now().toUtc().millisecondsSinceEpoch;
    for (final name in ['Sample Pharmacy A', 'Sample Medicals B', 'Sample Health Mart C']) {
      final rows = await d.query('medical_shops', where: 'shop_name = ? AND deleted = 0', whereArgs: [name]);
      ids.add(rows.isEmpty
          ? await d.insert('medical_shops', {
              'shop_name': name,
              'notes': sampleTag,
              'deleted': 0,
              'updated_at_ms': nowMs,
            })
          : rows.first['id'] as int);
    }
    var n = 0;
    final now = today();
    await d.transaction((tx) async {
      for (var day = 0; day < 6; day++) {
        final date = isoDate(now.subtract(Duration(days: day)));
        for (var i = 0; i < ids.length; i++) {
          n++;
          final cash = (1500 + 250 * i + 100 * day) * 100;
          final gpay = (800 + 120 * i) * 100;
          final cheque = (500 * ((day + i) % 2)) * 100;
          await tx.insert('collections', {
            'receipt_number': 'SMP-${n.toString().padLeft(4, '0')}',
            'medical_shop_id': ids[i],
            'collection_date': date,
            'cash_amount': cash,
            'gpay_amount': gpay,
            'cheque_amount': cheque,
            'total_amount': cash + gpay + cheque,
            'notes': sampleTag,
            'deleted': 0,
            'updated_at_ms': nowMs,
          });
        }
        for (final e in [('Petrol', 400), ('Food', 150)]) {
          await tx.insert('expenses', {
            'expense_date': date,
            'category': e.$1,
            'description': 'Sample ${e.$1.toLowerCase()}',
            'amount': (e.$2 + day * 10) * 100,
            'notes': sampleTag,
            'deleted': 0,
            'updated_at_ms': nowMs,
          });
        }
      }
    });
  }

  Future<void> clearSample() async {
    final d = await _db;
    await d.delete('collections', where: 'notes = ?', whereArgs: [sampleTag]);
    await d.delete('expenses', where: 'notes = ?', whereArgs: [sampleTag]);
    await d.rawDelete(
        'DELETE FROM medical_shops WHERE notes = ? AND id NOT IN (SELECT medical_shop_id FROM collections WHERE deleted = 0)', [sampleTag]);
  }

  // ---------------------------------------------------------------- reports
  Future<Report> buildReport(String kind, Filters f) async {
    f = f.normalized();
    final df = f.dateFrom, dt = f.dateTo, shopId = f.shopId;
    late List<String> headers;
    late List<List<Object?>> rows;
    switch (kind) {
      case 'date_range':
        headers = ['#', 'Receipt No.', 'Date', 'Customer', 'Cash', 'Gpay/NEFT/Others', 'Total', 'Notes'];
        var idx = 1;
        rows = (await collections(f, oldestFirst: true))
            .map((c) => <Object?>[
                  idx++,
                  c.receiptNumber.replaceFirst(RegExp(r'^#'), ''),
                  c.date,
                  c.shopName,
                  Money(c.cash),
                  Money(c.gpay + c.cheque),
                  Money(c.total),
                  (c.notes == null || c.notes!.isEmpty) ? '-' : c.notes,
                ])
            .toList();
      case 'daily_collection':
        headers = ['Date', 'Transactions', 'Cash', 'Gpay/NEFT/Others', 'Total'];
        rows = (await periodBreakdown('daily', from: df, to: dt, shopId: shopId, newestFirst: false))
            .map((r) => <Object?>[parseIso(r.key), r.count, Money(r.cash), Money(r.gpay + r.cheque), Money(r.total)])
            .toList();
      case 'shop_wise':
        headers = ['Customer', 'Status', 'Transactions', 'Cash', 'Gpay/NEFT/Others', 'Total'];
        rows = (await shopBreakdown(df, dt, shopId))
            .map((r) => <Object?>[r.name, r.active ? 'Active' : 'Inactive', r.count, Money(r.cash), Money(r.gpay + r.cheque), Money(r.total)])
            .toList();
      case 'payment_method':
        headers = ['Payment Method', 'Transactions', 'Amount', 'Share'];
        final base = Filters(dateFrom: df, dateTo: dt, shopId: shopId);
        final t = await totalsFor(base);
        final counts = await methodCounts(base);
        rows = [];
        final onlineAmount = t.gpay + t.cheque;
        for (final (label, count, amount) in [
          ('Cash', counts['cash'] ?? 0, t.cash),
          ('Gpay/NEFT/Others', counts['gpay_cheque'] ?? ((counts['gpay'] ?? 0) + (counts['cheque'] ?? 0)), onlineAmount),
        ]) {
          final share = t.total == 0 ? '0.0%' : '${((amount * 1000 / t.total).round() / 10).toStringAsFixed(1)}%';
          rows.add([label, count, Money(amount), share]);
        }
      case 'expenses':
        headers = ['Expense ID', 'Date', 'Category', 'Description', 'Amount', 'Notes'];
        rows = (await expenses(f, oldestFirst: true))
            .map((e) => <Object?>[e.displayId, e.date, e.category, e.description, Money(e.amount), (e.notes == null || e.notes!.isEmpty) ? '-' : e.notes])
            .toList();
      case 'daily_balance':
        headers = ['Date', 'Cash', 'Expenses', 'Remaining Cash (Cash - Exp)', 'Gpay/NEFT/Others', 'Total Collection', 'Total Remaining'];
        rows = (await dailySummaryRows(df, dt, false))
            .map((r) => <Object?>[r.date, Money(r.cash), Money(r.expenses), Money(r.remainingCash), Money(r.gpay + r.cheque), Money(r.total), Money(r.remaining)])
            .toList();
      default:
        throw RuleException('Unknown report.');
    }
    List<Object?>? footer;
    if (rows.isNotEmpty) {
      final moneyCols = [for (var i = 0; i < headers.length; i++) if (rows.every((r) => r[i] is Money)) i];
      if (moneyCols.isNotEmpty) {
        footer = [for (var i = 0; i < headers.length; i++) i == 0 ? 'Total' : '-'];
        for (final i in moneyCols) {
          footer[i] = Money(rows.fold<int>(0, (s, r) => s + (r[i] as Money).paise));
        }
      }
    }
    return Report(kind, reportTitles[kind]!, headers, rows, footer);
  }
}

const reportTitles = {
  'daily_collection': 'Daily Collection Report',
  'shop_wise': 'Shop-wise Collection Report',
  'date_range': 'Date-range Collection Report',
  'expenses': 'Expense Report',
  'daily_balance': 'Daily Money Balance Report',
  'payment_method': 'Payment-method Report',
};

/// Marks a report cell as currency (₹ on screen, plain number in CSV).
class Money {
  final int paise;
  const Money(this.paise);
}

class Report {
  final String kind, title;
  final List<String> headers;
  final List<List<Object?>> rows;
  final List<Object?>? footer;
  const Report(this.kind, this.title, this.headers, this.rows, this.footer);

  /// Renders one cell for screen (₹, dd-mm-yyyy) or CSV (plain numbers, formula-injection safe).
  static String cell(Object? v, {bool csv = false}) {
    if (v is Money) return csv ? plain(v.paise) : inr(v.paise);
    if (v is DateTime) return dmy(v);
    if (v == null) return '';
    var t = v.toString();
    if (csv && t.isNotEmpty && '=+-@\t\r'.contains(t[0])) t = "'$t";
    return t;
  }
}
