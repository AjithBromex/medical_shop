import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_service.dart';
import '../data/mongo_database.dart';
import '../data/repository.dart';
import '../data/sync_queue.dart';

/// Session + a `revision` counter + automatic cloud sync state + theme preference.
/// Runs continuous automatic background sync with MongoDB Atlas every 12s,
/// on app resume, and immediately on every data change.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final Repository repo = Repository.instance;

  String? admin;
  bool needsSetup = false;
  bool ready = false;
  int revision = 0;

  ThemeMode themeMode = ThemeMode.light;
  bool get isDarkMode => themeMode == ThemeMode.dark;

  bool isSyncing = false;
  int pendingSyncCount = 0;
  bool isOnline = true;
  Timer? _autoCloudSyncTimer;

  int _fails = 0;
  DateTime? _firstFail;
  static const maxFails = 5;
  static const lockSeconds = 300;

  Future<void> loadInitialSettings() async {
    // Fast load persisted theme preference (<5ms)
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('theme_mode');
      if (savedTheme == 'dark') {
        themeMode = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        themeMode = ThemeMode.light;
      }
    } catch (_) {}
    ready = true;
  }

  void startBackgroundServices() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initBackgroundServices());
  }

  Future<void> _initBackgroundServices() async {
    try {
      await ApiService.instance.init();
      needsSetup = !await repo.hasAdmin();
      notifyListeners();

      // Start background queue manager (every 10s)
      SyncQueueManager.instance.startAutoSync(interval: const Duration(seconds: 10));
      await updatePendingCount();

      // Sync cloud data from MongoDB Atlas in background without blocking app startup
      await triggerSync(silent: true);

      // Start continuous automatic two-way background sync every 12 seconds
      _startContinuousSync();
    } catch (e) {
      debugPrint('[AppState] background sync error: $e');
    }
  }

  Future<void> init() async {
    await loadInitialSettings();
    startBackgroundServices();
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

  void toggleTheme() async {
    themeMode = isDarkMode ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', isDarkMode ? 'dark' : 'light');
    } catch (_) {}
  }

  void setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('theme_mode', mode == ThemeMode.dark ? 'dark' : 'light');
    } catch (_) {}
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
