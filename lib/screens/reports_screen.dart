import 'package:flutter/material.dart';

import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../widgets/common.dart';
import '../widgets/filter_bar.dart';
import 'report_export.dart';

class _R {
  final List<MedicalShop> shops;
  final List<String> categories;
  final Report? report;
  final Totals? totals;
  final int expenseTotal;
  _R(this.shops, this.categories, this.report, {this.totals, this.expenseTotal = 0});
}

/// On-screen reports + CSV export. Both use the same filters.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _kind;
  Filters _f = const Filters();

  Future<_R> _load() async {
    final r = Repository.instance;
    Report? report;
    Totals? totals;
    int expTotal = 0;
    if (_kind != null) {
      report = await r.buildReport(_kind!, _f);
      if (_kind == 'collection_notes') {
        int c = 0, g = 0;
        for (final row in report.rows) {
          if (row.length > 5) {
            if (row[4] is Money) c += (row[4] as Money).paise;
            if (row[5] is Money) g += (row[5] as Money).paise;
          }
        }
        totals = Totals(c, g, 0, report.rows.length);
        expTotal = await r.expenseTotal(_f.dateFrom, _f.dateTo);
      } else if (_kind != 'expenses') {
        totals = await r.totalsFor(_f);
        expTotal = await r.expenseTotal(_f.dateFrom, _f.dateTo);
      } else {
        expTotal = await r.expenseTotal(_f.dateFrom, _f.dateTo, _f.category);
      }
    }
    return _R(await r.shops(), await r.categoryNames(), report, totals: totals, expenseTotal: expTotal);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Loader<_R>(
        deps: (_kind, _f.q, _f.dateFrom, _f.dateTo, _f.shopId, _f.category, _f.method),
        loader: _load,
        builder: (context, d) {
          final isExpense = _kind == 'expenses';
          final isCollection = _kind != null && !isExpense && _kind != 'daily_balance';
          return PageBody([
            GlassCard(
              padding: const EdgeInsets.all(14),
              child: DropdownButtonFormField<String>(
                initialValue: _kind,
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                decoration: const InputDecoration(labelText: 'Choose a report', prefixIcon: Icon(Icons.assessment_outlined)),
                items: [for (final e in reportTitles.entries) DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis))],
                onChanged: (v) => setState(() => _kind = v),
              ),
            ),
            if (_kind != null) ...[
              const SizedBox(height: 12),
              FilterBar(
                value: _f,
                shops: d.shops,
                categories: d.categories,
                showSearch: _kind == 'date_range' || _kind == 'collection_notes' || isExpense,
                showShop: isCollection,
                showMethod: _kind == 'date_range' || _kind == 'collection_notes',
                showCategory: isExpense,
                onChanged: (f) => setState(() => _f = f),
              ),
            ],
            if (d.report == null)
              const Padding(padding: EdgeInsets.only(top: 30), child: EmptyState('Pick a report above to see it here.', icon: Icons.description_outlined))
            else ...[
              SectionTitle(d.report!.title),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      onPressed: () => exportReportPdf(context, _kind!, _f),
                      icon: Icons.picture_as_pdf_outlined,
                      accentColor: AppColors.total,
                      isPrimary: true,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: const Text('Export PDF', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GlassButton(
                      onPressed: () => printReportPdf(context, _kind!, _f),
                      icon: Icons.print_outlined,
                      accentColor: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                      isPrimary: false,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: const Text('Print', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GlassButton(
                      onPressed: () => exportReport(context, _kind!, _f),
                      icon: Icons.table_chart_outlined,
                      accentColor: AppColors.cash,
                      isPrimary: false,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      child: const Text('Export Excel', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              if (_kind != null && _kind != 'expenses' && d.totals != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: MiniStatCard(
                        label: 'Total cash collected',
                        value: inr(d.totals!.cash),
                        icon: Icons.payments_outlined,
                        iconColor: const Color(0xFF10B981),
                        iconBg: const Color(0xFFE8F8F0),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: MiniStatCard(
                        label: 'Gpay/NEFT/Others',
                        value: inr(d.totals!.gpay + d.totals!.cheque),
                        icon: Icons.account_balance_outlined,
                        iconColor: const Color(0xFF3B82F6),
                        iconBg: const Color(0xFFEFF6FF),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TotalCollectionCard(
                  amount: inr(d.totals!.total),
                  subtext: '${d.totals!.count} record${d.totals!.count == 1 ? '' : 's'} found',
                ),
              ] else if (_kind == 'expenses') ...[
                const SizedBox(height: 12),
                HeroStatCard(
                  amount: inr(d.expenseTotal),
                  title: 'Total expenses',
                  icon: Icons.receipt_long_outlined,
                  gradientColors: const [Color(0xFFDC2626), Color(0xFFEF4444)],
                  subtext: '${d.report?.rows.length ?? 0} expense record${(d.report?.rows.length ?? 0) == 1 ? '' : 's'}',
                ),
              ],
              const SizedBox(height: 12),
              GlassCard(
                padding: const EdgeInsets.all(8),
                child: d.report!.rows.isEmpty
                    ? const EmptyState('No data for these filters.')
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 48,
                          dataRowMinHeight: 44,
                          dataRowMaxHeight: 52,
                          headingTextStyle: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                          ),
                          dataTextStyle: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          ),
                          columns: [
                            for (final h in d.report!.headers)
                              DataColumn(
                                label: Text(
                                  h,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFFF8FAFC) : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                          ],
                          rows: [
                            for (final r in d.report!.rows)
                              DataRow(
                                cells: [
                                  for (var i = 0; i < r.length; i++)
                                    DataCell(
                                      Builder(
                                        builder: (context) {
                                          final cellStr = Report.cell(r[i]);
                                          final isDash = cellStr == '-' || cellStr == ' - ';
                                          final isNotesCol = i < d.report!.headers.length && d.report!.headers[i] == 'Notes';
                                          TextStyle style;
                                          if (isNotesCol && !isDash) {
                                            style = const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFFDC2626),
                                            );
                                          } else if (isDash) {
                                            style = TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            );
                                          } else {
                                            style = TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                            );
                                          }
                                          return Text(cellStr, style: style);
                                        },
                                      ),
                                    ),
                                ],
                              ),
                            if (d.report!.footer != null)
                              DataRow(
                                color: WidgetStatePropertyAll(AppColors.total.withValues(alpha: isDark ? 0.25 : 0.15)),
                                cells: [
                                  for (var i = 0; i < d.report!.footer!.length; i++)
                                    DataCell(Text(
                                      Report.cell(d.report!.footer![i]),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        color: (Report.cell(d.report!.footer![i]) == '-' || Report.cell(d.report!.footer![i]) == ' - ')
                                            ? (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))
                                            : (((_kind == 'date_range' || _kind == 'collection_notes') && i >= 4 && i <= 6)
                                                ? const Color(0xFF0D9488)
                                                : (isDark ? const Color(0xFF38BDF8) : AppColors.total)),
                                      ),
                                    )),
                                ],
                              ),
                          ],
                        ),
                      ),
              ),
            ],
            const SizedBox(height: 24),
          ]);
        },
      );
  }
}
