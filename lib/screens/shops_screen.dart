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
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _edit([MedicalShop? shop]) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: isDark ? const Color(0x99000000) : const Color(0x730F172A),
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: _ShopForm(shop: shop),
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
      toast(context, 'Syncing data with cloud backup...');
      await MongoDatabase.instance.syncAtlasToLocal();
      if (!mounted) return;
      context.read<AppState>().changed();
      toast(context, 'Data synced successfully.');
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
              boxShadow: const [
                BoxShadow(color: Color(0x330284C7), blurRadius: 16, offset: Offset(0, 4)),
              ],
            ),
            child: FloatingActionButton.extended(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onPressed: _edit,
              icon: const Icon(Icons.add),
              label: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          body: PageBody([
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'Search shops',
                hintText: 'Type shop name...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0284C7)),
                suffixIcon: _q.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _q = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _q = v.trim()),
              onSubmitted: (v) => setState(() => _q = v.trim()),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: EdgeInsets.zero,
              child: rows.isEmpty
                  ? const EmptyState('No medical shops yet. Tap “Add shop” to create the first one.', icon: Icons.storefront_outlined)
                  : Column(children: [
                      for (var i = 0; i < rows.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: rows[i].shop.isActive ? const Color(0xFFE0F2FE) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.storefront_outlined,
                                  color: rows[i].shop.isActive ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            rows[i].shop.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: rows[i].shop.isActive
                                                  ? (Theme.of(context).brightness == Brightness.dark
                                                      ? const Color(0xFFF8FAFC)
                                                      : const Color(0xFF0F172A))
                                                  : const Color(0xFF94A3B8),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        SyncItemBadge(isPending: rows[i].shop.isPendingSync),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    if (rows[i].shop.phone != null && rows[i].shop.phone!.isNotEmpty) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.phone_outlined, size: 14, color: Color(0xFF64748B)),
                                          const SizedBox(width: 4),
                                          Text(
                                            rows[i].shop.phone!,
                                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    if (rows[i].shop.address != null && rows[i].shop.address!.isNotEmpty) ...[
                                      Text(
                                        rows[i].shop.address!,
                                        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '${rows[i].count} collections',
                                            style: const TextStyle(color: Color(0xFF475569), fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0F2FE),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            inr(rows[i].total),
                                            style: const TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                        if (!rows[i].shop.isActive)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'Inactive',
                                              style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF64748B)),
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
                            ],
                          ),
                        ),
                        if (i < rows.length - 1) const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      ],
                    ]),
            ),
            const SectionTitle('Data & cloud backup'),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Wrap(spacing: 10, runSpacing: 10, children: [
                GlassButton(
                  onPressed: _backup,
                  icon: Icons.download_rounded,
                  accentColor: AppColors.total,
                  isPrimary: true,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: const Text('Export local backup'),
                ),
                GlassButton(
                  onPressed: _restore,
                  icon: Icons.sync_rounded,
                  accentColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: const Text('Sync with cloud backup'),
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final cardBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final accentColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.shop == null ? 'Add customer' : 'Edit customer',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 22),
                onPressed: () => Navigator.pop(context),
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ErrorBox(_errors),
          TextField(
            controller: _name,
            autofocus: true,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Shop name',
              labelStyle: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: accentColor,
              ),
              prefixIcon: Icon(
                Icons.storefront_outlined,
                color: accentColor,
                size: 22,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: cardBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accentColor, width: 1.8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accentColor, width: 2.2),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accentColor, width: 1.8),
              ),
            ),
            onSubmitted: (_) => _save(),
          ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _saving ? null : _save,
                child: Text(
                  widget.shop == null ? 'Save shop' : 'Update shop',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
  }
}
