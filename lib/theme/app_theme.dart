import 'package:flutter/material.dart';
import 'package:babblelon/theme/unified_dark_theme.dart';

/// Unified theme configuration for BabbleOn
/// Now implements modern dark theme for sophisticated language learning experience
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Font Families - using unified theme
  static String get titleFont => UnifiedDarkTheme.titleFont;
  static String get bodyFont => UnifiedDarkTheme.bodyFont;

  // Text Themes - using unified dark theme
  static TextTheme get textTheme => UnifiedDarkTheme.textTheme;

  // Light Theme - using unified dark theme as primary
  static ThemeData get lightTheme => UnifiedDarkTheme.darkTheme;
  
  // Dark Theme - same as light for now (we're going dark-first)
  static ThemeData get darkTheme => UnifiedDarkTheme.darkTheme;
  
  // Legacy text styles for compatibility
  static TextStyle get cartoon3DTitle => UnifiedDarkTheme.heroTitle;
  static TextStyle get cheerfulText => UnifiedDarkTheme.accentText;
}