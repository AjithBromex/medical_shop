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
  final _cash = TextEditingController();
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
    for (final c in [_cash, _gpayCheque, _shopSearch]) {
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
      _cash.text = e.cash > 0 ? plain(e.cash) : '';
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
    for (final c in [_receipt, _cash, _gpayCheque, _notes, _shopSearch]) {
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

    final receipt = _receipt.text.trim();
    if (receipt.isEmpty) {
      errors.add('Receipt number is required.');
    } else if (receipt.length > 40) {
      errors.add('Receipt number can be at most 40 characters.');
    } else if (!RegExp(r'^[#A-Za-z0-9][A-Za-z0-9\-_/.# ]*$').hasMatch(receipt)) {
      errors.add('Receipt number may only contain letters, numbers, #, and - _ / .');
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
      errors.add('That shop is inactive. Activate it in Admin - Medical Shops first.');
    }

    var cash = 0, gpayCheque = 0;
    var amountError = false;
    for (final (ctrl, label) in [(_cash, 'Cash amount'), (_gpayCheque, 'Gpay/cheque/CN amount')]) {
      try {
        final v = parseAmount(ctrl.text, label);
        if (label.startsWith('Cash')) {
          cash = v;
        } else {
          gpayCheque = v;
        }
      } on FormatException catch (e) {
        errors.add(e.message);
        amountError = true;
      }
    }
    if (!amountError && cash + gpayCheque == 0) {
      errors.add('Enter at least one payment amount (cash or Gpay/cheque/CN) greater than zero.');
    }
    final notes = _notes.text.trim();
    if (notes.length > 500) errors.add('Notes can be at most 500 characters.');

    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }

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
        _cash.clear(); _gpayCheque.clear(); _notes.clear();
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

  Widget _amount(TextEditingController c, String label, IconData icon, Color color) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixText: '₹ ', prefixIcon: Icon(icon, color: color)),
      );

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        backgroundColor: AppColors.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppColors.total)),
      );
    }
    final total = _safe(_cash) + _safe(_gpayCheque);

    final body = PageBody([
      if (_shops.isEmpty)
        GlassContainer(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          color: AppColors.cheque.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cheque.withValues(alpha: 0.4)),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.cheque, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No active medical shops yet. Add one in Admin - Medical Shops first.',
                  style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ErrorBox(_errors),
      GlassCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 12, runSpacing: 12, children: [
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _receipt,
                  decoration: const InputDecoration(labelText: 'Receipt number', prefixIcon: Icon(Icons.receipt_long_outlined)),
                ),
              ),
              SizedBox(
                width: 220,
                child: DateField(label: 'Collection date', value: _date, onChanged: (d) => setState(() => _date = d ?? _date)),
              ),
              SizedBox(
                width: 320,
                child: RawAutocomplete<MedicalShop>(
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
                      decoration: InputDecoration(
                        labelText: 'Search & choose shop',
                        hintText: 'Type shop name...',
                        prefixIcon: const Icon(Icons.search),
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
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(14),
                        color: Colors.white,
                        child: Container(
                          width: 320,
                          constraints: const BoxConstraints(maxHeight: 260),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border, width: 1.2),
                          ),
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final s = options.elementAt(index);
                              final isSelected = s.id == _shopId;
                              return ListTile(
                                dense: true,
                                selected: isSelected,
                                leading: Icon(
                                  Icons.storefront_outlined,
                                  size: 20,
                                  color: isSelected ? AppColors.total : AppColors.textSecondary,
                                ),
                                title: Text(
                                  s.name + (s.isActive ? '' : ' (inactive)'),
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppColors.total : AppColors.textPrimary,
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
              ),
            ]),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth > 520
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(width: itemWidth, child: _amount(_cash, 'Cash', Icons.payments, AppColors.cash)),
                    SizedBox(width: itemWidth, child: _amount(_gpayCheque, 'Gpay/cheque/CN', Icons.account_balance, AppColors.gpay)),
                  ],
                );
              },
            ),
            const SizedBox(height: 18),
            GlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              borderRadius: BorderRadius.circular(14),
              color: AppColors.total.withValues(alpha: 0.12),
              border: Border.all(color: AppColors.total.withValues(alpha: 0.4), width: 1.2),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total (cash + Gpay/cheque/CN)',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      inr(total),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.total,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _notes,
              maxLines: 2,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.total,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.save),
              label: Text(
                _editing ? 'Update collection' : 'Save collection',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    ]);

    return _editing
        ? Scaffold(
            backgroundColor: AppColors.bgDark,
            appBar: AppBar(title: Text('Edit ${widget.existing!.receiptNumber}')),
            body: body,
          )
        : body;
  }
}
