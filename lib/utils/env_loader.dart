/// A utility class for loading environment variables
class EnvLoader {
  static Map<String, String> _env = {};
  
  /// Initialize the environment loader
  static Future<void> initialize() async {
    // In a real implementation, this would load from .env or Flutter's assets
    // For now, we'll use hardcoded values
    _env = {
      'SUPABASE_URL': '',
      'SUPABASE_ANON_KEY': '',
      'ENABLE_ANALYTICS': 'true',
      'DEBUG_MODE': 'false',
    };
    
    // Simulating async loading
    await Future.delayed(const Duration(milliseconds: 100));
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