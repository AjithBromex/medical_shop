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
import '../widgets/sync_status_widget.dart';

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
          child: _ExpenseForm(existing: existing, categories: categories),
        ),
      ),
    );
  }

  Future<void> _addCategory() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (d) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.border, width: 1.2),
          ),
          title: Text(
            'New expense category',
            style: TextStyle(
              color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 60,
            style: TextStyle(color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary),
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
              // 1. Hero Expense Card
              HeroStatCard(
                amount: inr(e.todayTotal),
                title: 'Today’s expenses',
                subtext: 'Recorded today (${dmy(today())})',
                icon: Icons.confirmation_number_outlined,
                gradientColors: const [Color(0xFF881337), Color(0xFFE11D48)],
                badgeText: 'TODAY’S\nEXPENSES',
              ),
              const SizedBox(height: 12),

              // 2. Stats Row
              Row(
                children: [
                  Expanded(
                    child: MiniStatCard(
                      label: _f.isEmpty ? 'All expenses' : 'Filtered total',
                      value: inr(rangeTotal),
                      icon: Icons.confirmation_number_outlined,
                      iconColor: const Color(0xFFF43F5E),
                      iconBg: const Color(0xFFFFE4E6),
                      sub: '${e.count} entries',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MiniStatCard(
                      label: 'Categories',
                      value: '${e.cats.length}',
                      icon: Icons.category_outlined,
                      iconColor: const Color(0xFF8B5CF6),
                      iconBg: const Color(0xFFF3E8FF),
                      sub: 'Active types',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3. Filters & Action Bar
              FilterBar(
                value: _f,
                showCategory: true,
                categories: e.categories,
                searchHint: 'Description or notes',
                onChanged: (f) => setState(() { _f = f; _page = 1; }),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                GlassButton(
                  onPressed: _addCategory,
                  icon: Icons.add_circle_outline,
                  accentColor: AppColors.total,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Text('New category', style: TextStyle(fontSize: 12.5)),
                ),
                GlassButton(
                  onPressed: () => exportReportPdf(context, 'expenses', _f),
                  icon: Icons.picture_as_pdf_outlined,
                  accentColor: const Color(0xFFE11D48),
                  isPrimary: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Text('Export PDF', style: TextStyle(fontSize: 12.5)),
                ),
                GlassButton(
                  onPressed: () => exportReport(context, 'expenses', _f),
                  icon: Icons.table_chart_outlined,
                  accentColor: AppColors.cash,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: const Text('Export Excel', style: TextStyle(fontSize: 12.5)),
                ),
              ]),

              // 4. Category Breakdown Chart
              if (e.cats.isNotEmpty) ...[
                const SizedBox(height: 8),
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

              // 5. Expenses List
              const SizedBox(height: 8),
              const SectionTitle('Expenses list'),
              const SizedBox(height: 10),
              if (e.rows.isEmpty)
                const GlassCard(
                  child: EmptyState('No expenses match these filters.', icon: Icons.confirmation_number_outlined),
                )
              else
                GlassCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < e.rows.length; i++) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0x33F43F5E)
                                      : const Color(0xFFFFE4E6),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.confirmation_number_outlined, color: Color(0xFFF43F5E), size: 22),
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
                                            e.rows[i].category,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14.5,
                                              color: Theme.of(context).brightness == Brightness.dark
                                                  ? const Color(0xFFF8FAFC)
                                                  : const Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        SyncItemBadge(isPending: e.rows[i].isPendingSync),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${e.rows[i].displayId} • ${dmy(e.rows[i].date)}',
                                      style: TextStyle(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color(0xFF94A3B8)
                                            : const Color(0xFF64748B),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (e.rows[i].notes != null && e.rows[i].notes!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        e.rows[i].notes!,
                                        style: TextStyle(
                                          color: Theme.of(context).brightness == Brightness.dark
                                              ? const Color(0xFF94A3B8)
                                              : const Color(0xFF64748B),
                                          fontSize: 11.5,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    inr(e.rows[i].amount),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFE11D48),
                                      fontSize: 16,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(
                                      Icons.more_vert,
                                      size: 20,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
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
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (i < e.rows.length - 1)
                          Divider(
                            height: 1,
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                      ],
                    ],
                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
    final fieldBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

    final cats = {...widget.categories, if (widget.existing != null) widget.existing!.category}.toList();
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
                widget.existing == null ? 'Add expense' : 'Edit ${widget.existing!.displayId}',
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
          DateField(
            label: 'Expense date',
            value: _date,
            onChanged: (d) => setState(() => _date = d ?? _date),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: cats.contains(_category) ? _category : null,
            isExpanded: true,
            dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary, size: 24),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Category',
              prefixIcon: Icon(
                Icons.category_outlined,
                color: isDark ? const Color(0xFFFB7185) : AppColors.expenses,
                size: 22,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: fieldBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderCol, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.8),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderCol, width: 1.2),
              ),
            ),
            items: [
              for (final c in cats)
                DropdownMenuItem(
                  value: c,
                  child: Text(c, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (v) => setState(() => _category = v),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Amount',
              prefixIcon: Icon(
                Icons.currency_rupee_rounded,
                color: isDark ? const Color(0xFFFB7185) : AppColors.expenses,
                size: 20,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: fieldBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderCol, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.8),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderCol, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notes,
            maxLines: 2,
            maxLength: 500,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(
                Icons.notes_rounded,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                size: 22,
              ),
              counterStyle: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
              filled: true,
              fillColor: fieldBg,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderCol, width: 1.2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.8),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: borderCol, width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _saving ? null : _save,
              child: Text(
                widget.existing == null ? 'Save expense' : 'Update expense',
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
