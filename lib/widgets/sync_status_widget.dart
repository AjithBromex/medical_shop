import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../data/api_service.dart';
import '../state/app_state.dart';
import 'common.dart';
import 'glass.dart';

class SyncStatusHeaderButton extends StatelessWidget {
  final bool compact;
  const SyncStatusHeaderButton({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    Widget icon;
    String label;
    Color color;

    if (state.isSyncing) {
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
      label = 'Saved to Atlas';
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

    return Tooltip(
      message: 'Saved to MongoDB Atlas',
      child: Icon(Icons.cloud_done_rounded, size: 14, color: AppColors.gpay.withValues(alpha: 0.8)),
    );
  }
}

void showCloudSyncSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final state = ctx.watch<AppState>();
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Color(0x1F0F172A), blurRadius: 24, offset: Offset(0, -4)),
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
                decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.cloud_sync_rounded, color: AppColors.total, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Cloud Synchronization',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bgDark,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: state.isOnline ? AppColors.gpay : Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.isOnline ? 'Connected to Hosted Backend' : 'Offline / Server Unreachable',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('Backend URL: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Expanded(
                        child: Text(
                          ApiService.instance.baseUrl,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('Offline Queue: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(
                        state.pendingSyncCount == 0
                            ? '0 items (All data in Atlas)'
                            : '${state.pendingSyncCount} items waiting to sync',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: state.pendingSyncCount == 0 ? AppColors.gpay : Colors.amber.shade800,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GlassButton(
                    onPressed: state.isSyncing
                        ? null
                        : () async {
                            await state.triggerSync();
                            if (ctx.mounted) {
                              toast(ctx, state.isOnline ? 'Synced with MongoDB Atlas' : 'Sync attempt failed - offline');
                            }
                          },
                    icon: Icons.refresh_rounded,
                    accentColor: AppColors.total,
                    isPrimary: true,
                    child: Text(state.isSyncing ? 'Syncing...' : 'Sync Now'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GlassButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      showConfigureServerDialog(context);
                    },
                    icon: Icons.settings_outlined,
                    accentColor: AppColors.cash,
                    child: const Text('Server Settings'),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

void showConfigureServerDialog(BuildContext context) {
  final urlCtrl = TextEditingController(text: ApiService.instance.baseUrl);
  final keyCtrl = TextEditingController(text: ApiService.instance.apiKey);

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.cloud_queue, color: AppColors.total),
          SizedBox(width: 10),
          Text('Cloud Server Settings'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your deployed online backend URL (e.g. from Render or Railway). Never uses localhost.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlCtrl,
              decoration: const InputDecoration(
                labelText: 'Hosted Backend API URL',
                hintText: 'https://your-service.onrender.com/api',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: keyCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Secret Key (Optional)',
                hintText: 'Set in your hosting environment',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.key),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            final newUrl = urlCtrl.text.trim();
            final newKey = keyCtrl.text.trim();
            if (newUrl.isEmpty) return;

            await ApiService.instance.updateConfig(newUrl: newUrl, newApiKey: newKey);
            if (ctx.mounted) {
              Navigator.pop(ctx);
              context.read<AppState>().triggerSync();
              toast(context, 'Server settings updated. Connecting...');
            }
          },
          child: const Text('Save & Connect'),
        ),
      ],
    ),
  );
}
