import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppStyles {
  static const Color primaryColor = Color(0xFF1F1F1F);
  static const Color secondaryColor = Color(0xFF2D2D2D);
  static const Color accentColor = Color(0xFF4ECCA3);
  static const Color textColor = Colors.white;
  static const Color subtitleTextColor = Colors.white70;
  static const Color indicatorColor = Colors.white38;

  static final BoxDecoration cardDecoration = BoxDecoration(
    color: primaryColor,
    borderRadius: BorderRadius.circular(16.0),
    border: Border.all(
      color: Colors.white.withOpacity(0.15),
      width: 1.0,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.7),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static final BoxDecoration flashcardDecoration = BoxDecoration(
    color: const Color(0xFF2D2D2D),
    borderRadius: BorderRadius.circular(16.0),
    border: Border.all(
      color: Colors.white.withOpacity(0.1),
      width: 1.0,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.5),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static final TextStyle titleTextStyle = GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textColor,
  );

  static final TextStyle subtitleTextStyle = GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: textColor,
  );

  static final TextStyle bodyTextStyle = GoogleFonts.poppins(
    fontSize: 16,
    color: subtitleTextColor,
  );

  static final TextStyle smallTextStyle = GoogleFonts.poppins(
    fontSize: 14,
    color: subtitleTextColor,
  );

  static final TextStyle flashcardThaiTextStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: textColor,
  );

  static final TextStyle flashcardTransliterationTextStyle = smallTextStyle.copyWith(
    fontStyle: FontStyle.italic,
  );

  static final ThemeData mainTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: const Color(0xFF121212),
    colorScheme: const ColorScheme.dark(
      primary: accentColor,
      secondary: secondaryColor,
      surface: primaryColor,
      onPrimary: Colors.black,
      onSecondary: Colors.white,
      onSurface: Colors.white,
      onError: Colors.white,
      background: Color(0xFF121212), 
      error: Colors.redAccent,
    ),
    textTheme: TextTheme(
      displayLarge: titleTextStyle.copyWith(fontSize: 32),
      displayMedium: titleTextStyle.copyWith(fontSize: 28),
      displaySmall: titleTextStyle.copyWith(fontSize: 24),
      headlineMedium: subtitleTextStyle.copyWith(fontSize: 20),
      headlineSmall: subtitleTextStyle.copyWith(fontSize: 18),
      titleLarge: subtitleTextStyle.copyWith(fontSize: 16),
      bodyLarge: bodyTextStyle,
      bodyMedium: bodyTextStyle.copyWith(fontSize: 14),
      labelLarge: bodyTextStyle.copyWith(fontWeight: FontWeight.bold, color: Colors.black),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: primaryButtonStyle),
    outlinedButtonTheme: OutlinedButtonThemeData(style: secondaryButtonStyle),
    dialogTheme: DialogThemeData(
      backgroundColor: primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: secondaryColor,
      foregroundColor: textColor,
      elevation: 0,
      titleTextStyle: subtitleTextStyle,
    ),
  );

  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: accentColor,
    foregroundColor: Colors.black,
    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
    ),
    elevation: 3,
  );

  static final ButtonStyle secondaryButtonStyle = OutlinedButton.styleFrom(
    foregroundColor: textColor,
    side: BorderSide(color: Colors.white.withOpacity(0.3)),
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8.0),
    ),
  );
}