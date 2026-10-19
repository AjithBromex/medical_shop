import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/money.dart';
import '../core/theme.dart';
import '../state/app_state.dart';
import 'glass.dart';

export 'glass.dart';

void toast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      content: GlassContainer(
        blur: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        borderRadius: BorderRadius.circular(14),
        color: error ? AppColors.expenses.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.95),
        border: Border.all(
          color: error ? AppColors.expenses.withValues(alpha: 0.4) : AppColors.border,
          width: 1.2,
        ),
        child: Row(
          children: [
            Icon(
              error ? Icons.error_outline : Icons.check_circle_outline,
              color: error ? AppColors.expenses : AppColors.total,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    ));
}

Future<bool> confirm(BuildContext context, String title, String message, {String action = 'Delete'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1.2),
        ),
        title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(message, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: action == 'Delete' ? AppColors.expenses : AppColors.total,
              foregroundColor: action == 'Delete' ? Colors.white : Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(action, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    ),
  );
  return r ?? false;
}

/// Re-runs [loader] whenever app data changes (revision) or [deps] change.
class Loader<T> extends StatefulWidget {
  final Future<T> Function() loader;
  final Widget Function(BuildContext, T) builder;
  final Object? deps;
  const Loader({super.key, required this.loader, required this.builder, this.deps});
  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _future;
  int _rev = -1;
  Object? _deps;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rev = context.watch<AppState>().revision;
    if (rev != _rev || widget.deps != _deps) {
      _rev = rev;
      _deps = widget.deps;
      _future = widget.loader();
    }
  }

  @override
  void didUpdateWidget(covariant Loader<T> old) {
    super.didUpdateWidget(old);
    if (widget.deps != _deps) {
      _deps = widget.deps;
      _future = widget.loader();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _future,
        builder: (c, s) {
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: GlassContainer(
                  padding: const EdgeInsets.all(20),
                  borderRadius: BorderRadius.circular(16),
                  color: AppColors.expenses.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.expenses.withValues(alpha: 0.3)),
                  child: Text('Something went wrong: ${s.error}', style: const TextStyle(color: AppColors.textPrimary)),
                ),
              ),
            );
          }
          if (!s.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.total),
            );
          }
          return widget.builder(c, s.data as T);
        },
      );
}

class StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final String? sub;
  const StatCard(this.label, this.value, this.icon, this.color, {super.key, this.sub});

  @override
  Widget build(BuildContext context) => GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.40), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.4,
                    ),
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ]),
            ),
          ],
        ),
      );
}

/// Responsive grid of cards.
class CardGrid extends StatelessWidget {
  final List<Widget> children;
  final double minWidth;
  const CardGrid(this.children, {super.key, this.minWidth = 260});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (c, box) {
        final cols = (box.maxWidth / minWidth).floor().clamp(1, 6);
        final w = (box.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(28),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Icon(icon, size: 36, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
          ]),
        ),
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 12),
        child: Row(children: [
          Container(
            width: 4.5,
            height: 18,
            margin: const EdgeInsets.only(right: 10),
            decoration: BoxDecoration(
              color: AppColors.total,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}

class DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  const DateField({super.key, required this.label, required this.value, required this.onChanged, this.clearable = false});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: value ?? today(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (d != null) onChanged(dateOnly(d));
        },
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: clearable && value != null
                ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => onChanged(null))
                : const Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(
            value == null ? 'Any' : dmy(value),
            style: TextStyle(color: value == null ? AppColors.textMuted : AppColors.textPrimary),
          ),
        ),
      );
}

/// Previous / next day navigator with frosted glass pill style.
class DayNav extends StatelessWidget {
  final DateTime day;
  final ValueChanged<DateTime> onChanged;
  const DayNav({super.key, required this.day, required this.onChanged});

  @override
  Widget build(BuildContext context) => GlassContainer(
        blur: 16,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        borderRadius: BorderRadius.circular(24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: () => onChanged(day.subtract(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary),
              tooltip: 'Previous day',
            ),
            TextButton.icon(
              icon: const Icon(Icons.calendar_today, size: 16, color: AppColors.total),
              label: Text(
                dmy(day),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: day,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) onChanged(dateOnly(d));
              },
            ),
            IconButton(
              onPressed: () => onChanged(day.add(const Duration(days: 1))),
              icon: const Icon(Icons.chevron_right, color: AppColors.textPrimary),
              tooltip: 'Next day',
            ),
            if (day != today()) ...[
              const SizedBox(width: 4),
              GlassButton(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                onPressed: () => onChanged(today()),
                isPrimary: true,
                child: const Text('Today', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
      );
}

class MoneyText extends StatelessWidget {
  final int paise;
  final TextStyle? style;
  final bool signColor;
  const MoneyText(this.paise, {super.key, this.style, this.signColor = false});
  @override
  Widget build(BuildContext context) => Text(
        inr(paise),
        style: (style ?? const TextStyle()).copyWith(
          color: signColor
              ? (paise < 0 ? AppColors.expenses : AppColors.cash)
              : (style?.color ?? AppColors.textPrimary),
        ),
      );
}

/// PageBody with ambient glowing backdrop and constrained content width.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  const PageBody(this.children, {super.key});

  @override
  Widget build(BuildContext context) => AmbientBackdrop(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: children,
            ),
          ),
        ),
      );
}

class ErrorBox extends StatelessWidget {
  final List<String> errors;
  const ErrorBox(this.errors, {super.key});

  @override
  Widget build(BuildContext context) => errors.isEmpty
      ? const SizedBox.shrink()
      : GlassContainer(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFFFEF2F2),
          border: Border.all(color: const Color(0xFFF87171), width: 1.3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final e in errors)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.error_outline, size: 17, color: Color(0xFFDC2626)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          e,
                          style: const TextStyle(
                            color: Color(0xFF991B1B),
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            height: 1.35,
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
