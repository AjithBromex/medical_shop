import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'receipt_screen.dart';

class _Dash {
  final Totals t, all;
  final int expToday, expAll;
  final List<DayRow> week;
  final List<Collection> recent;
  final List<Expense> recentExp;
  _Dash(this.t, this.all, this.expToday, this.expAll, this.week, this.recent, this.recentExp);
}

class DashboardScreen extends StatelessWidget {
  final ValueChanged<int> onGo;
  const DashboardScreen({super.key, required this.onGo});

  Future<_Dash> _load() async {
    final r = Repository.instance;
    final td = today();
    final start = td.subtract(const Duration(days: 6));
    return _Dash(
      await r.collectionTotals(td, td),
      await r.collectionTotals(),
      await r.expenseTotal(td, td),
      await r.expenseTotal(),
      await r.dailySummaryRows(start, td),
      await r.recentCollections(),
      await r.recentExpenses(),
    );
  }

  @override
  Widget build(BuildContext context) => Loader<_Dash>(
        loader: _load,
        builder: (context, d) {
          final td = today();
          final start = td.subtract(const Duration(days: 6));
          final days = [for (var i = 0; i < 7; i++) start.add(Duration(days: i))];
          final byDay = {for (final r in d.week) isoDate(r.date): r};
          final series = [for (final x in days) byDay[isoDate(x)] ?? DayRow(x, 0, 0, 0, 0)];
          final remToday = d.t.total - d.expToday;
          final remAll = d.all.total - d.expAll;

          return PageBody([
            Wrap(spacing: 10, runSpacing: 10, children: [
              GlassButton(
                onPressed: () => onGo(1),
                icon: Icons.add_circle_outline,
                accentColor: AppColors.total,
                isPrimary: true,
                child: const Text('Add collection'),
              ),
              GlassButton(
                onPressed: () => onGo(4),
                icon: Icons.account_balance_wallet_outlined,
                accentColor: AppColors.expenses,
                child: const Text('Add expense'),
              ),
              GlassButton(
                onPressed: () => onGo(3),
                icon: Icons.bar_chart,
                accentColor: AppColors.gpay,
                child: const Text('Today’s analysis'),
              ),
              GlassButton(
                onPressed: () => onGo(5),
                icon: Icons.payments_outlined,
                accentColor: AppColors.remaining,
                child: const Text('Daily money'),
              ),
            ]),
            SectionTitle('Today — ${dmy(td)}'),
            CardGrid([
              StatCard('Cash collection', inr(d.t.cash), Icons.payments, AppColors.cash),
              StatCard('Gpay/cheque/CN collection', inr(d.t.gpay + d.t.cheque), Icons.account_balance, AppColors.gpay),
              StatCard('Total collection', inr(d.t.total), Icons.monetization_on_outlined, AppColors.total,
                  sub: '${d.t.count} transaction${d.t.count == 1 ? '' : 's'}'),
              StatCard('Total expenses', inr(d.expToday), Icons.receipt_long, AppColors.expenses),
              StatCard('Remaining cash', inr(d.t.cash - d.expToday), Icons.account_balance_wallet_outlined,
                  d.t.cash - d.expToday >= 0 ? AppColors.cash : AppColors.expenses,
                  sub: 'Cash − expenses'),
              StatCard('Total remaining', inr(remToday), Icons.savings_outlined, remToday >= 0 ? AppColors.cash : AppColors.expenses,
                  sub: 'Total collection − expenses'),
            ]),
            const SectionTitle('All dates'),
            CardGrid([
              StatCard('Total collection', inr(d.all.total), Icons.monetization_on_outlined, AppColors.total, sub: '${d.all.count} transactions'),
              StatCard('Total expenses', inr(d.expAll), Icons.receipt_long, AppColors.expenses),
              StatCard('Overall remaining balance', inr(remAll), Icons.savings_outlined, remAll >= 0 ? AppColors.cash : AppColors.expenses),
            ], minWidth: 300),
            const SectionTitle('Last 7 days — collection by payment method, with expenses'),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: d.all.count == 0 && d.expAll == 0
                  ? const EmptyState('No data yet. Add your first collection to see charts.', icon: Icons.bar_chart)
                  : BarsChart(
                      labels: [for (final x in days) shortDay(x)],
                      bars: [
                        Series('Cash', AppColors.cash, [for (final r in series) r.cash]),
                        Series('Gpay/cheque/CN', AppColors.gpay, [for (final r in series) r.gpay + r.cheque]),
                      ],
                      line: Series('Expenses', AppColors.expenses, [for (final r in series) r.expenses]),
                    ),
            ),
            const SectionTitle('All-time collection by payment method'),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: d.all.total == 0
                  ? const EmptyState('Nothing collected yet.', icon: Icons.pie_chart_outline)
                  : DoughnutChart(
                      labels: const ['Cash', 'Gpay/cheque/CN'],
                      paise: [d.all.cash, d.all.gpay + d.all.cheque],
                      colors: const [AppColors.cash, AppColors.gpay],
                    ),
            ),
            SectionTitle('Recent collections', trailing: TextButton(onPressed: () => onGo(2), child: const Text('View all', style: TextStyle(color: AppColors.total)))),
            GlassCard(
              padding: EdgeInsets.zero,
              child: d.recent.isEmpty
                  ? const EmptyState('No collections yet.')
                  : Column(children: [
                      for (var i = 0; i < d.recent.length; i++) ...[
                        ListTile(
                          dense: true,
                          title: Text('${d.recent[i].receiptNumber} · ${d.recent[i].shopName}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          subtitle: Text(dmy(d.recent[i].date), style: const TextStyle(color: AppColors.textSecondary)),
                          trailing: Text(inr(d.recent[i].total), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.total)),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(collectionId: d.recent[i].id!))),
                        ),
                        if (i < d.recent.length - 1) Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                      ],
                    ]),
            ),
            SectionTitle('Recent expenses', trailing: TextButton(onPressed: () => onGo(4), child: const Text('View all', style: TextStyle(color: AppColors.total)))),
            GlassCard(
              padding: EdgeInsets.zero,
              child: d.recentExp.isEmpty
                  ? const EmptyState('No expenses yet.')
                  : Column(children: [
                      for (var i = 0; i < d.recentExp.length; i++) ...[
                        ListTile(
                          dense: true,
                          title: Text('${d.recentExp[i].category} · ${d.recentExp[i].description}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          subtitle: Text('${d.recentExp[i].displayId} · ${dmy(d.recentExp[i].date)}', style: const TextStyle(color: AppColors.textSecondary)),
                          trailing: Text(inr(d.recentExp[i].amount), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.expenses)),
                        ),
                        if (i < d.recentExp.length - 1) Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                      ],
                    ]),
            ),
            const SizedBox(height: 24),
          ]);
        },
      );
}
