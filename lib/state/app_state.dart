import 'dart:async';
import 'package:flutter/widgets.dart';

import '../data/api_service.dart';
import '../data/mongo_database.dart';
import '../data/repository.dart';
import '../data/sync_queue.dart';

/// Session + a `revision` counter + automatic cloud sync state.
/// Runs continuous automatic background sync with MongoDB Atlas every 12s,
/// on app resume, and immediately on every data change.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final Repository repo = Repository.instance;

  String? admin;
  bool needsSetup = false;
  bool ready = false;
  int revision = 0;

  bool isSyncing = false;
  int pendingSyncCount = 0;
  bool isOnline = true;
  Timer? _autoCloudSyncTimer;

  int _fails = 0;
  DateTime? _firstFail;
  static const maxFails = 5;
  static const lockSeconds = 300;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    await ApiService.instance.init();
    needsSetup = !await repo.hasAdmin();
    ready = true;
    notifyListeners();

    // Start background queue manager (every 10s)
    SyncQueueManager.instance.startAutoSync(interval: const Duration(seconds: 10));
    await updatePendingCount();

    // Sync cloud data from MongoDB Atlas on startup
    await triggerSync(silent: true);

    // Start continuous automatic two-way background sync every 12 seconds
    _startContinuousSync();
  }

  void _startContinuousSync() {
    _autoCloudSyncTimer?.cancel();
    _autoCloudSyncTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      triggerSync(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Auto-sync immediately when phone unlocks or app returns to foreground
      triggerSync(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoCloudSyncTimer?.cancel();
    super.dispose();
  }

  Future<void> updatePendingCount() async {
    pendingSyncCount = await SyncQueueManager.instance.getPendingCount();
    notifyListeners();
  }

  Future<void> triggerSync({bool silent = false}) async {
    if (isSyncing) return;
    isSyncing = true;
    if (!silent) notifyListeners();

    try {
      isOnline = await ApiService.instance.checkHealth();
      await MongoDatabase.instance.syncAtlasToLocal();
      pendingSyncCount = await SyncQueueManager.instance.getPendingCount();
    } catch (_) {
      isOnline = false;
    } finally {
      isSyncing = false;
      revision++;
      notifyListeners();
    }
  }

  bool get locked {
    if (_firstFail == null) return false;
    if (DateTime.now().difference(_firstFail!).inSeconds > lockSeconds) {
      _fails = 0;
      _firstFail = null;
      return false;
    }
    return _fails >= maxFails;
  }

  /// Returns an error message, or null on success.
  Future<String?> login(String username, String password) async {
    if (locked) return 'Too many failed attempts. Please wait a few minutes and try again.';
    final user = await repo.login(username, password);
    if (user == null) {
      _firstFail ??= DateTime.now();
      _fails++;
      return 'Invalid username or password.';
    }
    _fails = 0;
    _firstFail = null;
    admin = user;
    notifyListeners();
    return null;
  }

  Future<void> createFirstAdmin(String username, String password) async {
    await repo.createAdmin(username, password);
    needsSetup = false;
    admin = username.trim();
    notifyListeners();
  }

  void logout() {
    admin = null;
    notifyListeners();
  }

  /// Call after any data change to immediately sync to cloud.
  void changed() {
    revision++;
    updatePendingCount();
    notifyListeners();
    // Auto-sync immediately in background whenever any change occurs
    triggerSync(silent: true);
  }
}
