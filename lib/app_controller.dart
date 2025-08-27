import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/intro_loading_screen.dart';
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/services/authentication_service.dart';
import 'package:babblelon/providers/profile_providers.dart';
import 'package:babblelon/providers/sync_providers.dart' as sync;
import 'package:babblelon/services/app_lifecycle_service.dart';
import 'package:babblelon/providers/player_data_providers.dart' as player_providers;

/// App controller that manages the main app flow  
/// Intro-first approach: Intro Screen → Auth Gate → Email Verification → Profile Setup → Game
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

        // STEP 1: Always show Loading Screen first
        // IntroLoadingScreen will preload assets then navigate to IntroSplashScreen
        debugPrint('🌟 AppController: Showing intro loading screen to preload assets');
        return const IntroLoadingScreen();
      },
    );
  }

  /// Trigger sync when authentication state changes
  void _triggerAuthStateSync(WidgetRef ref, AuthState authState) {
    debugPrint('🔄 AppController: Triggering sync for auth state change: $authState');
    
    // Only sync when user becomes authenticated
    if (authState == AuthState.authenticated) {
      // Invalidate profile provider to force fresh fetch with new auth state
      ref.invalidate(player_providers.currentPlayerProfileProvider);
      debugPrint('🔄 AppController: Profile provider invalidated for fresh data');
      
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

}