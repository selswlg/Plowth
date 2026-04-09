import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Plowth App Design System
/// Premium, dark-first design with vibrant accent colors.

class AppColors {
  // ─── Primary Palette ───
  static const primary = Color(0xFF6C5CE7); // Vibrant purple
  static const primaryLight = Color(0xFF8B7CF6);
  static const primaryDark = Color(0xFF5A4BD1);

  // ─── Accent ───
  static const accent = Color(0xFF00D2FF); // Cyan accent
  static const accentGreen = Color(0xFF00E676); // Success green
  static const accentOrange = Color(0xFFFF9100); // Warning orange
  static const accentRed = Color(0xFFFF5252); // Error/Again red

  // ─── Rating Colors ───
  static const ratingAgain = Color(0xFFFF5252);
  static const ratingHard = Color(0xFFFF9100);
  static const ratingGood = Color(0xFF00E676);
  static const ratingEasy = Color(0xFF00B0FF);

  // ─── Surfaces (Dark Theme) ───
  static const background = Color(0xFF0D0D1A);
  static const surface = Color(0xFF1A1A2E);
  static const surfaceLight = Color(0xFF242442);
  static const surfaceCard = Color(0xFF16162A);
  static const surfaceElevated = Color(0xFF2A2A4A);

  // ─── Text ───
  static const textPrimary = Color(0xFFF5F5F7);
  static const textSecondary = Color(0xFFB0B0C8);
  static const textTertiary = Color(0xFF6B6B8A);
  static const textOnPrimary = Color(0xFFFFFFFF);

  // ─── Borders ───
  static const border = Color(0xFF2E2E4A);
  static const borderLight = Color(0xFF3A3A5E);

  // ─── Gradients ───
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF6C5CE7), Color(0xFF00D2FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16162A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTypography {
  static TextStyle get displayLarge => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle get displayMedium => GoogleFonts.outfit(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle get headlineLarge => GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get headlineMedium => GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );

  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: 0.5,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textTertiary,
    letterSpacing: 0.5,
  );

  static TextStyle get button => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnPrimary,
  );
}

class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class AppRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double full = 100;
}

class AppShadows {
  static List<BoxShadow> get subtle => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get medium => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get glow => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.3),
      blurRadius: 20,
      spreadRadius: -2,
    ),
  ];
}

/// Build the app-wide dark theme
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.accentRed,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppTypography.headlineMedium,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textTertiary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    cardTheme: CardTheme(
      color: AppColors.surfaceCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        textStyle: AppTypography.button,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      hintStyle: AppTypography.bodyMedium,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
  );
}
