import 'package:flutter/material.dart';

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
  _R(this.shops, this.categories, this.report);
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
    return _R(await r.shops(), await r.categoryNames(), _kind == null ? null : await r.buildReport(_kind!, _f));
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
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                decoration: const InputDecoration(labelText: 'Choose a report', prefixIcon: Icon(Icons.assessment_outlined)),
                items: [for (final e in reportTitles.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                onChanged: (v) => setState(() => _kind = v),
              ),
            ),
            if (_kind != null) ...[
              const SizedBox(height: 12),
              FilterBar(
                value: _f,
                shops: d.shops,
                categories: d.categories,
                showSearch: _kind == 'date_range' || isExpense,
                showShop: isCollection,
                showMethod: _kind == 'date_range',
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
                                  for (final v in r)
                                    DataCell(
                                      Text(
                                        Report.cell(v),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            if (d.report!.footer != null)
                              DataRow(
                                color: WidgetStatePropertyAll(AppColors.total.withValues(alpha: isDark ? 0.25 : 0.15)),
                                cells: [
                                  for (final v in d.report!.footer!)
                                    DataCell(Text(
                                      Report.cell(v),
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFF38BDF8) : AppColors.total),
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
