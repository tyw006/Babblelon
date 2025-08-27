import 'dart:async';
import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:babblelon/services/authentication_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Abstract authentication service interface
/// Provides platform-agnostic authentication methods
abstract class AuthServiceInterface {
  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges;

  /// Current authenticated user ID
  String? get currentUserId;

  /// Current authenticated user email
  String? get currentUserEmail;

  /// Check if user is currently authenticated
  bool get isAuthenticated;

  /// Check if current user's email is verified
  bool get isEmailVerified;

  /// Sign in with a specific provider
  Future<AuthResult> signInWithProvider(AuthProvider provider);

  /// Sign up with email and password
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  });

  /// Sign in with email and password
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  });

  /// Send email verification to current user
  Future<bool> sendEmailVerification();

  /// Verify email with verification token/code
  Future<AuthResult> verifyEmail(String token);

  /// Send password reset email
  Future<bool> sendPasswordReset(String email);

  /// Reset password with token and new password
  Future<AuthResult> resetPassword({
    required String token,
    required String newPassword,
  });

  /// Link additional authentication provider to current account
  Future<AuthResult> linkProvider(AuthProvider provider);

  /// Unlink authentication provider from current account
  Future<AuthResult> unlinkProvider(AuthProvider provider);

  /// Get list of linked providers for current account
  Future<List<AuthProvider>> getLinkedProviders();

  /// Sign out current user
  Future<void> signOut();

  /// Delete current user account
  Future<bool> deleteAccount();

  /// Refresh current authentication token
  Future<bool> refreshToken();

  /// Get current authentication token
  Future<String?> getAccessToken();

  /// Update user profile information
  Future<bool> updateProfile({
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  });

  /// Get user profile information
  Future<Map<String, dynamic>?> getUserProfile();
}

/// Authentication service factory
class AuthServiceFactory {
  static AuthServiceInterface? _instance;

  /// Get singleton instance of authentication service
  static AuthServiceInterface getInstance() {
    _instance ??= SupabaseAuthService();
    return _instance!;
  }

  /// Override instance for testing
  static void setInstance(AuthServiceInterface service) {
    _instance = service;
  }

  /// Reset instance (for testing)
  static void reset() {
    _instance = null;
  }
}

/// Supabase implementation of authentication service
class SupabaseAuthService implements AuthServiceInterface {
  final AuthenticationService _platformService = AuthenticationService();
  final StreamController<AuthState> _authStateController = StreamController<AuthState>.broadcast();
  StreamSubscription<supabase.AuthState>? _authSubscription;

  final supabase.SupabaseClient _supabase = supabase.Supabase.instance.client;

  SupabaseAuthService() {
    // Emit initial state based on current auth status
    if (_supabase.auth.currentUser != null) {
      _authStateController.add(AuthState.authenticated);
    } else {
      _authStateController.add(AuthState.unauthenticated);
    }

    // Listen to Supabase auth changes and convert to our AuthState enum
    _authSubscription = _supabase.auth.onAuthStateChange.listen((data) {
      final supabase.AuthChangeEvent event = data.event;
      switch (event) {
        case supabase.AuthChangeEvent.signedIn:
          _authStateController.add(AuthState.authenticated);
          break;
        case supabase.AuthChangeEvent.signedOut:
          _authStateController.add(AuthState.unauthenticated);
          break;
        case supabase.AuthChangeEvent.userUpdated:
          _authStateController.add(AuthState.authenticated);
          break;
        default:
          // Don't assume unauthenticated - check actual auth status
          if (_supabase.auth.currentUser != null) {
            _authStateController.add(AuthState.authenticated);
          } else {
            _authStateController.add(AuthState.unauthenticated);
          }
      }
    });
  }

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  @override
  String? get currentUserId {
    return _supabase.auth.currentUser?.id;
  }

  @override
  String? get currentUserEmail {
    return _supabase.auth.currentUser?.email;
  }

  @override
  bool get isAuthenticated {
    return _supabase.auth.currentUser != null;
  }

  @override
  bool get isEmailVerified {
    return _supabase.auth.currentUser?.emailConfirmedAt != null;
  }

  @override
  Future<AuthResult> signInWithProvider(AuthProvider provider) async {
    try {
      if (!_platformService.isProviderSupported(provider)) {
        return AuthResult.failure('Provider $provider not supported on this platform');
      }

      switch (provider) {
        case AuthProvider.apple:
          return await _signInWithApple();
        case AuthProvider.google:
          return await _signInWithGoogle();
        case AuthProvider.github:
          return await _signInWithGitHub();
        case AuthProvider.email:
          throw Exception('Use signInWithEmail for email authentication');
      }
    } catch (e) {
      return AuthResult.failure('Sign in failed: $e');
    }
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      debugPrint('🔐 SupabaseAuth: Starting sign-up for email: $email');
      debugPrint('🔐 SupabaseAuth: Metadata passed: $metadata');
      
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );

      debugPrint('🔐 SupabaseAuth: Sign-up response received');
      debugPrint('🔐 SupabaseAuth: User created: ${response.user != null}');
      debugPrint('🔐 SupabaseAuth: User ID: ${response.user?.id}');
      debugPrint('🔐 SupabaseAuth: User email: ${response.user?.email}');
      debugPrint('🔐 SupabaseAuth: Email confirmed: ${response.user?.emailConfirmedAt != null}');
      debugPrint('🔐 SupabaseAuth: Session exists: ${response.session != null}');

      if (response.user != null) {
        debugPrint('✅ SupabaseAuth: Sign-up successful for user ID: ${response.user!.id}');
        return AuthResult.success(
          userId: response.user!.id,
          email: response.user!.email,
          isEmailVerified: response.user!.emailConfirmedAt != null,
        );
      } else {
        debugPrint('❌ SupabaseAuth: Sign-up failed - no user returned from Supabase');
        return AuthResult.failure('Sign up failed - no user returned');
      }
    } catch (e) {
      debugPrint('💥 SupabaseAuth: Sign-up exception: $e');
      debugPrint('💥 SupabaseAuth: Exception type: ${e.runtimeType}');
      return AuthResult.failure('Sign up failed: $e');
    }
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('🔐 SupabaseAuth: Starting email sign-in for: $email');
      
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      debugPrint('🔐 SupabaseAuth: Sign-in response received');
      debugPrint('🔐 SupabaseAuth: User created: ${response.user != null}');
      debugPrint('🔐 SupabaseAuth: Session created: ${response.session != null}');

      if (response.user != null) {
        debugPrint('✅ SupabaseAuth: Email sign-in successful for user ID: ${response.user!.id}');
        debugPrint('✅ SupabaseAuth: Email verified: ${response.user!.emailConfirmedAt != null}');
        
        return AuthResult.success(
          userId: response.user!.id,
          email: response.user!.email,
          isEmailVerified: response.user!.emailConfirmedAt != null,
        );
      } else {
        debugPrint('❌ SupabaseAuth: Sign in failed - no user returned from Supabase');
        return AuthResult.failure('Sign in failed - no user returned');
      }
    } catch (e) {
      debugPrint('💥 SupabaseAuth: Sign-in exception: $e');
      debugPrint('💥 SupabaseAuth: Exception type: ${e.runtimeType}');
      return AuthResult.failure('Sign in failed: $e');
    }
  }

  @override
  Future<bool> sendEmailVerification() async {
    try {
      if (currentUserEmail == null) return false;
      
      await _supabase.auth.resend(
        type: supabase.OtpType.signup,
        email: currentUserEmail!,
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AuthResult> verifyEmail(String token) async {
    try {
      if (currentUserEmail == null) {
        return AuthResult.failure('No current user email for verification');
      }
      
      final response = await _supabase.auth.verifyOTP(
        token: token,
        type: supabase.OtpType.signup,
        email: currentUserEmail!,
      );
      
      if (response.user != null) {
        return AuthResult.success(
          userId: response.user!.id,
          email: response.user!.email,
          isEmailVerified: response.user!.emailConfirmedAt != null,
        );
      } else {
        return AuthResult.failure('Email verification failed - no user returned');
      }
    } catch (e) {
      return AuthResult.failure('Email verification failed: $e');
    }
  }

  @override
  Future<bool> sendPasswordReset(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<AuthResult> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      final response = await _supabase.auth.verifyOTP(
        token: token,
        type: supabase.OtpType.recovery,
      );
      
      if (response.user != null) {
        await _supabase.auth.updateUser(
          supabase.UserAttributes(password: newPassword),
        );
        
        return AuthResult.success(
          userId: response.user!.id,
          email: response.user!.email,
          isEmailVerified: response.user!.emailConfirmedAt != null,
        );
      } else {
        return AuthResult.failure('Password reset verification failed');
      }
    } catch (e) {
      return AuthResult.failure('Password reset failed: $e');
    }
  }

  @override
  Future<AuthResult> linkProvider(AuthProvider provider) async {
    try {
      if (!isAuthenticated) {
        return AuthResult.failure('Must be authenticated to link providers');
      }

      if (!_platformService.isProviderSupported(provider)) {
        return AuthResult.failure('Provider $provider not supported on this platform');
      }

      switch (provider) {
        case AuthProvider.apple:
          await _supabase.auth.linkIdentity(
            supabase.OAuthProvider.apple,
            redirectTo: _platformService.getPlatformConfig().redirectUrl,
          );
          break;
        case AuthProvider.google:
          await _supabase.auth.linkIdentity(
            supabase.OAuthProvider.google,
            redirectTo: _platformService.getPlatformConfig().redirectUrl,
          );
          break;
        case AuthProvider.github:
          await _supabase.auth.linkIdentity(
            supabase.OAuthProvider.github,
            redirectTo: _platformService.getPlatformConfig().redirectUrl,
          );
          break;
        case AuthProvider.email:
          return AuthResult.failure('Cannot link email provider - use updateUser instead');
      }

      return AuthResult.success(
        userId: currentUserId!,
        email: currentUserEmail,
        isEmailVerified: isEmailVerified,
      );
    } catch (e) {
      return AuthResult.failure('Provider linking failed: $e');
    }
  }

  @override
  Future<AuthResult> unlinkProvider(AuthProvider provider) async {
    try {
      if (!isAuthenticated) {
        return AuthResult.failure('Must be authenticated to unlink providers');
      }

      // Get current user identities to check if unlinking is safe
      final user = _supabase.auth.currentUser;
      if (user?.identities == null || user!.identities!.length <= 1) {
        return AuthResult.failure('Cannot unlink last authentication method');
      }

      // Find the identity to unlink
      final identityToUnlink = user.identities!.firstWhere(
        (identity) => _matchesProvider(identity.provider, provider),
        orElse: () => throw Exception('Provider not linked to this account'),
      );

      await _supabase.auth.unlinkIdentity(identityToUnlink);

      return AuthResult.success(
        userId: currentUserId!,
        email: currentUserEmail,
        isEmailVerified: isEmailVerified,
      );
    } catch (e) {
      return AuthResult.failure('Provider unlinking failed: $e');
    }
  }

  @override
  Future<List<AuthProvider>> getLinkedProviders() async {
    try {
      if (!isAuthenticated) {
        return [];
      }

      final user = _supabase.auth.currentUser;
      if (user?.identities == null) {
        return [];
      }

      final linkedProviders = <AuthProvider>[];
      
      for (final identity in user!.identities!) {
        final provider = _mapSupabaseProviderToAuthProvider(identity.provider);
        if (provider != null && !linkedProviders.contains(provider)) {
          linkedProviders.add(provider);
        }
      }

      return linkedProviders;
    } catch (e) {
      return [];
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      // Auth state change will be handled by the listener
      rethrow;
    }
  }

  @override
  Future<bool> deleteAccount() async {
    try {
      // TODO: Implement account deletion
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> refreshToken() async {
    try {
      final response = await _supabase.auth.refreshSession();
      return response.session != null;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String?> getAccessToken() async {
    try {
      final session = _supabase.auth.currentSession;
      return session?.accessToken;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> updateProfile({
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _supabase.auth.updateUser(
        supabase.UserAttributes(
          data: {
            if (displayName != null) 'display_name': displayName,
            if (photoUrl != null) 'photo_url': photoUrl,
            if (metadata != null) ...metadata,
          },
        ),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      return user?.userMetadata;
    } catch (e) {
      return null;
    }
  }

  // Private helper methods for provider-specific authentication
  Future<AuthResult> _signInWithApple() async {
    try {
      // Native Apple Sign-In for iOS
      if (!kIsWeb && Platform.isIOS) {
        debugPrint('🍎 Starting native Apple Sign-In flow...');
        
        // Check if running on simulator (known Apple Sign-In issues)
        if (await _isRunningOnSimulator()) {
          debugPrint('⚠️ Apple Sign-In on iOS Simulator has known issues. Please test on a physical device.');
          return AuthResult.failure('Apple Sign-In is not fully supported on iOS Simulator. Please test on a physical device or use Email sign-in for development.');
        }
        
        final credential = await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );
        
        debugPrint('🍎 Apple credential received - Identity token present: ${credential.identityToken != null}');
        
        if (credential.identityToken == null) {
          debugPrint('❌ Apple Sign-In failed: No identity token received');
          return AuthResult.failure('Failed to get Apple ID token');
        }
        
        debugPrint('🔗 Signing in with Supabase using Apple ID token...');
        
        // Sign in with Supabase using the Apple ID token
        final response = await _supabase.auth.signInWithIdToken(
          provider: supabase.OAuthProvider.apple,
          idToken: credential.identityToken!,
        );
        
        if (response.user != null) {
          debugPrint('✅ Apple Sign-In successful: ${response.user!.email}');
          return AuthResult.success(
            userId: response.user!.id,
            email: response.user!.email,
            isEmailVerified: true, // Apple IDs are pre-verified
          );
        } else {
          debugPrint('❌ Apple Sign-In failed: No user returned from Supabase');
          return AuthResult.failure('Apple sign in failed - no user returned');
        }
      } else {
        // Web-based OAuth flow (fallback)
        debugPrint('🌐 Starting web-based Apple OAuth flow...');
        await _supabase.auth.signInWithOAuth(
          supabase.OAuthProvider.apple,
          redirectTo: _platformService.getPlatformConfig().redirectUrl,
        );
        
        // OAuth redirects, so return pending status
        return AuthResult.success(
          userId: 'oauth_pending',
          email: null,
          isEmailVerified: true,
        );
      }
    } catch (e) {
      debugPrint('💥 Apple Sign-In error: $e');
      
      // Enhanced error handling for common Apple Sign-In issues
      if (e.toString().contains('AuthorizationErrorCode.unknown')) {
        return AuthResult.failure('Apple Sign-In configuration error. Please ensure Apple Sign-In is properly set up in your Apple Developer account and this app is configured correctly.');
      } else if (e.toString().contains('AuthorizationErrorCode.canceled')) {
        return AuthResult.failure('Apple Sign-In was canceled. Please try again.');
      } else if (e.toString().contains('AuthorizationErrorCode.invalidResponse')) {
        return AuthResult.failure('Invalid response from Apple. Please try again or contact support.');
      } else if (e.toString().contains('AuthorizationErrorCode.notHandled')) {
        return AuthResult.failure('Apple Sign-In is not properly configured. Please contact support.');
      } else if (e.toString().contains('AuthorizationErrorCode.failed')) {
        return AuthResult.failure('Apple Sign-In failed. Please check your internet connection and try again.');
      } else if (e.toString().contains('error 1000')) {
        return AuthResult.failure('Apple Sign-In configuration error (1000). Please ensure the app is properly configured with Apple.');
      } else if (e.toString().contains('error 1001')) {
        return AuthResult.failure('Apple Sign-In was canceled or timed out (1001). Please try again.');
      } else {
        return AuthResult.failure('Apple sign in failed: $e');
      }
    }
  }

  Future<AuthResult> _signInWithGoogle() async {
    try {
      // Native Google Sign-In for mobile
      if (!kIsWeb) {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          scopes: ['email'],
          // Add your web client ID from Google Cloud Console if needed
          // serverClientId: 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com',
        );
        
        // Trigger the Google Sign-In flow
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        
        if (googleUser == null) {
          // User canceled the sign-in
          return AuthResult.failure('Google sign in was canceled');
        }
        
        // Obtain the auth details from the request
        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        
        if (googleAuth.idToken == null) {
          return AuthResult.failure('Failed to get Google ID token');
        }
        
        // Sign in with Supabase using the Google ID token
        final response = await _supabase.auth.signInWithIdToken(
          provider: supabase.OAuthProvider.google,
          idToken: googleAuth.idToken!,
          accessToken: googleAuth.accessToken,
        );
        
        if (response.user != null) {
          debugPrint('✅ Google Sign-In successful: ${response.user!.email}');
          return AuthResult.success(
            userId: response.user!.id,
            email: response.user!.email ?? googleUser.email,
            isEmailVerified: true, // Google accounts are pre-verified
          );
        } else {
          return AuthResult.failure('Google sign in failed - no user returned');
        }
      } else {
        // Web-based OAuth flow
        await _supabase.auth.signInWithOAuth(
          supabase.OAuthProvider.google,
          redirectTo: _platformService.getPlatformConfig().redirectUrl,
        );
        
        // OAuth redirects, so return pending status
        return AuthResult.success(
          userId: 'oauth_pending',
          email: null,
          isEmailVerified: true,
        );
      }
    } catch (e) {
      debugPrint('💥 Google Sign-In error: $e');
      return AuthResult.failure('Google sign in failed: $e');
    }
  }

  Future<AuthResult> _signInWithGitHub() async {
    try {
      await _supabase.auth.signInWithOAuth(
        supabase.OAuthProvider.github,
        redirectTo: _platformService.getPlatformConfig().redirectUrl,
      );
      
      // OAuth typically redirects, so we'll return success and let the auth listener handle the actual result
      return AuthResult.success(
        userId: 'oauth_pending',
        email: null,
        isEmailVerified: true, // GitHub accounts are pre-verified
      );
    } catch (e) {
      return AuthResult.failure('GitHub sign in failed: $e');
    }
  }

  void dispose() {
    _authSubscription?.cancel();
    _authStateController.close();
  }

  // Helper method to detect iOS simulator
  Future<bool> _isRunningOnSimulator() async {
    if (!Platform.isIOS) return false;
    
    // Check if running on iOS simulator by checking platform environment
    try {
      final result = await Process.run('uname', ['-m']);
      final architecture = result.stdout.toString().trim();
      // iOS simulators typically run on x86_64 or arm64 with simulator indicators
      return architecture.contains('x86_64') || 
             Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
             Platform.environment.containsKey('SIMULATOR_ROOT');
    } catch (e) {
      // Fallback detection - assume simulator if we can't determine
      debugPrint('Could not detect simulator status: $e');
      return false;
    }
  }

  // Helper methods for provider matching and conversion
  bool _matchesProvider(String supabaseProvider, AuthProvider provider) {
    switch (provider) {
      case AuthProvider.apple:
        return supabaseProvider == 'apple';
      case AuthProvider.google:
        return supabaseProvider == 'google';
      case AuthProvider.github:
        return supabaseProvider == 'github';
      case AuthProvider.email:
        return supabaseProvider == 'email';
    }
  }

  AuthProvider? _mapSupabaseProviderToAuthProvider(String supabaseProvider) {
    switch (supabaseProvider.toLowerCase()) {
      case 'apple':
        return AuthProvider.apple;
      case 'google':
        return AuthProvider.google;
      case 'github':
        return AuthProvider.github;
      case 'email':
        return AuthProvider.email;
      default:
        return null;
    }
  }
}