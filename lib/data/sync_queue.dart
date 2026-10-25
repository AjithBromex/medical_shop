import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'database.dart';
import 'drive_sync_service.dart';

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

/// Durable local queue stored in SQLite. Tracks pending mutations
/// that need to be synced to Google Drive appDataFolder.
class SyncQueueManager {
  static final SyncQueueManager instance = SyncQueueManager._();
  SyncQueueManager._();

  Timer? _autoSyncTimer;
  bool _isProcessing = false;

  void startAutoSync({Duration interval = const Duration(seconds: 15)}) {
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

    // Remove any existing pending action for the exact same entity to avoid redundant records
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

  /// Removes an entity from the queue once confirmed saved to Drive.
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

  /// Drains the queue by syncing pending changes with Google Drive appDataFolder.
  Future<bool> processQueue() async {
    if (_isProcessing) return false;
    _isProcessing = true;

    try {
      final count = await getPendingCount();
      if (count == 0) return true;

      debugPrint('[SyncQueue] Triggering Drive sync for $count pending local mutations...');
      final success = await DriveSyncService.instance.triggerSync(silent: true);
      return success;
    } catch (e) {
      debugPrint('[SyncQueue] processQueue error: $e');
      return false;
    } finally {
      _isProcessing = false;
    }
  }
}
