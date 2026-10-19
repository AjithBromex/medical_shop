import 'package:flutter/foundation.dart';

import '../core/dates.dart';
import 'api_service.dart';
import 'database.dart';
import 'models.dart';
import 'sync_queue.dart';

/// Cloud synchronization manager connecting to MongoDB Atlas via the hosted API.
/// Manages online confirmations and delegates offline mutations to the durable SyncQueueManager.
class MongoDatabase {
  static final MongoDatabase instance = MongoDatabase._();
  MongoDatabase._();

  // ------------------------------------------------------------- Two-way Sync (Local SQLite <-> Backend / Atlas)
  Future<void> syncAtlasToLocal() async {
    try {
      // 1. Drain any pending local offline mutations first so local changes reach Atlas
      await SyncQueueManager.instance.processQueue();

      final isUp = await ApiService.instance.checkHealth();
      if (!isUp) {
        debugPrint('[Atlas Sync] Backend API is not currently reachable at ${ApiService.instance.baseUrl}. Working in offline mode.');
        return;
      }

      final syncData = await ApiService.instance.getAllSyncData();
      if (syncData == null) {
        debugPrint('[Atlas Sync] Could not fetch sync data from hosted API.');
        return;
      }

      final localDb = await AppDatabase.instance.db;

      final remoteShops = (syncData['shops'] as List?) ?? [];
      final remoteCollections = (syncData['collections'] as List?) ?? [];
      final remoteExpenses = (syncData['expenses'] as List?) ?? [];
      final remoteCategories = (syncData['categories'] as List?) ?? [];

      // 1. Pull remote shops to local SQLite (respecting any locally pending shop edits)
      for (final s in remoteShops) {
        final name = s['name'] as String?;
        if (name == null || name.trim().isEmpty) continue;
        final trimmed = name.trim();
        final active = (s['active'] == true || s['is_active'] == 1 || s['is_active'] == true) ? 1 : 0;
        final existing = await localDb.query('medical_shops', where: 'shop_name = ?', whereArgs: [trimmed]);
        if (existing.isEmpty) {
          await localDb.insert('medical_shops', {
            'shop_name': trimmed,
            'address': s['address'] ?? '',
            'phone': s['phone'] ?? '',
            'notes': s['notes'] ?? '',
            'is_active': active,
            'sync_status': 'synced',
          });
        } else {
          // Only overwrite if local record is already synced (do not overwrite pending offline changes)
          final isPending = existing.first['sync_status'] == 'pending';
          if (!isPending) {
            await localDb.update(
              'medical_shops',
              {
                'address': s['address'] ?? '',
                'phone': s['phone'] ?? '',
                'notes': s['notes'] ?? '',
                'is_active': active,
                'sync_status': 'synced',
              },
              where: 'shop_name = ?',
              whereArgs: [trimmed],
            );
          }
        }
      }

      // 2. Pull remote categories
      for (final cat in remoteCategories) {
        final name = (cat is Map ? cat['name'] : cat)?.toString().trim();
        if (name != null && name.isNotEmpty) {
          await localDb.rawInsert('INSERT OR IGNORE INTO expense_categories (name) VALUES (?)', [name]);
        }
      }

      // 3. Pull remote collections (respecting any locally pending collection edits)
      for (final c in remoteCollections) {
        final rNo = (c['receiptNumber'] ?? c['receipt_number'])?.toString().trim();
        final sName = (c['shopName'] ?? c['shop_name'])?.toString().trim();
        if (rNo == null || rNo.isEmpty || sName == null || sName.isEmpty) continue;

        // Ensure shop exists in local database
        final shopRows = await localDb.query('medical_shops', where: 'shop_name = ?', whereArgs: [sName]);
        int shopId;
        if (shopRows.isEmpty) {
          shopId = await localDb.insert('medical_shops', {'shop_name': sName, 'is_active': 1, 'sync_status': 'synced'});
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
            'sync_status': 'synced',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        } else {
          final isPending = existing.first['sync_status'] == 'pending';
          if (!isPending) {
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
                'sync_status': 'synced',
                'updated_at': DateTime.now().toIso8601String(),
              },
              where: 'receipt_number = ?',
              whereArgs: [rNo],
            );
          }
        }
      }

      // 4. Pull remote expenses (respecting locally pending edits)
      for (final e in remoteExpenses) {
        final dId = (e['displayId'] ?? e['display_id'])?.toString().trim();
        final cat = (e['category'])?.toString().trim();
        if (cat == null || cat.isEmpty) continue;

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
              final isPending = hit.first['sync_status'] == 'pending';
              if (!isPending) {
                await localDb.update(
                  'expenses',
                  {
                    'expense_date': eDate,
                    'category': cat,
                    'description': desc,
                    'amount': amount,
                    'notes': notes,
                    'sync_status': 'synced',
                    'updated_at': DateTime.now().toIso8601String(),
                  },
                  where: 'id = ?',
                  whereArgs: [idNum],
                );
              }
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
            'sync_status': 'synced',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }

      debugPrint('[Atlas Sync] Sync completed successfully via hosted API.');
    } catch (e) {
      debugPrint('[Atlas Sync] Sync error: $e');
    }
  }

  // ------------------------------------------------------------- Write to Atlas: Shops
  Future<bool> upsertShop(MedicalShop s) async {
    try {
      await ApiService.instance.saveShop(s);
      final localDb = await AppDatabase.instance.db;
      await localDb.update(
        'medical_shops',
        {'sync_status': 'synced'},
        where: 'shop_name = ?',
        whereArgs: [s.name],
      );
      await SyncQueueManager.instance.remove(entityType: 'shop', entityId: s.name);
      debugPrint('[Atlas Sync] Shop confirmed saved to Atlas: ${s.name}');
      return true;
    } catch (e) {
      debugPrint('[Atlas Sync] Offline/Error saving shop, queuing locally: $e');
      await SyncQueueManager.instance.enqueue(
        entityType: 'shop',
        entityId: s.name,
        action: 'upsert',
        payload: s.toMap(),
      );
      return false;
    }
  }

  Future<void> deleteShop(String name) async {
    try {
      await ApiService.instance.deleteShopByName(name);
      await SyncQueueManager.instance.remove(entityType: 'shop', entityId: name);
      debugPrint('[Atlas Sync] Shop deleted from Atlas: $name');
    } catch (e) {
      debugPrint('[Atlas Sync] Offline/Error deleting shop, queuing locally: $e');
      await SyncQueueManager.instance.enqueue(
        entityType: 'shop',
        entityId: name,
        action: 'delete',
        payload: {'name': name},
      );
    }
  }

  // ------------------------------------------------------------- Write to Atlas: Collections
  Future<bool> upsertCollection(Collection c) async {
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
      final localDb = await AppDatabase.instance.db;
      await localDb.update(
        'collections',
        {'sync_status': 'synced'},
        where: 'receipt_number = ?',
        whereArgs: [c.receiptNumber],
      );
      await SyncQueueManager.instance.remove(entityType: 'collection', entityId: c.receiptNumber);
      debugPrint('[Atlas Sync] Collection confirmed saved to Atlas: ${c.receiptNumber}');
      return true;
    } catch (e) {
      debugPrint('[Atlas Sync] Offline/Error saving collection, queuing locally: $e');
      await SyncQueueManager.instance.enqueue(
        entityType: 'collection',
        entityId: c.receiptNumber,
        action: 'upsert',
        payload: c.toMap()..['shop_name'] = c.shopName,
      );
      return false;
    }
  }

  Future<void> deleteCollection(String receiptNumber) async {
    try {
      await ApiService.instance.deleteCollectionByReceipt(receiptNumber);
      await SyncQueueManager.instance.remove(entityType: 'collection', entityId: receiptNumber);
      debugPrint('[Atlas Sync] Collection deleted from Atlas: $receiptNumber');
    } catch (e) {
      debugPrint('[Atlas Sync] Offline/Error deleting collection, queuing locally: $e');
      await SyncQueueManager.instance.enqueue(
        entityType: 'collection',
        entityId: receiptNumber,
        action: 'delete',
        payload: {'receiptNumber': receiptNumber},
      );
    }
  }

  // ------------------------------------------------------------- Write to Atlas: Expenses
  Future<bool> upsertExpense(Expense e) async {
    try {
      await ApiService.instance.createOrUpdateExpense(
        displayId: e.displayId,
        date: e.date,
        category: e.category,
        description: e.description,
        amount: e.amount,
        notes: e.notes,
      );
      if (e.id != null) {
        final localDb = await AppDatabase.instance.db;
        await localDb.update(
          'expenses',
          {'sync_status': 'synced'},
          where: 'id = ?',
          whereArgs: [e.id],
        );
      }
      await SyncQueueManager.instance.remove(entityType: 'expense', entityId: e.displayId);
      debugPrint('[Atlas Sync] Expense confirmed saved to Atlas: ${e.displayId}');
      return true;
    } catch (err) {
      debugPrint('[Atlas Sync] Offline/Error saving expense, queuing locally: $err');
      await SyncQueueManager.instance.enqueue(
        entityType: 'expense',
        entityId: e.displayId,
        action: 'upsert',
        payload: e.toMap()..['display_id'] = e.displayId,
      );
      return false;
    }
  }

  Future<void> deleteExpense(String displayId) async {
    try {
      await ApiService.instance.deleteExpenseByDisplayId(displayId);
      await SyncQueueManager.instance.remove(entityType: 'expense', entityId: displayId);
      debugPrint('[Atlas Sync] Expense deleted from Atlas: $displayId');
    } catch (e) {
      debugPrint('[Atlas Sync] Offline/Error deleting expense, queuing locally: $e');
      await SyncQueueManager.instance.enqueue(
        entityType: 'expense',
        entityId: displayId,
        action: 'delete',
        payload: {'displayId': displayId},
      );
    }
  }

  // ------------------------------------------------------------- Write to Atlas: Categories
  Future<void> upsertCategory(String name) async {
    try {
      await ApiService.instance.addCategory(name);
      await SyncQueueManager.instance.remove(entityType: 'category', entityId: name);
    } catch (e) {
      await SyncQueueManager.instance.enqueue(
        entityType: 'category',
        entityId: name,
        action: 'upsert',
        payload: {'name': name},
      );
    }
  }

  Future<void> deleteCategory(String name) async {
    try {
      await ApiService.instance.deleteCategory(name);
      await SyncQueueManager.instance.remove(entityType: 'category', entityId: name);
    } catch (e) {
      await SyncQueueManager.instance.enqueue(
        entityType: 'category',
        entityId: name,
        action: 'delete',
        payload: {'name': name},
      );
    }
  }
}
