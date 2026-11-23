import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Paleta ───────────────────────────────────────────────────────────────────
/// Colores de PAEGo: los mismos del panel web (`oPAEGo/backend/static/css/
/// tokens.css`, sistema de diseño GOV.CO). Si cambia uno allá, cambiarlo aquí.
class PaeColors {
  // Marca GOV.CO
  static const primary = Color(0xFF3366CC); // --govco-azul
  static const primaryDark = Color(0xFF004884); // --govco-azul-oscuro
  static const primaryLight = Color(0xFF6B93E0); // azul legible en tema oscuro
  static const primarySoft = Color(0xFFE8EFFB); // --govco-azul-claro

  // Acento: el mismo azul (la web no usa un segundo color de marca).
  static const accent = Color(0xFF3366CC);
  static const accentLight = Color(0xFF6B93E0);

  static const secondary = Color(0xFF004884);
  static const secondaryLight = Color(0xFF3366CC);

  // Encabezados: azul institucional plano (la web no usa degradados).
  static const gradStart = Color(0xFF004884);
  static const gradMid = Color(0xFF004884);
  static const gradEnd = Color(0xFF004884);

  // Fondos y superficies
  static const bgLight = Color(0xFFF2F4F7); // --fondo
  static const bgDark = Color(0xFF0B1626);
  static const surfaceLight = Color(0xFFFFFFFF); // --superficie
  static const surfaceDark = Color(0xFF12223A);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF172A45);

  // Retroalimentación
  static const success = Color(0xFF05785A); // --ok
  static const warning = Color(0xFFB25E00);
  static const error = Color(0xFFA80521); // --error
  static const info = Color(0xFF3366CC);
  static const focus = Color(0xFFFFAB00); // --foco

  // Estados del envío (iguales a la web, RF-18)
  static const statusPending = Color(0xFF8A5300); // --aviso
  static const statusAssigned = Color(0xFF3366CC); // --e-asignado
  static const statusEnRoute = Color(0xFFB25E00); // --e-transito
  static const statusDelivered = Color(0xFF05785A); // --e-entregado
  static const statusNovedad = Color(0xFFC2410C); // --e-novedad
  static const statusCancelado = Color(0xFF6B7280); // --e-cancelado

  // Tinta y neutros
  static const textPrimary = Color(0xFF1B1B1B); // --tinta
  static const textSecondary = Color(0xFF5F6672); // --tinta-3
  static const textLight = Color(0xFFFFFFFF);
  static const divider = Color(0xFFE1E5EB); // --borde
  static const inactive = Color(0xFFB8BEC8); // --borde-fuerte

  // "Degradados" planos: se conservan los nombres para no tocar las pantallas.
  static const primaryGradient = LinearGradient(colors: [gradStart, gradEnd]);
  static const heroGradient = LinearGradient(colors: [gradStart, gradEnd]);
  static const cardGradient = LinearGradient(
    colors: [primaryDark, primaryDark],
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
