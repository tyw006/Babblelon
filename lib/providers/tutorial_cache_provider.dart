import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:babblelon/services/tutorial_cache_service.dart';
import 'package:babblelon/services/tutorial_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for tutorial cache service
final tutorialCacheProvider = Provider<TutorialCacheService>((ref) {
  return TutorialCacheService();
});

/// Provider that monitors auth state changes and manages tutorial cache lifecycle
final tutorialCacheInitializerProvider = Provider<void>((ref) {
  final cacheService = ref.read(tutorialCacheProvider);
  
  // Listen to Supabase auth state changes directly
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    final session = data.session;
    
    switch (event) {
      case AuthChangeEvent.signedIn:
        if (session?.user != null) {
          final userId = session!.user.id;
          debugPrint('TutorialCacheInitializer: User signed in, loading cache for $userId');
          
          // Clear session-based tutorial checking cache on auth change
          TutorialManager.clearSessionCache();
          
          // Load tutorial cache after successful authentication
          cacheService.loadAfterAuth(userId).then((_) {
            final stats = cacheService.getStats();
            debugPrint('TutorialCacheInitializer: Cache loaded - ${stats['total_tutorials']} tutorials, ${stats['completed_tutorials']} completed (${stats['completion_rate']}%)');
          }).catchError((error) {
            debugPrint('TutorialCacheInitializer: Error loading cache: $error');
          });
        }
        break;
        
      case AuthChangeEvent.signedOut:
        debugPrint('TutorialCacheInitializer: User signed out, clearing cache');
        cacheService.clear();
        // Also clear session-based tutorial checking cache
        TutorialManager.clearSessionCache();
        break;
        
      case AuthChangeEvent.userUpdated:
        // User profile updated, cache stays valid
        debugPrint('TutorialCacheInitializer: User profile updated');
        break;
        
      default:
        // Other auth events - maintain current cache state
        break;
    }
  });
  
  // Initialize cache if user is already authenticated
  final currentUser = Supabase.instance.client.auth.currentUser;
  if (currentUser != null) {
    debugPrint('TutorialCacheInitializer: User already authenticated, initializing cache for ${currentUser.id}');
    cacheService.loadAfterAuth(currentUser.id);
  }
});

/// Convenience provider for quick tutorial completion checks
/// Usage: ref.watch(tutorialCompletedProvider('tutorial_id'))
final tutorialCompletedProvider = Provider.family<bool, String>((ref, tutorialId) {
  // Ensure cache initializer is active
  ref.watch(tutorialCacheInitializerProvider);
  
  // Return cached result
  return ref.read(tutorialCacheProvider).isTutorialCompleted(tutorialId);
});

/// Provider for tutorial cache statistics (useful for debugging)
final tutorialCacheStatsProvider = Provider<Map<String, dynamic>>((ref) {
  final cacheService = ref.watch(tutorialCacheProvider);
  return cacheService.getStats();
});