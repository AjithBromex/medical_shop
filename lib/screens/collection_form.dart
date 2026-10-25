import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'receipt_screen.dart';
import 'shell.dart';

/// Add (no [existing]) or edit a collection. Same validation rules as the Flask app.
class CollectionForm extends StatefulWidget {
  final Collection? existing;
  final VoidCallback? onSaved;
  const CollectionForm({super.key, this.existing, this.onSaved});
  @override
  State<CollectionForm> createState() => _CollectionFormState();
}

class _CollectionFormState extends State<CollectionForm> {
  final _receipt = TextEditingController();
  final _collected = TextEditingController();
  final _gpayCheque = TextEditingController();
  final _notes = TextEditingController();
  final _shopSearch = TextEditingController();
  final _shopFocus = FocusNode();
  DateTime _date = today();
  int? _shopId;
  List<MedicalShop> _shops = [];
  List<String> _errors = [];
  bool _saving = false, _loaded = false;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _init();
    for (final c in [_collected, _gpayCheque, _shopSearch]) {
      c.addListener(() => setState(() {}));
    }
    _shopSearch.addListener(() {
      if (_shopSearch.text.trim().isEmpty && _shopId != null) {
        setState(() => _shopId = null);
      }
    });
  }

  Future<void> _init() async {
    final repo = Repository.instance;
    final e = widget.existing;
    _shops = await repo.shops(activeOnly: true, includeId: e?.shopId);
    if (e != null) {
      _receipt.text = e.receiptNumber;
      _date = e.date;
      _shopId = e.shopId;
      _collected.text = e.total > 0 ? plain(e.total) : '';
      final online = e.gpay + e.cheque;
      _gpayCheque.text = online > 0 ? plain(online) : '';
      _notes.text = e.notes ?? '';
      final match = _shops.where((s) => s.id == e.shopId).firstOrNull;
      if (match != null) {
        _shopSearch.text = match.name;
      }
    } else {
      _receipt.text = await repo.nextReceiptNumber();
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _shopFocus.dispose();
    for (final c in [_receipt, _collected, _gpayCheque, _notes, _shopSearch]) {
      c.dispose();
    }
    super.dispose();
  }

  int _safe(TextEditingController c) {
    try {
      return parseAmount(c.text, 'x');
    } on FormatException {
      return 0;
    }
  }

  void _goHome() {
    final shell = context.findAncestorStateOfType<ShellState>();
    if (shell != null) {
      shell.go(0);
    } else if (widget.onSaved != null) {
      widget.onSaved!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _save() async {
    if (_saving) return; // double-tap protection
    final repo = Repository.instance;
    final errors = <String>[];

    var receipt = _receipt.text.trim();
    if (receipt.isEmpty) {
      errors.add('Receipt number is required.');
    } else {
      // Auto-format standard numeric receipts to 5 digits (#00001 - #99999)
      final numMatch = RegExp(r'^(#?)(\d+)$').firstMatch(receipt);
      if (numMatch != null) {
        final val = int.tryParse(numMatch.group(2)!) ?? 0;
        receipt = '#${val.toString().padLeft(5, '0')}';
        _receipt.text = receipt;
      }
      if (receipt.length > 40) {
        errors.add('Receipt number can be at most 40 characters.');
      } else if (!RegExp(r'^[#A-Za-z0-9][A-Za-z0-9\-_/.# ]*$').hasMatch(receipt)) {
        errors.add('Receipt number may only contain letters, numbers, #, and - _ / .');
      }
    }

    MedicalShop? shop;
    if (_shopId == null && _shopSearch.text.trim().isNotEmpty) {
      final typed = _shopSearch.text.trim().toLowerCase();
      final match = _shops.where((s) => s.name.trim().toLowerCase() == typed).firstOrNull;
      if (match != null) _shopId = match.id;
    }
    if (_shopId != null) shop = await repo.shopById(_shopId!);
    if (shop == null) {
      errors.add('Please select a medical shop.');
    } else if (!shop.isActive && !(widget.existing != null && widget.existing!.shopId == shop.id)) {
      errors.add('That shop is inactive. Activate it in Admin - Customers first.');
    }

    int collected = 0, gpayCheque = 0;
    bool amountError = false;

    try {
      collected = parseAmount(_collected.text, 'Collected amount', allowZero: false);
    } on FormatException catch (e) {
      errors.add(e.message);
      amountError = true;
    }

    try {
      gpayCheque = parseAmount(_gpayCheque.text, 'GPay / Cheque amount', allowZero: true);
    } on FormatException catch (e) {
      errors.add(e.message);
      amountError = true;
    }

    if (!amountError) {
      if (collected <= 0) {
        errors.add('Collected amount must be greater than zero.');
      }
      if (gpayCheque < 0) {
        errors.add('GPay / Cheque amount cannot be negative.');
      }
      if (gpayCheque > collected) {
        errors.add('GPay / Cheque amount (${inr(gpayCheque)}) cannot exceed Collected amount (${inr(collected)}).');
      }
    }

    final notes = _notes.text.trim();
    if (notes.length > 500) errors.add('Notes can be at most 500 characters.');

    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

    // Automatically calculate cash amount: Cash Amount = Collected Amount − GPay / Cheque Amount
    final cash = collected - gpayCheque;

    setState(() { _saving = true; _errors = []; });
    try {
      final c = Collection(
        id: widget.existing?.id,
        receiptNumber: receipt,
        shopId: shop!.id!,
        date: _date,
        cash: cash,
        gpay: gpayCheque,
        cheque: 0,
        notes: notes.isEmpty ? null : notes,
      );
      final savedId = await repo.saveCollection(c);
      if (!mounted) return;
      final state = context.read<AppState>();
      state.changed();
      if (_editing) {
        toast(context, 'Collection $receipt updated.');
        Navigator.pop(context, true);
      } else {
        toast(context, 'Collection $receipt saved (${inr(c.total)}).');
        // ready for the next entry, same date kept
        _receipt.text = await repo.nextReceiptNumber();
        _collected.clear(); _gpayCheque.clear(); _notes.clear();
        _shopSearch.clear();
        setState(() => _shopId = null);
        if (mounted) {
          final view = await showDialog<bool>(
            context: context,
            builder: (d) => AlertDialog(
              title: const Text('Collection saved'),
              content: Text('$receipt · ${inr(c.total)}\nDo you want to view / print the receipt?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(d, false),
                  child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(d, true),
                  child: const Text('View receipt'),
                ),
              ],
            ),
          );
          if (view == true && mounted) {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(collectionId: savedId)));
          }
          if (mounted) {
            _goHome();
          }
        }
      }
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
    if (!_loaded) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0B132B) : AppColors.bgDark,
        body: const Center(child: CircularProgressIndicator(color: AppColors.total)),
      );
    }
    final collected = _safe(_collected);
    final gpayCheque = _safe(_gpayCheque);
    final cash = gpayCheque > collected ? 0 : collected - gpayCheque;

    final body = PageBody([
      if (_shops.isEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFDBA74), width: 1.2),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEA580C), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'No active medical shops yet. Add one in Admin - Customers first.',
                  style: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ErrorBox(_errors),

      // 1. Hero Total Card
      HeroStatCard(
        amount: inr(collected),
        title: 'Total collection',
        subtext: 'Cash (auto): ${inr(cash)}  •  GPay / Cheque: ${inr(gpayCheque)}',
        icon: Icons.monetization_on_outlined,
        gradientColors: const [Color(0xFF0284C7), Color(0xFF0EA5E9)],
        badgeText: 'LIVE\nTOTAL',
      ),
      const SizedBox(height: 16),

      // 2. Receipt Details Section
      const SectionTitle('Receipt details'),
      const SizedBox(height: 10),
      GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth > 500;
              if (isWide) {
                return Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: TextField(
                        controller: _receipt,
                        decoration: const InputDecoration(
                          labelText: 'Receipt number',
                          prefixIcon: Icon(Icons.tag_rounded, color: AppColors.total),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      flex: 4,
                      child: DateField(
                        label: 'Collection date',
                        value: _date,
                        onChanged: (d) => setState(() => _date = d ?? _date),
                      ),
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    TextField(
                      controller: _receipt,
                      decoration: const InputDecoration(
                        labelText: 'Receipt number',
                        prefixIcon: Icon(Icons.tag_rounded, color: AppColors.total),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DateField(
                      label: 'Collection date',
                      value: _date,
                      onChanged: (d) => setState(() => _date = d ?? _date),
                    ),
                  ],
                );
              }
            }),
            const SizedBox(height: 14),
            RawAutocomplete<MedicalShop>(
              textEditingController: _shopSearch,
              focusNode: _shopFocus,
              optionsBuilder: (TextEditingValue textEditingValue) {
                final q = textEditingValue.text.trim().toLowerCase();
                if (q.isEmpty) return _shops;
                return _shops.where((s) => s.name.toLowerCase().contains(q));
              },
              displayStringForOption: (s) => s.name,
              onSelected: (s) {
                setState(() => _shopId = s.id);
              },
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Search & choose medical shop',
                    hintText: 'Type shop name...',
                    prefixIcon: const Icon(Icons.storefront_outlined, color: AppColors.total),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Clear selection',
                            splashRadius: 18,
                            onPressed: () {
                              controller.clear();
                              setState(() => _shopId = null);
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_drop_down),
                            tooltip: 'Show all shops',
                            splashRadius: 18,
                            onPressed: () {
                              if (!focusNode.hasFocus) {
                                focusNode.requestFocus();
                              }
                            },
                          ),
                  ),
                  onSubmitted: (_) => onFieldSubmitted(),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 10,
                    borderRadius: BorderRadius.circular(16),
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    child: Container(
                      width: 340,
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : AppColors.border, width: 1.2),
                      ),
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final s = options.elementAt(index);
                          final isSelected = s.id == _shopId;
                          return ListTile(
                            dense: true,
                            selected: isSelected,
                            leading: Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? const Color(0x330284C7) : const Color(0xFFE0F2FE))
                                    : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.storefront_outlined,
                                size: 18,
                                color: isSelected ? AppColors.total : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                            title: Text(
                              s.name + (s.isActive ? '' : ' (inactive)'),
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                color: isSelected
                                    ? AppColors.total
                                    : (isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary),
                              ),
                            ),
                            onTap: () => onSelected(s),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // 3. Payment Amounts Section
      const SectionTitle('Payment amounts'),
      const SizedBox(height: 10),
      GlassCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                final itemWidth = isWide ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth;
                return Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: TextField(
                        controller: _collected,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Collected amount',
                          hintText: 'Enter total collected',
                          prefixText: '₹ ',
                          prefixIcon: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF0284C7), size: 20),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: TextField(
                        controller: _gpayCheque,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'GPay / Cheque amount',
                          hintText: 'Enter GPay or cheque amount',
                          prefixText: '₹ ',
                          prefixIcon: Container(
                            width: 36,
                            height: 36,
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.account_balance_outlined, color: Color(0xFF3B82F6), size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),

            const SizedBox(height: 14),
            TextField(
              controller: _notes,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_rounded, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),

      // 4. Save Button
      SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 2,
          ),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_outline, size: 20),
          label: Text(
            _editing ? 'Update collection' : 'Save collection',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ),
      const SizedBox(height: 32),
    ]);

    return _editing
        ? Scaffold(
            backgroundColor: isDark ? const Color(0xFF0B132B) : AppColors.bgDark,
            appBar: AppBar(
              title: Text(
                'Edit ${widget.existing!.receiptNumber}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                ),
              ),
              backgroundColor: isDark ? const Color(0xFF0B132B) : AppColors.bgDark,
              elevation: 0,
              iconTheme: IconThemeData(
                color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
              ),
            ),
            body: body,
          )
        : body;
  }

}
