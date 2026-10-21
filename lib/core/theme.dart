import 'package:flutter/material.dart';

class AppColors {
  // Vibrant saturated colors tuned for high contrast in light & dark mode
  static const cash = Color(0xFF047857);       // Deep Emerald
  static const gpay = Color(0xFF1D4ED8);       // Deep Royal Azure
  static const cheque = Color(0xFFB45309);     // Deep Warm Amber
  static const expenses = Color(0xFFBE123C);   // Deep Rose Coral
  static const remaining = Color(0xFF6D28D9);  // Deep Violet
  static const total = Color(0xFF0369A1);      // Deep Cyan Ocean

  // Canvas and borders (Light)
  static const bgDark = Color(0xFFF8FAFC);     // Slate-50 Canvas
  static const bgSurface = Color(0xFFFFFFFF);  // Pure White Surface
  static const bgCard = Color(0xFFFFFFFF);     // White Card
  static const bgCardSolid = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);     // Crisp Slate-200 Border
  static const borderStrong = Color(0xFFCBD5E1); // Slate-300 Border

  // Text tokens for light background
  static const textPrimary = Color(0xFF0F172A);   // Slate 900
  static const textSecondary = Color(0xFF334155); // Slate 700
  static const textMuted = Color(0xFF64748B);     // Slate 500

  // Dark mode tokens
  static const darkBgCanvas = Color(0xFF0B132B);   // Deep Midnight Slate
  static const darkBgSurface = Color(0xFF1E293B);  // Slate 800 Surface
  static const darkBgCard = Color(0xFF1E293B);     // Slate 800 Card
  static const darkBorder = Color(0xFF334155);     // Slate 700 Border
  static const darkBorderStrong = Color(0xFF475569); // Slate 600 Border
  static const darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const darkTextSecondary = Color(0xFFCBD5E1); // Slate 300
  static const darkTextMuted = Color(0xFF94A3B8);     // Slate 400

  static const categories = [
    Color(0xFF0369A1), // Cyan
    Color(0xFF047857), // Emerald
    Color(0xFF1D4ED8), // Blue
    Color(0xFF6D28D9), // Purple
    Color(0xFFBE123C), // Rose
    Color(0xFFB45309), // Amber
    Color(0xFF0F766E), // Teal
    Color(0xFFBE185D), // Pink
  ];

  static Color textPrimaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextPrimary : textPrimary;
  static Color textSecondaryOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextSecondary : textSecondary;
  static Color textMutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkTextMuted : textMuted;
  static Color bgOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBgCanvas : bgDark;
  static Color cardOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBgSurface : bgSurface;
  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? darkBorder : border;
}

extension ThemeContext on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bgCanvas => isDark ? AppColors.darkBgCanvas : AppColors.bgDark;
  Color get bgCard => isDark ? AppColors.darkBgCard : AppColors.bgCard;
  Color get borderColor => isDark ? AppColors.darkBorder : AppColors.border;
  Color get textPrimaryColor => isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  Color get textSecondaryColor => isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  Color get textMutedColor => isDark ? AppColors.darkTextMuted : AppColors.textMuted;
}

ThemeData buildTheme([Brightness brightness = Brightness.light]) {
  final isDark = brightness == Brightness.dark;

  final scheme = isDark
      ? const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          onPrimary: Color(0xFF0F172A),
          secondary: Color(0xFFA78BFA),
          onSecondary: Color(0xFF0F172A),
          surface: AppColors.darkBgSurface,
          onSurface: AppColors.darkTextPrimary,
          error: Color(0xFFFB7185),
          onError: Color(0xFF0F172A),
        )
      : const ColorScheme.light(
          primary: AppColors.total,
          onPrimary: Colors.white,
          secondary: AppColors.remaining,
          onSecondary: Colors.white,
          surface: AppColors.bgSurface,
          onSurface: AppColors.textPrimary,
          error: AppColors.expenses,
          onError: Colors.white,
        );

  final cardBg = isDark ? AppColors.darkBgSurface : Colors.white;
  final canvasBg = isDark ? AppColors.darkBgCanvas : AppColors.bgDark;
  final borderColor = isDark ? AppColors.darkBorder : AppColors.border;
  final textPrimaryColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
  final textSecondaryColor = isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
  final textMutedColor = isDark ? AppColors.darkTextMuted : AppColors.textMuted;

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: canvasBg,
    canvasColor: canvasBg,
    cardTheme: CardThemeData(
      color: cardBg,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardBg,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: cardBg,
      headerBackgroundColor: isDark ? const Color(0xFF0F172A) : AppColors.total,
      headerForegroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        if (states.contains(WidgetState.disabled)) return textMutedColor.withValues(alpha: 0.4);
        return textPrimaryColor;
      }),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return Colors.white;
        if (states.contains(WidgetState.disabled)) return textMutedColor.withValues(alpha: 0.4);
        return textPrimaryColor;
      }),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    dataTableTheme: DataTableThemeData(
      headingTextStyle: TextStyle(
        fontWeight: FontWeight.w800,
        color: textPrimaryColor,
        fontSize: 14,
      ),
      dataTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        color: textPrimaryColor,
        fontSize: 13.5,
      ),
      dividerThickness: 1.0,
      headingRowColor: WidgetStatePropertyAll(
        isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark
                ? const Color(0xFF0284C7).withValues(alpha: 0.35)
                : AppColors.total.withValues(alpha: 0.15);
          }
          return isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.8)
              : Colors.white.withValues(alpha: 0.8);
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return isDark ? const Color(0xFF38BDF8) : AppColors.total;
          }
          return isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary;
        }),
        textStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          );
        }),
        side: WidgetStatePropertyAll(
          BorderSide(
            color: borderColor,
            width: 1.2,
          ),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: isDark ? const Color(0xFF38BDF8) : AppColors.total, width: 1.5),
      ),
      labelStyle: TextStyle(color: textSecondaryColor),
      hintStyle: TextStyle(color: textMutedColor),
      prefixIconColor: textSecondaryColor,
      suffixIconColor: textSecondaryColor,
      isDense: true,
    ),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: textPrimaryColor,
    ),
    dividerTheme: DividerThemeData(
      color: borderColor,
      thickness: 1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor),
      ),
      textStyle: TextStyle(color: textPrimaryColor),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: textPrimaryColor,
        side: BorderSide(color: borderColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
