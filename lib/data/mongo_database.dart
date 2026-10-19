import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import 'api_service.dart';
import 'database.dart';
import 'models.dart';

/// Secure Atlas synchronization coordinator.
/// Uses the backend REST API instead of raw database connections,
/// ensuring database credentials and connection strings never exist in Flutter client code.
class MongoDatabase {
  static final MongoDatabase instance = MongoDatabase._();
  MongoDatabase._();

  // ------------------------------------------------------------- Two-way Sync (Local SQLite <-> Backend / Atlas)
  Future<void> syncAtlasToLocal() async {
    try {
      final isUp = await ApiService.instance.checkHealth();
      if (!isUp) {
        debugPrint('[Atlas Sync] Backend API is not currently reachable at ${ApiService.instance.baseUrl}. Using offline database.');
        return;
      }

      final syncData = await ApiService.instance.getAllSyncData();
      if (syncData == null) {
        debugPrint('[Atlas Sync] Could not fetch sync data from backend.');
        return;
      }

      final localDb = await AppDatabase.instance.db;

      final remoteShops = (syncData['shops'] as List?) ?? [];
      final remoteCollections = (syncData['collections'] as List?) ?? [];
      final remoteExpenses = (syncData['expenses'] as List?) ?? [];
      final remoteCategories = (syncData['categories'] as List?) ?? [];

      final remoteShopNames = <String>{};
      final remoteReceipts = <String>{};
      final remoteDisplayIds = <String>{};
      final remoteCatNames = <String>{};

      // 1. Pull remote shops to local SQLite
      for (final s in remoteShops) {
        final name = s['name'] as String?;
        if (name == null || name.trim().isEmpty) continue;
        final trimmed = name.trim();
        remoteShopNames.add(trimmed.toLowerCase());
        final active = (s['active'] == true || s['is_active'] == 1 || s['is_active'] == true) ? 1 : 0;
        final existing = await localDb.query('medical_shops', where: 'shop_name = ?', whereArgs: [trimmed]);
        if (existing.isEmpty) {
          await localDb.insert('medical_shops', {
            'shop_name': trimmed,
            'address': s['address'] ?? '',
            'phone': s['phone'] ?? '',
            'notes': s['notes'] ?? '',
            'is_active': active,
          });
        } else {
          await localDb.update(
            'medical_shops',
            {
              'address': s['address'] ?? '',
              'phone': s['phone'] ?? '',
              'notes': s['notes'] ?? '',
              'is_active': active,
            },
            where: 'shop_name = ?',
            whereArgs: [trimmed],
          );
        }
      }

      // 2. Pull remote categories
      for (final cat in remoteCategories) {
        final name = (cat is Map ? cat['name'] : cat)?.toString().trim();
        if (name != null && name.isNotEmpty) {
          remoteCatNames.add(name.toLowerCase());
          await localDb.rawInsert('INSERT OR IGNORE INTO expense_categories (name) VALUES (?)', [name]);
        }
      }

      // 3. Pull remote collections
      for (final c in remoteCollections) {
        final rNo = (c['receiptNumber'] ?? c['receipt_number'])?.toString().trim();
        final sName = (c['shopName'] ?? c['shop_name'])?.toString().trim();
        if (rNo == null || rNo.isEmpty || sName == null || sName.isEmpty) continue;
        remoteReceipts.add(rNo.toLowerCase());

        // Ensure shop exists in local database
        final shopRows = await localDb.query('medical_shops', where: 'shop_name = ?', whereArgs: [sName]);
        int shopId;
        if (shopRows.isEmpty) {
          shopId = await localDb.insert('medical_shops', {'shop_name': sName, 'is_active': 1});
        } else {
          shopId = shopRows.first['id'] as int;
        }

        String cDate;
        final rawDate = c['date'] ?? c['collection_date'];
        if (rawDate is String) {
          cDate = rawDate.split('T')[0];
        } else if (rawDate is DateTime) {
          cDate = isoDate(rawDate);
        } else {
          cDate = isoDate(DateTime.now());
        }

        final cash = (c['cash'] ?? c['cash_amount'] ?? 0) as int;
        final gpay = (c['gpay'] ?? c['gpay_amount'] ?? 0) as int;
        final cheque = (c['cheque'] ?? c['cheque_amount'] ?? 0) as int;
        final total = (c['total'] ?? c['total_amount'] ?? (cash + gpay + cheque)) as int;
        final notes = (c['notes'] ?? '').toString();

        final existing = await localDb.query('collections', where: 'receipt_number = ?', whereArgs: [rNo]);
        if (existing.isEmpty) {
          await localDb.insert('collections', {
            'receipt_number': rNo,
            'collection_date': cDate,
            'medical_shop_id': shopId,
            'cash_amount': cash,
            'gpay_amount': gpay,
            'cheque_amount': cheque,
            'total_amount': total,
            'notes': notes,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } else {
          await localDb.update(
            'collections',
            {
              'collection_date': cDate,
              'medical_shop_id': shopId,
              'cash_amount': cash,
              'gpay_amount': gpay,
              'cheque_amount': cheque,
              'total_amount': total,
              'notes': notes,
              'updated_at': DateTime.now().toIso8601String(),
            },
            where: 'receipt_number = ?',
            whereArgs: [rNo],
          );
        }
      }

      // 4. Pull remote expenses
      for (final e in remoteExpenses) {
        final dId = (e['displayId'] ?? e['display_id'])?.toString().trim();
        final cat = (e['category'])?.toString().trim();
        if (cat == null || cat.isEmpty) continue;
        if (dId != null && dId.isNotEmpty) remoteDisplayIds.add(dId.toLowerCase());

        String eDate;
        final rawDate = e['date'] ?? e['expense_date'];
        if (rawDate is String) {
          eDate = rawDate.split('T')[0];
        } else if (rawDate is DateTime) {
          eDate = isoDate(rawDate);
        } else {
          eDate = isoDate(DateTime.now());
        }

        final amount = (e['amount'] ?? 0) as int;
        final desc = (e['description'] ?? '').toString();
        final notes = (e['notes'] ?? '').toString();

        bool exists = false;
        if (dId != null && dId.isNotEmpty) {
          final idNum = int.tryParse(dId.replaceAll(RegExp(r'[^0-9]'), ''));
          if (idNum != null && idNum > 0) {
            final hit = await localDb.query('expenses', where: 'id = ?', whereArgs: [idNum]);
            if (hit.isNotEmpty) {
              exists = true;
              await localDb.update(
                'expenses',
                {
                  'expense_date': eDate,
                  'category': cat,
                  'description': desc,
                  'amount': amount,
                  'notes': notes,
                  'updated_at': DateTime.now().toIso8601String(),
                },
                where: 'id = ?',
                whereArgs: [idNum],
              );
            }
          }
        }
        if (!exists) {
          await localDb.insert('expenses', {
            'expense_date': eDate,
            'category': cat,
            'description': desc,
            'amount': amount,
            'notes': notes,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      // 5. PUSH local records not yet on Atlas to backend
      final localShops = await localDb.query('medical_shops');
      final shopsToPush = <Map<String, dynamic>>[];
      for (final s in localShops) {
        final name = (s['shop_name'] as String?)?.trim();
        if (name == null || name.isEmpty) continue;
        if (!remoteShopNames.contains(name.toLowerCase())) {
          shopsToPush.add({
            'name': name,
            'address': s['address'] ?? '',
            'phone': s['phone'] ?? '',
            'notes': s['notes'] ?? '',
            'active': (s['is_active'] ?? 1) == 1,
          });
        }
      }

      final localCols = await localDb.rawQuery(
        'SELECT c.*, s.shop_name FROM collections c JOIN medical_shops s ON s.id = c.medical_shop_id',
      );
      final colsToPush = <Map<String, dynamic>>[];
      for (final c in localCols) {
        final rNo = (c['receipt_number'] as String?)?.trim();
        if (rNo == null || rNo.isEmpty) continue;
        if (!remoteReceipts.contains(rNo.toLowerCase())) {
          colsToPush.add({
            'receiptNumber': rNo,
            'shopName': c['shop_name'],
            'shopId': c['medical_shop_id'],
            'date': c['collection_date'],
            'cash': c['cash_amount'] ?? 0,
            'gpay': c['gpay_amount'] ?? 0,
            'cheque': c['cheque_amount'] ?? 0,
            'notes': c['notes'] ?? '',
          });
        }
      }

      final localExps = await localDb.query('expenses');
      final expsToPush = <Map<String, dynamic>>[];
      for (final e in localExps) {
        final id = e['id'] as int;
        final displayId = '#EXP${id.toString().padLeft(5, '0')}';
        if (!remoteDisplayIds.contains(displayId.toLowerCase())) {
          expsToPush.add({
            'displayId': displayId,
            'date': e['expense_date'],
            'category': e['category'],
            'description': e['description'],
            'amount': e['amount'],
            'notes': e['notes'] ?? '',
          });
        }
      }

      final localCats = await localDb.query('expense_categories');
      final catsToPush = <String>[];
      for (final c in localCats) {
        final name = (c['name'] as String?)?.trim();
        if (name != null && name.isNotEmpty && !remoteCatNames.contains(name.toLowerCase())) {
          catsToPush.add(name);
        }
      }

      if (shopsToPush.isNotEmpty || colsToPush.isNotEmpty || expsToPush.isNotEmpty || catsToPush.isNotEmpty) {
        await ApiService.instance.pushSyncBatch(
          shops: shopsToPush,
          collections: colsToPush,
          expenses: expsToPush,
          categories: catsToPush,
        );
      }

      debugPrint('[Atlas Sync] Sync completed successfully via backend API.');
    } catch (e) {
      debugPrint('[Atlas Sync] Sync error: $e');
    }
  }

  // ------------------------------------------------------------- Write to Atlas via Backend API: Shops
  Future<void> upsertShop(MedicalShop s) async {
    try {
      await ApiService.instance.saveShop(s);
      debugPrint('[Atlas Sync] Shop saved via API: ${s.name}');
    } catch (e) {
      debugPrint('[Atlas Sync] Failed to save shop via API: $e');
    }
  }

  Future<void> deleteShop(String name) async {
    try {
      await ApiService.instance.deleteShopByName(name);
      debugPrint('[Atlas Sync] Shop deleted via API: $name');
    } catch (e) {
      debugPrint('[Atlas Sync] Failed to delete shop via API: $e');
    }
  }

  // ------------------------------------------------------------- Write to Atlas via Backend API: Collections
  Future<void> upsertCollection(Collection c) async {
    try {
      await ApiService.instance.createOrUpdateCollection(
        receiptNumber: c.receiptNumber,
        shopName: c.shopName,
        shopId: c.shopId,
        date: c.date,
        cash: c.cash,
        gpay: c.gpay,
        cheque: c.cheque,
        notes: c.notes,
      );
      debugPrint('[Atlas Sync] Collection saved via API: ${c.receiptNumber}');
    } catch (e) {
      debugPrint('[Atlas Sync] Failed to save collection via API: $e');
    }
  }

  Future<void> deleteCollection(String receiptNumber) async {
    try {
      await ApiService.instance.deleteCollectionByReceipt(receiptNumber);
      debugPrint('[Atlas Sync] Collection deleted via API: $receiptNumber');
    } catch (e) {
      debugPrint('[Atlas Sync] Failed to delete collection via API: $e');
    }
  }

  // ------------------------------------------------------------- Write to Atlas via Backend API: Expenses
  Future<void> upsertExpense(Expense e) async {
    try {
      await ApiService.instance.createOrUpdateExpense(
        displayId: e.displayId,
        date: e.date,
        category: e.category,
        description: e.description,
        amount: e.amount,
        notes: e.notes,
      );
      debugPrint('[Atlas Sync] Expense saved via API: ${e.displayId}');
    } catch (e) {
      debugPrint('[Atlas Sync] Failed to save expense via API: $e');
    }
  }

  Future<void> deleteExpense(String displayId) async {
    try {
      await ApiService.instance.deleteExpenseByDisplayId(displayId);
      debugPrint('[Atlas Sync] Expense deleted via API: $displayId');
    } catch (e) {
      debugPrint('[Atlas Sync] Failed to delete expense via API: $e');
    }
  }

  // ------------------------------------------------------------- Write to Atlas via Backend API: Categories
  Future<void> upsertCategory(String name) async {
    try {
      await ApiService.instance.addCategory(name);
    } catch (e) {
      debugPrint('[Atlas Sync] Failed to save category via API: $e');
    }
  }

  Future<void> deleteCategory(String name) async {
    try {
      await ApiService.instance.deleteCategory(name);
    } catch (e) {
      debugPrint('[Atlas Sync] Failed to delete category via API: $e');
    }
  }
}
