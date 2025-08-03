import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';
import 'package:babblelon/theme/font_extensions.dart';

/// Unified theme configuration for BabbleOn
/// Implements the cartoon-themed, playful design system
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Font Families
  static String get titleFont => GoogleFonts.quicksand().fontFamily!;
  static String get bodyFont => GoogleFonts.nunito().fontFamily!;

  // Text Themes
  static TextTheme get textTheme => TextTheme(
    // Display styles for large titles
    displayLarge: GoogleFonts.quicksand(
      fontSize: 60,
      fontWeight: FontWeight.w800,
      color: CartoonDesignSystem.textPrimary,
      letterSpacing: -1.5,
      height: 1.1,
    ),
    displayMedium: GoogleFonts.quicksand(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      color: CartoonDesignSystem.textPrimary,
      letterSpacing: -1.0,
      height: 1.2,
    ),
    displaySmall: GoogleFonts.quicksand(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: CartoonDesignSystem.textPrimary,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    
    // Heading styles
    headlineLarge: GoogleFonts.quicksand(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: CartoonDesignSystem.textPrimary,
      letterSpacing: -0.5,
      height: 1.3,
    ),
    headlineMedium: GoogleFonts.quicksand(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: CartoonDesignSystem.textPrimary,
      letterSpacing: -0.3,
      height: 1.3,
    ),
    headlineSmall: GoogleFonts.quicksand(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: CartoonDesignSystem.textPrimary,
      height: 1.3,
    ),
    
    // Title styles
    titleLarge: GoogleFonts.nunito(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: CartoonDesignSystem.textPrimary,
      height: 1.4,
    ),
    titleMedium: GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: CartoonDesignSystem.textPrimary,
      height: 1.4,
    ),
    titleSmall: GoogleFonts.nunito(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: CartoonDesignSystem.textPrimary,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    
    // Body styles
    bodyLarge: GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: CartoonDesignSystem.textPrimary,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.nunito(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: CartoonDesignSystem.textPrimary,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.nunito(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: CartoonDesignSystem.textPrimary,
      height: 1.5,
    ),
    
    // Label styles
    labelLarge: GoogleFonts.nunito(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: CartoonDesignSystem.textPrimary,
      letterSpacing: 0.5,
    ),
    labelMedium: GoogleFonts.nunito(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: CartoonDesignSystem.textPrimary,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.nunito(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: CartoonDesignSystem.textPrimary,
      letterSpacing: 0.5,
    ),
  );

  // Light Theme
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light, // Using light brightness for cartoon theme
    primaryColor: CartoonDesignSystem.sunshineYellow,
    scaffoldBackgroundColor: CartoonDesignSystem.creamWhite,
    colorScheme: const ColorScheme.light(
      primary: CartoonDesignSystem.sunshineYellow,
      secondary: CartoonDesignSystem.cherryRed,
      surface: CartoonDesignSystem.softPeach,
      error: CartoonDesignSystem.cherryRed,
      onPrimary: CartoonDesignSystem.textPrimary,
      onSecondary: CartoonDesignSystem.textOnBright,
      onSurface: CartoonDesignSystem.textPrimary,
      onError: CartoonDesignSystem.textOnBright,
    ),
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[
      BabbleFontTheme(
        logo: BabbleFonts.logo,
        logoAlternate: BabbleFonts.logoAlternate,
        taglineVerb: BabbleFonts.taglineVerb,
        taglineParticle: BabbleFonts.taglineParticle,
      ),
    ],
    
    // App Bar Theme
    appBarTheme: AppBarTheme(
      backgroundColor: CartoonDesignSystem.creamWhite,
      foregroundColor: CartoonDesignSystem.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.quicksand(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: CartoonDesignSystem.textPrimary,
      ),
    ),
    
    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: CartoonDesignSystem.sunshineYellow,
        foregroundColor: CartoonDesignSystem.textPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusSmall),
        ),
        textStyle: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        elevation: 4,
      ),
    ),
    
    // Text Button Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: CartoonDesignSystem.cherryRed,
        textStyle: GoogleFonts.nunito(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    
    // Card Theme
    cardTheme: CardThemeData(
      color: CartoonDesignSystem.softPeach,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
      ),
    ),
    
    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: CartoonDesignSystem.softPeach.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusSmall),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusSmall),
        borderSide: BorderSide(
          color: CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusSmall),
        borderSide: const BorderSide(
          color: CartoonDesignSystem.cherryRed,
          width: 2,
        ),
      ),
      labelStyle: GoogleFonts.nunito(
        color: CartoonDesignSystem.textSecondary,
      ),
      hintStyle: GoogleFonts.nunito(
        color: CartoonDesignSystem.textMuted,
      ),
    ),
  );
  
  // Dark Theme (same as light for now since we're using a cartoon theme)
  static ThemeData get darkTheme => lightTheme;
  
  // Custom Text Styles
  static TextStyle get cartoon3DTitle => GoogleFonts.quicksand(
    fontSize: 60,
    fontWeight: FontWeight.w800,
    color: CartoonDesignSystem.textPrimary,
    letterSpacing: -1.5,
    shadows: [
      Shadow(
        color: CartoonDesignSystem.sunshineYellow.withValues(alpha: 0.5),
        blurRadius: 20,
        offset: const Offset(0, 0),
      ),
      const Shadow(
        color: CartoonDesignSystem.chocolateBrown,
        blurRadius: 10,
        offset: Offset(2, 2),
      ),
    ],
  );
  
  static TextStyle get cheerfulText => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: CartoonDesignSystem.cherryRed,
    shadows: [
      Shadow(
        color: CartoonDesignSystem.cherryRed.withValues(alpha: 0.8),
        blurRadius: 10,
        offset: const Offset(0, 0),
      ),
    ],
  );
}