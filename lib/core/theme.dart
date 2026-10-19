import 'package:flutter/material.dart';

class AppColors {
  // Vibrant saturated colors tuned for high contrast in light mode
  static const cash = Color(0xFF047857);       // Deep Emerald (AAA contrast)
  static const gpay = Color(0xFF1D4ED8);       // Deep Royal Azure
  static const cheque = Color(0xFFB45309);     // Deep Warm Amber
  static const expenses = Color(0xFFBE123C);   // Deep Rose Coral
  static const remaining = Color(0xFF6D28D9);  // Deep Violet
  static const total = Color(0xFF0369A1);      // Deep Cyan Ocean

  // Canvas and borders
  static const bgDark = Color(0xFFEDF2F7);     // Cool Slate Canvas
  static const bgSurface = Color(0xFFFFFFFF);  // Pure White Surface
  static const bgCard = Color(0xFFFFFFFF);     // White Card
  static const bgCardSolid = Color(0xFFFFFFFF);
  static const border = Color(0xFFCBD5E1);     // Crisp Slate-300 Border (high visibility)
  static const borderStrong = Color(0xFF94A3B8); // Slate-400 Border

  // Text tokens for light background
  static const textPrimary = Color(0xFF0F172A);   // Slate 900
  static const textSecondary = Color(0xFF334155); // Slate 700
  static const textMuted = Color(0xFF64748B);     // Slate 500

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
}

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: AppColors.total,
    onPrimary: Colors.white,
    secondary: AppColors.remaining,
    onSecondary: Colors.white,
    surface: AppColors.bgSurface,
    onSurface: AppColors.textPrimary,
    error: AppColors.expenses,
    onError: Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bgDark,
    canvasColor: AppColors.bgDark,
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.85),
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white.withValues(alpha: 0.96),
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: AppColors.border, width: 1.2),
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.85),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.total, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
      prefixIconColor: AppColors.textSecondary,
      suffixIconColor: AppColors.textSecondary,
      isDense: true,
    ),
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: AppColors.textPrimary,
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      textStyle: const TextStyle(color: AppColors.textPrimary),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textPrimary,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
}
