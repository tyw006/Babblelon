import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Custom font extensions for BabbleOn Cartoon 2025
/// Provides themed fonts matching playful cartoon game design
class BabbleFonts {
  // Logo fonts - rounded, friendly style
  static TextStyle get logo => GoogleFonts.quicksand(
    fontSize: 56,
    fontWeight: FontWeight.w800, // ExtraBold
    height: 1.1,
    letterSpacing: 1.5, // Increased spacing for friendly look
  );

  static TextStyle get logoAlternate => GoogleFonts.quicksand(
    fontSize: 56,
    fontWeight: FontWeight.w700, // Bold
    height: 1.1,
    letterSpacing: 1.2, // Slightly less spacing for alternate
  );

  // Tagline verb fonts - for highlighted words like "Live", "Learn"
  static TextStyle get taglineVerb => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w700, // Bold for emphasis
    height: 1.3,
    letterSpacing: 0.3, // Friendly spacing
  );

  // Tagline particle fonts - for supporting text like "the City", "the Language"
  static TextStyle get taglineParticle => GoogleFonts.nunito(
    fontSize: 16,
    fontWeight: FontWeight.w400, // Regular
    height: 1.5,
    letterSpacing: 0.1, // Subtle spacing for readability
  );

  // Color constants from cartoon design guide
  static const Color sunshineYellow = Color(0xFFFFD700);
  static const Color cherryRed = Color(0xFFFF4757);
  static const Color chocolateBrown = Color(0xFF8D6E63);
  static const Color warmOrange = Color(0xFFFFA726);
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

  /// Default font theme - cartoon style
  static const BabbleFontTheme defaultTheme = BabbleFontTheme(
    logo: TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: 1.5,
      fontFamily: 'Quicksand',
    ),
    logoAlternate: TextStyle(
      fontSize: 56,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: 1.2,
      fontFamily: 'Quicksand',
    ),
    taglineVerb: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: 0.3,
      fontFamily: 'Nunito',
    ),
    taglineParticle: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      letterSpacing: 0.1,
      fontFamily: 'Nunito',
    ),
  );
}