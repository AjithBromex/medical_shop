import 'package:flutter/foundation.dart';
import 'package:mongo_dart/mongo_dart.dart';

import '../core/dates.dart';
import 'database.dart';
import 'models.dart';

class MongoDatabase {
  static final MongoDatabase instance = MongoDatabase._();
  MongoDatabase._();

  static const String mongoUri =
      'mongodb+srv://ajithnpofficial_db_user:XM508St1NO7NMdCu@medicalshop.p6sujar.mongodb.net/medical_shop?retryWrites=true&w=majority';

  Db? _db;
  Future<Db>? _connectFuture;

  Future<Db?> get database async {
    if (kIsWeb) return null; // Browsers cannot open raw TCP database sockets
    if (_db != null && _db!.isConnected) return _db;
    if (_connectFuture != null) {
      try {
        return await _connectFuture;
      } catch (_) {
        return null;
      }
    }

    _connectFuture = () async {
      try {
        final d = await Db.create(mongoUri);
        await d.open();
        _db = d;
        debugPrint('[MongoDB Atlas] Connected successfully to medical_shop database.');
        return d;
      } catch (e) {
        debugPrint('[MongoDB Atlas] Connection attempt error: $e');
        _db = null;
        rethrow;
      } finally {
        _connectFuture = null;
      }
    }();

    try {
      return await _connectFuture;
    } catch (_) {
      return null;
    }
  }

  Future<DbCollection?> _getCol(String name) async {
    final d = await database;
    if (d == null || !d.isConnected) return null;
    return d.collection(name);
  }

  // ------------------------------------------------------------- Two-way Sync (Local <-> Atlas)
  Future<void> syncAtlasToLocal() async {
    if (kIsWeb) return;
    try {
      final d = await database;
      if (d == null || !d.isConnected) return;
      final localDb = await AppDatabase.instance.db;

      // 1. PUSH local shops to Atlas
      final localShops = await localDb.query('medical_shops');
      final shopsCol = d.collection('medical_shops');
      for (final s in localShops) {
        final name = s['shop_name'] as String?;
        if (name == null || name.isEmpty) continue;
        await shopsCol.update(
          where.eq('shop_name', name),
          {
            r'$set': {
              'shop_name': name,
              'address': s['address'] ?? '',
              'phone': s['phone'] ?? '',
              'notes': s['notes'] ?? '',
              'is_active': s['is_active'] ?? 1,
              'updatedAt': DateTime.now(),
            }
          },
          upsert: true,
        );
      }

      // 2. PUSH local collections to Atlas
      final localCollections = await localDb.rawQuery(
        'SELECT c.*, s.shop_name FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id',
      );
      final collectionsCol = d.collection('collections');
      for (final c in localCollections) {
        final rNo = c['receipt_number'] as String?;
        if (rNo == null || rNo.isEmpty) continue;
        await collectionsCol.update(
          where.eq('receipt_number', rNo),
          {
            r'$set': {
              'receipt_number': rNo,
              'shop_name': c['shop_name'],
              'medical_shop_id': c['medical_shop_id'],
              'collection_date': c['collection_date'],
              'cash_amount': c['cash_amount'] ?? 0,
              'gpay_amount': c['gpay_amount'] ?? 0,
              'cheque_amount': c['cheque_amount'] ?? 0,
              'total_amount': c['total_amount'] ?? 0,
              'notes': c['notes'] ?? '',
              'updatedAt': DateTime.now(),
            }
          },
          upsert: true,
        );
      }

      // 3. PUSH local expenses to Atlas
      final localExpenses = await localDb.query('expenses');
      final expensesCol = d.collection('expenses');
      for (final e in localExpenses) {
        final id = e['id'] as int;
        final displayId = '#EXP${id.toString().padLeft(5, '0')}';
        await expensesCol.update(
          where.eq('display_id', displayId),
          {
            r'$set': {
              'display_id': displayId,
              'expense_date': e['expense_date'],
              'category': e['category'],
              'description': e['description'],
              'amount': e['amount'],
              'notes': e['notes'] ?? '',
              'updatedAt': DateTime.now(),
            }
          },
          upsert: true,
        );
      }

      // 4. PULL shops from Atlas
      final remoteShops = await shopsCol.find().toList();
      for (final s in remoteShops) {
        final name = s['shop_name'] ?? s['name'];
        if (name == null) continue;
        await localDb.rawInsert(
          'INSERT OR IGNORE INTO medical_shops (shop_name, address, phone, notes, is_active) VALUES (?, ?, ?, ?, ?)',
          [name, s['address'], s['phone'], s['notes'], (s['is_active'] ?? s['active'] == true ? 1 : 0)],
        );
      }

      // 5. Sync collections from Atlas
      final remoteCollections = await collectionsCol.find().toList();
      for (final c in remoteCollections) {
        final rNo = c['receipt_number'] ?? c['receiptNumber'];
        final sName = c['shop_name'] ?? c['shopName'];
        if (rNo == null || sName == null) continue;

        // Ensure shop exists locally
        final shopRows = await localDb.query('medical_shops', where: 'shop_name = ?', whereArgs: [sName]);
        int shopId;
        if (shopRows.isEmpty) {
          shopId = await localDb.insert('medical_shops', {'shop_name': sName, 'is_active': 1});
        } else {
          shopId = shopRows.first['id'] as int;
        }

        final cDate = c['collection_date'] ?? (c['date'] is DateTime ? isoDate(c['date'] as DateTime) : c['date']?.toString());
        await localDb.rawInsert(
          '''INSERT OR IGNORE INTO collections
             (receipt_number, collection_date, medical_shop_id, cash_amount, gpay_amount, cheque_amount, total_amount, notes, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            rNo,
            cDate,
            shopId,
            c['cash_amount'] ?? c['cash'] ?? 0,
            c['gpay_amount'] ?? c['gpay'] ?? 0,
            c['cheque_amount'] ?? c['cheque'] ?? 0,
            c['total_amount'] ?? c['total'] ?? 0,
            c['notes'] ?? '',
            DateTime.now().toIso8601String(),
          ],
        );
      }

      // 6. Sync expenses from Atlas
      final remoteExpenses = await expensesCol.find().toList();
      for (final e in remoteExpenses) {
        final cat = e['category'];
        final eDate = e['expense_date'] ?? (e['date'] is DateTime ? isoDate(e['date'] as DateTime) : e['date']?.toString());
        if (cat == null || eDate == null) continue;

        await localDb.rawInsert(
          'INSERT OR IGNORE INTO expenses (expense_date, category, description, amount, notes) VALUES (?, ?, ?, ?, ?)',
          [eDate, cat, e['description'] ?? '', e['amount'] ?? 0, e['notes'] ?? ''],
        );
      }

      // 4. Sync categories
      final categoriesCol = d.collection('categories');
      final remoteCats = await categoriesCol.find().toList();
      for (final cat in remoteCats) {
        final name = cat['name']?.toString();
        if (name != null) {
          await localDb.rawInsert('INSERT OR IGNORE INTO expense_categories (name) VALUES (?)', [name]);
        }
      }

      debugPrint('[MongoDB Atlas] Sync completed successfully.');
    } catch (e) {
      debugPrint('[MongoDB Atlas] Sync error: $e');
    }
  }

  // ------------------------------------------------------------- Write to Atlas: Shops
  Future<void> upsertShop(MedicalShop s) async {
    try {
      final col = await _getCol('medical_shops');
      if (col == null) return;
      final data = {
        'shop_name': s.name.trim(),
        'address': s.address ?? '',
        'phone': s.phone ?? '',
        'notes': s.notes ?? '',
        'is_active': s.isActive ? 1 : 0,
        'updatedAt': DateTime.now(),
      };
      await col.update(
        where.eq('shop_name', s.name.trim()),
        {r'$set': data},
        upsert: true,
      );
      debugPrint('[MongoDB Atlas] Shop saved: ${s.name}');
    } catch (e) {
      debugPrint('[MongoDB Atlas] Failed to save shop to Atlas: $e');
    }
  }

  Future<void> deleteShop(String name) async {
    try {
      final col = await _getCol('medical_shops');
      if (col == null) return;
      await col.remove(where.eq('shop_name', name.trim()));
      debugPrint('[MongoDB Atlas] Shop deleted from Atlas: $name');
    } catch (e) {
      debugPrint('[MongoDB Atlas] Failed to delete shop from Atlas: $e');
    }
  }

  // ------------------------------------------------------------- Write to Atlas: Collections
  Future<void> upsertCollection(Collection c) async {
    try {
      final col = await _getCol('collections');
      if (col == null) return;
      final data = {
        'receipt_number': c.receiptNumber,
        'shop_name': c.shopName,
        'medical_shop_id': c.shopId,
        'collection_date': isoDate(c.date),
        'cash_amount': c.cash,
        'gpay_amount': c.gpay,
        'cheque_amount': c.cheque,
        'total_amount': c.total,
        'notes': c.notes ?? '',
        'updatedAt': DateTime.now(),
      };
      await col.update(
        where.eq('receipt_number', c.receiptNumber),
        {r'$set': data},
        upsert: true,
      );
      debugPrint('[MongoDB Atlas] Collection saved: ${c.receiptNumber}');
    } catch (e) {
      debugPrint('[MongoDB Atlas] Failed to save collection to Atlas: $e');
    }
  }

  Future<void> deleteCollection(String receiptNumber) async {
    try {
      final col = await _getCol('collections');
      if (col == null) return;
      await col.remove(where.eq('receipt_number', receiptNumber));
      debugPrint('[MongoDB Atlas] Collection deleted from Atlas: $receiptNumber');
    } catch (e) {
      debugPrint('[MongoDB Atlas] Failed to delete collection from Atlas: $e');
    }
  }

  // ------------------------------------------------------------- Write to Atlas: Expenses
  Future<void> upsertExpense(Expense e) async {
    try {
      final col = await _getCol('expenses');
      if (col == null) return;
      final data = {
        'display_id': e.displayId,
        'expense_date': isoDate(e.date),
        'category': e.category,
        'description': e.description,
        'amount': e.amount,
        'notes': e.notes ?? '',
        'updatedAt': DateTime.now(),
      };
      await col.update(
        where.eq('display_id', e.displayId),
        {r'$set': data},
        upsert: true,
      );
      debugPrint('[MongoDB Atlas] Expense saved: ${e.displayId}');
    } catch (e) {
      debugPrint('[MongoDB Atlas] Failed to save expense to Atlas: $e');
    }
  }

  Future<void> deleteExpense(String displayId) async {
    try {
      final col = await _getCol('expenses');
      if (col == null) return;
      await col.remove(where.eq('display_id', displayId));
      debugPrint('[MongoDB Atlas] Expense deleted from Atlas: $displayId');
    } catch (e) {
      debugPrint('[MongoDB Atlas] Failed to delete expense from Atlas: $e');
    }
  }

  // ------------------------------------------------------------- Write to Atlas: Categories
  Future<void> upsertCategory(String name) async {
    try {
      final col = await _getCol('categories');
      if (col == null) return;
      await col.update(
        where.eq('name', name.trim()),
        {r'$set': {'name': name.trim(), 'updatedAt': DateTime.now()}},
        upsert: true,
      );
    } catch (e) {
      debugPrint('[MongoDB Atlas] Failed to save category to Atlas: $e');
    }
  }

  Future<void> deleteCategory(String name) async {
    try {
      final col = await _getCol('categories');
      if (col == null) return;
      await col.remove(where.eq('name', name.trim()));
    } catch (e) {
      debugPrint('[MongoDB Atlas] Failed to delete category from Atlas: $e');
    }
  }
}
