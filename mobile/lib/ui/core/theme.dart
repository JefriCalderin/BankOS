import 'package:flutter/material.dart';

/// Design tokens inspired by the Figma Banking Design System & BankOS specifications.
class BankOsColors {
  // Brand Primary & Gradients (Figma Banking palette)
  static const Color primary = Color(0xFF3862F8);
  static const Color primaryDark = Color(0xFF1E3A8A);
  static const Color primaryLight = Color(0xFF60A5FA);

  // Surface & Neutral tones
  static const Color navy = Color(0xFF0F172A);
  static const Color slate = Color(0xFF334155);
  static const Color slateSoft = Color(0xFFF1F5F9);
  static const Color muted = Color(0xFF64748B);
  static const Color surface = Color(0xFFF8FAFD);
  static const Color card = Colors.white;
  static const Color border = Color(0xFFE2E8F0);

  // Status & Highlights (Figma accents)
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldSoft = Color(0xFFECFDF5);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color violet = Color(0xFF8B5CF6);
  static const Color violetSoft = Color(0xFFF5F3FF);
  static const Color crimson = Color(0xFFEF4444);
  static const Color crimsonSoft = Color(0xFFFEF2F2);

  // Gradients matching Figma screens
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF469EF0),
      Color(0xFF5C75F0),
      Color(0xFF6C56F0),
    ],
  );

  static const LinearGradient darkCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF283648),
      Color(0xFF384D6B),
      Color(0xFF4B6994),
    ],
  );

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E293B),
      Color(0xFF0F172A),
    ],
  );
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
      backgroundColor: Colors.white,
      foregroundColor: BankOsColors.navy,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: BankOsColors.navy,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      iconTheme: IconThemeData(color: BankOsColors.navy),
    ),
    cardTheme: CardThemeData(
      color: BankOsColors.card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: BankOsColors.border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BankOsColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BankOsColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: BankOsColors.primary, width: 1.8),
      ),
      labelStyle: const TextStyle(color: BankOsColors.muted, fontSize: 13),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: BankOsColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: BankOsColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
