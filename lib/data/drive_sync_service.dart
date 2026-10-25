import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'database.dart';

class DriveSyncException implements Exception {
  final String message;
  final bool isAuthError;
  final bool isQuotaError;
  final bool isNetworkError;

  DriveSyncException(
    this.message, {
    this.isAuthError = false,
    this.isQuotaError = false,
    this.isNetworkError = false,
  });

  @override
  String toString() => message;
}

/// Google Drive appDataFolder synchronization service.
/// Uses Drive v3 API to store and merge application snapshots
/// directly inside each user's private Google Drive application folder.
class DriveSyncService {
  static final DriveSyncService instance = DriveSyncService._();
  DriveSyncService._();

  static const String snapshotFileName = 'medical_shop_data.json';

  Timer? _periodicTimer;
  Timer? _debounceTimer;
  bool _isSyncing = false;

  /// Callbacks invoked when sync starts and finishes, allowing UI/AppState to react in real time.
  VoidCallback? onSyncStarted;
  VoidCallback? onSyncCompleted;

  bool get isSyncing => _isSyncing;

  /// Starts the periodic background sync (every 60 seconds).
  void startPeriodicSync({Duration interval = const Duration(seconds: 60)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) {
      triggerSync(silent: true);
    });
  }

  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Debounced sync triggered after a local save/edit/delete (fast 200ms debounce instead of 2s).
  void scheduleDebouncedSync({Duration delay = const Duration(milliseconds: 200)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      triggerSync(silent: true);
    });
  }

  /// Triggers full two-way synchronization between local SQLite and Google Drive appDataFolder.
  Future<bool> triggerSync({bool silent = false}) async {
    if (_isSyncing) return false;
    _isSyncing = true;
    onSyncStarted?.call();

    try {
      final client = await AuthService.instance.getAuthenticatedClient();
      if (client == null) {
        debugPrint('[DriveSync] No authenticated Google client. Working offline.');
        return false;
      }

      final driveApi = drive.DriveApi(client);

      // 1. Find or create snapshot file in appDataFolder
      final fileId = await _findOrCreateSnapshotFile(driveApi);
      if (fileId == null) {
        debugPrint('[DriveSync] Could not locate or create snapshot file.');
        return false;
      }

      // 2. Download remote snapshot
      final remoteSnapshot = await _downloadSnapshot(driveApi, fileId);

      // 3. Perform two-way merge ("latest updated_at wins")
      final mergedSnapshot = await _mergeLocalWithRemote(remoteSnapshot);

      // 4. Upload merged snapshot back to Drive appDataFolder
      await _uploadSnapshot(driveApi, fileId, mergedSnapshot);

      // 5. Drain local sync_queue on confirmed Drive persistence
      final d = await AppDatabase.instance.db;
      await d.delete('sync_queue');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_drive_sync_time', DateTime.now().toUtc().millisecondsSinceEpoch);

      debugPrint('[DriveSync] Synchronization completed successfully with Google Drive appDataFolder.');
      return true;
    } on SocketException catch (e) {
      debugPrint('[DriveSync] Network offline: $e');
      return false;
    } on drive.DetailedApiRequestError catch (e) {
      debugPrint('[DriveSync] Drive API error: ${e.status} ${e.message}');
      if (e.status == 401) {
        throw DriveSyncException('Google Drive authentication expired. Please sign in again.', isAuthError: true);
      } else if (e.status == 403 && (e.message?.contains('quota') ?? false)) {
        throw DriveSyncException('Google Drive storage quota full.', isQuotaError: true);
      }
      return false;
    } catch (e) {
      debugPrint('[DriveSync] Sync exception: $e');
      return false;
    } finally {
      _isSyncing = false;
      onSyncCompleted?.call();
    }
  }

  /// Locates the snapshot file in appDataFolder, or creates it if not found.
  Future<String?> _findOrCreateSnapshotFile(drive.DriveApi driveApi) async {
    try {
      final list = await driveApi.files.list(
        spaces: 'appDataFolder',
        q: "name = '$snapshotFileName' and trashed = false",
        $fields: 'files(id, name, modifiedTime)',
      );

      final files = list.files;
      if (files != null && files.isNotEmpty) {
        return files.first.id;
      }

      // Create new file in appDataFolder
      final newFile = drive.File()
        ..name = snapshotFileName
        ..parents = ['appDataFolder']
        ..description = 'Oscar Pharma Medical Shop Manager Backup Data';

      final emptyContent = jsonEncode({
        'version': 1,
        'last_synced_at': DateTime.now().toUtc().millisecondsSinceEpoch,
        'shops': [],
        'collections': [],
        'expenses': [],
        'categories': [],
      });

      final media = drive.Media(
        Stream.value(utf8.encode(emptyContent)),
        utf8.encode(emptyContent).length,
      );

      final created = await driveApi.files.create(
        newFile,
        uploadMedia: media,
      );

      return created.id;
    } catch (e) {
      debugPrint('[DriveSync] _findOrCreateSnapshotFile error: $e');
      rethrow;
    }
  }

  /// Downloads the content of snapshot file from Google Drive.
  Future<Map<String, dynamic>?> _downloadSnapshot(drive.DriveApi driveApi, String fileId) async {
    try {
      final media = await driveApi.files.get(
        fileId,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }

      if (bytes.isEmpty) return null;
      final text = utf8.decode(bytes);
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[DriveSync] _downloadSnapshot error: $e');
      return null;
    }
  }

  /// Uploads updated snapshot content to Drive.
  Future<void> _uploadSnapshot(drive.DriveApi driveApi, String fileId, Map<String, dynamic> data) async {
    final encoded = utf8.encode(jsonEncode(data));
    final media = drive.Media(Stream.value(encoded), encoded.length);

    await driveApi.files.update(
      drive.File(),
      fileId,
      uploadMedia: media,
    );
  }

  /// Two-way merge: compares local SQLite records and remote snapshot records.
  /// "Latest updated_at_ms wins". Deletions (deleted == 1) propagate as tombstones.
  Future<Map<String, dynamic>> _mergeLocalWithRemote(Map<String, dynamic>? remote) async {
    final d = await AppDatabase.instance.db;

    // Load all local records (including soft-deleted ones)
    final localShops = await d.query('medical_shops');
    final localCollections = await d.query('collections');
    final localExpenses = await d.query('expenses');
    final localCategories = await d.query('expense_categories');

    final remoteShopsList = (remote?['shops'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final remoteCollectionsList = (remote?['collections'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final remoteExpensesList = (remote?['expenses'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final remoteCategoriesList = (remote?['categories'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    // Maps keyed by unique business identifier
    final mergedShops = <String, Map<String, dynamic>>{};
    final mergedCollections = <String, Map<String, dynamic>>{};
    final mergedExpenses = <String, Map<String, dynamic>>{};
    final mergedCategories = <String, Map<String, dynamic>>{};

    // --- 1. MERGE MEDICAL SHOPS (Key: shop_name)
    final localShopsByName = <String, Map<String, dynamic>>{};
    for (final row in localShops) {
      final name = (row['shop_name'] as String).trim();
      localShopsByName[name.toLowerCase()] = Map<String, dynamic>.from(row);
    }

    for (final r in remoteShopsList) {
      final name = (r['shop_name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final key = name.toLowerCase();
      final local = localShopsByName[key];

      final remoteUpdatedAt = (r['updated_at_ms'] as int?) ?? 0;
      final localUpdatedAt = (local?['updated_at_ms'] as int?) ?? 0;

      if (local == null) {
        // Insert remote into local
        final newId = await d.insert('medical_shops', {
          'shop_name': name,
          'address': r['address'] ?? '',
          'phone': r['phone'] ?? '',
          'notes': r['notes'] ?? '',
          'is_active': (r['is_active'] as int?) ?? 1,
          'sync_status': 'synced',
          'deleted': (r['deleted'] as int?) ?? 0,
          'updated_at_ms': remoteUpdatedAt,
        });
        mergedShops[key] = {
          ...r,
          'id': newId,
          'shop_name': name,
          'sync_status': 'synced',
        };
      } else {
        if (remoteUpdatedAt > localUpdatedAt) {
          // Remote wins!
          await d.update(
            'medical_shops',
            {
              'address': r['address'] ?? '',
              'phone': r['phone'] ?? '',
              'notes': r['notes'] ?? '',
              'is_active': (r['is_active'] as int?) ?? 1,
              'sync_status': 'synced',
              'deleted': (r['deleted'] as int?) ?? 0,
              'updated_at_ms': remoteUpdatedAt,
            },
            where: 'id = ?',
            whereArgs: [local['id']],
          );
          mergedShops[key] = {
            ...r,
            'id': local['id'],
            'shop_name': name,
            'sync_status': 'synced',
          };
        } else {
          // Local wins! Keep local, mark synced
          await d.update(
            'medical_shops',
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [local['id']],
          );
          mergedShops[key] = {
            ...local,
            'sync_status': 'synced',
          };
        }
      }
    }

    // Include local shops that were never in remote
    for (final entry in localShopsByName.entries) {
      if (!mergedShops.containsKey(entry.key)) {
        await d.update(
          'medical_shops',
          {'sync_status': 'synced'},
          where: 'id = ?',
          whereArgs: [entry.value['id']],
        );
        mergedShops[entry.key] = {
          ...entry.value,
          'sync_status': 'synced',
        };
      }
    }

    // Refresh shops map to resolve shopId foreign keys
    final allShopsRows = await d.query('medical_shops');
    final shopIdByName = <String, int>{};
    for (final s in allShopsRows) {
      shopIdByName[(s['shop_name'] as String).toLowerCase()] = s['id'] as int;
    }

    // --- 2. MERGE CATEGORIES (Key: name)
    final localCatsByName = <String, Map<String, dynamic>>{};
    for (final row in localCategories) {
      final name = (row['name'] as String).trim();
      localCatsByName[name.toLowerCase()] = Map<String, dynamic>.from(row);
    }

    for (final r in remoteCategoriesList) {
      final name = (r['name'] as String?)?.trim();
      if (name == null || name.isEmpty) continue;
      final key = name.toLowerCase();
      final local = localCatsByName[key];

      final remoteUpdatedAt = (r['updated_at_ms'] as int?) ?? 0;
      final localUpdatedAt = (local?['updated_at_ms'] as int?) ?? 0;

      if (local == null) {
        await d.insert('expense_categories', {
          'name': name,
          'deleted': (r['deleted'] as int?) ?? 0,
          'updated_at_ms': remoteUpdatedAt,
        });
        mergedCategories[key] = {...r, 'name': name};
      } else {
        if (remoteUpdatedAt > localUpdatedAt) {
          await d.update(
            'expense_categories',
            {
              'deleted': (r['deleted'] as int?) ?? 0,
              'updated_at_ms': remoteUpdatedAt,
            },
            where: 'id = ?',
            whereArgs: [local['id']],
          );
          mergedCategories[key] = {...r, 'name': name};
        } else {
          mergedCategories[key] = local;
        }
      }
    }

    for (final entry in localCatsByName.entries) {
      if (!mergedCategories.containsKey(entry.key)) {
        mergedCategories[entry.key] = entry.value;
      }
    }

    // --- 3. MERGE COLLECTIONS (Key: receipt_number)
    final localCollectionsByReceipt = <String, Map<String, dynamic>>{};
    for (final row in localCollections) {
      final rNo = (row['receipt_number'] as String).trim();
      localCollectionsByReceipt[rNo.toLowerCase()] = Map<String, dynamic>.from(row);
    }

    for (final r in remoteCollectionsList) {
      final rNo = (r['receipt_number'] as String?)?.trim();
      if (rNo == null || rNo.isEmpty) continue;
      final key = rNo.toLowerCase();
      final local = localCollectionsByReceipt[key];

      final remoteUpdatedAt = (r['updated_at_ms'] as int?) ?? 0;
      final localUpdatedAt = (local?['updated_at_ms'] as int?) ?? 0;

      final sName = (r['shop_name'] as String?)?.trim() ?? '';
      int sId = shopIdByName[sName.toLowerCase()] ?? ((r['medical_shop_id'] as int?) ?? 1);
      if (shopIdByName[sName.toLowerCase()] == null && sName.isNotEmpty) {
        sId = await d.insert('medical_shops', {
          'shop_name': sName,
          'is_active': 1,
          'sync_status': 'synced',
          'deleted': 0,
          'updated_at_ms': remoteUpdatedAt,
        });
        shopIdByName[sName.toLowerCase()] = sId;
      }

      if (local == null) {
        final newId = await d.insert('collections', {
          'receipt_number': rNo,
          'medical_shop_id': sId,
          'collection_date': r['collection_date'],
          'cash_amount': r['cash_amount'] ?? 0,
          'gpay_amount': r['gpay_amount'] ?? 0,
          'cheque_amount': r['cheque_amount'] ?? 0,
          'total_amount': r['total_amount'] ?? ((r['cash_amount'] ?? 0) + (r['gpay_amount'] ?? 0) + (r['cheque_amount'] ?? 0)),
          'notes': r['notes'] ?? '',
          'sync_status': 'synced',
          'deleted': (r['deleted'] as int?) ?? 0,
          'updated_at_ms': remoteUpdatedAt,
        });
        mergedCollections[key] = {
          ...r,
          'id': newId,
          'receipt_number': rNo,
          'medical_shop_id': sId,
          'shop_name': sName,
          'sync_status': 'synced',
        };
      } else {
        if (remoteUpdatedAt > localUpdatedAt) {
          // Remote wins!
          await d.update(
            'collections',
            {
              'medical_shop_id': sId,
              'collection_date': r['collection_date'],
              'cash_amount': r['cash_amount'] ?? 0,
              'gpay_amount': r['gpay_amount'] ?? 0,
              'cheque_amount': r['cheque_amount'] ?? 0,
              'total_amount': r['total_amount'] ?? ((r['cash_amount'] ?? 0) + (r['gpay_amount'] ?? 0) + (r['cheque_amount'] ?? 0)),
              'notes': r['notes'] ?? '',
              'sync_status': 'synced',
              'deleted': (r['deleted'] as int?) ?? 0,
              'updated_at_ms': remoteUpdatedAt,
            },
            where: 'id = ?',
            whereArgs: [local['id']],
          );
          mergedCollections[key] = {
            ...r,
            'id': local['id'],
            'receipt_number': rNo,
            'medical_shop_id': sId,
            'shop_name': sName,
            'sync_status': 'synced',
          };
        } else {
          // Local wins! Mark synced
          await d.update(
            'collections',
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [local['id']],
          );
          mergedCollections[key] = {
            ...local,
            'shop_name': sName,
            'sync_status': 'synced',
          };
        }
      }
    }

    for (final entry in localCollectionsByReceipt.entries) {
      if (!mergedCollections.containsKey(entry.key)) {
        await d.update(
          'collections',
          {'sync_status': 'synced'},
          where: 'id = ?',
          whereArgs: [entry.value['id']],
        );
        // Find shop name
        final shopRow = allShopsRows.firstWhere(
          (s) => s['id'] == entry.value['medical_shop_id'],
          orElse: () => {'shop_name': ''},
        );
        mergedCollections[entry.key] = {
          ...entry.value,
          'shop_name': shopRow['shop_name'],
          'sync_status': 'synced',
        };
      }
    }

    // --- 4. MERGE EXPENSES (Key: display_id or ID)
    final localExpensesById = <String, Map<String, dynamic>>{};
    for (final row in localExpenses) {
      final id = row['id'] as int;
      final dId = 'EXP-${id.toString().padLeft(5, '0')}';
      localExpensesById[dId] = Map<String, dynamic>.from(row);
    }

    for (final r in remoteExpensesList) {
      final dId = (r['display_id'] as String?) ?? 'EXP-${(r['id'] ?? 0).toString().padLeft(5, '0')}';
      final local = localExpensesById[dId];

      final remoteUpdatedAt = (r['updated_at_ms'] as int?) ?? 0;
      final localUpdatedAt = (local?['updated_at_ms'] as int?) ?? 0;

      if (local == null) {
        final newId = await d.insert('expenses', {
          'expense_date': r['expense_date'],
          'category': r['category'] ?? 'Other',
          'description': r['description'] ?? '',
          'amount': r['amount'] ?? 0,
          'notes': r['notes'] ?? '',
          'sync_status': 'synced',
          'deleted': (r['deleted'] as int?) ?? 0,
          'updated_at_ms': remoteUpdatedAt,
        });
        mergedExpenses[dId] = {
          ...r,
          'id': newId,
          'display_id': dId,
          'sync_status': 'synced',
        };
      } else {
        if (remoteUpdatedAt > localUpdatedAt) {
          // Remote wins!
          await d.update(
            'expenses',
            {
              'expense_date': r['expense_date'],
              'category': r['category'] ?? 'Other',
              'description': r['description'] ?? '',
              'amount': r['amount'] ?? 0,
              'notes': r['notes'] ?? '',
              'sync_status': 'synced',
              'deleted': (r['deleted'] as int?) ?? 0,
              'updated_at_ms': remoteUpdatedAt,
            },
            where: 'id = ?',
            whereArgs: [local['id']],
          );
          mergedExpenses[dId] = {
            ...r,
            'id': local['id'],
            'display_id': dId,
            'sync_status': 'synced',
          };
        } else {
          // Local wins!
          await d.update(
            'expenses',
            {'sync_status': 'synced'},
            where: 'id = ?',
            whereArgs: [local['id']],
          );
          mergedExpenses[dId] = {
            ...local,
            'display_id': dId,
            'sync_status': 'synced',
          };
        }
      }
    }

    for (final entry in localExpensesById.entries) {
      if (!mergedExpenses.containsKey(entry.key)) {
        await d.update(
          'expenses',
          {'sync_status': 'synced'},
          where: 'id = ?',
          whereArgs: [entry.value['id']],
        );
        mergedExpenses[entry.key] = {
          ...entry.value,
          'display_id': entry.key,
          'sync_status': 'synced',
        };
      }
    }

    return {
      'version': 1,
      'last_synced_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      'shops': mergedShops.values.toList(),
      'collections': mergedCollections.values.toList(),
      'expenses': mergedExpenses.values.toList(),
      'categories': mergedCategories.values.toList(),
    };
  }
}
