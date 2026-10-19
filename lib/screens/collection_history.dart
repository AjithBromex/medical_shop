import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/filter_bar.dart';
import 'collection_form.dart';
import 'receipt_screen.dart';
import 'report_export.dart';

const pageSize = 25;

class CollectionHistory extends StatefulWidget {
  const CollectionHistory({super.key});
  @override
  State<CollectionHistory> createState() => _CollectionHistoryState();
}

class _H {
  final List<Collection> rows;
  final Totals totals;
  final List<MedicalShop> shops;
  _H(this.rows, this.totals, this.shops);
}

class _CollectionHistoryState extends State<CollectionHistory> {
  Filters _f = const Filters();
  int _page = 1;

  Future<_H> _load() async {
    final r = Repository.instance;
    final totals = await r.totalsFor(_f);
    final pages = (totals.count / pageSize).ceil().clamp(1, 1 << 30);
    if (_page > pages) _page = pages;
    return _H(await r.collections(_f, limit: pageSize, offset: (_page - 1) * pageSize), totals, await r.shops());
  }

  @override
  Widget build(BuildContext context) => Loader<_H>(
        loader: _load,
        deps: (_f.q, _f.dateFrom, _f.dateTo, _f.shopId, _f.method, _page),
        builder: (context, h) {
          final pages = (h.totals.count / pageSize).ceil().clamp(1, 1 << 30);
          return PageBody([
            FilterBar(
              value: _f,
              shops: h.shops,
              showShop: true,
              showMethod: true,
              searchHint: 'Receipt no. or shop',
              onChanged: (f) => setState(() { _f = f; _page = 1; }),
            ),
            const SizedBox(height: 12),
            CardGrid([
              StatCard('Cash', inr(h.totals.cash), Icons.payments, AppColors.cash),
              StatCard('Gpay/cheque/CN', inr(h.totals.gpay + h.totals.cheque), Icons.account_balance, AppColors.gpay),
              StatCard('Total', inr(h.totals.total), Icons.monetization_on_outlined, AppColors.total, sub: '${h.totals.count} records'),
            ], minWidth: 200),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  GlassButton(
                    onPressed: () => exportReportPdf(context, 'date_range', _f),
                    icon: Icons.picture_as_pdf_outlined,
                    accentColor: AppColors.total,
                    isPrimary: true,
                    child: const Text('Export PDF'),
                  ),
                  GlassButton(
                    onPressed: () => exportReport(context, 'date_range', _f),
                    icon: Icons.table_chart_outlined,
                    accentColor: AppColors.cash,
                    child: const Text('Export CSV'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              padding: EdgeInsets.zero,
              child: h.rows.isEmpty
                  ? const EmptyState('No collections match these filters.', icon: Icons.menu_book_outlined)
                  : Column(children: [
                      for (final c in h.rows) ...[
                        ListTile(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(collectionId: c.id!))),
                          title: Text('${c.receiptNumber} · ${c.shopName}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                          subtitle: Text(
                            '${dmy(c.date)}\nCash ${inr(c.cash)} · Gpay/cheque/CN ${inr(c.gpay + c.cheque)}'
                            '${c.notes == null ? '' : '\n${c.notes}'}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          isThreeLine: true,
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(inr(c.total), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.total)),
                            IconButton(
                              tooltip: 'Receipt PDF',
                              icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppColors.total),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(collectionId: c.id!))),
                            ),
                            PopupMenuButton<String>(
                              iconColor: AppColors.textSecondary,
                              onSelected: (v) async {
                                if (v == 'receipt') {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(collectionId: c.id!)));
                                } else if (v == 'edit') {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionForm(existing: c)));
                                } else if (v == 'delete') {
                                  await showConfirmDelete(context, 'collection ${c.receiptNumber}', () async {
                                    await Repository.instance.deleteCollection(c.id!);
                                    if (context.mounted) {
                                      context.read<AppState>().changed();
                                      toast(context, 'Collection ${c.receiptNumber} deleted.');
                                    }
                                  });
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'receipt', child: Text('Receipt / PDF')),
                                PopupMenuItem(value: 'edit', child: Text('Edit')),
                                PopupMenuItem(value: 'delete', child: Text('Delete')),
                              ],
                            ),
                          ]),
                        ),
                        Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
                      ],
                    ]),
            ),
            Pager(page: _page, pages: pages, onPage: (p) => setState(() => _page = p)),
            const SizedBox(height: 24),
          ]);
        },
      );
}
