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
            const SizedBox(height: 12),

            // 1. Hero Banner: Remaining Cash
            HeroStatCard(
              amount: inr(d.t.cash - d.expenses),
              title: 'Remaining cash',
              subtext: 'Cash (${inr(d.t.cash)}) − Expenses (${inr(d.expenses)})',
              badgeText: 'CURRENT\nBALANCE',
            ),
            const SizedBox(height: 12),

            // 2. Row of 2: Cash & Gpay/NEFT/Others
            Row(
              children: [
                Expanded(
                  child: MiniStatCard(
                    label: 'Cash collection',
                    value: inr(d.t.cash),
                    icon: Icons.payments_outlined,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFFE8F5E9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MiniStatCard(
                    label: 'Gpay/NEFT/Others',
                    value: inr(d.t.gpay + d.t.cheque),
                    icon: Icons.account_balance_outlined,
                    iconColor: const Color(0xFF3B82F6),
                    iconBg: const Color(0xFFEFF6FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Full Width: Total Collection (Matching Home Page)
            WideStatCard.totalCollection(
              value: inr(d.t.total),
              sub: '${d.t.count} transaction${d.t.count == 1 ? '' : 's'}',
            ),
            const SizedBox(height: 12),

            // 4. Row of 2: Total expenses & Total remaining
            Row(
              children: [
                Expanded(
                  child: MiniStatCard(
                    label: 'Total expenses',
                    value: inr(d.expenses),
                    icon: Icons.confirmation_number_outlined,
                    iconColor: const Color(0xFFF43F5E),
                    iconBg: const Color(0xFFFFE4E6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MiniStatCard(
                    label: 'Total remaining',
                    value: inr(d.remaining),
                    sub: 'Total − expenses',
                    icon: Icons.savings_outlined,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFFE8F5E9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (d.cats.isNotEmpty) ...[
              const SectionTitle('Expenses on this day'),
              const SizedBox(height: 10),
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < d.cats.length; i++) ...[
                    ListTile(
                      dense: true,
                      leading: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE4E6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.confirmation_number_outlined, color: Color(0xFFF43F5E), size: 18),
                      ),
                      title: Text(
                        d.cats[i].category,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFFF8FAFC)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: Text(
                        '${d.cats[i].count} entr${d.cats[i].count == 1 ? 'y' : 'ies'}',
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      trailing: Text(inr(d.cats[i].total), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFFE11D48), fontSize: 15)),
                    ),
                    if (i < d.cats.length - 1)
                      Divider(
                        height: 1,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                  ],
                ]),
              ),
              const SizedBox(height: 18),
            ],

            const SectionTitle('Daily history'),
            const SizedBox(height: 10),
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 500;
                if (isWide) {
                  return Row(children: [
                    Expanded(child: DateField(label: 'From', value: _from, onChanged: (v) => setState(() => _from = v ?? _from))),
                    const SizedBox(width: 14),
                    Expanded(child: DateField(label: 'To', value: _to, onChanged: (v) => setState(() => _to = v ?? _to))),
                  ]);
                } else {
                  return Column(children: [
                    DateField(label: 'From', value: _from, onChanged: (v) => setState(() => _from = v ?? _from)),
                    const SizedBox(height: 12),
                    DateField(label: 'To', value: _to, onChanged: (v) => setState(() => _to = v ?? _to)),
                  ]);
                }
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: MiniStatCard(
                    label: 'Range collection',
                    value: inr(rangeTotal),
                    icon: Icons.monetization_on_outlined,
                    iconColor: const Color(0xFF0284C7),
                    iconBg: const Color(0xFFE0F2FE),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MiniStatCard(
                    label: 'Range expenses',
                    value: inr(rangeExp),
                    icon: Icons.confirmation_number_outlined,
                    iconColor: const Color(0xFFF43F5E),
                    iconBg: const Color(0xFFFFE4E6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            WideStatCard(
              label: 'Range remaining',
              value: inr(rangeTotal - rangeExp),
              sub: 'Total collection − Total expenses',
              icon: Icons.savings_outlined,
              iconColor: rangeTotal - rangeExp >= 0 ? const Color(0xFF10B981) : const Color(0xFFF43F5E),
              iconBg: rangeTotal - rangeExp >= 0 ? const Color(0xFFE8F5E9) : const Color(0xFFFFE4E6),
            ),
            const SizedBox(height: 16),
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
                  : Builder(builder: (context) {
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      final textColor = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
                      final totalColor = isDark ? const Color(0xFF38BDF8) : AppColors.total;
                      final cashColor = isDark ? const Color(0xFF34D399) : AppColors.cash;
                      final expColor = isDark ? const Color(0xFFFB7185) : AppColors.expenses;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          showCheckboxColumn: false,
                          headingRowHeight: 46,
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: 50,
                          headingTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor),
                          dataTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor),
                          columns: [
                            DataColumn(label: Text('Date', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor))),
                            DataColumn(label: Text('Cash', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
                            DataColumn(label: Text('Expenses', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
                            DataColumn(label: Text('Remaining Cash\n(Cash − Exp)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
                            DataColumn(label: Text('Gpay/NEFT/Others', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
                            DataColumn(label: Text('Total Collection', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
                            DataColumn(label: Text('Total Remaining', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
                          ],
                          rows: [
                            for (final r in d.history)
                              DataRow(
                                onSelectChanged: (_) => setState(() => _day = r.date),
                                cells: [
                                  DataCell(Text(dmy(r.date), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor))),
                                  DataCell(Text(inr(r.cash), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor))),
                                  DataCell(Text(inr(r.expenses), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: expColor))),
                                  DataCell(Text(inr(r.remainingCash),
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: r.remainingCash < 0 ? expColor : cashColor))),
                                  DataCell(Text(inr(r.gpay + r.cheque), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor))),
                                  DataCell(Text(inr(r.total), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: totalColor))),
                                  DataCell(Text(inr(r.remaining),
                                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: r.remaining < 0 ? expColor : totalColor))),
                                ],
                              ),
                          ],
                        ),
                      );
                    }),
            ),
            const SizedBox(height: 24),
          ]);
        },
      );
}
