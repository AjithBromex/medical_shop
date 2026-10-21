import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/sync_status_widget.dart';
import '../widgets/theme_mode_switcher.dart';
import 'analysis_screen.dart';
import 'collection_form.dart';
import 'collection_history.dart';
import 'daily_money_screen.dart';
import 'dashboard_screen.dart';
import 'expenses_screen.dart';
import 'reports_screen.dart';
import 'shops_screen.dart';

class _Dest {
  final String label;
  final IconData icon;
  final Widget Function() build;
  const _Dest(this.label, this.icon, this.build);
}

/// Navigation shell: frosted glass side rail on wide screens, glass drawer on phones.
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  int _index = 0;
  final Map<int, Widget> _cachedScreens = {};

  late final List<_Dest> _dests = [
    _Dest('Dashboard', Icons.speed, () => DashboardScreen(onGo: go)),
    _Dest('Add Collection', Icons.add_circle_outline, () => CollectionForm(onSaved: () => go(0))),
    const _Dest('Collection History', Icons.menu_book_outlined, CollectionHistory.new),
    const _Dest('Collection Analysis', Icons.bar_chart, AnalysisScreen.new),
    const _Dest('Expenses', Icons.confirmation_number_outlined, ExpensesScreen.new),
    const _Dest('Daily Money', Icons.payments_outlined, DailyMoneyScreen.new),
    const _Dest('Reports', Icons.description_outlined, ReportsScreen.new),
    const _Dest('Admin - Customers', Icons.storefront_outlined, ShopsScreen.new),
  ];

  void go(int i) {
    if (_index == i) return;
    if (i == 1) {
      // Re-create Add Collection screen so form fields start fresh
      _cachedScreens.remove(1);
    }
    setState(() => _index = i);
  }

  Widget _buildTab(int i) {
    if (i == 1) {
      // Add Collection: fresh form when active, or empty placeholder when inactive
      if (_index == 1) {
        return _dests[1].build();
      }
      return const SizedBox.shrink();
    }
    // Lazy cache: instantiate only visited tabs once, then keep them alive for 0ms lag-free switching
    if (i == _index || _cachedScreens.containsKey(i)) {
      return _cachedScreens.putIfAbsent(i, () => _dests[i].build());
    }
    return const SizedBox.shrink();
  }

  void _openMoreSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F0F172A),
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).padding.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF475569) : AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                Text(
                  'More Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MoreSheetTile(
              title: 'Expenses',
              subtitle: 'Daily store expenses & category breakdown',
              icon: Icons.confirmation_number_outlined,
              color: AppColors.expenses,
              isSelected: _index == 4,
              onTap: () {
                Navigator.pop(ctx);
                go(4);
              },
            ),
            _MoreSheetTile(
              title: 'Daily Money',
              subtitle: 'Day-by-day cash, online, and balance records',
              icon: Icons.payments_outlined,
              color: AppColors.remaining,
              isSelected: _index == 5,
              onTap: () {
                Navigator.pop(ctx);
                go(5);
              },
            ),
            _MoreSheetTile(
              title: 'Reports',
              subtitle: 'Period summaries and Excel spreadsheets',
              icon: Icons.description_outlined,
              color: AppColors.total,
              isSelected: _index == 6,
              onTap: () {
                Navigator.pop(ctx);
                go(6);
              },
            ),
            _MoreSheetTile(
              title: 'Admin - Customers',
              subtitle: 'Manage client medical shops and contacts',
              icon: Icons.storefront_outlined,
              color: AppColors.cash,
              isSelected: _index == 7,
              onTap: () {
                Navigator.pop(ctx);
                go(7);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dest = _dests[_index];

    final nav = _SideNav(
      selected: _index,
      labels: [for (final d in _dests) (d.label, d.icon)],
      onSelect: (i) {
        go(i);
        if (!wide) Navigator.of(context).maybePop();
      },
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B132B) : AppColors.bgDark,
      extendBodyBehindAppBar: false,
      appBar: wide
          ? null
          : AppBar(
              leading: _index != 0
                  ? IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 19, color: isDark ? Colors.white : AppColors.textPrimary),
                      tooltip: 'Back to Dashboard',
                      onPressed: () => go(0),
                    )
                  : Builder(
                      builder: (c) => IconButton(
                        icon: Icon(Icons.menu_rounded, size: 24, color: isDark ? Colors.white : AppColors.textPrimary),
                        tooltip: 'Open menu',
                        onPressed: () => Scaffold.of(c).openDrawer(),
                      ),
                    ),
              centerTitle: true,
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _index == 0
                    ? (isDark
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x22000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Image.asset('assets/home_logo.png', height: 26, fit: BoxFit.contain, key: const ValueKey('home_logo_dark')),
                          )
                        : Image.asset('assets/home_logo.png', height: 32, fit: BoxFit.contain, key: const ValueKey('home_logo')))
                    : Text(
                        dest.label,
                        key: ValueKey(dest.label),
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: isDark ? Colors.white : AppColors.textPrimary),
                      ),
              ),
              actions: const [
                ThemeModeSwitcher(compact: true),
                SyncStatusHeaderButton(compact: true),
              ],
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 0,
              shape: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
            ),
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              child: SafeArea(child: nav),
            ),
      bottomNavigationBar: wide
          ? null
          : Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2)),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? const Color(0x33000000) : const Color(0x0D0F172A),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 68,
                  child: Row(
                    children: [
                      _MobileNavItem(
                        icon: Icons.home_rounded,
                        label: 'Home',
                        isSelected: _index == 0,
                        onTap: () => go(0),
                      ),
                      _MobileNavItem(
                        icon: Icons.receipt_long_outlined,
                        label: 'History',
                        isSelected: _index == 2,
                        onTap: () => go(2),
                      ),
                      _CenterAddButton(
                        isSelected: _index == 1,
                        onTap: () => go(1),
                      ),
                      _MobileNavItem(
                        icon: Icons.bar_chart_rounded,
                        label: 'Analysis',
                        isSelected: _index == 3,
                        onTap: () => go(3),
                      ),
                      _MobileNavItem(
                        icon: Icons.grid_view_rounded,
                        label: 'More',
                        isSelected: _index >= 4,
                        onTap: () => _openMoreSheet(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 270,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.border, width: 1.2)),
                ),
                child: nav,
              ),
            ),
          Expanded(
            child: Column(
              children: [
                if (wide)
                  RepaintBoundary(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : AppColors.border, width: 1)),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) =>
                            FadeTransition(opacity: animation, child: child),
                        child: Row(
                          key: ValueKey(_index),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.total.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.total.withValues(alpha: 0.3)),
                              ),
                              child: Icon(dest.icon, color: AppColors.total, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              dest.label,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const Spacer(),
                            const ThemeModeSwitcher(compact: true),
                            const SizedBox(width: 8),
                            const SyncStatusHeaderButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                // High-performance IndexedStack: 0ms instant tab switching with preserved state
                Expanded(
                  child: RepaintBoundary(
                    child: IndexedStack(
                      index: _index,
                      children: [
                        for (int i = 0; i < _dests.length; i++)
                          _buildTab(i),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreSheetTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoreSheetTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected
            ? color.withValues(alpha: isDark ? 0.20 : 0.10)
            : (isDark ? const Color(0xFF334155).withValues(alpha: 0.35) : Colors.grey.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color.withValues(alpha: 0.6) : (isDark ? const Color(0xFF334155) : AppColors.border),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          color: isSelected ? color : (isDark ? Colors.white : AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? (isDark ? const Color(0x330284C7) : const Color(0xFFE0F2FE)) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterAddButton extends StatelessWidget {
  final bool isSelected;
  final VoidCallback onTap;

  const _CenterAddButton({
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              height: 32,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: -22,
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.42),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                letterSpacing: -0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final int selected;
  final List<(String, IconData)> labels;
  final ValueChanged<int> onSelect;
  const _SideNav({
    required this.selected,
    required this.labels,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
        child: Container(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: isDark
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Image.asset(
                          'assets/home_logo.png',
                          height: 36,
                          fit: BoxFit.contain,
                        ),
                      )
                    : Image.asset(
                        'assets/home_logo.png',
                        height: 44,
                        fit: BoxFit.contain,
                      ),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF334155) : AppColors.border),
              const SizedBox(height: 6),

              // Navigation Items
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  itemCount: labels.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    return _NavItem(
                      icon: labels[i].$2,
                      label: labels[i].$1,
                      isSelected: i == selected,
                      onTap: () => onSelect(i),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
  }
}

class _NavItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? const Color(0xFF38BDF8) : AppColors.total;
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : AppColors.textSecondary;
    final currentColor = widget.isSelected ? activeColor : inactiveColor;

    final bgColor = widget.isSelected
        ? activeColor.withValues(alpha: 0.12)
        : (_isHovered ? activeColor.withValues(alpha: 0.05) : Colors.transparent);

    final borderColor = widget.isSelected
        ? activeColor.withValues(alpha: 0.35)
        : (_isHovered ? activeColor.withValues(alpha: 0.15) : Colors.transparent);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(12),
              splashColor: activeColor.withValues(alpha: 0.12),
              highlightColor: activeColor.withValues(alpha: 0.05),
              hoverColor: Colors.transparent,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: bgColor,
                  border: Border.all(
                    color: borderColor,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  children: [
                    TweenAnimationBuilder<Color?>(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      tween: ColorTween(end: currentColor),
                      builder: (context, color, child) => Icon(
                        widget.icon,
                        size: 20,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        style: TextStyle(
                          color: currentColor,
                          fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13.5,
                        ),
                        child: Text(widget.label),
                      ),
                    ),
                    AnimatedScale(
                      scale: widget.isSelected ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutBack,
                      child: AnimatedOpacity(
                        opacity: widget.isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: activeColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

