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
  Widget build(BuildContext context) => Loader<_R>(
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
                dropdownColor: Colors.white,
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
              SectionTitle(
                d.report!.title,
                trailing: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    GlassButton(
                      onPressed: () => exportReportPdf(context, _kind!, _f),
                      icon: Icons.picture_as_pdf_outlined,
                      accentColor: AppColors.total,
                      isPrimary: true,
                      child: const Text('Export PDF'),
                    ),
                    GlassButton(
                      onPressed: () => exportReport(context, _kind!, _f),
                      icon: Icons.table_chart_outlined,
                      accentColor: AppColors.cash,
                      isPrimary: false,
                      child: const Text('Export CSV'),
                    ),
                  ],
                ),
              ),
              GlassCard(
                padding: const EdgeInsets.all(8),
                child: d.report!.rows.isEmpty
                    ? const EmptyState('No data for these filters.')
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 44,
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 46,
                          headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                          dataTextStyle: const TextStyle(color: AppColors.textPrimary),
                          columns: [for (final h in d.report!.headers) DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.w700)))],
                          rows: [
                            for (final r in d.report!.rows) DataRow(cells: [for (final v in r) DataCell(Text(Report.cell(v)))]),
                            if (d.report!.footer != null)
                              DataRow(
                                color: WidgetStatePropertyAll(AppColors.total.withValues(alpha: 0.15)),
                                cells: [
                                  for (final v in d.report!.footer!)
                                    DataCell(Text(
                                      Report.cell(v),
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.total),
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
