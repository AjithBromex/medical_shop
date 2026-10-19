import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

class _D {
  final Totals t;
  final int expenses, remaining;
  final List<CategoryTotal> cats;
  final List<DayRow> history;
  _D(this.t, this.expenses, this.remaining, this.cats, this.history);
}

/// Remaining = (Cash + GPay + Cheque) - Expenses, for any date.
class DailyMoneyScreen extends StatefulWidget {
  const DailyMoneyScreen({super.key});
  @override
  State<DailyMoneyScreen> createState() => _DailyMoneyScreenState();
}

class _DailyMoneyScreenState extends State<DailyMoneyScreen> {
  DateTime _day = today();
  late DateTime _from = _day.subtract(const Duration(days: 29));
  late DateTime _to = _day;

  Future<_D> _load() async {
    final r = Repository.instance;
    var from = _from, to = _to;
    if (from.isAfter(to)) { final x = from; from = to; to = x; }
    final s = await r.daySummary(_day);
    return _D(s.totals, s.expenses, s.remaining, await r.categoryTotals(Filters(dateFrom: _day, dateTo: _day)),
        await r.dailySummaryRows(from, to));
  }

  @override
  Widget build(BuildContext context) => Loader<_D>(
        deps: (_day, _from, _to),
        loader: _load,
        builder: (context, d) {
          final asc = d.history.reversed.toList();
          final rangeTotal = d.history.fold<int>(0, (s, r) => s + r.total);
          final rangeExp = d.history.fold<int>(0, (s, r) => s + r.expenses);
          return PageBody([
            Center(child: DayNav(day: _day, onChanged: (x) => setState(() => _day = x))),
            const SizedBox(height: 8),
            CardGrid([
              StatCard('Cash', inr(d.t.cash), Icons.payments, AppColors.cash),
              StatCard('Gpay/cheque/CN', inr(d.t.gpay + d.t.cheque), Icons.account_balance, AppColors.gpay),
              StatCard('Total collection', inr(d.t.total), Icons.monetization_on_outlined, AppColors.total, sub: '${d.t.count} transactions'),
              StatCard('Total expenses', inr(d.expenses), Icons.receipt_long, AppColors.expenses),
              StatCard('Remaining cash', inr(d.t.cash - d.expenses), Icons.account_balance_wallet_outlined,
                  d.t.cash - d.expenses >= 0 ? AppColors.cash : AppColors.expenses,
                  sub: 'Cash − expenses'),
              StatCard('Total remaining', inr(d.remaining), Icons.savings_outlined, d.remaining >= 0 ? AppColors.cash : AppColors.expenses,
                  sub: '${inr(d.t.total)} − ${inr(d.expenses)}'),
            ]),
            if (d.cats.isNotEmpty) ...[
              const SectionTitle('Expenses on this day (information only)'),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < d.cats.length; i++) ...[
                    ListTile(
                      dense: true,
                      title: Text(d.cats[i].category, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      subtitle: Text('${d.cats[i].count} entr${d.cats[i].count == 1 ? 'y' : 'ies'}', style: const TextStyle(color: AppColors.textSecondary)),
                      trailing: Text(inr(d.cats[i].total), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.expenses)),
                    ),
                    if (i < d.cats.length - 1) Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                  ],
                ]),
              ),
            ],
            const SectionTitle('Daily history'),
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: Wrap(spacing: 12, runSpacing: 12, children: [
                SizedBox(width: 200, child: DateField(label: 'From', value: _from, onChanged: (v) => setState(() => _from = v ?? _from))),
                SizedBox(width: 200, child: DateField(label: 'To', value: _to, onChanged: (v) => setState(() => _to = v ?? _to))),
              ]),
            ),
            const SizedBox(height: 12),
            CardGrid([
              StatCard('Range collection', inr(rangeTotal), Icons.monetization_on_outlined, AppColors.total),
              StatCard('Range expenses', inr(rangeExp), Icons.receipt_long, AppColors.expenses),
              StatCard('Range remaining', inr(rangeTotal - rangeExp), Icons.savings_outlined, rangeTotal - rangeExp >= 0 ? AppColors.cash : AppColors.expenses),
            ], minWidth: 240),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: asc.isEmpty
                  ? const EmptyState('No collections or expenses in this range.', icon: Icons.bar_chart)
                  : BarsChart(
                      stacked: false,
                      labels: [for (final r in asc) shortDay(r.date)],
                      bars: [
                        Series('Collection', AppColors.total, [for (final r in asc) r.total]),
                        Series('Expenses', AppColors.expenses, [for (final r in asc) r.expenses]),
                      ],
                      line: Series('Remaining', AppColors.remaining, [for (final r in asc) r.remaining]),
                    ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              padding: const EdgeInsets.all(8),
              child: d.history.isEmpty
                  ? const SizedBox.shrink()
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        showCheckboxColumn: false,
                        headingRowHeight: 44,
                        dataRowMinHeight: 40,
                        dataRowMaxHeight: 46,
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        dataTextStyle: const TextStyle(color: AppColors.textPrimary),
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Cash'), numeric: true),
                          DataColumn(label: Text('Expenses'), numeric: true),
                          DataColumn(label: Text('Remaining Cash\n(Cash − Exp)'), numeric: true),
                          DataColumn(label: Text('Gpay/cheque/CN'), numeric: true),
                          DataColumn(label: Text('Total Collection'), numeric: true),
                          DataColumn(label: Text('Total Remaining'), numeric: true),
                        ],
                        rows: [
                          for (final r in d.history)
                            DataRow(
                              onSelectChanged: (_) => setState(() => _day = r.date),
                              cells: [
                                DataCell(Text(dmy(r.date))),
                                DataCell(Text(inr(r.cash))),
                                DataCell(Text(inr(r.expenses), style: const TextStyle(color: AppColors.expenses))),
                                DataCell(Text(inr(r.remainingCash),
                                    style: TextStyle(fontWeight: FontWeight.w800, color: r.remainingCash < 0 ? AppColors.expenses : AppColors.cash))),
                                DataCell(Text(inr(r.gpay + r.cheque))),
                                DataCell(Text(inr(r.total), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.total))),
                                DataCell(Text(inr(r.remaining),
                                    style: TextStyle(fontWeight: FontWeight.w800, color: r.remaining < 0 ? AppColors.expenses : AppColors.total))),
                              ],
                            ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 24),
          ]);
        },
      );
}
