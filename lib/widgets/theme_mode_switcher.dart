import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../state/app_state.dart';

/// A versatile Light / Dark mode switcher supporting both:
/// 1. Compact icon toggle for AppBar/header actions
/// 2. Segmented pill switcher for the Home Screen / Dashboard banner
class ThemeModeSwitcher extends StatelessWidget {
  final bool compact;

  const ThemeModeSwitcher({
    super.key,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = state.isDarkMode;

    if (compact) {
      return IconButton(
        tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          transitionBuilder: (child, animation) => RotationTransition(
            turns: animation,
            child: ScaleTransition(scale: animation, child: child),
          ),
          child: Icon(
            isDark ? Icons.wb_sunny_rounded : Icons.nightlight_round,
            key: ValueKey(isDark),
            size: 20,
            color: isDark ? const Color(0xFFFBBF24) : AppColors.textPrimary,
          ),
        ),
        onPressed: () => state.toggleTheme(),
      );
    }

    // Segmented Pill Switcher for Dashboard Home Screen
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PillOption(
            icon: Icons.wb_sunny_rounded,
            label: 'Light',
            isSelected: !isDark,
            activeColor: const Color(0xFFD97706),
            onTap: () {
              if (isDark) state.setThemeMode(ThemeMode.light);
            },
          ),
          const SizedBox(width: 2),
          _PillOption(
            icon: Icons.nightlight_round,
            label: 'Dark',
            isSelected: isDark,
            activeColor: const Color(0xFF38BDF8),
            onTap: () {
              if (!isDark) state.setThemeMode(ThemeMode.dark);
            },
          ),
        ],
      ),
    );
  }
}

class _PillOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  const _PillOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF334155) : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: isDark ? const Color(0x33000000) : const Color(0x0F0F172A),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? activeColor
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

