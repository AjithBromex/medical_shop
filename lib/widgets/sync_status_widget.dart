import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../screens/login_screen.dart';
import '../state/app_state.dart';
import 'common.dart';

class SyncStatusHeaderButton extends StatelessWidget {
  final bool compact;
  const SyncStatusHeaderButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    Widget icon;
    String label;
    Color color;

    if (!state.isSignedIn) {
      icon = const Icon(Icons.account_circle_outlined, size: 19, color: AppColors.textSecondary);
      label = 'Sign In';
      color = AppColors.textSecondary;
    } else if (state.isSyncing) {
      icon = const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.total),
      );
      label = 'Syncing...';
      color = AppColors.total;
    } else if (state.pendingSyncCount > 0) {
      icon = Badge(
        label: Text('${state.pendingSyncCount}'),
        backgroundColor: Colors.amber.shade800,
        child: const Icon(Icons.cloud_upload_outlined, size: 19, color: Colors.amber),
      );
      label = '${state.pendingSyncCount} waiting to sync';
      color = Colors.amber.shade800;
    } else if (!state.isOnline) {
      icon = const Icon(Icons.cloud_off_outlined, size: 19, color: AppColors.textSecondary);
      label = 'Offline';
      color = AppColors.textSecondary;
    } else {
      icon = const Icon(Icons.cloud_done_rounded, size: 19, color: AppColors.gpay);
      label = 'Drive Backed Up';
      color = AppColors.gpay;
    }

    if (compact) {
      return IconButton(
        icon: icon,
        tooltip: label,
        onPressed: () => showCloudSyncSheet(context),
      );
    }

    return InkWell(
      onTap: () => showCloudSyncSheet(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SyncItemBadge extends StatelessWidget {
  final bool isPending;
  const SyncItemBadge({super.key, required this.isPending});

  @override
  Widget build(BuildContext context) {
    if (isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.amber.shade400),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_upload_outlined, size: 12, color: Colors.amber.shade900),
            const SizedBox(width: 3),
            Text(
              'Waiting to sync',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

void showCloudSyncSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final state = ctx.watch<AppState>();
      final isUpToDate = state.isSignedIn && state.isOnline && state.pendingSyncCount == 0;
      final user = state.currentUser;

      return Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: isDark ? const Color(0x33000000) : const Color(0x1F0F172A),
              blurRadius: 24,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.cloud_sync_rounded, color: AppColors.total, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Google Drive Sync',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Google Account Status
            if (user != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.total.withValues(alpha: 0.15),
                      child: Text(
                        (user.displayName.isNotEmpty ? user.displayName[0] : 'U').toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.total),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: isDark ? Colors.white : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (val) async {
                        if (val == 'switch') {
                          await _showSignInOrSwitchDialog(ctx, isSwitch: true);
                        } else if (val == 'signout') {
                          await state.signOut();
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            toast(ctx, 'Signed out of Google Drive.');
                            Navigator.of(ctx, rootNavigator: true).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          }
                        }
                      },
                      itemBuilder: (c) => [
                        const PopupMenuItem(
                          value: 'switch',
                          child: Row(
                            children: [
                              Icon(Icons.switch_account_outlined, size: 18),
                              SizedBox(width: 8),
                              Text('Switch Account'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'signout',
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Sign Out', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lock_outline, color: AppColors.total, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Personal Cloud Backup',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Sign in with your Google account. Your records will be stored in your private Google Drive appDataFolder, accessible only by you.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: const Icon(Icons.login_rounded, size: 18),
                        label: const Text('Sign In with Google'),
                        onPressed: () => _showSignInOrSwitchDialog(ctx, isSwitch: false),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Sync Status Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: !state.isSignedIn
                              ? const Color(0xFF94A3B8)
                              : (isUpToDate
                                  ? AppColors.gpay
                                  : (state.isOnline ? Colors.amber.shade700 : const Color(0xFF94A3B8))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        !state.isSignedIn
                            ? 'Local Mode Only'
                            : (isUpToDate
                                ? 'All Records Synced to Drive'
                                : (state.isOnline
                                    ? '${state.pendingSyncCount} changes uploading...'
                                    : 'Working Offline')),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    !state.isSignedIn
                        ? 'Records are saved locally on this device. Sign in with Google to enable automatic cloud backup.'
                        : (isUpToDate
                            ? 'Your collections, expenses, and customer records are safely synced with your Google Drive appDataFolder.'
                            : (state.isOnline
                                ? 'Backing up latest records to your Google Drive.'
                                : 'Records are saved safely on this device and will sync automatically once an internet connection is available.')),
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      height: 1.35,
                    ),
                  ),
                  if (state.lastSyncTime != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last synced: ${DateFormat('dd MMM yyyy, hh:mm a').format(state.lastSyncTime!)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                  if (state.syncErrorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.syncErrorMessage!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 18),

            if (state.isSignedIn)
              SizedBox(
                width: double.infinity,
                child: GlassButton(
                  onPressed: state.isSyncing
                      ? null
                      : () async {
                          await state.triggerSync();
                          if (ctx.mounted) {
                            toast(
                              ctx,
                              state.isOnline
                                  ? 'Google Drive backup updated successfully.'
                                  : (state.syncErrorMessage ?? 'Working offline. Saved locally.'),
                            );
                          }
                        },
                  icon: Icons.refresh_rounded,
                  accentColor: AppColors.total,
                  isPrimary: true,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    state.isSyncing ? 'Syncing to Drive...' : 'Sync Now',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
}

Future<void> _showSignInOrSwitchDialog(BuildContext context, {required bool isSwitch}) async {
  final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  if (!isDesktop) {
    // Mobile & Web can sign in directly
    final state = context.read<AppState>();
    try {
      if (isSwitch) {
        await state.switchAccount();
      } else {
        await state.signIn();
      }
      if (context.mounted) {
        toast(context, 'Signed in with Google successfully.');
      }
    } catch (e) {
      if (context.mounted) {
        toast(context, 'Sign in failed: $e', error: true);
      }
    }
    return;
  }

  // Desktop OAuth dialog (asking for Google Cloud Web/Desktop Client ID if not configured)
  final clientIdCtrl = TextEditingController();
  final clientSecretCtrl = TextEditingController();

  await showDialog(
    context: context,
    builder: (dCtx) => AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.cloud_sync, color: AppColors.total),
          const SizedBox(width: 10),
          Text(isSwitch ? 'Switch Google Account' : 'Desktop Google Sign-In'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'On desktop (Windows/Linux), signing into Google Drive uses browser-based OAuth 2.0 loopback authorization.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: clientIdCtrl,
              decoration: const InputDecoration(
                labelText: 'Google OAuth Client ID',
                hintText: 'xxxx.apps.googleusercontent.com',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.vpn_key_outlined),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: clientSecretCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Client Secret (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dCtx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final cId = clientIdCtrl.text.trim();
            final cSec = clientSecretCtrl.text.trim();
            Navigator.pop(dCtx);
            final state = context.read<AppState>();
            try {
              if (isSwitch) {
                await state.switchAccount(desktopClientId: cId, desktopClientSecret: cSec);
              } else {
                await state.signIn(desktopClientId: cId, desktopClientSecret: cSec);
              }
              if (context.mounted) {
                toast(context, 'Signed in with Google successfully.');
              }
            } catch (e) {
              if (context.mounted) {
                toast(context, 'Sign-in error: $e', error: true);
              }
            }
          },
          child: const Text('Continue to Browser Sign-In'),
        ),
      ],
    ),
  );
}
