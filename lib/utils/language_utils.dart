/// Language utilities for multi-language support
/// Provides language names, native names, and flags for all supported Asian languages

class LanguageUtils {
  /// Language data mapping
  static const Map<String, Map<String, String>> _languageData = {
    'thai': {
      'name': 'Thai',
      'nativeName': 'ไทย',
      'flag': '🇹🇭',
    },
    'chinese': {
      'name': 'Chinese',
      'nativeName': '中文',
      'flag': '🇨🇳',
    },
    'japanese': {
      'name': 'Japanese',
      'nativeName': '日本語',
      'flag': '🇯🇵',
    },
    'korean': {
      'name': 'Korean',
      'nativeName': '한국어',
      'flag': '🇰🇷',
    },
    'vietnamese': {
      'name': 'Vietnamese',
      'nativeName': 'Tiếng Việt',
      'flag': '🇻🇳',
    },
    'mandarin': {
      'name': 'Chinese',
      'nativeName': '中文',
      'flag': '🇨🇳',
    },
  };

  /// Get the display name for a language code
  /// e.g., 'thai' -> 'Thai'
  static String getLanguageName(String? languageCode) {
    if (languageCode == null) return 'Language';
    return _languageData[languageCode.toLowerCase()]?['name'] ?? 'Language';
  }

  /// Get the native name for a language code
  /// e.g., 'thai' -> 'ไทย'
  static String getNativeName(String? languageCode) {
    if (languageCode == null) return '';
    return _languageData[languageCode.toLowerCase()]?['nativeName'] ?? '';
  }

  /// Get the flag emoji for a language code
  /// e.g., 'thai' -> '🇹🇭'
  static String getLanguageFlag(String? languageCode) {
    if (languageCode == null) return '🌏';
    return _languageData[languageCode.toLowerCase()]?['flag'] ?? '🌏';
  }

  /// Get both name and native name formatted for display
  /// e.g., 'thai' -> 'Thai (ไทย)'
  static String getFormattedLanguageName(String? languageCode) {
    final name = getLanguageName(languageCode);
    final nativeName = getNativeName(languageCode);
    return nativeName.isNotEmpty ? '$name ($nativeName)' : name;
  }

  /// Check if a language is supported
  static bool isLanguageSupported(String? languageCode) {
    if (languageCode == null) return false;
    return _languageData.containsKey(languageCode.toLowerCase());
  }

  /// Get all supported language codes
  static List<String> getSupportedLanguageCodes() {
    return _languageData.keys.toList();
  }
}