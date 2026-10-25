import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/auth_service.dart';
import '../data/database.dart';
import '../data/drive_sync_service.dart';
import '../data/repository.dart';
import '../data/sync_queue.dart';

/// Session + Google Account state + automatic Drive sync state + theme preference.
/// Syncs data privately to each user's Google Drive appDataFolder.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  final Repository repo = Repository.instance;

  AuthUser? currentUser;
  bool get isSignedIn => currentUser != null;
  String? get admin => currentUser?.displayName ?? currentUser?.email;

  bool ready = false;
  int revision = 0;

  ThemeMode themeMode = ThemeMode.light;
  bool get isDarkMode => themeMode == ThemeMode.dark;

  bool isSyncing = false;
  int pendingSyncCount = 0;
  bool isOnline = true;
  String? syncErrorMessage;
  DateTime? lastSyncTime;

  Future<void> loadInitialSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('theme_mode');
      if (savedTheme == 'dark') {
        themeMode = ThemeMode.dark;
      } else if (savedTheme == 'light') {
        themeMode = ThemeMode.light;
      }

      final lastMs = prefs.getInt('last_drive_sync_time');
      if (lastMs != null) {
        lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastMs);
      }

      currentUser = await AuthService.instance.init();
      if (currentUser != null) {
        await AppDatabase.instance.switchAccount(currentUser!.id);
      } else {
        await AppDatabase.instance.switchAccount('default');
      }
    } catch (_) {}
    ready = true;
    notifyListeners();
  }

  void startBackgroundServices() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initBackgroundServices());
  }

  Future<void> _initBackgroundServices() async {
    try {
      if (!ready) {
        await loadInitialSettings();
      }

      // Connect DriveSyncService lifecycle callbacks to AppState for real-time UI updates
      DriveSyncService.instance.onSyncStarted = () {
        if (!isSyncing) {
          isSyncing = true;
          notifyListeners();
        }
      };
      DriveSyncService.instance.onSyncCompleted = () async {
        isSyncing = false;
        pendingSyncCount = await SyncQueueManager.instance.getPendingCount();
        lastSyncTime = DateTime.now();
        isOnline = true;
        syncErrorMessage = null;
        revision++;
        notifyListeners();
      };

      // Start background sync services
      SyncQueueManager.instance.startAutoSync(interval: const Duration(seconds: 15));
      DriveSyncService.instance.startPeriodicSync(interval: const Duration(seconds: 60));
      await updatePendingCount();

      if (isSignedIn) {
        await triggerSync(silent: true);
      }
    } catch (e) {
      debugPrint('[AppState] Init error: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && isSignedIn) {
      triggerSync(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    DriveSyncService.instance.onSyncStarted = null;
    DriveSyncService.instance.onSyncCompleted = null;
    DriveSyncService.instance.stopPeriodicSync();
    SyncQueueManager.instance.stopAutoSync();
    super.dispose();
  }

  Future<void> updatePendingCount() async {
    pendingSyncCount = await SyncQueueManager.instance.getPendingCount();
    notifyListeners();
  }

  Future<void> triggerSync({bool silent = false}) async {
    if (isSyncing) return;
    isSyncing = true;
    syncErrorMessage = null;
    notifyListeners();

    try {
      final success = await DriveSyncService.instance.triggerSync(silent: silent);
      isOnline = success;
      if (success) {
        lastSyncTime = DateTime.now();
        syncErrorMessage = null;
      }
    } on DriveSyncException catch (e) {
      syncErrorMessage = e.message;
      if (e.isAuthError) {
        isOnline = false;
      }
    } catch (e) {
      isOnline = false;
      syncErrorMessage = 'Sync failed. Will retry automatically.';
    } finally {
      isSyncing = false;
      pendingSyncCount = await SyncQueueManager.instance.getPendingCount();
      revision++;
      notifyListeners();
    }
  }

  Future<bool> signIn({String? desktopClientId, String? desktopClientSecret}) async {
    try {
      final user = await AuthService.instance.signIn(
        desktopClientId: desktopClientId,
        desktopClientSecret: desktopClientSecret,
      );
      if (user != null) {
        currentUser = user;
        await AppDatabase.instance.switchAccount(user.id);
        revision++;
        await updatePendingCount();
        notifyListeners();
        await triggerSync(silent: false);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[AppState] signIn error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await AuthService.instance.signOut();
    currentUser = null;
    await AppDatabase.instance.switchAccount('default');
    revision++;
    await updatePendingCount();
    notifyListeners();
  }

  Future<void> switchAccount({String? desktopClientId, String? desktopClientSecret}) async {
    try {
      final user = await AuthService.instance.switchAccount(
        desktopClientId: desktopClientId,
        desktopClientSecret: desktopClientSecret,
      );
      if (user != null) {
        currentUser = user;
        await AppDatabase.instance.switchAccount(user.id);
        revision++;
        await updatePendingCount();
        notifyListeners();
        await triggerSync(silent: false);
      }
    } catch (e) {
      debugPrint('[AppState] switchAccount error: $e');
      rethrow;
    }
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

  /// Call after any data change to immediately queue and trigger sync to Google Drive.
  void changed() {
    revision++;
    updatePendingCount();
    notifyListeners();
    DriveSyncService.instance.scheduleDebouncedSync(delay: const Duration(milliseconds: 100));
  }
}
