import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:babblelon/theme/font_extensions.dart';

/// Unified dark theme system for BabbleOn
/// Modern, sophisticated design optimized for language learning with gaming elements
class UnifiedDarkTheme {
  // Private constructor to prevent instantiation
  UnifiedDarkTheme._();

  // ===== COLOR SYSTEM =====
  
  // Primary Dark Palette
  static const Color primaryBackground = Color(0xFF0F1419); // Rich dark background
  static const Color primarySurface = Color(0xFF1E212B); // Elevated surfaces (cards, dialogs)
  static const Color primarySurfaceVariant = Color(0xFF2A2D3A); // Subtle variations
  
  // Accent Colors
  static const Color primaryAccent = Color(0xFF6C5CE7); // Electric violet for highlights
  static const Color secondaryAccent = Color(0xFFFD79A8); // Warm coral for friendly actions
  static const Color tertiaryAccent = Color(0xFF4ECDC4); // Teal for information
  
  // Semantic Colors
  static const Color success = Color(0xFF00B894); // Emerald green for achievements
  static const Color warning = Color(0xFFFDCB6E); // Sunset orange for warnings
  static const Color error = Color(0xFFE17055); // Soft red for errors
  static const Color info = Color(0xFF74B9FF); // Light blue for information
  
  // Text Colors
  static const Color textPrimary = Color(0xFFE8E9EA); // High contrast white
  static const Color textSecondary = Color(0xFFA0A3B1); // Muted blue for secondary info
  static const Color textTertiary = Color(0xFF6C7086); // Dark gray for disabled/subtle text
  static const Color textOnColor = Color(0xFFFFFFFF); // Pure white for colored backgrounds
  
  // Border and Divider Colors
  static const Color borderPrimary = Color(0xFF3A3F4B); // Subtle borders
  static const Color borderSecondary = Color(0xFF2C3139); // Very subtle borders
  static const Color divider = Color(0xFF262B35); // Divider lines
  
  // ===== GRADIENTS =====
  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryAccent, Color(0xFF5B4DDB)], // Electric violet to deeper purple
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondaryAccent, Color(0xFFFF6B9D)], // Warm coral to pink
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [success, Color(0xFF00A085)], // Emerald to deeper green
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [primarySurface, primarySurfaceVariant], // Subtle surface variation
  );

  static const RadialGradient accentGlow = RadialGradient(
    center: Alignment.center,
    radius: 0.8,
    colors: [primaryAccent, Colors.transparent],
  );

  // Deep space gradient for crisp backgrounds without gray overlay
  static const LinearGradient deepSpaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0A0D12), // Very dark blue-black
      Color(0xFF000000), // Pure black
    ],
  );

  // Deep red gradient for prominent CTA buttons
  static const LinearGradient deepRedGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFD32F2F), // Material deep red
      Color(0xFFB71C1C), // Material darker red
    ],
  );

  // ===== TYPOGRAPHY SYSTEM =====
  
  // Font Families
  static String get titleFont => GoogleFonts.quicksand().fontFamily!;
  static String get bodyFont => GoogleFonts.nunito().fontFamily!;

  // Text Theme optimized for dark backgrounds
  static TextTheme get textTheme => TextTheme(
    // Display styles for large titles
    displayLarge: GoogleFonts.quicksand(
      fontSize: 60,
      fontWeight: FontWeight.w800,
      color: textPrimary,
      letterSpacing: -1.5,
      height: 1.1,
    ),
    displayMedium: GoogleFonts.quicksand(
      fontSize: 48,
      fontWeight: FontWeight.w700,
      color: textPrimary,
      letterSpacing: -1.0,
      height: 1.2,
    ),
    displaySmall: GoogleFonts.quicksand(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      letterSpacing: -0.5,
      height: 1.2,
    ),
    
    // Heading styles
    headlineLarge: GoogleFonts.quicksand(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      letterSpacing: -0.5,
      height: 1.3,
    ),
    headlineMedium: GoogleFonts.quicksand(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      letterSpacing: -0.3,
      height: 1.3,
    ),
    headlineSmall: GoogleFonts.quicksand(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.3,
    ),
    
    // Title styles
    titleLarge: GoogleFonts.nunito(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: textPrimary,
      height: 1.4,
    ),
    titleMedium: GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: textPrimary,
      height: 1.4,
    ),
    titleSmall: GoogleFonts.nunito(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
      letterSpacing: 0.1,
      height: 1.4,
    ),
    
    // Body styles
    bodyLarge: GoogleFonts.nunito(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: textPrimary,
      height: 1.5,
    ),
    bodyMedium: GoogleFonts.nunito(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: textSecondary,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.nunito(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: textTertiary,
      height: 1.5,
    ),
    
    // Label styles
    labelLarge: GoogleFonts.nunito(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: textPrimary,
      letterSpacing: 0.5,
    ),
    labelMedium: GoogleFonts.nunito(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: textSecondary,
      letterSpacing: 0.5,
    ),
    labelSmall: GoogleFonts.nunito(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: textTertiary,
      letterSpacing: 0.5,
    ),
  );

  // ===== SPACING SYSTEM =====
  
  // 8pt Grid System
  static const double spaceXXS = 4;   // 0.5 × 8pt
  static const double spaceXS = 8;    // 1 × 8pt base
  static const double spaceSM = 16;   // 2 × 8pt
  static const double spaceMD = 24;   // 3 × 8pt
  static const double spaceLG = 32;   // 4 × 8pt
  static const double spaceXL = 48;   // 6 × 8pt
  static const double spaceXXL = 64;  // 8 × 8pt

  // Touch Target Sizes
  static const double touchTargetMin = 48;     // Minimum touch target
  static const double touchTargetButton = 56;  // Standard button height
  static const double touchTargetLarge = 72;   // Large touch area
  
  // Border Radius
  static const double radiusXS = 8;    // Small elements
  static const double radiusSM = 12;   // Buttons, chips
  static const double radiusMD = 16;   // Cards, input fields
  static const double radiusLG = 20;   // Large cards
  static const double radiusXL = 24;   // Modals, bottom sheets
  static const double radiusXXL = 32;  // Hero elements
  static const double radiusRound = 100; // Fully rounded

  // ===== ANIMATION CONSTANTS =====
  
  static const Duration microInteraction = Duration(milliseconds: 16);
  static const Duration quickTransition = Duration(milliseconds: 200);
  static const Duration standardTransition = Duration(milliseconds: 300);
  static const Duration slowTransition = Duration(milliseconds: 500);
  static const Duration bounceTransition = Duration(milliseconds: 600);

  // Animation scales and offsets
  static const double hoverScale = 1.02;
  static const double pressScale = 0.98;
  static const double bounceOffset = 8;

  // ===== SHADOW SYSTEM =====
  
  static List<BoxShadow> get shadowSM => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.1),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowMD => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowLG => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get shadowXL => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.25),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  // Colored shadows for accents
  static List<BoxShadow> accentShadow(Color color) => [
    BoxShadow(
      color: color.withValues(alpha: 0.3),
      blurRadius: 20,
      offset: const Offset(0, 0),
    ),
  ];

  // ===== CUSTOM TEXT STYLES =====
  
  static TextStyle get heroTitle => GoogleFonts.quicksand(
    fontSize: 60,
    fontWeight: FontWeight.w800,
    color: textPrimary,
    letterSpacing: -1.5,
    shadows: [
      Shadow(
        color: primaryAccent.withValues(alpha: 0.5),
        blurRadius: 20,
        offset: const Offset(0, 0),
      ),
      Shadow(
        color: Colors.black.withValues(alpha: 0.8),
        blurRadius: 10,
        offset: const Offset(2, 2),
      ),
    ],
  );
  
  static TextStyle get accentText => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: primaryAccent,
    shadows: [
      Shadow(
        color: primaryAccent.withValues(alpha: 0.8),
        blurRadius: 10,
        offset: const Offset(0, 0),
      ),
    ],
  );

  // ===== THEME DATA =====
  
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryAccent,
    scaffoldBackgroundColor: primaryBackground,
    colorScheme: const ColorScheme.dark(
      primary: primaryAccent,
      secondary: secondaryAccent,
      tertiary: tertiaryAccent,
      surface: primarySurface,
      surfaceContainerHighest: primarySurfaceVariant,
      error: error,
      onPrimary: textOnColor,
      onSecondary: textOnColor,
      onSurface: textPrimary,
      onError: textOnColor,
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
      backgroundColor: primarySurface,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.quicksand(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    ),
    
    // Card Theme
    cardTheme: CardThemeData(
      color: primarySurface,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMD),
      ),
    ),
    
    // Bottom Navigation Theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: primarySurface,
      selectedItemColor: primaryAccent,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    
    // Dialog Theme
    dialogTheme: const DialogThemeData(
      backgroundColor: primarySurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusXL)),
      ),
    ),
    
    // Bottom Sheet Theme
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: primarySurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(radiusXL),
        ),
      ),
    ),
    
    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: primarySurfaceVariant,
      contentPadding: const EdgeInsets.all(spaceSM),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMD)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMD)),
        borderSide: BorderSide(
          color: borderPrimary,
          width: 1,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(radiusMD)),
        borderSide: BorderSide(
          color: primaryAccent,
          width: 2,
        ),
      ),
      labelStyle: GoogleFonts.nunito(
        color: textSecondary,
      ),
      hintStyle: GoogleFonts.nunito(
        color: textTertiary,
      ),
    ),
    
    // SnackBar Theme
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: primarySurface,
      contentTextStyle: TextStyle(color: textPrimary),
      actionTextColor: primaryAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
    ),
  );
  
  // Light theme variant (for future use)
  static ThemeData get lightTheme => darkTheme.copyWith(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8F9FA),
    colorScheme: const ColorScheme.light(
      primary: primaryAccent,
      secondary: secondaryAccent,
      tertiary: tertiaryAccent,
      surface: Colors.white,
      error: error,
      onPrimary: textOnColor,
      onSecondary: textOnColor,
      onSurface: Color(0xFF1A1B2E),
      onError: textOnColor,
    ),
  );
}