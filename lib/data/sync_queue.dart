import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'database.dart';
import 'models.dart';

class SyncQueueItem {
  final int id;
  final String entityType;
  final String entityId;
  final String action; // 'upsert', 'delete'
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.action,
    required this.payload,
    required this.createdAt,
    required this.attempts,
    this.lastError,
  });

  factory SyncQueueItem.fromMap(Map<String, dynamic> m) => SyncQueueItem(
        id: m['id'] as int,
        entityType: m['entity_type'] as String,
        entityId: m['entity_id'] as String,
        action: m['action'] as String,
        payload: (jsonDecode(m['payload'] as String) as Map).cast<String, dynamic>(),
        createdAt: DateTime.parse(m['created_at'] as String),
        attempts: (m['attempts'] as int?) ?? 0,
        lastError: m['last_error'] as String?,
      );
}

/// Durable local queue stored in SQLite. Retries failed requests,
/// manages offline persistence, and confirms Atlas persistence.
class SyncQueueManager {
  static final SyncQueueManager instance = SyncQueueManager._();
  SyncQueueManager._();

  Timer? _autoSyncTimer;
  bool _isProcessing = false;

  void startAutoSync({Duration interval = const Duration(seconds: 25)}) {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(interval, (_) => processQueue());
  }

  void stopAutoSync() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = null;
  }

  /// Adds a change to the durable SQLite queue.
  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final d = await AppDatabase.instance.db;

    // Remove any existing pending action for the exact same entity to avoid redundant traffic
    await d.delete(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
    );

    await d.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'action': action,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().toIso8601String(),
      'attempts': 0,
      'last_error': null,
    });

    debugPrint('[SyncQueue] Enqueued $action for $entityType ($entityId)');
  }

  /// Removes an entity from the queue once confirmed saved to Atlas.
  Future<void> remove({required String entityType, required String entityId}) async {
    final d = await AppDatabase.instance.db;
    await d.delete(
      'sync_queue',
      where: 'entity_type = ? AND entity_id = ?',
      whereArgs: [entityType, entityId],
    );
  }

  /// Returns total items currently waiting in the offline queue.
  Future<int> getPendingCount() async {
    try {
      final d = await AppDatabase.instance.db;
      final res = await d.rawQuery('SELECT COUNT(*) as cnt FROM sync_queue');
      return (res.first['cnt'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Returns all currently pending items.
  Future<List<SyncQueueItem>> getPendingItems() async {
    try {
      final d = await AppDatabase.instance.db;
      final rows = await d.query('sync_queue', orderBy: 'id ASC');
      return rows.map((r) => SyncQueueItem.fromMap(r)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Drains the queue by sending pending changes to the online API in FIFO order.
  Future<bool> processQueue() async {
    if (_isProcessing) return false;
    _isProcessing = true;

    try {
      final isOnline = await ApiService.instance.checkHealth();
      if (!isOnline) {
        return false;
      }

      final items = await getPendingItems();
      if (items.isEmpty) return true;

      debugPrint('[SyncQueue] Processing ${items.length} queued offline changes...');
      final d = await AppDatabase.instance.db;

      for (final item in items) {
        bool success = false;
        String? errMessage;

        try {
          switch (item.entityType) {
            case 'shop':
              if (item.action == 'delete') {
                await ApiService.instance.deleteShopByName(item.entityId);
                success = true;
              } else {
                final s = MedicalShop(
                  name: item.payload['shop_name'] as String,
                  address: item.payload['address'] as String?,
                  phone: item.payload['phone'] as String?,
                  notes: item.payload['notes'] as String?,
                  isActive: (item.payload['is_active'] as int?) == 1,
                );
                await ApiService.instance.saveShop(s);
                await d.update(
                  'medical_shops',
                  {'sync_status': 'synced'},
                  where: 'shop_name = ?',
                  whereArgs: [s.name],
                );
                success = true;
              }
              break;

            case 'collection':
              if (item.action == 'delete') {
                await ApiService.instance.deleteCollectionByReceipt(item.entityId);
                success = true;
              } else {
                await ApiService.instance.createOrUpdateCollection(
                  receiptNumber: item.payload['receipt_number'] as String,
                  shopName: (item.payload['shop_name'] as String?) ?? '',
                  shopId: item.payload['medical_shop_id'],
                  date: DateTime.parse(item.payload['collection_date'] as String),
                  cash: item.payload['cash_amount'] as int,
                  gpay: item.payload['gpay_amount'] as int,
                  cheque: item.payload['cheque_amount'] as int,
                  notes: item.payload['notes'] as String?,
                );
                await d.update(
                  'collections',
                  {'sync_status': 'synced'},
                  where: 'receipt_number = ?',
                  whereArgs: [item.payload['receipt_number']],
                );
                success = true;
              }
              break;

            case 'expense':
              if (item.action == 'delete') {
                await ApiService.instance.deleteExpenseByDisplayId(item.entityId);
                success = true;
              } else {
                await ApiService.instance.createOrUpdateExpense(
                  displayId: item.payload['display_id'] as String,
                  date: DateTime.parse(item.payload['expense_date'] as String),
                  category: item.payload['category'] as String,
                  description: item.payload['description'] as String,
                  amount: item.payload['amount'] as int,
                  notes: item.payload['notes'] as String?,
                );
                if (item.payload['id'] != null) {
                  await d.update(
                    'expenses',
                    {'sync_status': 'synced'},
                    where: 'id = ?',
                    whereArgs: [item.payload['id']],
                  );
                }
                success = true;
              }
              break;

            case 'category':
              if (item.action == 'delete') {
                await ApiService.instance.deleteCategory(item.entityId);
                success = true;
              } else {
                await ApiService.instance.addCategory(item.entityId);
                success = true;
              }
              break;
          }
        } catch (e) {
          errMessage = e.toString();
          success = false;
        }

        if (success) {
          await d.delete('sync_queue', where: 'id = ?', whereArgs: [item.id]);
          debugPrint('[SyncQueue] Successfully synced ${item.entityType} (${item.entityId}) to Atlas');
        } else {
          debugPrint('[SyncQueue] Failed to sync ${item.entityType} (${item.entityId}): $errMessage');
          await d.update(
            'sync_queue',
            {
              'attempts': item.attempts + 1,
              'last_error': errMessage,
            },
            where: 'id = ?',
            whereArgs: [item.id],
          );
          // Stop this cycle on network or server error to preserve FIFO order and avoid spamming
          break;
        }
      }

      return true;
    } finally {
      _isProcessing = false;
    }
  }
}
