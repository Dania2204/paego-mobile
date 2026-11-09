import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Brand Palette ────────────────────────────────────────────────────────────
class PaeColors {
  // Primary: deep teal-blue
  static const primary = Color(0xFF0A7B6B);
  static const primaryDark = Color(0xFF065A4E);
  static const primaryLight = Color(0xFF14A88F);

  // Accent: vivid cyan-green
  static const accent = Color(0xFF00D4AA);
  static const accentLight = Color(0xFF4DFFDA);

  // Secondary: ocean blue
  static const secondary = Color(0xFF1565C0);
  static const secondaryLight = Color(0xFF42A5F5);

  // Gradient stops
  static const gradStart = Color(0xFF0D6E5F);
  static const gradMid = Color(0xFF0B8C7A);
  static const gradEnd = Color(0xFF059B8A);

  // Backgrounds
  static const bgLight = Color(0xFFF0FAF8);
  static const bgDark = Color(0xFF071A17);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceDark = Color(0xFF0E2922);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF132E28);

  // Status
  static const success = Color(0xFF00C48C);
  static const warning = Color(0xFFFFB300);
  static const error = Color(0xFFE53935);
  static const info = Color(0xFF039BE5);

  // Delivery status
  static const statusPending = Color(0xFFFFB300);
  static const statusAssigned = Color(0xFF039BE5);
  static const statusEnRoute = Color(0xFF00C48C);
  static const statusDelivered = Color(0xFF43A047);

  // Neutrals
  static const textPrimary = Color(0xFF0D1F1C);
  static const textSecondary = Color(0xFF4A7068);
  static const textLight = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE0F0EC);
  static const inactive = Color(0xFFB2CFCA);

  // Gradient constructors
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [gradStart, gradMid, gradEnd],
  );

  static const heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0A5C50), Color(0xFF0D8C78), Color(0xFF00D4AA)],
    stops: [0.0, 0.6, 1.0],
  );

  static const cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D7A6A), Color(0xFF0A9B87)],
  );
}

// ── Typography ───────────────────────────────────────────────────────────────
class PaeTypography {
  static const fontDisplay = 'Nunito';
  static const fontBody = 'Nunito';

  // Use GoogleFonts for reliable Nunito loading (no pubspec font assets needed)
  static TextStyle display(TextStyle base) =>
      GoogleFonts.nunito(textStyle: base);
  static TextStyle body(TextStyle base) => GoogleFonts.nunito(textStyle: base);

  static TextTheme get textTheme => GoogleFonts.nunitoTextTheme(
    const TextTheme(
      displayLarge: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
        color: PaeColors.textPrimary,
      ),
      displayMedium: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 26,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: PaeColors.textPrimary,
      ),
      displaySmall: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: PaeColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: PaeColors.textPrimary,
      ),
      headlineSmall: TextStyle(
        fontFamily: fontDisplay,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: PaeColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: fontBody,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: PaeColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: fontBody,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: PaeColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontFamily: fontBody,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: PaeColors.textSecondary,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontBody,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: PaeColors.textPrimary,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontBody,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: PaeColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontFamily: fontBody,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: PaeColors.textSecondary,
      ),
      labelLarge: TextStyle(
        fontFamily: fontBody,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      labelSmall: TextStyle(
        fontFamily: fontBody,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.8,
      ),
    ),
  );
}

// ── Theme Builders ────────────────────────────────────────────────────────────
ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PaeColors.primary,
    brightness: Brightness.light,
    primary: PaeColors.primary,
    secondary: PaeColors.accent,
    surface: PaeColors.surfaceLight,
    error: PaeColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: PaeTypography.textTheme,
    scaffoldBackgroundColor: PaeColors.bgLight,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: PaeColors.textLight,
      elevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PaeColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: PaeTypography.fontBody,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: PaeColors.primary,
        side: const BorderSide(color: PaeColors.primary, width: 1.5),
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PaeColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PaeColors.divider, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PaeColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PaeColors.error, width: 1.5),
      ),
      labelStyle: const TextStyle(
        color: PaeColors.textSecondary,
        fontFamily: PaeTypography.fontBody,
        fontSize: 14,
      ),
      hintStyle: const TextStyle(
        color: PaeColors.inactive,
        fontFamily: PaeTypography.fontBody,
        fontSize: 14,
      ),
      prefixIconColor: PaeColors.primary,
    ),
    cardTheme: CardThemeData(
      color: PaeColors.cardLight,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: PaeColors.divider, width: 1),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      selectedColor: PaeColors.primary.withValues(alpha: 0.15),
      backgroundColor: PaeColors.bgLight,
      labelStyle: const TextStyle(
        fontFamily: PaeTypography.fontBody,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: PaeColors.primary,
      ),
      side: const BorderSide(color: PaeColors.primaryLight, width: 1),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: PaeColors.primary,
      unselectedItemColor: PaeColors.inactive,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(
        fontFamily: PaeTypography.fontBody,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: PaeTypography.fontBody,
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: PaeColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),
    dividerTheme: const DividerThemeData(
      color: PaeColors.divider,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: PaeColors.primaryDark,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontFamily: PaeTypography.fontBody,
        fontSize: 14,
      ),
    ),
  );
}

ThemeData buildDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PaeColors.primary,
    brightness: Brightness.dark,
    primary: PaeColors.primaryLight,
    secondary: PaeColors.accent,
    surface: PaeColors.surfaceDark,
    error: PaeColors.error,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: PaeTypography.textTheme.apply(
      bodyColor: Colors.white,
      displayColor: Colors.white,
    ),
    scaffoldBackgroundColor: PaeColors.bgDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: PaeColors.primaryLight,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PaeColors.cardDark,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: PaeColors.primaryLight.withValues(alpha: 0.3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: PaeColors.primaryLight.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: PaeColors.accent, width: 2),
      ),
      labelStyle: TextStyle(color: PaeColors.accent.withValues(alpha: 0.8)),
      prefixIconColor: PaeColors.accent,
    ),
    cardTheme: CardThemeData(
      color: PaeColors.cardDark,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: PaeColors.primaryLight.withValues(alpha: 0.2)),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: PaeColors.surfaceDark,
      selectedItemColor: PaeColors.accent,
      unselectedItemColor: PaeColors.textSecondary.withValues(alpha: 0.5),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
  );
}
