import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/main_screen/widgets/space_loading_screen.dart';
import 'package:babblelon/screens/enhanced_onboarding_screen.dart';
import 'package:babblelon/screens/authentication_screen.dart';
import 'package:babblelon/screens/email_verification_screen.dart';
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/services/authentication_service.dart';
import 'package:babblelon/providers/profile_providers.dart';
import 'package:babblelon/providers/sync_providers.dart' as sync;
import 'package:babblelon/services/app_lifecycle_service.dart';

/// App controller that manages the main app flow
/// Authentication-first approach: Auth Gate → Email Verification → Profile Setup → Game
class AppController extends ConsumerWidget {
  const AppController({super.key});
  
  // Track previous auth state to detect changes
  static AuthState? _previousAuthState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = AuthServiceFactory.getInstance();
    
    // Initialize app lifecycle service for automatic sync triggers
    ref.watch(appLifecycleServiceProvider);

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, authSnapshot) {
        // Debug logging for authentication state
        debugPrint('\n🔍 === AppController Debug State ===');
        debugPrint('🔍 Auth Snapshot State: ${authSnapshot.connectionState}');
        debugPrint('🔍 Auth Snapshot Data: ${authSnapshot.data}');
        debugPrint('🔍 Is Authenticated: ${authService.isAuthenticated}');
        debugPrint('🔍 Current User ID: ${authService.currentUserId}');
        debugPrint('🔍 Current User Email: ${authService.currentUserEmail}');
        debugPrint('🔍 Is Email Verified: ${authService.isEmailVerified}');
        debugPrint('🔍 === End Auth Debug ===\n');

        // Detect auth state changes and trigger sync
        final currentAuthState = authSnapshot.data;
        if (currentAuthState != null && currentAuthState != _previousAuthState) {
          debugPrint('🔄 AppController: Auth state changed from $_previousAuthState to $currentAuthState');
          
          // Trigger sync on auth state change (except for initial load)
          if (_previousAuthState != null) {
            _triggerAuthStateSync(ref, currentAuthState);
          }
          
          _previousAuthState = currentAuthState;
        }

        if (authSnapshot.connectionState == ConnectionState.waiting) {
          debugPrint('⏳ AppController: Waiting for auth state...');
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // STEP 1: Authentication Gate
        if (!authService.isAuthenticated) {
          debugPrint('🚪 AppController: User not authenticated, showing auth screen');
          return AuthenticationScreen(
            onAuthSuccess: (result) {
              debugPrint('✅ Authentication successful for user: ${result.userId}');
              debugPrint('✅ Email verified: ${result.isEmailVerified}');
              // StreamBuilder will automatically rebuild when auth state changes
              // No manual navigation needed - the auth state listener will trigger rebuild
            },
            onAuthError: (error) {
              debugPrint('❌ Auth error: $error');
            },
          );
        }

        // STEP 2: Email Verification Gate (for email users only)
        if (!authService.isEmailVerified && _requiresEmailVerification()) {
          debugPrint('📧 AppController: Email not verified, showing verification screen');
          return EmailVerificationScreen(
            onVerificationComplete: () {
              debugPrint('✅ Email verification completed');
              // StreamBuilder will automatically rebuild when auth state changes
              // No manual navigation needed - the auth state listener will trigger rebuild
            },
          );
        }

        // STEP 3: Profile Setup Gate - Using reactive provider
        debugPrint('👤 AppController: Checking profile completion with reactive provider...');
        
        final profileCompletionAsync = ref.watch(profileCompletionProvider);
        
        return profileCompletionAsync.when(
          loading: () {
            debugPrint('⏳ AppController: Waiting for profile check...');
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          },
          error: (error, stackTrace) {
            debugPrint('💥 AppController: Profile check error: $error');
            // On error, show onboarding to be safe
            return const EnhancedOnboardingScreen();
          },
          data: (profileState) {
            debugPrint('🔍 Profile State: $profileState');
            
            final hasCompletedProfile = profileState.isCompleted;
            debugPrint('🔍 Has Completed Profile: $hasCompletedProfile');

            // STEP 4: Profile Setup (if needed)
            if (!hasCompletedProfile) {
              debugPrint('📝 AppController: Profile incomplete, showing onboarding');
              debugPrint('🎯 AppController: RETURNING EnhancedOnboardingScreen widget');
              return const EnhancedOnboardingScreen();
            }

            // STEP 5: Full App Access
            debugPrint('🎮 AppController: Profile complete, loading main app');
            debugPrint('🎯 AppController: RETURNING SpaceLoadingScreen widget');
            return const SpaceLoadingScreen();
          },
        );
      },
    );
  }

  /// Trigger sync when authentication state changes
  void _triggerAuthStateSync(WidgetRef ref, AuthState authState) {
    debugPrint('🔄 AppController: Triggering sync for auth state change: $authState');
    
    // Only sync when user becomes authenticated
    if (authState == AuthState.authenticated) {
      // Use async execution to avoid blocking the UI
      Future.microtask(() async {
        try {
          final syncService = ref.read(sync.syncServiceProvider);
          debugPrint('🔄 AppController: Starting auth state sync...');
          await syncService.syncAll();
          debugPrint('✅ AppController: Auth state sync completed');
          
          // Refresh profile completion provider
          final refreshProfile = ref.read(profileRefreshProvider);
          refreshProfile();
          debugPrint('✅ AppController: Profile completion refreshed after auth sync');
        } catch (e) {
          debugPrint('💥 AppController: Auth state sync failed: $e');
        }
      });
    }
  }

  bool _requiresEmailVerification() {
    // OAuth providers (Apple, Google) are pre-verified
    // Only email/password users need to verify their email
    final authService = AuthServiceFactory.getInstance();
    final userEmail = authService.currentUserEmail;
    
    debugPrint('🔍 _requiresEmailVerification: User email: $userEmail');
    debugPrint('🔍 _requiresEmailVerification: Is email verified: ${authService.isEmailVerified}');
    
    // If we can't determine the auth method, require verification to be safe
    // In a real implementation, we'd check the user's auth provider
    // For now, we'll check if the email looks like an OAuth email
    if (userEmail != null) {
      // OAuth emails typically have specific patterns, but for safety,
      // we'll require verification for all email users unless they're OAuth
      // This will be refined when we have proper OAuth provider detection
      const requires = true;
      debugPrint('🔍 _requiresEmailVerification: Returning: $requires');
      return requires;
    }
    
    debugPrint('🔍 _requiresEmailVerification: No email, returning false');
    return false;
  }
}