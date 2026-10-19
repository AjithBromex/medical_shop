import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/sync_status_widget.dart';
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

  late final List<_Dest> _dests = [
    _Dest('Dashboard', Icons.speed, () => DashboardScreen(onGo: go)),
    _Dest('Add Collection', Icons.add_circle_outline, () => CollectionForm(onSaved: () => go(0))),
    const _Dest('Collection History', Icons.menu_book_outlined, CollectionHistory.new),
    const _Dest('Collection Analysis', Icons.bar_chart, AnalysisScreen.new),
    const _Dest('Expenses', Icons.account_balance_wallet_outlined, ExpensesScreen.new),
    const _Dest('Daily Money', Icons.payments_outlined, DailyMoneyScreen.new),
    const _Dest('Reports', Icons.description_outlined, ReportsScreen.new),
    const _Dest('Admin - Medical Shops', Icons.storefront_outlined, ShopsScreen.new),
  ];

  void go(int i) {
    if (_index == i) return;
    setState(() => _index = i);
  }

  void _openMoreSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
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
                color: AppColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              children: [
                const Text(
                  'More Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _MoreSheetTile(
              title: 'Expenses',
              subtitle: 'Daily store expenses & category breakdown',
              icon: Icons.account_balance_wallet_outlined,
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
              subtitle: 'Period summaries and CSV spreadsheets',
              icon: Icons.description_outlined,
              color: AppColors.total,
              isSelected: _index == 6,
              onTap: () {
                Navigator.pop(ctx);
                go(6);
              },
            ),
            _MoreSheetTile(
              title: 'Admin - Medical Shops',
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
      backgroundColor: AppColors.bgDark,
      extendBodyBehindAppBar: false,
      appBar: wide
          ? null
          : AppBar(
              leading: _index != 0
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                      tooltip: 'Back to Dashboard',
                      onPressed: () => go(0),
                    )
                  : Builder(
                      builder: (c) => IconButton(
                        icon: const Icon(Icons.menu_rounded),
                        tooltip: 'Open menu',
                        onPressed: () => Scaffold.of(c).openDrawer(),
                      ),
                    ),
              title: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _index == 0
                    ? Image.asset('assets/logo.png', height: 32, fit: BoxFit.contain, key: const ValueKey('app_logo'))
                    : Text(
                        dest.label,
                        key: ValueKey(dest.label),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                      ),
              ),
              actions: [
                const SyncStatusHeaderButton(compact: true),
                if (_index != 1)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.total),
                    tooltip: 'Add collection',
                    onPressed: () => go(1),
                  ),
                if (_index != 0)
                  Builder(
                    builder: (c) => IconButton(
                      icon: const Icon(Icons.menu_rounded),
                      tooltip: 'All menus',
                      onPressed: () => Scaffold.of(c).openDrawer(),
                    ),
                  ),
              ],
              backgroundColor: Colors.white.withValues(alpha: 0.95),
              elevation: 0,
              shape: const Border(bottom: BorderSide(color: AppColors.border)),
            ),
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: Colors.white,
              child: SafeArea(child: nav),
            ),
      bottomNavigationBar: wide
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border, width: 1.2)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0D0F172A),
                    blurRadius: 12,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 64,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MobileNavItem(
                        icon: Icons.speed,
                        label: 'Home',
                        isSelected: _index == 0,
                        onTap: () => go(0),
                      ),
                      _MobileNavItem(
                        icon: Icons.add_circle_outline,
                        activeIcon: Icons.add_circle,
                        label: 'Add',
                        isAction: true,
                        isSelected: _index == 1,
                        onTap: () => go(1),
                      ),
                      _MobileNavItem(
                        icon: Icons.menu_book_outlined,
                        label: 'History',
                        isSelected: _index == 2,
                        onTap: () => go(2),
                      ),
                      _MobileNavItem(
                        icon: Icons.bar_chart,
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
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: AppColors.border, width: 1.2)),
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
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
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
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const Spacer(),
                            const SyncStatusHeaderButton(),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Smooth AnimatedSwitcher with RepaintBoundary for seamless 60/120fps transition
                Expanded(
                  child: RepaintBoundary(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      reverseDuration: const Duration(milliseconds: 120),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                        return Stack(
                          alignment: Alignment.topLeft,
                          children: <Widget>[
                            ...previousChildren,
                            if (currentChild != null) currentChild,
                          ],
                        );
                      },
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: child,
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey(_index),
                        child: dest.build(),
                      ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: isSelected ? color.withValues(alpha: 0.10) : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color.withValues(alpha: 0.4) : AppColors.border,
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
                          color: isSelected ? color : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
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

class _MobileNavItem extends StatefulWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isSelected;
  final bool isAction;
  final VoidCallback onTap;

  const _MobileNavItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    required this.isSelected,
    this.isAction = false,
    required this.onTap,
  });

  @override
  State<_MobileNavItem> createState() => _MobileNavItemState();
}

class _MobileNavItemState extends State<_MobileNavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    const activeColor = AppColors.total;
    const inactiveColor = AppColors.textSecondary;
    final iconColor = widget.isSelected ? activeColor : inactiveColor;

    if (widget.isAction) {
      return GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 34,
                decoration: BoxDecoration(
                  color: widget.isSelected ? activeColor : activeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: activeColor.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: Icon(
                  widget.isSelected ? (widget.activeIcon ?? widget.icon) : widget.icon,
                  color: widget.isSelected ? Colors.white : activeColor,
                  size: 20,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: widget.isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.92 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? activeColor.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.isSelected ? (widget.activeIcon ?? widget.icon) : widget.icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: widget.isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
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
  Widget build(BuildContext context) => RepaintBoundary(
        child: Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                child: Image.asset(
                  'assets/logo.png',
                  height: 44,
                  fit: BoxFit.contain,
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
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
    const activeColor = AppColors.total;
    const inactiveColor = AppColors.textSecondary;
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
                          decoration: const BoxDecoration(
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

