import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:babblelon/widgets/modern_design_system.dart';
import 'package:babblelon/theme/font_extensions.dart';

/// Unified theme configuration for BabbleOn
/// Implements the space-themed, futuristic design system
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Font Families
  static String get titleFont => GoogleFonts.exo2().fontFamily!;
  static String get bodyFont => GoogleFonts.poppins().fontFamily!;

  // Text Themes
  static TextTheme get textTheme => TextTheme(
    // Display styles for large titles
    displayLarge: GoogleFonts.exo2(
      fontSize: 60,
      fontWeight: FontWeight.w800,
      color: ModernDesignSystem.ghostWhite,
      letterSpacing: -1.5,
      height: 1.1,
    ),
    displayMedium: GoogleFonts.exo2(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      color: ModernDesignSystem.ghostWhite,
      letterSpacing: -1.0,
      height: 1.2,
    ),
    displaySmall: GoogleFonts.exo2(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: ModernDesignSystem.ghostWhite,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    
    // Heading styles
    headlineLarge: GoogleFonts.exo2(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: ModernDesignSystem.ghostWhite,
      letterSpacing: -0.5,
      height: 1.3,
    ),
    headlineMedium: GoogleFonts.exo2(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: ModernDesignSystem.ghostWhite,
      letterSpacing: -0.3,
      height: 1.3,
    ),
    headlineSmall: GoogleFonts.exo2(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: ModernDesignSystem.ghostWhite,
      height: 1.3,
    ),
    
    // Title styles
    titleLarge: GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: ModernDesignSystem.ghostWhite,
      height: 1.4,
    ),
    titleMedium: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: ModernDesignSystem.ghostWhite,
      height: 1.4,
    ),
    titleSmall: GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: ModernDesignSystem.ghostWhite,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    
    // Body styles
    bodyLarge: GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: ModernDesignSystem.ghostWhite,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: ModernDesignSystem.ghostWhite,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: ModernDesignSystem.ghostWhite,
      height: 1.5,
    ),
    
    // Label styles
    labelLarge: GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: ModernDesignSystem.ghostWhite,
      letterSpacing: 0.5,
    ),
    labelMedium: GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: ModernDesignSystem.ghostWhite,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.poppins(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: ModernDesignSystem.ghostWhite,
      letterSpacing: 0.5,
    ),
  );

  // Light Theme
  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.dark, // Using dark brightness for space theme
    primaryColor: ModernDesignSystem.electricCyan,
    scaffoldBackgroundColor: ModernDesignSystem.deepSpaceBlue,
    colorScheme: const ColorScheme.dark(
      primary: ModernDesignSystem.electricCyan,
      secondary: ModernDesignSystem.warmOrange,
      surface: ModernDesignSystem.deepSpaceBlue,
      error: Colors.red,
      onPrimary: ModernDesignSystem.deepSpaceBlue,
      onSecondary: ModernDesignSystem.deepSpaceBlue,
      onSurface: ModernDesignSystem.ghostWhite,
      onError: Colors.white,
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
      backgroundColor: ModernDesignSystem.deepSpaceBlue,
      foregroundColor: ModernDesignSystem.ghostWhite,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.exo2(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: ModernDesignSystem.ghostWhite,
      ),
    ),
    
    // Elevated Button Theme
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: ModernDesignSystem.electricCyan,
        foregroundColor: ModernDesignSystem.deepSpaceBlue,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
        ),
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        elevation: 0,
      ),
    ),
    
    // Text Button Theme
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ModernDesignSystem.electricCyan,
        textStyle: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    
    // Card Theme
    cardTheme: CardThemeData(
      color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
      ),
    ),
    
    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.5),
      contentPadding: const EdgeInsets.all(16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ModernDesignSystem.radiusSmall),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ModernDesignSystem.radiusSmall),
        borderSide: BorderSide(
          color: ModernDesignSystem.slateGray.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(ModernDesignSystem.radiusSmall),
        borderSide: const BorderSide(
          color: ModernDesignSystem.electricCyan,
          width: 2,
        ),
      ),
      labelStyle: GoogleFonts.poppins(
        color: ModernDesignSystem.slateGray,
      ),
      hintStyle: GoogleFonts.poppins(
        color: ModernDesignSystem.slateGray.withValues(alpha: 0.7),
      ),
    ),
  );
  
  // Dark Theme (same as light for now since we're using a space theme)
  static ThemeData get darkTheme => lightTheme;
  
  // Custom Text Styles
  static TextStyle get space3DTitle => GoogleFonts.exo2(
    fontSize: 60,
    fontWeight: FontWeight.w800,
    color: ModernDesignSystem.ghostWhite,
    letterSpacing: -1.5,
    shadows: [
      Shadow(
        color: ModernDesignSystem.electricCyan.withValues(alpha: 0.5),
        blurRadius: 20,
        offset: const Offset(0, 0),
      ),
      const Shadow(
        color: Colors.black,
        blurRadius: 10,
        offset: Offset(2, 2),
      ),
    ],
  );
  
  static TextStyle get glowingText => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: ModernDesignSystem.electricCyan,
    shadows: [
      Shadow(
        color: ModernDesignSystem.electricCyan.withValues(alpha: 0.8),
        blurRadius: 10,
        offset: const Offset(0, 0),
      ),
    ],
  );
}