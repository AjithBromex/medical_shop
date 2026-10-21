import 'package:flutter/material.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/filter_bar.dart';

/// Collection Analysis: "Today / chosen day" and "All dates" tabs.
class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: GlassContainer(
            blur: 0,
            borderRadius: BorderRadius.circular(14),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : AppColors.border,
              width: 1.2,
            ),
            child: TabBar(
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: const Color(0xFF0284C7),
                borderRadius: BorderRadius.circular(12),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [Tab(text: 'Today'), Tab(text: 'All dates')],
            ),
          ),
        ),
        const Expanded(child: TabBarView(children: [_DayTab(), _AllTab()])),
      ]),
    );
  }
}

Widget _totalsGrid(Totals t) => Column(
      children: [
        Row(
          children: [
            Expanded(
              child: MiniStatCard(
                label: 'Cash collection',
                value: inr(t.cash),
                icon: Icons.payments_outlined,
                iconColor: const Color(0xFF10B981),
                iconBg: const Color(0xFFE8F5E9),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MiniStatCard(
                label: 'Gpay/cheque/CN',
                value: inr(t.gpay + t.cheque),
                icon: Icons.account_balance_outlined,
                iconColor: const Color(0xFF3B82F6),
                iconBg: const Color(0xFFEFF6FF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        WideStatCard.totalCollection(
          value: inr(t.total),
          sub: '${t.count} transaction${t.count == 1 ? '' : 's'}',
        ),
      ],
    );

Widget _shopChart(List<ShopBreakdown> rows) => rows.isEmpty
    ? const EmptyState('No collections for this selection.', icon: Icons.bar_chart)
    : BarsChart(
        labels: [for (final r in rows) r.name],
        bars: [
          Series('Cash', AppColors.cash, [for (final r in rows) r.cash]),
          Series('Gpay/cheque/CN', AppColors.gpay, [for (final r in rows) r.gpay + r.cheque]),
        ],
      );

Widget _shopTable(BuildContext context, List<ShopBreakdown> rows) {
  if (rows.isEmpty) return const SizedBox.shrink();
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final textColor = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
  final subTextColor = isDark ? const Color(0xFF94A3B8) : AppColors.textMuted;
  final totalColor = isDark ? const Color(0xFF38BDF8) : AppColors.total;

  return GlassCard(
    padding: const EdgeInsets.all(8),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 46,
        dataRowMinHeight: 44,
        dataRowMaxHeight: 50,
        headingTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor),
        dataTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor),
        columns: [
          DataColumn(label: Text('Medical shop', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor))),
          DataColumn(label: Text('Txns', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
          DataColumn(label: Text('Cash', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
          DataColumn(label: Text('Gpay/cheque/CN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
        ],
        rows: [
          for (final r in rows)
            DataRow(cells: [
              DataCell(Text(r.name + (r.active ? '' : ' (inactive)'), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: r.active ? textColor : subTextColor))),
              DataCell(Text('${r.count}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor))),
              DataCell(Text(inr(r.cash), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor))),
              DataCell(Text(inr(r.gpay + r.cheque), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor))),
              DataCell(Text(inr(r.total), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: totalColor))),
            ]),
        ],
      ),
    ),
  );
}

class _DayTab extends StatefulWidget {
  const _DayTab();
  @override
  State<_DayTab> createState() => _DayTabState();
}

class _DayTabState extends State<_DayTab> with AutomaticKeepAliveClientMixin {
  DateTime _day = today();
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Loader<(Totals, List<ShopBreakdown>)>(
      deps: _day,
      loader: () async => (await Repository.instance.collectionTotals(_day, _day), await Repository.instance.shopBreakdown(_day, _day)),
      builder: (context, d) => PageBody([
        Center(child: DayNav(day: _day, onChanged: (x) => setState(() => _day = x))),
        const SizedBox(height: 8),
        _totalsGrid(d.$1),
        const SectionTitle('Shop-wise collection'),
        GlassCard(padding: const EdgeInsets.all(16), child: _shopChart(d.$2)),
        const SizedBox(height: 12),
        _shopTable(context, d.$2),
        const SizedBox(height: 24),
      ]),
    );
  }
}

class _AllData {
  final Totals totals;
  final List<ShopBreakdown> shops;
  final List<PeriodRow> daily, weekly, monthly;
  final List<MedicalShop> allShops;
  _AllData(this.totals, this.shops, this.daily, this.weekly, this.monthly, this.allShops);
}

class _AllTab extends StatefulWidget {
  const _AllTab();
  @override
  State<_AllTab> createState() => _AllTabState();
}

class _AllTabState extends State<_AllTab> with AutomaticKeepAliveClientMixin {
  Filters _f = const Filters();
  String _period = 'daily';
  @override
  bool get wantKeepAlive => true;

  Future<_AllData> _load() async {
    final r = Repository.instance;
    return _AllData(
      await r.collectionTotals(_f.dateFrom, _f.dateTo, _f.shopId),
      await r.shopBreakdown(_f.dateFrom, _f.dateTo, _f.shopId),
      await r.periodBreakdown('daily', from: _f.dateFrom, to: _f.dateTo, shopId: _f.shopId, limit: 90),
      await r.periodBreakdown('weekly', from: _f.dateFrom, to: _f.dateTo, shopId: _f.shopId, limit: 104),
      await r.periodBreakdown('monthly', from: _f.dateFrom, to: _f.dateTo, shopId: _f.shopId, limit: 12),
      await r.shops(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Loader<_AllData>(
      deps: (_f.dateFrom, _f.dateTo, _f.shopId),
      loader: _load,
      builder: (context, d) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final rows = switch (_period) { 'weekly' => d.weekly, 'monthly' => d.monthly, _ => d.daily };
        final monthlyAsc = d.monthly.reversed.toList();
        return PageBody([
          FilterBar(value: _f, shops: d.allShops, showSearch: false, showShop: true, onChanged: (f) => setState(() => _f = f)),
          const SizedBox(height: 12),
          _totalsGrid(d.totals),
          const SectionTitle('Shop-wise collection'),
          GlassCard(padding: const EdgeInsets.all(16), child: _shopChart(d.shops)),
          const SizedBox(height: 12),
          _shopTable(context, d.shops),
          const SectionTitle('Monthly collection (last 12 months)'),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: monthlyAsc.isEmpty
                ? const EmptyState('No data.', icon: Icons.bar_chart)
                : BarsChart(
                    labels: [for (final m in monthlyAsc) m.label],
                    bars: [
                      Series('Cash', AppColors.cash, [for (final m in monthlyAsc) m.cash]),
                      Series('Gpay/cheque/CN', AppColors.gpay, [for (final m in monthlyAsc) m.gpay + m.cheque]),
                    ],
                  ),
          ),
          SectionTitle('Breakdown', trailing: SegmentedButton<String>(
            showSelectedIcon: false,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return isDark
                      ? const Color(0xFF0284C7).withValues(alpha: 0.35)
                      : AppColors.total.withValues(alpha: 0.15);
                }
                return isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.8)
                    : Colors.white.withValues(alpha: 0.8);
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return isDark ? const Color(0xFF38BDF8) : AppColors.total;
                }
                return isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary;
              }),
              textStyle: WidgetStateProperty.resolveWith((states) {
                final isSelected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                );
              }),
              side: WidgetStatePropertyAll(
                BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 1.2,
                ),
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              ),
            ),
            segments: const [
              ButtonSegment(value: 'daily', label: Text('Daily')),
              ButtonSegment(value: 'weekly', label: Text('Weekly')),
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          )),
          Builder(builder: (context) {
            final textColor = isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary;
            final totalColor = isDark ? const Color(0xFF38BDF8) : AppColors.total;

            return GlassCard(
              padding: const EdgeInsets.all(8),
              child: rows.isEmpty
                  ? const EmptyState('No data.')
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowHeight: 46,
                        dataRowMinHeight: 44,
                        dataRowMaxHeight: 50,
                        headingTextStyle: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor),
                        dataTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor),
                        columns: [
                          DataColumn(label: Text('Period', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor))),
                          DataColumn(label: Text('Txns', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
                          DataColumn(label: Text('Cash', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
                          DataColumn(label: Text('Gpay/cheque/CN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
                          DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: textColor)), numeric: true),
                        ],
                        rows: [
                          for (final r in rows)
                            DataRow(cells: [
                              DataCell(Text(r.label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor))),
                              DataCell(Text('${r.count}', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor))),
                              DataCell(Text(inr(r.cash), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor))),
                              DataCell(Text(inr(r.gpay + r.cheque), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: textColor))),
                              DataCell(Text(inr(r.total), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: totalColor))),
                            ]),
                        ],
                      ),
                    ),
            );
          }),
          const SizedBox(height: 24),
        ]);
      },
    );
  }
}
