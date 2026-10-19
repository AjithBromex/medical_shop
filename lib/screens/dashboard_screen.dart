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
            SectionTitle('Today — ${dmy(td)}'),
            const SizedBox(height: 12),

            // 1. Hero Banner: Remaining Cash
            _HeroBalanceCard(
              amount: inr(d.t.cash - d.expToday),
              subtext: 'Cash – expenses',
              onTap: () => onGo(5),
            ),
            const SizedBox(height: 12),

            // 2. Row of 2: Cash collection & Gpay/cheque/CN
            Row(
              children: [
                Expanded(
                  child: _MiniStatCard(
                    label: 'Cash collection',
                    value: inr(d.t.cash),
                    icon: Icons.payments_outlined,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFFE8F5E9),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatCard(
                    label: 'Gpay/cheque/CN',
                    value: inr(d.t.gpay + d.t.cheque),
                    icon: Icons.account_balance_outlined,
                    iconColor: const Color(0xFF3B82F6),
                    iconBg: const Color(0xFFEFF6FF),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 3. Full Width: Total Collection
            _WideStatCard(
              label: 'Total collection',
              value: inr(d.t.total),
              sub: '${d.t.count} transaction${d.t.count == 1 ? '' : 's'}',
              icon: Icons.monetization_on_outlined,
              iconColor: const Color(0xFF0284C7),
              iconBg: const Color(0xFFE0F2FE),
              onTap: () => onGo(2),
            ),
            const SizedBox(height: 12),

            // 4. Row of 2: Total expenses & Total remaining
            Row(
              children: [
                Expanded(
                  child: _MiniStatCard(
                    label: 'Total expenses',
                    value: inr(d.expToday),
                    icon: Icons.confirmation_number_outlined,
                    iconColor: const Color(0xFFF43F5E),
                    iconBg: const Color(0xFFFFE4E6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatCard(
                    label: 'Total remaining',
                    value: inr(remToday),
                    icon: Icons.savings_outlined,
                    iconColor: const Color(0xFF10B981),
                    iconBg: const Color(0xFFE8F5E9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 5. Section: All dates
            const SectionTitle('All dates'),
            const SizedBox(height: 12),

            // 6. Row of 2: Total collection & Total expenses (All dates)
            Row(
              children: [
                Expanded(
                  child: _MiniStatCard(
                    label: 'Total collection',
                    value: inr(d.all.total),
                    sub: '${d.all.count} transactions',
                    icon: Icons.monetization_on_outlined,
                    iconColor: const Color(0xFF0284C7),
                    iconBg: const Color(0xFFE0F2FE),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStatCard(
                    label: 'Total expenses',
                    value: inr(d.expAll),
                    icon: Icons.confirmation_number_outlined,
                    iconColor: const Color(0xFFF43F5E),
                    iconBg: const Color(0xFFFFE4E6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 7. Full Width: Overall remaining balance
            _WideStatCard(
              label: 'Overall remaining balance',
              value: inr(remAll),
              icon: Icons.savings_outlined,
              iconColor: const Color(0xFF10B981),
              iconBg: const Color(0xFFE8F5E9),
            ),
            const SizedBox(height: 24),

            // 8. Weekly Chart Section
            const SectionTitle('Last 7 days — collection by payment method, with expenses'),
            const SizedBox(height: 12),
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
            const SizedBox(height: 18),

            // 9. Recent collections
            SectionTitle(
              'Recent collections',
              trailing: TextButton(
                onPressed: () => onGo(2),
                child: const Text('View all', style: TextStyle(color: AppColors.total, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            GlassCard(
              padding: EdgeInsets.zero,
              child: d.recent.isEmpty
                  ? const EmptyState('No collections yet.')
                  : Column(children: [
                      for (var i = 0; i < d.recent.length; i++) ...[
                        ListTile(
                          dense: true,
                          title: Text(
                            '${d.recent[i].receiptNumber} · ${d.recent[i].shopName}',
                            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                          subtitle: Text(dmy(d.recent[i].date), style: const TextStyle(color: AppColors.textSecondary)),
                          trailing: Text(
                            inr(d.recent[i].total),
                            style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.total),
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => ReceiptScreen(collectionId: d.recent[i].id!)),
                          ),
                        ),
                        if (i < d.recent.length - 1) const Divider(height: 1, color: AppColors.border),
                      ],
                    ]),
            ),
            const SizedBox(height: 28),
          ]);
        },
      );
}

// ------------------------------------------------------------- Specialized Stat Widgets matching Reference Mockup

class _HeroBalanceCard extends StatelessWidget {
  final String amount;
  final String subtext;
  final VoidCallback? onTap;

  const _HeroBalanceCard({
    required this.amount,
    required this.subtext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0C4A6E), Color(0xFF0284C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x330284C7),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Color(0xFF38BDF8),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Remaining cash',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      amount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtext,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D9488).withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF2DD4BF).withValues(alpha: 0.6)),
                ),
                child: const Text(
                  'CURRENT\nBALANCE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF5EEAD4),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    height: 1.15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback? onTap;

  const _MiniStatCard({
    required this.label,
    required this.value,
    this.sub,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WideStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback? onTap;

  const _WideStatCard({
    required this.label,
    required this.value,
    this.sub,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 10,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.4,
                      ),
                    ),
                    if (sub != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub!,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
