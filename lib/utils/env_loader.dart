import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A utility class for loading environment variables
class EnvLoader {
  static Map<String, String> _env = {};
  
  /// Initialize the environment loader
  static Future<void> initialize() async {
    try {
      // In a real implementation, we would load from a real .env file
      // For now, we'll use hardcoded values that match our actual Supabase project
      _env = {
        'SUPABASE_URL': 'https://odhtvjzaopqurehepkry.supabase.co',
        'SUPABASE_ANON_KEY': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9kaHR2anphb3BxdXJlaGVwa3J5Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc0MDgzNjIsImV4cCI6MjA2Mjk4NDM2Mn0._TWZ45XOMgsXQPEbezJBpnujAGjZX2_-0xbwX5IjDZE',
        'ENABLE_ANALYTICS': 'true',
        'DEBUG_MODE': 'false',
      };
      
      // Note: In a production app, you would load values from a real .env file
      // or use a secure method like loading from assets or platform-specific methods
      // This is simplified for development purposes
      
      debugPrint('Environment variables loaded successfully');
    } catch (e) {
      debugPrint('Error loading environment variables: $e');
      // Fallback to defaults
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