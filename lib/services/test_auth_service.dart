import 'dart:async';
import 'package:flutter/foundation.dart';
import 'auth_service_interface.dart';
import 'authentication_service.dart';

/// Test authentication service that bypasses real authentication
/// Used only in test_main.dart for testing purposes
class TestAuthService implements AuthServiceInterface {
  final StreamController<AuthState> _authStateController = StreamController<AuthState>.broadcast();
  
  // Mock test user data
  static const String _testUserId = 'test-user-12345';
  static const String _testUserEmail = 'test@babblelon.dev';
  
  TestAuthService() {
    // Automatically sign in test user after initialization
    Future.delayed(Duration.zero, () {
      _authStateController.add(AuthState.authenticated);
    });
  }

  @override
  Stream<AuthState> get authStateChanges => _authStateController.stream;

  @override
  String? get currentUserId => _testUserId;

  @override
  String? get currentUserEmail => _testUserEmail;

  @override
  bool get isAuthenticated => true;

  @override
  bool get isEmailVerified => true;

  @override
  Future<AuthResult> signInWithProvider(AuthProvider provider) async {
    await Future.delayed(const Duration(milliseconds: 100)); // Simulate network delay
    debugPrint('🧪 TestAuth: Mock sign-in with provider $provider');
    _authStateController.add(AuthState.authenticated);
    return AuthResult.success(
      userId: _testUserId,
      email: _testUserEmail,
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthResult> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('🧪 TestAuth: Mock sign-up with email $email');
    _authStateController.add(AuthState.authenticated);
    return AuthResult.success(
      userId: _testUserId,
      email: email,
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    debugPrint('🧪 TestAuth: Mock sign-in with email $email');
    _authStateController.add(AuthState.authenticated);
    return AuthResult.success(
      userId: _testUserId,
      email: email,
      isEmailVerified: true,
    );
  }

  @override
  Future<bool> sendEmailVerification() async {
    debugPrint('🧪 TestAuth: Mock send email verification');
    return true;
  }

  @override
  Future<AuthResult> verifyEmail(String token) async {
    debugPrint('🧪 TestAuth: Mock verify email with token $token');
    return AuthResult.success(
      userId: _testUserId,
      email: _testUserEmail,
      isEmailVerified: true,
    );
  }

  @override
  Future<bool> sendPasswordReset(String email) async {
    debugPrint('🧪 TestAuth: Mock send password reset to $email');
    return true;
  }

  @override
  Future<AuthResult> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    debugPrint('🧪 TestAuth: Mock reset password');
    return AuthResult.success(
      userId: _testUserId,
      email: _testUserEmail,
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthResult> linkProvider(AuthProvider provider) async {
    debugPrint('🧪 TestAuth: Mock link provider $provider');
    return AuthResult.success(
      userId: _testUserId,
      email: _testUserEmail,
      isEmailVerified: true,
    );
  }

  @override
  Future<AuthResult> unlinkProvider(AuthProvider provider) async {
    debugPrint('🧪 TestAuth: Mock unlink provider $provider');
    return AuthResult.success(
      userId: _testUserId,
      email: _testUserEmail,
      isEmailVerified: true,
    );
  }

  @override
  Future<List<AuthProvider>> getLinkedProviders() async {
    debugPrint('🧪 TestAuth: Mock get linked providers');
    return [AuthProvider.email];
  }

  @override
  Future<void> signOut() async {
    debugPrint('🧪 TestAuth: Mock sign out');
    _authStateController.add(AuthState.unauthenticated);
  }

  @override
  Future<bool> deleteAccount() async {
    debugPrint('🧪 TestAuth: Mock delete account');
    return true;
  }

  @override
  Future<bool> refreshToken() async {
    debugPrint('🧪 TestAuth: Mock refresh token');
    return true;
  }

  @override
  Future<String?> getAccessToken() async {
    return 'test-access-token-12345';
  }

  @override
  Future<bool> updateProfile({
    String? displayName,
    String? photoUrl,
    Map<String, dynamic>? metadata,
  }) async {
    debugPrint('🧪 TestAuth: Mock update profile');
    return true;
  }

  @override
  Future<Map<String, dynamic>?> getUserProfile() async {
    return {
      'id': _testUserId,
      'email': _testUserEmail,
      'display_name': 'Test User',
      'email_verified': true,
    };
  }

  void dispose() {
    _authStateController.close();
  }
}