import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../data/mongo_database.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/sync_status_widget.dart';


/// Admin: manage shops, create / share / restore backups, optional sample data.
class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});
  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  String _q = '';

  Future<void> _edit([MedicalShop? shop]) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Color(0x330F172A),
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: _ShopForm(shop: shop),
          ),
        ),
      ),
    );
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    try {
      await action();
      if (!mounted) return;
      context.read<AppState>().changed();
      toast(context, ok);
    } on RuleException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    } catch (e) {
      if (mounted) toast(context, 'Error: $e', error: true);
    }
  }

  Future<void> _backup() async {
    if (kIsWeb) {
      toast(context, 'Database backup is available on desktop/mobile.', error: true);
      return;
    }
    try {
      final f = await AppDatabase.instance.backup();
      if (!mounted) return;
      toast(context, 'Backup saved: ${f.path}');
      await Share.shareXFiles([XFile(f.path)], subject: 'Medical shop database backup');
    } catch (e) {
      if (mounted) toast(context, 'Backup failed: $e', error: true);
    }
  }

  Future<void> _restore() async {
    try {
      toast(context, 'Syncing data with MongoDB Atlas...');
      await MongoDatabase.instance.syncAtlasToLocal();
      if (!mounted) return;
      context.read<AppState>().changed();
      toast(context, 'Data synced successfully with MongoDB Atlas.');
    } catch (e) {
      if (mounted) toast(context, 'Sync failed: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Loader<List<ShopRow>>(
        deps: _q,
        loader: () => Repository.instance.shopRows(_q),
        builder: (context, rows) => Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: AppColors.total.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4)),
              ],
            ),
            child: FloatingActionButton.extended(
              backgroundColor: AppColors.total,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: _edit,
              icon: const Icon(Icons.add),
              label: const Text('Add shop', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          body: PageBody([
            TextField(
              decoration: const InputDecoration(labelText: 'Search shops', prefixIcon: Icon(Icons.search)),
              onSubmitted: (v) => setState(() => _q = v.trim()),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: EdgeInsets.zero,
              child: rows.isEmpty
                  ? const EmptyState('No medical shops yet. Tap “Add shop” to create the first one.', icon: Icons.storefront_outlined)
                  : Column(children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: rows[i].shop.isActive ? AppColors.total.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: rows[i].shop.isActive ? AppColors.total.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.1),
                              ),
                            ),
                            child: Icon(
                              Icons.storefront_outlined,
                              color: rows[i].shop.isActive ? AppColors.total : AppColors.textMuted,
                              size: 22,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  rows[i].shop.name,
                                  style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              SyncItemBadge(isPending: rows[i].shop.isPendingSync),
                            ],
                          ),
                          subtitle: Text(
                            [
                              if (rows[i].shop.phone != null) rows[i].shop.phone!,
                              if (rows[i].shop.address != null) rows[i].shop.address!,
                              '${rows[i].count} collections · ${inr(rows[i].total)}',
                              if (!rows[i].shop.isActive) 'Inactive',
                            ].join('\n'),
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            iconColor: AppColors.textSecondary,
                            onSelected: (v) async {
                              switch (v) {
                                case 'edit':
                                  _edit(rows[i].shop);
                                case 'toggle':
                                  _run(() => Repository.instance.toggleShop(rows[i].shop),
                                      'Shop “${rows[i].shop.name}” ${rows[i].shop.isActive ? 'deactivated (history is kept)' : 'activated'}.');
                                case 'delete':
                                  if (await confirm(context, 'Delete shop?', 'Delete “${rows[i].shop.name}”? Shops with collections cannot be deleted.')) {
                                    _run(() => Repository.instance.deleteShop(rows[i].shop.id!), 'Shop “${rows[i].shop.name}” deleted.');
                                  }
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(value: 'edit', child: Text('Edit')),
                              PopupMenuItem(value: 'toggle', child: Text(rows[i].shop.isActive ? 'Deactivate' : 'Activate')),
                              const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                        if (i < rows.length - 1) Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                      ],
                    ]),
            ),
            const SectionTitle('Data & backup'),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                GlassButton(
                  onPressed: _backup,
                  icon: Icons.download,
                  accentColor: AppColors.total,
                  isPrimary: true,
                  child: const Text('Create & share backup'),
                ),
                GlassButton(
                  onPressed: _restore,
                  icon: Icons.restore,
                  accentColor: AppColors.gpay,
                  child: const Text('Sync with Atlas'),
                ),
                GlassButton(
                  onPressed: () => showConfigureServerDialog(context),
                  icon: Icons.cloud_outlined,
                  accentColor: AppColors.total,
                  child: const Text('Cloud Server Settings'),
                ),
              ]),
            ),
            const SizedBox(height: 80),
          ]),
        ),
      );
}

class _ShopForm extends StatefulWidget {
  final MedicalShop? shop;
  const _ShopForm({this.shop});
  @override
  State<_ShopForm> createState() => _ShopFormState();
}

class _ShopFormState extends State<_ShopForm> {
  late final _name = TextEditingController(text: widget.shop?.name ?? '');
  List<String> _errors = [];
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim().split(RegExp(r'\s+')).join(' ');
    final errors = <String>[];
    if (name.isEmpty) errors.add('Medical shop name is required.');
    if (name.length > 150) errors.add('Shop name can be at most 150 characters.');
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    setState(() { _saving = true; _errors = []; });
    try {
      await Repository.instance.saveShop(MedicalShop(
        id: widget.shop?.id,
        name: name,
        address: widget.shop?.address,
        phone: widget.shop?.phone,
        notes: widget.shop?.notes,
        isActive: widget.shop?.isActive ?? true,
      ));
      if (!mounted) return;
      context.read<AppState>().changed();
      Navigator.pop(context);
      toast(context, 'Shop “$name” ${widget.shop == null ? 'added' : 'updated'}.');
    } on RuleException catch (e) {
      setState(() => _errors = [e.message]);
    } catch (e) {
      setState(() => _errors = ['Could not save: $e']);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              widget.shop == null ? 'Add medical shop' : 'Edit shop',
              style: const TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 16),
            ErrorBox(_errors),
            TextField(
              controller: _name,
              autofocus: true,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: 'Shop name',
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0369A1),
                ),
                prefixIcon: const Icon(
                  Icons.storefront_outlined,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0369A1), width: 1.6),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0369A1), width: 2.0),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0369A1), width: 1.6),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0369A1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: Text(
                  widget.shop == null ? 'Save shop' : 'Update shop',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
}
