import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom font extensions for BabbleOn Modern 2025
/// Provides themed fonts matching modern mobile game design trends
class BabbleFonts {
  // Logo fonts - modern geometric style
  static TextStyle get logo => GoogleFonts.inter(
    fontSize: 56,
    fontWeight: FontWeight.w800, // ExtraBold
    height: 1.1,
    letterSpacing: 1.5, // Increased spacing for modern look
  );

  static TextStyle get logoAlternate => GoogleFonts.workSans(
    fontSize: 56,
    fontWeight: FontWeight.w800, // ExtraBold
    height: 1.1,
    letterSpacing: 1.5, // Increased spacing for modern look
  );

  // Tagline verb fonts - for highlighted words like "Live", "Learn"
  static TextStyle get taglineVerb => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600, // SemiBold
    height: 1.3,
    letterSpacing: 0.5, // Slightly increased for modern look
  );

  // Tagline particle fonts - for supporting text like "the City", "the Language"
  static TextStyle get taglineParticle => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    height: 1.5,
    letterSpacing: 0.2, // Subtle spacing for readability
  );

  // Color constants from design guide
  static const Color butterYellow = Color(0xFFFFE07B);
  static const Color cherryRed = Color(0xFFFF4F4F);
  static const Color navyOutline = Color(0xFF0D1B2A);
  static const Color auraIndigo = Color(0xFF3A67FF);
}

/// Theme extension for easy access to custom fonts
class BabbleFontTheme extends ThemeExtension<BabbleFontTheme> {
  const BabbleFontTheme({
    required this.logo,
    required this.logoAlternate,
    required this.taglineVerb,
    required this.taglineParticle,
  });

  final TextStyle logo;
  final TextStyle logoAlternate;
  final TextStyle taglineVerb;
  final TextStyle taglineParticle;

  @override
  ThemeExtension<BabbleFontTheme> copyWith({
    TextStyle? logo,
    TextStyle? logoAlternate,
    TextStyle? taglineVerb,
    TextStyle? taglineParticle,
  }) {
    return BabbleFontTheme(
      logo: logo ?? this.logo,
      logoAlternate: logoAlternate ?? this.logoAlternate,
      taglineVerb: taglineVerb ?? this.taglineVerb,
      taglineParticle: taglineParticle ?? this.taglineParticle,
    );
  }

  @override
  ThemeExtension<BabbleFontTheme> lerp(
    ThemeExtension<BabbleFontTheme>? other,
    double t,
  ) {
    if (other is! BabbleFontTheme) return this;
    return BabbleFontTheme(
      logo: TextStyle.lerp(logo, other.logo, t)!,
      logoAlternate: TextStyle.lerp(logoAlternate, other.logoAlternate, t)!,
      taglineVerb: TextStyle.lerp(taglineVerb, other.taglineVerb, t)!,
      taglineParticle: TextStyle.lerp(taglineParticle, other.taglineParticle, t)!,
    );
  }

  /// Default font theme
  static const BabbleFontTheme defaultTheme = BabbleFontTheme(
    logo: TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: 1.5,
    ),
    logoAlternate: TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: 1.5,
    ),
    taglineVerb: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.3,
      letterSpacing: 0.5,
    ),
    taglineParticle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0.2,
    ),
  );
}