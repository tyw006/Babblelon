import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Authentication provider types
enum AuthProvider {
  apple,
  google,
  email,
  github,
}

/// Authentication result wrapper
class AuthResult {
  final bool success;
  final String? userId;
  final String? email;
  final String? error;
  final bool isEmailVerified;

  const AuthResult({
    required this.success,
    this.userId,
    this.email,
    this.error,
    this.isEmailVerified = false,
  });

  factory AuthResult.success({
    required String userId,
    String? email,
    bool isEmailVerified = false,
  }) {
    return AuthResult(
      success: true,
      userId: userId,
      email: email,
      isEmailVerified: isEmailVerified,
    );
  }

  factory AuthResult.failure(String error) {
    return AuthResult(
      success: false,
      error: error,
    );
  }
}

/// Authentication state
enum AuthState {
  authenticated,
  unauthenticated,
  loading,
  error,
}

/// Platform-aware authentication service
class AuthenticationService {
  /// Get available authentication providers based on current platform
  List<AuthProvider> getAvailableProviders() {
    if (kIsWeb) {
      return [
        AuthProvider.google,    // Primary for web (71% preference)
        AuthProvider.email,     // Universal fallback
        AuthProvider.github,    // Popular with tech users
      ];
    } else if (Platform.isIOS) {
      return [
        AuthProvider.apple,     // Primary for iOS (App Store compliance)
        AuthProvider.email,     // Universal fallback
      ];
    } else if (Platform.isAndroid) {
      return [
        AuthProvider.google,    // Primary for Android
        AuthProvider.email,     // Universal fallback
      ];
    } else {
      // Desktop or other platforms
      return [
        AuthProvider.email,
      ];
    }
  }

  /// Get primary authentication provider for current platform
  AuthProvider getPrimaryProvider() {
    if (kIsWeb) {
      return AuthProvider.google;
    } else if (Platform.isIOS) {
      return AuthProvider.apple;
    } else {
      return AuthProvider.google;
    }
  }

  /// Check if email verification is required for the given provider
  bool requiresEmailVerification(AuthProvider provider) {
    switch (provider) {
      case AuthProvider.apple:
        return false; // Apple IDs are pre-verified
      case AuthProvider.google:
        return false; // Google accounts are pre-verified
      case AuthProvider.github:
        return false; // GitHub accounts are pre-verified
      case AuthProvider.email:
        return true;  // Email/password requires verification
    }
  }

  /// Get display name for authentication provider
  String getProviderDisplayName(AuthProvider provider) {
    switch (provider) {
      case AuthProvider.apple:
        return 'Continue with Apple';
      case AuthProvider.google:
        return 'Continue with Google';
      case AuthProvider.github:
        return 'Continue with GitHub';
      case AuthProvider.email:
        return 'Continue with Email';
    }
  }

  /// Get icon name for authentication provider
  String getProviderIcon(AuthProvider provider) {
    switch (provider) {
      case AuthProvider.apple:
        return 'assets/icons/apple_logo.png';
      case AuthProvider.google:
        return 'assets/icons/google_logo.png';
      case AuthProvider.github:
        return 'assets/icons/github_logo.png';
      case AuthProvider.email:
        return 'assets/icons/email_icon.png';
    }
  }

  /// Check if provider is supported on current platform
  bool isProviderSupported(AuthProvider provider) {
    final availableProviders = getAvailableProviders();
    return availableProviders.contains(provider);
  }

  /// Get platform-specific configuration
  AuthPlatformConfig getPlatformConfig() {
    if (kIsWeb) {
      return WebAuthConfig();
    } else if (Platform.isIOS) {
      return IOSAuthConfig();
    } else if (Platform.isAndroid) {
      return AndroidAuthConfig();
    } else {
      return DefaultAuthConfig();
    }
  }
}

/// Platform-specific authentication configuration
abstract class AuthPlatformConfig {
  List<AuthProvider> get primaryProviders;
  bool get requireEmailVerification;
  String get redirectUrl;
  Duration get sessionTimeout;
  bool get supportsBiometric;
  bool get supportsPasswordManager;
}

/// Web platform authentication configuration
class WebAuthConfig extends AuthPlatformConfig {
  @override
  List<AuthProvider> get primaryProviders => [
    AuthProvider.google,
    AuthProvider.email,
    AuthProvider.github,
  ];

  @override
  bool get requireEmailVerification => true;

  @override
  String get redirectUrl => 'https://odhtvjzaopqurehepkry.supabase.co/auth/v1/callback';

  @override
  Duration get sessionTimeout => const Duration(days: 30); // Longer for web

  @override
  bool get supportsBiometric => false;

  @override
  bool get supportsPasswordManager => true;
}

/// iOS platform authentication configuration
class IOSAuthConfig extends AuthPlatformConfig {
  @override
  List<AuthProvider> get primaryProviders => [
    AuthProvider.apple,
    AuthProvider.email,
  ];

  @override
  bool get requireEmailVerification => false; // Apple IDs pre-verified

  @override
  String get redirectUrl => 'https://odhtvjzaopqurehepkry.supabase.co/auth/v1/callback';

  @override
  Duration get sessionTimeout => const Duration(days: 7); // Shorter for mobile

  @override
  bool get supportsBiometric => true;

  @override
  bool get supportsPasswordManager => true;
}

/// Android platform authentication configuration
class AndroidAuthConfig extends AuthPlatformConfig {
  @override
  List<AuthProvider> get primaryProviders => [
    AuthProvider.google,
    AuthProvider.email,
  ];

  @override
  bool get requireEmailVerification => false; // Google accounts pre-verified

  @override
  String get redirectUrl => 'https://odhtvjzaopqurehepkry.supabase.co/auth/v1/callback';

  @override
  Duration get sessionTimeout => const Duration(days: 7);

  @override
  bool get supportsBiometric => true;

  @override
  bool get supportsPasswordManager => true;
}

/// Default platform authentication configuration
class DefaultAuthConfig extends AuthPlatformConfig {
  @override
  List<AuthProvider> get primaryProviders => [AuthProvider.email];

  @override
  bool get requireEmailVerification => true;

  @override
  String get redirectUrl => 'http://localhost:3000/auth/callback';

  @override
  Duration get sessionTimeout => const Duration(hours: 24);

  @override
  bool get supportsBiometric => false;

  @override
  bool get supportsPasswordManager => false;
}