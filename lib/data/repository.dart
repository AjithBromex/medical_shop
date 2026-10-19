import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../core/dates.dart';
import '../core/money.dart';
import 'database.dart';
import 'models.dart';
import 'mongo_database.dart';

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

  // ------------------------------------------------------------------ auth
  String _hash(String password, String salt) => sha256.convert(utf8.encode('$salt:$password')).toString();

  Future<bool> hasAdmin() async {
    final d = await _db;
    return Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM admin_users'))! > 0;
  }

  Future<void> createAdmin(String username, String password) async {
    username = username.trim();
    if (username.length < 3) throw RuleException('Username must be at least 3 characters.');
    if (password.length < 8) throw RuleException('Password must be at least 8 characters.');
    final d = await _db;
    final salt = base64UrlEncode(List<int>.generate(16, (_) => Random.secure().nextInt(256)));
    final existing = await d.query('admin_users', where: 'username = ?', whereArgs: [username]);
    if (existing.isNotEmpty) {
      await d.update('admin_users', {'password_hash': _hash(password, salt), 'salt': salt},
          where: 'id = ?', whereArgs: [existing.first['id']]);
    } else {
      await d.insert('admin_users', {'username': username, 'password_hash': _hash(password, salt), 'salt': salt});
    }
  }

  /// Returns the username when the credentials are valid, otherwise null.
  Future<String?> login(String username, String password) async {
    final d = await _db;
    final rows = await d.query('admin_users', where: 'username = ?', whereArgs: [username.trim()]);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return _hash(password, r['salt'] as String) == r['password_hash'] ? r['username'] as String : null;
  }

  // ----------------------------------------------------------------- shops
  Future<List<MedicalShop>> shops({bool activeOnly = false, int? includeId}) async {
    final d = await _db;
    String? where;
    List<Object?>? args;
    if (activeOnly) {
      where = includeId == null ? 'is_active = 1' : 'is_active = 1 OR id = ?';
      args = includeId == null ? null : [includeId];
    }
    final rows = await d.query('medical_shops', where: where, whereArgs: args, orderBy: 'shop_name COLLATE NOCASE');
    return rows.map(MedicalShop.fromMap).toList();
  }

  Future<MedicalShop?> shopById(int id) async {
    final rows = await (await _db).query('medical_shops', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : MedicalShop.fromMap(rows.first);
  }

  Future<List<ShopRow>> shopRows(String? q) async {
    final d = await _db;
    final where = q == null || q.isEmpty ? '' : "WHERE s.shop_name LIKE ? ESCAPE '\\'";
    final rows = await d.rawQuery('''
SELECT s.*, COUNT(c.id) AS cnt, COALESCE(SUM(c.total_amount),0) AS tot
FROM medical_shops s LEFT JOIN collections c ON c.medical_shop_id = s.id
$where GROUP BY s.id ORDER BY s.shop_name COLLATE NOCASE''', where.isEmpty ? null : ['%${_esc(q!)}%']);
    return rows.map((r) => ShopRow(MedicalShop.fromMap(r), r['cnt'] as int, r['tot'] as int)).toList();
  }

  String _esc(String s) => s.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');

  Future<void> saveShop(MedicalShop s) async {
    final d = await _db;
    final dup = await d.query('medical_shops',
        where: s.id == null ? 'shop_name = ?' : 'shop_name = ? AND id != ?',
        whereArgs: s.id == null ? [s.name] : [s.name, s.id]);
    if (dup.isNotEmpty) throw RuleException('A shop named “${s.name}” already exists.');
    if (s.id == null) {
      final id = await d.insert('medical_shops', {...s.toMap(), 'sync_status': 'pending'});
      final saved = MedicalShop(id: id, name: s.name, address: s.address, phone: s.phone, notes: s.notes, isActive: s.isActive, syncStatus: 'pending');
      await MongoDatabase.instance.upsertShop(saved);
    } else {
      await d.update('medical_shops', {...s.toMap(), 'sync_status': 'pending'}, where: 'id = ?', whereArgs: [s.id]);
      await MongoDatabase.instance.upsertShop(s);
    }
  }

  Future<void> toggleShop(MedicalShop s) async {
    final newActive = !s.isActive;
    await (await _db).update('medical_shops', {'is_active': newActive ? 1 : 0, 'sync_status': 'pending'}, where: 'id = ?', whereArgs: [s.id]);
    await MongoDatabase.instance.upsertShop(MedicalShop(id: s.id, name: s.name, address: s.address, phone: s.phone, notes: s.notes, isActive: newActive, syncStatus: 'pending'));
  }

  Future<void> deleteShop(int id) async {
    final d = await _db;
    final shop = await shopById(id);
    final used = await d.query('collections', columns: ['id'], where: 'medical_shop_id = ?', whereArgs: [id], limit: 1);
    if (used.isNotEmpty) {
      throw RuleException('This shop has collection records and cannot be deleted. Deactivate it instead.');
    }
    await d.delete('medical_shops', where: 'id = ?', whereArgs: [id]);
    if (shop != null) {
      MongoDatabase.instance.deleteShop(shop.name);
    }
  }

  // ----------------------------------------------------------- collections
  /// Computes the next receipt number by continuing from the most recently entered/saved
  /// sequence (e.g. #14000 -> #14001, or #02000 -> #02001).
  /// If [baseReceipt] is provided, calculates the next available number from that specific sequence.
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
      final rows = await d.rawQuery('SELECT receipt_number FROM collections ORDER BY id DESC LIMIT 1');
      if (rows.isNotEmpty) {
        reference = (rows.first['receipt_number'] as String?)?.trim();
      }
    }

    String prefix = '#';
    int padLength = 6;
    int currentNum = 0;

    if (reference != null && reference.isNotEmpty) {
      final match = RegExp(r'^(.*?)(\d+)$').firstMatch(reference);
      if (match != null) {
        prefix = match.group(1) ?? '#';
        final digitsStr = match.group(2)!;
        padLength = digitsStr.length;
        currentNum = int.tryParse(digitsStr) ?? 0;
      }
    }

    var nextNum = currentNum + 1;
    if (nextNum <= 0) nextNum = 1;

    while (true) {
      final candidate = '$prefix${nextNum.toString().padLeft(padLength, '0')}';
      final hit = await d.query(
        'collections',
        columns: ['id'],
        where: 'receipt_number = ?',
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
        where: exceptId == null ? 'receipt_number = ?' : 'receipt_number = ? AND id != ?',
        whereArgs: exceptId == null ? [receipt] : [receipt, exceptId]);
    return rows.isNotEmpty;
  }

  /// Builds the shared WHERE for collection queries.
  ({String where, List<Object?> args}) _collectionWhere(Filters f) {
    final w = <String>[];
    final a = <Object?>[];
    if (f.q != null && f.q!.isNotEmpty) {
      w.add("(c.receipt_number LIKE ? ESCAPE '\\' OR s.shop_name LIKE ? ESCAPE '\\')");
      a..add('%${_esc(f.q!)}%')..add('%${_esc(f.q!)}%');
    }
    if (f.dateFrom != null) { w.add('c.collection_date >= ?'); a.add(isoDate(f.dateFrom!)); }
    if (f.dateTo != null) { w.add('c.collection_date <= ?'); a.add(isoDate(f.dateTo!)); }
    if (f.shopId != null) { w.add('c.medical_shop_id = ?'); a.add(f.shopId); }
    if (f.method != null) {
      if (f.method == 'gpay_cheque' || f.method == 'online') {
        w.add('(c.gpay_amount > 0 OR c.cheque_amount > 0)');
      } else if (methodColumns.containsKey(f.method)) {
        w.add('c.${methodColumns[f.method]} > 0');
      }
    }
    return (where: w.isEmpty ? '' : 'WHERE ${w.join(' AND ')}', args: a);
  }

  Future<int> saveCollection(Collection c) async {
    final d = await _db;
    if (await receiptExists(c.receiptNumber, exceptId: c.id)) {
      throw RuleException('Receipt number “${c.receiptNumber}” is already used. Next free number: ${await nextReceiptNumber(baseReceipt: c.receiptNumber)}.');
    }
    try {
      int id;
      if (c.id == null) {
        id = await d.insert('collections', {...c.toMap(), 'sync_status': 'pending'}, conflictAlgorithm: ConflictAlgorithm.abort);
      } else {
        await d.update('collections', {...c.toMap(), 'sync_status': 'pending', 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?', whereArgs: [c.id]);
        id = c.id!;
      }
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_saved_receipt_number', c.receiptNumber);
      } catch (_) {}
      final saved = await collectionById(id) ?? c;
      await MongoDatabase.instance.upsertCollection(saved);
      return id;
    } on DatabaseException catch (e) {
      if (e.toString().contains('UNIQUE')) throw RuleException('That receipt number already exists.');
      rethrow;
    }
  }

  Future<void> deleteCollection(int id) async {
    final c = await collectionById(id);
    await (await _db).delete('collections', where: 'id = ?', whereArgs: [id]);
    if (c != null) {
      MongoDatabase.instance.deleteCollection(c.receiptNumber);
    }
  }

  Future<Collection?> collectionById(int id) async {
    final rows = await (await _db).rawQuery(
        'SELECT c.*, s.shop_name FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id WHERE c.id = ?', [id]);
    return rows.isEmpty ? null : Collection.fromMap(rows.first);
  }

  Future<List<Collection>> collections(Filters f, {int? limit, int offset = 0, bool oldestFirst = false}) async {
    final w = _collectionWhere(f);
    final order = oldestFirst ? 'c.collection_date ASC, c.id ASC' : 'c.collection_date DESC, c.id DESC';
    final rows = await (await _db).rawQuery(
        '''SELECT c.*, s.shop_name FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id
        ${w.where} ORDER BY $order ${limit != null ? 'LIMIT $limit OFFSET $offset' : ''}''', w.args);
    return rows.map(Collection.fromMap).toList();
  }

  Future<List<Collection>> recentCollections([int n = 8]) async {
    final rows = await (await _db).rawQuery(
        'SELECT c.*, s.shop_name FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id ORDER BY c.id DESC LIMIT $n');
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
FROM medical_shops s JOIN collections c ON c.medical_shop_id = s.id ${w.where} GROUP BY s.id''', w.args);
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
    final w = <String>[];
    final a = <Object?>[];
    if (f.q != null && f.q!.isNotEmpty) {
      w.add("(description LIKE ? ESCAPE '\\' OR notes LIKE ? ESCAPE '\\')");
      a..add('%${_esc(f.q!)}%')..add('%${_esc(f.q!)}%');
    }
    if (f.category != null) { w.add('category = ?'); a.add(f.category); }
    if (f.dateFrom != null) { w.add('expense_date >= ?'); a.add(isoDate(f.dateFrom!)); }
    if (f.dateTo != null) { w.add('expense_date <= ?'); a.add(isoDate(f.dateTo!)); }
    return (where: w.isEmpty ? '' : 'WHERE ${w.join(' AND ')}', args: a);
  }

  Future<List<String>> categoryNames() async =>
      (await (await _db).query('expense_categories', orderBy: 'name COLLATE NOCASE')).map((r) => r['name'] as String).toList();

  Future<void> addCategory(String name) async {
    name = name.trim().split(RegExp(r'\s+')).join(' ');
    if (name.isEmpty || name.length > 60) throw RuleException('Category name is required (maximum 60 characters).');
    final d = await _db;
    if ((await d.query('expense_categories', where: 'name = ?', whereArgs: [name])).isNotEmpty) {
      throw RuleException('Category “$name” already exists.');
    }
    await d.insert('expense_categories', {'name': name});
    MongoDatabase.instance.upsertCategory(name);
  }

  Future<void> saveExpense(Expense e) async {
    final d = await _db;
    int id;
    if (e.id == null) {
      id = await d.insert('expenses', {...e.toMap(), 'sync_status': 'pending'});
    } else {
      await d.update('expenses', {...e.toMap(), 'sync_status': 'pending', 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?', whereArgs: [e.id]);
      id = e.id!;
    }
    final saved = Expense(id: id, date: e.date, category: e.category, description: e.description, amount: e.amount, notes: e.notes, syncStatus: 'pending');
    await MongoDatabase.instance.upsertExpense(saved);
  }

  Future<void> deleteExpense(int id) async {
    final rows = await (await _db).query('expenses', where: 'id = ?', whereArgs: [id]);
    await (await _db).delete('expenses', where: 'id = ?', whereArgs: [id]);
    if (rows.isNotEmpty) {
      final exp = Expense.fromMap(rows.first);
      MongoDatabase.instance.deleteExpense(exp.displayId);
    }
  }

  Future<List<Expense>> expenses(Filters f, {int? limit, int offset = 0, bool oldestFirst = false}) async {
    final w = _expenseWhere(f);
    final order = oldestFirst ? 'expense_date ASC, id ASC' : 'expense_date DESC, id DESC';
    final rows = await (await _db).rawQuery(
        "SELECT * FROM expenses ${w.where} ORDER BY $order ${limit != null ? 'LIMIT $limit OFFSET $offset' : ''}", w.args);
    return rows.map(Expense.fromMap).toList();
  }

  Future<int> expenseCount(Filters f) async {
    final w = _expenseWhere(f);
    return Sqflite.firstIntValue(await (await _db).rawQuery('SELECT COUNT(*) FROM expenses ${w.where}', w.args)) ?? 0;
  }

  Future<int> collectionCount(Filters f) async => (await totalsFor(f)).count;

  Future<List<Expense>> recentExpenses([int n = 5]) async =>
      (await (await _db).query('expenses', orderBy: 'id DESC', limit: n)).map(Expense.fromMap).toList();

  Future<int> expenseTotal([DateTime? from, DateTime? to, String? category]) async {
    final w = _expenseWhere(Filters(dateFrom: from, dateTo: to, category: category));
    return Sqflite.firstIntValue(
            await (await _db).rawQuery('SELECT COALESCE(SUM(amount),0) FROM expenses ${w.where}', w.args)) ??
        0;
  }

  Future<List<CategoryTotal>> categoryTotals(Filters f) async {
    final w = _expenseWhere(f);
    final rows = await (await _db).rawQuery(
        'SELECT category, SUM(amount) t, COUNT(id) n FROM expenses ${w.where} GROUP BY category ORDER BY t DESC', w.args);
    return rows.map((r) => CategoryTotal(r['category'] as String, r['t'] as int, r['n'] as int)).toList();
  }

  // ----------------------------------------------------------- daily money
  /// One row per date with any collection or expense.
  /// remaining = (cash + gpay + cheque) - expenses, on the combined total only.
  Future<List<DayRow>> dailySummaryRows([DateTime? from, DateTime? to, bool newestFirst = true]) async {
    final d = await _db;
    final cw = _collectionWhere(Filters(dateFrom: from, dateTo: to));
    final ew = _expenseWhere(Filters(dateFrom: from, dateTo: to));
    final cRows = await d.rawQuery('''
SELECT c.collection_date AS d, SUM(c.cash_amount) c, SUM(c.gpay_amount) g, SUM(c.cheque_amount) q
FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id ${cw.where} GROUP BY c.collection_date''', cw.args);
    final eRows = await d.rawQuery(
        'SELECT expense_date AS d, SUM(amount) a FROM expenses ${ew.where} GROUP BY expense_date', ew.args);
    final days = <String, List<int>>{}; // cash, gpay, cheque, expenses
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
    final has = (Sqflite.firstIntValue(await d.rawQuery('SELECT (SELECT COUNT(*) FROM collections)+(SELECT COUNT(*) FROM expenses)')) ?? 0) > 0;
    if (has && !force) throw RuleException('Real data already exists. Sample data was not added.');
    final ids = <int>[];
    for (final name in ['Sample Pharmacy A', 'Sample Medicals B', 'Sample Health Mart C']) {
      final rows = await d.query('medical_shops', where: 'shop_name = ?', whereArgs: [name]);
      ids.add(rows.isEmpty ? await d.insert('medical_shops', {'shop_name': name, 'notes': sampleTag}) : rows.first['id'] as int);
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
            'receipt_number': 'SMP-${n.toString().padLeft(4, '0')}', 'medical_shop_id': ids[i],
            'collection_date': date, 'cash_amount': cash, 'gpay_amount': gpay, 'cheque_amount': cheque,
            'total_amount': cash + gpay + cheque, 'notes': sampleTag,
          });
        }
        for (final e in [('Petrol', 400), ('Food', 150)]) {
          await tx.insert('expenses', {
            'expense_date': date, 'category': e.$1, 'description': 'Sample ${e.$1.toLowerCase()}',
            'amount': (e.$2 + day * 10) * 100, 'notes': sampleTag,
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
        'DELETE FROM medical_shops WHERE notes = ? AND id NOT IN (SELECT medical_shop_id FROM collections)', [sampleTag]);
  }

  // ---------------------------------------------------------------- reports
  Future<Report> buildReport(String kind, Filters f) async {
    f = f.normalized();
    final df = f.dateFrom, dt = f.dateTo, shopId = f.shopId;
    late List<String> headers;
    late List<List<Object?>> rows;
    switch (kind) {
      case 'date_range':
        headers = ['Receipt No', 'Date', 'Medical Shop', 'Cash', 'Gpay/cheque/CN', 'Total', 'Notes'];
        rows = (await collections(f, oldestFirst: true))
            .map((c) => <Object?>[c.receiptNumber, c.date, c.shopName, Money(c.cash), Money(c.gpay + c.cheque), Money(c.total), c.notes ?? ''])
            .toList();
      case 'daily_collection':
        headers = ['Date', 'Transactions', 'Cash', 'Gpay/cheque/CN', 'Total'];
        rows = (await periodBreakdown('daily', from: df, to: dt, shopId: shopId, newestFirst: false))
            .map((r) => <Object?>[parseIso(r.key), r.count, Money(r.cash), Money(r.gpay + r.cheque), Money(r.total)])
            .toList();
      case 'shop_wise':
        headers = ['Medical Shop', 'Status', 'Transactions', 'Cash', 'Gpay/cheque/CN', 'Total'];
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
          ('Gpay/cheque/CN', counts['gpay_cheque'] ?? ((counts['gpay'] ?? 0) + (counts['cheque'] ?? 0)), onlineAmount),
        ]) {
          final share = t.total == 0 ? '0.0%' : '${((amount * 1000 / t.total).round() / 10).toStringAsFixed(1)}%';
          rows.add([label, count, Money(amount), share]);
        }
      case 'expenses':
        headers = ['Expense ID', 'Date', 'Category', 'Description', 'Amount', 'Notes'];
        rows = (await expenses(f, oldestFirst: true))
            .map((e) => <Object?>[e.displayId, e.date, e.category, e.description, Money(e.amount), e.notes ?? ''])
            .toList();
      case 'daily_balance':
        headers = ['Date', 'Cash', 'Expenses', 'Remaining Cash (Cash - Exp)', 'Gpay/cheque/CN', 'Total Collection', 'Total Remaining'];
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
        footer = [for (var i = 0; i < headers.length; i++) i == 0 ? 'Total' : ''];
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
