import 'package:flutter/material.dart';

class BankOsColors {
  static const Color navy = Color(0xFF0F172A);
  static const Color slate = Color(0xFF334155);
  static const Color muted = Color(0xFF64748B);
  static const Color surface = Color(0xFFF8FAFC);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE2E8F0);

  static const Color primary = Color(0xFF1D4ED8);
  static const Color emerald = Color(0xFF059669);
  static const Color emeraldSoft = Color(0xFFECFDF5);
  static const Color amber = Color(0xFFD97706);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color violet = Color(0xFF7C3AED);
  static const Color violetSoft = Color(0xFFF5F3FF);
  static const Color crimson = Color(0xFFDC2626);
  static const Color crimsonSoft = Color(0xFFFEF2F2);
}

ThemeData buildBankOsTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: BankOsColors.primary,
    primary: BankOsColors.primary,
    secondary: BankOsColors.emerald,
    surface: BankOsColors.surface,
    error: BankOsColors.crimson,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: BankOsColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: BankOsColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    ),
    cardTheme: CardThemeData(
      color: BankOsColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: BankOsColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BankOsColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BankOsColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: BankOsColors.primary, width: 1.8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BankOsColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
