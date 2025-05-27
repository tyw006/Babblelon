import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// A utility class for loading environment variables
class EnvLoader {
  static Map<String, String> _env = {};
  
  /// Initialize the environment loader
  static Future<void> initialize() async {
    try {
      // Load environment variables from .env file
      await dotenv.load(fileName: ".env");
      _env = dotenv.env;
      
      // Note: In a production app, you would load values from a real .env file
      // or use a secure method like loading from assets or platform-specific methods
      // This is simplified for development purposes
      
      debugPrint('Environment variables loaded successfully');
    } catch (e) {
      debugPrint('Error loading environment variables: $e');
      // Fallback to defaults or handle error as appropriate
      // For example, you might want to ensure essential variables have defaults:
      _env = {
        'SUPABASE_URL': _env['SUPABASE_URL'] ?? '',
        'SUPABASE_ANON_KEY': _env['SUPABASE_ANON_KEY'] ?? '',
        'ENABLE_ANALYTICS': _env['ENABLE_ANALYTICS'] ?? 'false',
        'DEBUG_MODE': _env['DEBUG_MODE'] ?? 'false',
      };
    }
  }
  
  /// Get a string value from the environment
  static String getString(String key, {String defaultValue = ''}) {
    return _env[key] ?? defaultValue;
  }
  
  /// Get a boolean value from the environment
  static bool getBool(String key, {bool defaultValue = false}) {
    final value = _env[key]?.toLowerCase();
    if (value == null) return defaultValue;
    return value == 'true' || value == '1' || value == 'yes';
  }
  
  /// Get an integer value from the environment
  static int getInt(String key, {int defaultValue = 0}) {
    final value = _env[key];
    if (value == null) return defaultValue;
    return int.tryParse(value) ?? defaultValue;
  }
  
  /// Get a double value from the environment
  static double getDouble(String key, {double defaultValue = 0.0}) {
    final value = _env[key];
    if (value == null) return defaultValue;
    return double.tryParse(value) ?? defaultValue;
  }
  
  /// Update environment values at runtime (for testing/development)
  static void update(Map<String, String> newValues) {
    _env.addAll(newValues);
  }
} 