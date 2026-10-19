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
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: GlassContainer(
              blur: 0,
              borderRadius: BorderRadius.circular(14),
              color: Colors.white,
              border: Border.all(color: AppColors.border, width: 1.2),
              child: TabBar(
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  color: AppColors.total.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.total.withValues(alpha: 0.4), width: 1.2),
                ),
                labelColor: AppColors.total,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                tabs: const [Tab(text: 'Today'), Tab(text: 'All dates')],
              ),
            ),
          ),
          const Expanded(child: TabBarView(children: [_DayTab(), _AllTab()])),
        ]),
      );
}

Widget _totalsGrid(Totals t) => CardGrid([
      StatCard('Cash', inr(t.cash), Icons.payments, AppColors.cash),
      StatCard('Gpay/cheque/CN', inr(t.gpay + t.cheque), Icons.account_balance, AppColors.gpay),
      StatCard('Total collection', inr(t.total), Icons.monetization_on_outlined, AppColors.total,
          sub: '${t.count} transaction${t.count == 1 ? '' : 's'}'),
    ], minWidth: 220);

Widget _shopChart(List<ShopBreakdown> rows) => rows.isEmpty
    ? const EmptyState('No collections for this selection.', icon: Icons.bar_chart)
    : BarsChart(
        labels: [for (final r in rows) r.name],
        bars: [
          Series('Cash', AppColors.cash, [for (final r in rows) r.cash]),
          Series('Gpay/cheque/CN', AppColors.gpay, [for (final r in rows) r.gpay + r.cheque]),
        ],
      );

Widget _shopTable(List<ShopBreakdown> rows) => rows.isEmpty
    ? const SizedBox.shrink()
    : GlassCard(
        padding: const EdgeInsets.all(8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 44,
            dataRowMinHeight: 40,
            dataRowMaxHeight: 46,
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            dataTextStyle: const TextStyle(color: AppColors.textPrimary),
            columns: const [
              DataColumn(label: Text('Medical shop')),
              DataColumn(label: Text('Txns'), numeric: true),
              DataColumn(label: Text('Cash'), numeric: true),
              DataColumn(label: Text('Gpay/cheque/CN'), numeric: true),
              DataColumn(label: Text('Total'), numeric: true),
            ],
            rows: [
              for (final r in rows)
                DataRow(cells: [
                  DataCell(Text(r.name + (r.active ? '' : ' (inactive)'), style: TextStyle(color: r.active ? AppColors.textPrimary : AppColors.textMuted))),
                  DataCell(Text('${r.count}')),
                  DataCell(Text(inr(r.cash))),
                  DataCell(Text(inr(r.gpay + r.cheque))),
                  DataCell(Text(inr(r.total), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.total))),
                ]),
            ],
          ),
        ),
      );

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
        _shopTable(d.$2),
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
        final rows = switch (_period) { 'weekly' => d.weekly, 'monthly' => d.monthly, _ => d.daily };
        final monthlyAsc = d.monthly.reversed.toList();
        return PageBody([
          FilterBar(value: _f, shops: d.allShops, showSearch: false, showShop: true, onChanged: (f) => setState(() => _f = f)),
          const SizedBox(height: 12),
          _totalsGrid(d.totals),
          const SectionTitle('Shop-wise collection'),
          GlassCard(padding: const EdgeInsets.all(16), child: _shopChart(d.shops)),
          const SizedBox(height: 12),
          _shopTable(d.shops),
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
            style: SegmentedButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.05),
              selectedBackgroundColor: AppColors.total.withValues(alpha: 0.3),
              foregroundColor: AppColors.textSecondary,
              selectedForegroundColor: AppColors.total,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
            ),
            segments: const [
              ButtonSegment(value: 'daily', label: Text('Daily')),
              ButtonSegment(value: 'weekly', label: Text('Weekly')),
              ButtonSegment(value: 'monthly', label: Text('Monthly')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() => _period = s.first),
          )),
          GlassCard(
            padding: const EdgeInsets.all(8),
            child: rows.isEmpty
                ? const EmptyState('No data.')
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 44,
                      dataRowMinHeight: 40,
                      dataRowMaxHeight: 46,
                      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      dataTextStyle: const TextStyle(color: AppColors.textPrimary),
                      columns: const [
                        DataColumn(label: Text('Period')),
                        DataColumn(label: Text('Txns'), numeric: true),
                        DataColumn(label: Text('Cash'), numeric: true),
                        DataColumn(label: Text('Gpay/cheque/CN'), numeric: true),
                        DataColumn(label: Text('Total'), numeric: true),
                      ],
                      rows: [
                        for (final r in rows)
                          DataRow(cells: [
                            DataCell(Text(r.label)),
                            DataCell(Text('${r.count}')),
                            DataCell(Text(inr(r.cash))),
                            DataCell(Text(inr(r.gpay + r.cheque))),
                            DataCell(Text(inr(r.total), style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.total))),
                          ]),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 24),
        ]);
      },
    );
  }
}
