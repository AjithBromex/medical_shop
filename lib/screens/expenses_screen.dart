import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/filter_bar.dart';
import 'collection_history.dart' show pageSize;
import 'report_export.dart';

class _E {
  final List<Expense> rows;
  final List<String> categories;
  final List<CategoryTotal> cats;
  final int todayTotal, count;
  _E(this.rows, this.categories, this.cats, this.todayTotal, this.count);
}

/// Expenses are recorded on their own - never tied to a shop or a payment method.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  Filters _f = const Filters();
  int _page = 1;

  Future<_E> _load() async {
    final r = Repository.instance;
    final count = await r.expenseCount(_f);
    final pages = (count / pageSize).ceil().clamp(1, 1 << 30);
    if (_page > pages) _page = pages;
    final td = today();
    return _E(await r.expenses(_f, limit: pageSize, offset: (_page - 1) * pageSize), await r.categoryNames(),
        await r.categoryTotals(_f), await r.expenseTotal(td, td), count);
  }

  Future<void> _openForm({Expense? existing, required List<String> categories}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: GlassContainer(
          blur: 24,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          color: Colors.white.withValues(alpha: 0.96),
          border: Border.all(color: AppColors.border, width: 1.2),
          child: _ExpenseForm(existing: existing, categories: categories),
        ),
      ),
    );
  }

  Future<void> _addCategory() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (d) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: Colors.white.withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border, width: 1.2),
          ),
          title: const Text('New expense category', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 60,
            decoration: const InputDecoration(labelText: 'Category name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.total,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.pop(d, c.text),
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
    if (name == null || !mounted) return;
    try {
      await Repository.instance.addCategory(name);
      if (!mounted) return;
      context.read<AppState>().changed();
      toast(context, 'Category “${name.trim()}” added.');
    } on RuleException catch (e) {
      if (mounted) toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) => Loader<_E>(
        deps: (_f.q, _f.dateFrom, _f.dateTo, _f.category, _page),
        loader: _load,
        builder: (context, e) {
          final pages = (e.count / pageSize).ceil().clamp(1, 1 << 30);
          final rangeTotal = e.cats.fold<int>(0, (s, c) => s + c.total);
          return Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppColors.expenses.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: FloatingActionButton.extended(
                backgroundColor: AppColors.expenses,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onPressed: () => _openForm(categories: e.categories),
                icon: const Icon(Icons.add),
                label: const Text('Add expense', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
            body: PageBody([
              CardGrid([
                StatCard('Today’s expenses', inr(e.todayTotal), Icons.receipt_long, AppColors.expenses),
                StatCard(
                  _f.isEmpty ? 'All expenses' : 'Filtered expenses',
                  inr(rangeTotal),
                  Icons.account_balance_wallet_outlined,
                  AppColors.expenses,
                  sub: '${e.count} entries',
                ),
              ], minWidth: 280),
              const SizedBox(height: 12),
              FilterBar(
                value: _f,
                showCategory: true,
                categories: e.categories,
                searchHint: 'Description or notes',
                onChanged: (f) => setState(() { _f = f; _page = 1; }),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 10, children: [
                GlassButton(
                  onPressed: _addCategory,
                  icon: Icons.label_outline,
                  accentColor: AppColors.total,
                  child: const Text('New category'),
                ),
                GlassButton(
                  onPressed: () => exportReportPdf(context, 'expenses', _f),
                  icon: Icons.picture_as_pdf_outlined,
                  accentColor: AppColors.total,
                  isPrimary: true,
                  child: const Text('Export PDF'),
                ),
                GlassButton(
                  onPressed: () => exportReport(context, 'expenses', _f),
                  icon: Icons.table_chart_outlined,
                  accentColor: AppColors.cash,
                  child: const Text('Export CSV'),
                ),
              ]),
              if (e.cats.isNotEmpty) ...[
                const SectionTitle('By category'),
                GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: DoughnutChart(
                    labels: [for (final c in e.cats) c.category],
                    paise: [for (final c in e.cats) c.total],
                    colors: AppColors.categories,
                  ),
                ),
              ],
              const SectionTitle('Expenses'),
              GlassCard(
                padding: EdgeInsets.zero,
                child: e.rows.isEmpty
                    ? const EmptyState('No expenses match these filters.', icon: Icons.receipt_long)
                    : Column(children: [
                        for (var i = 0; i < e.rows.length; i++) ...[
                          ListTile(
                            title: Text(e.rows[i].category, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            subtitle: Text(
                              '${e.rows[i].displayId} · ${dmy(e.rows[i].date)}${e.rows[i].notes == null ? '' : '\n${e.rows[i].notes}'}',
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                            isThreeLine: e.rows[i].notes != null,
                            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                              Text(inr(e.rows[i].amount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.expenses, fontSize: 15)),
                              PopupMenuButton<String>(
                                iconColor: AppColors.textSecondary,
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    _openForm(existing: e.rows[i], categories: e.categories);
                                  } else {
                                    await showConfirmDelete(context, 'expense ${e.rows[i].displayId}', () async {
                                      await Repository.instance.deleteExpense(e.rows[i].id!);
                                      if (context.mounted) {
                                        context.read<AppState>().changed();
                                        toast(context, 'Expense ${e.rows[i].displayId} deleted.');
                                      }
                                    });
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                                ],
                              ),
                            ]),
                          ),
                          if (i < e.rows.length - 1) Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                        ],
                      ]),
              ),
              Pager(page: _page, pages: pages, onPage: (p) => setState(() => _page = p)),
              const SizedBox(height: 80),
            ]),
          );
        },
      );
}

class _ExpenseForm extends StatefulWidget {
  final Expense? existing;
  final List<String> categories;
  const _ExpenseForm({this.existing, required this.categories});
  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  late DateTime _date = widget.existing?.date ?? today();
  late String? _category = widget.existing?.category;
  late final _amount = TextEditingController(text: widget.existing == null ? '' : plain(widget.existing!.amount));
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  List<String> _errors = [];
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final errors = <String>[];
    final allowed = {...widget.categories.map((c) => c.toLowerCase()), if (widget.existing != null) widget.existing!.category.toLowerCase()};
    if (_category == null || !allowed.contains(_category!.toLowerCase())) errors.add('Please choose an expense category.');
    var amount = 0;
    try {
      amount = parseAmount(_amount.text, 'Expense amount', allowZero: false);
    } on FormatException catch (e) {
      errors.add(e.message);
    }
    final notes = _notes.text.trim();
    if (notes.length > 500) errors.add('Notes can be at most 500 characters.');
    if (errors.isNotEmpty) {
      setState(() => _errors = errors);
      return;
    }
    setState(() { _saving = true; _errors = []; });
    try {
      await Repository.instance.saveExpense(Expense(
        id: widget.existing?.id,
        date: _date,
        category: _category!,
        description: widget.existing?.description ?? _category!,
        amount: amount,
        notes: notes.isEmpty ? null : notes,
      ));
      if (!mounted) return;
      context.read<AppState>().changed();
      Navigator.pop(context);
      toast(context, widget.existing == null ? 'Expense saved.' : 'Expense updated.');
    } catch (e) {
      setState(() => _errors = ['Could not save: $e']);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cats = {...widget.categories, if (widget.existing != null) widget.existing!.category}.toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Text(
          widget.existing == null ? 'Add expense' : 'Edit ${widget.existing!.displayId}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 14),
        ErrorBox(_errors),
        DateField(label: 'Expense date', value: _date, onChanged: (d) => setState(() => _date = d ?? _date)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: cats.contains(_category) ? _category : null,
          dropdownColor: Colors.white,
          decoration: const InputDecoration(labelText: 'Category', prefixIcon: Icon(Icons.category_outlined)),
          items: [for (final c in cats) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ', prefixIcon: Icon(Icons.currency_rupee, color: AppColors.expenses)),
        ),
        const SizedBox(height: 12),
        TextField(controller: _notes, maxLines: 2, maxLength: 500, decoration: const InputDecoration(labelText: 'Notes (optional)', prefixIcon: Icon(Icons.notes_outlined))),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.expenses,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _saving ? null : _save,
          child: Text(
            widget.existing == null ? 'Save expense' : 'Update expense',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ]),
    );
  }
}
