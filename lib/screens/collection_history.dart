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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Loader<_H>(
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

            // 1. Stats Row matching Home Page
            Row(
              children: [
                Expanded(
                  child: MiniStatCard(
                    label: 'Cash collection',
                    value: inr(h.totals.cash),
                    icon: Icons.payments_outlined,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFFE8F5E9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MiniStatCard(
                    label: 'Gpay/cheque/CN',
                    value: inr(h.totals.gpay + h.totals.cheque),
                    icon: Icons.account_balance_outlined,
                    iconColor: const Color(0xFF3B82F6),
                    iconBg: const Color(0xFFEFF6FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            WideStatCard.totalCollection(
              value: inr(h.totals.total),
              sub: '${h.totals.count} record${h.totals.count == 1 ? '' : 's'} found',
            ),
            const SizedBox(height: 16),

            // 2. Section Header with Export Buttons
            SectionTitle(
              'Collections',
              trailing: Wrap(
                spacing: 8,
                children: [
                  GlassButton(
                    onPressed: () => exportReportPdf(context, 'date_range', _f),
                    icon: Icons.picture_as_pdf_outlined,
                    accentColor: AppColors.total,
                    isPrimary: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: const Text('PDF', style: TextStyle(fontSize: 12.5)),
                  ),
                  GlassButton(
                    onPressed: () => printReportPdf(context, 'date_range', _f),
                    icon: Icons.print_outlined,
                    accentColor: AppColors.textPrimary,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: const Text('Print', style: TextStyle(fontSize: 12.5)),
                  ),
                  GlassButton(
                    onPressed: () => exportReport(context, 'date_range', _f),
                    icon: Icons.table_chart_outlined,
                    accentColor: AppColors.cash,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: const Text('Excel', style: TextStyle(fontSize: 12.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // 3. Collection List Cards
            if (h.rows.isEmpty)
              const GlassCard(
                child: EmptyState('No collections match these filters.', icon: Icons.menu_book_outlined),
              )
            else
              GlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < h.rows.length; i++) ...[
                      InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(collectionId: h.rows[i].id!))),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0x330284C7) : const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.receipt_long_outlined, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7), size: 22),
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
                                            '${h.rows[i].receiptNumber} · ${h.rows[i].shopName}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      dmy(h.rows[i].date),
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: [
                                        if (h.rows[i].cash > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0x2E10B981) : const Color(0xFFE8F5E9),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Cash: ${inr(h.rows[i].cash)}',
                                              style: const TextStyle(
                                                color: Color(0xFF10B981),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        if (h.rows[i].gpay + h.rows[i].cheque > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0x333B82F6) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              'Online: ${inr(h.rows[i].gpay + h.rows[i].cheque)}',
                                              style: TextStyle(
                                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    if (h.rows[i].notes != null && h.rows[i].notes!.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        h.rows[i].notes!,
                                        style: TextStyle(
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          fontSize: 11.5,
                                          fontStyle: FontStyle.italic,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                    inr(h.rows[i].total),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  PopupMenuButton<String>(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: Icon(Icons.more_vert, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    onSelected: (v) async {
                                      if (v == 'receipt') {
                                        await Navigator.push(context, MaterialPageRoute(builder: (_) => ReceiptScreen(collectionId: h.rows[i].id!)));
                                      } else if (v == 'edit') {
                                        await Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionForm(existing: h.rows[i])));
                                      } else if (v == 'delete') {
                                        await showConfirmDelete(context, 'collection ${h.rows[i].receiptNumber}', () async {
                                          await Repository.instance.deleteCollection(h.rows[i].id!);
                                          if (context.mounted) {
                                            context.read<AppState>().changed();
                                            toast(context, 'Collection ${h.rows[i].receiptNumber} deleted.');
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
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < h.rows.length - 1)
                        Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ],
                  ],
                ),
              ),
            Pager(page: _page, pages: pages, onPage: (p) => setState(() => _page = p)),
            const SizedBox(height: 24),
          ]);
        },
      );
  }
}
