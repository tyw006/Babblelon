import 'package:flutter/foundation.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:babblelon/services/supabase_service.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:babblelon/services/posthog_service.dart';
import 'package:babblelon/services/auth_service_interface.dart';

/// Service for managing tutorial completion state with database integration
/// Replaces SharedPreferences-only approach with ISAR/Supabase synchronization
class TutorialDatabaseService {
  static final TutorialDatabaseService _instance = TutorialDatabaseService._internal();
  factory TutorialDatabaseService() => _instance;
  TutorialDatabaseService._internal();
  
  /// Get the current authenticated user ID
  String get _currentUserId {
    final authService = AuthServiceFactory.getInstance();
    final userId = authService.currentUserId;
    
    if (userId == null) {
      throw Exception('No authenticated user found. Please sign in to continue.');
    }
    
    return userId;
  }

  final IsarService _isarService = IsarService();
  final SupabaseService _supabaseService = SupabaseService();
  
  bool _hasInitialized = false;
  
  /// Initialize service and perform initial sync
  Future<void> initialize() async {
    if (_hasInitialized) return;
    
    try {
      // Perform initial sync from Supabase to ensure local data is up to date
      await syncFromSupabase();
      _hasInitialized = true;
      debugPrint('TutorialDatabaseService: ✅ Initialized and synced');
    } catch (e) {
      debugPrint('TutorialDatabaseService: ⚠️ Initialization sync failed: $e');
      // Don't block service usage if sync fails
      _hasInitialized = true;
    }
  }

  /// Check if a specific tutorial has been completed
  Future<bool> isTutorialCompleted(String tutorialId) async {
    await initialize(); // Ensure initialized
    
    try {
      final profile = await _isarService.getPlayerProfile(_currentUserId);
      if (profile == null) {
        debugPrint('TutorialDatabaseService: No profile found for user $_currentUserId');
        return false;
      }
      
      final tutorialsCompleted = profile.tutorialsCompleted;
      final isCompleted = tutorialsCompleted[tutorialId] == true;
      
      debugPrint('TutorialDatabaseService: Tutorial $tutorialId completed: $isCompleted');
      return isCompleted;
    } catch (e) {
      debugPrint('TutorialDatabaseService: Error checking tutorial completion: $e');
      return false;
    }
  }

  /// Mark a tutorial as completed and sync to database
  Future<void> markTutorialCompleted(String tutorialId) async {
    await initialize(); // Ensure initialized
    
    try {
      debugPrint('TutorialDatabaseService: Marking tutorial $tutorialId as completed');
      
      // Get or create user profile
      PlayerProfile? profile = await _isarService.getPlayerProfile(_currentUserId);
      profile ??= _createDefaultProfile();
      
      // Update tutorials completed
      final updatedTutorials = Map<String, dynamic>.from(profile.tutorialsCompleted);
      updatedTutorials[tutorialId] = true;
      profile.tutorialsCompleted = updatedTutorials;
      profile.lastActiveAt = DateTime.now();
      
      // Save to local database
      await _isarService.savePlayerProfile(profile);
      debugPrint('TutorialDatabaseService: Saved to ISAR - Tutorial $tutorialId marked completed');
      
      // Track analytics event
      PostHogService.trackGameEvent(
        event: 'tutorial_completed',
        screen: 'tutorial_system',
        additionalProperties: {
          'tutorial_id': tutorialId,
          'user_id': _currentUserId,
          'completion_timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // Sync to Supabase in background
      _syncToSupabaseBackground(profile);
      
    } catch (e) {
      debugPrint('TutorialDatabaseService: Error marking tutorial completed: $e');
    }
  }

  /// Reset a specific tutorial (mark as not completed)
  Future<void> resetTutorial(String tutorialId) async {
    try {
      debugPrint('TutorialDatabaseService: Resetting tutorial $tutorialId');
      
      final profile = await _isarService.getPlayerProfile(_currentUserId);
      if (profile == null) {
        debugPrint('TutorialDatabaseService: No profile found, cannot reset tutorial');
        return;
      }
      
      // Remove tutorial from completed list
      final updatedTutorials = Map<String, dynamic>.from(profile.tutorialsCompleted);
      updatedTutorials.remove(tutorialId);
      profile.tutorialsCompleted = updatedTutorials;
      profile.lastActiveAt = DateTime.now();
      
      // Save to local database
      await _isarService.savePlayerProfile(profile);
      debugPrint('TutorialDatabaseService: Tutorial $tutorialId reset in ISAR');
      
      // Track analytics event
      PostHogService.trackGameEvent(
        event: 'tutorial_reset',
        screen: 'tutorial_system',
        additionalProperties: {
          'tutorial_id': tutorialId,
          'user_id': _currentUserId,
          'reset_timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // Sync to Supabase in background
      _syncToSupabaseBackground(profile);
      
    } catch (e) {
      debugPrint('TutorialDatabaseService: Error resetting tutorial: $e');
    }
  }

  /// Reset all tutorials (for testing and user preference)
  Future<void> resetAllTutorials() async {
    try {
      debugPrint('TutorialDatabaseService: Resetting all tutorials');
      
      final profile = await _isarService.getPlayerProfile(_currentUserId);
      if (profile == null) {
        debugPrint('TutorialDatabaseService: No profile found, cannot reset tutorials');
        return;
      }
      
      // Clear all tutorials
      profile.tutorialsCompleted = {};
      profile.lastActiveAt = DateTime.now();
      
      // Save to local database
      await _isarService.savePlayerProfile(profile);
      debugPrint('TutorialDatabaseService: All tutorials reset in ISAR');
      
      // Track analytics event
      PostHogService.trackGameEvent(
        event: 'all_tutorials_reset',
        screen: 'tutorial_system',
        additionalProperties: {
          'user_id': _currentUserId,
          'reset_timestamp': DateTime.now().toIso8601String(),
        },
      );
      
      // Sync to Supabase in background
      _syncToSupabaseBackground(profile);
      
    } catch (e) {
      debugPrint('TutorialDatabaseService: Error resetting all tutorials: $e');
    }
  }

  /// Get all completed tutorials
  Future<Map<String, dynamic>> getCompletedTutorials() async {
    try {
      final profile = await _isarService.getPlayerProfile(_currentUserId);
      if (profile == null) {
        return {};
      }
      
      return profile.tutorialsCompleted;
    } catch (e) {
      debugPrint('TutorialDatabaseService: Error getting completed tutorials: $e');
      return {};
    }
  }

  /// Get tutorial completion statistics
  Future<Map<String, dynamic>> getTutorialStats() async {
    try {
      // Use Supabase data for authenticated users
      return await _supabaseService.getTutorialMetrics(_currentUserId);
    } catch (e) {
      debugPrint('TutorialDatabaseService: Error getting tutorial stats: $e');
      return {};
    }
  }

  /// Sync tutorial progress to Supabase
  Future<void> syncToSupabase() async {
    try {
      final profile = await _isarService.getPlayerProfile(_currentUserId);
      if (profile == null) {
        debugPrint('TutorialDatabaseService: No profile to sync');
        return;
      }
      
      await _syncToSupabaseBackground(profile);
    } catch (e) {
      debugPrint('TutorialDatabaseService: Error syncing to Supabase: $e');
    }
  }
  
  /// Sync tutorial progress from Supabase to local ISAR (pull remote changes)
  Future<void> syncFromSupabase() async {
    
    try {
      // Get tutorial completion data from Supabase
      final remoteTutorials = await _supabaseService.getTutorialCompletion(_currentUserId);
      
      if (remoteTutorials.isEmpty) {
        debugPrint('TutorialDatabaseService: No remote tutorial data found');
        return;
      }
      
      // Get or create local profile
      PlayerProfile? profile = await _isarService.getPlayerProfile(_currentUserId);
      profile ??= _createDefaultProfile();
      
      // Merge remote data with local (remote is source of truth)
      profile.tutorialsCompleted = remoteTutorials;
      profile.lastActiveAt = DateTime.now();
      
      // Save to local database
      await _isarService.savePlayerProfile(profile);
      debugPrint('TutorialDatabaseService: ✅ Synced ${remoteTutorials.length} tutorials from Supabase to local');
      
    } catch (e) {
      debugPrint('TutorialDatabaseService: ❌ Error syncing from Supabase: $e');
    }
  }
  
  /// Full bidirectional sync: prioritizes Supabase as source of truth
  Future<void> fullSync() async {
    
    try {
      // First, pull from Supabase (source of truth)
      await syncFromSupabase();
      
      // Then, ensure local changes are pushed (in case of conflicts, Supabase wins)
      await syncToSupabase();
      
      debugPrint('TutorialDatabaseService: ✅ Full bidirectional sync completed');
    } catch (e) {
      debugPrint('TutorialDatabaseService: ❌ Error during full sync: $e');
    }
  }

  /// Background sync to Supabase (non-blocking)
  Future<void> _syncToSupabaseBackground(PlayerProfile profile) async {
    // Run sync in background without blocking the UI
    Future.microtask(() async {
      try {
        await _supabaseService.updateTutorialCompletion(
          userId: profile.userId,
          tutorialsCompleted: profile.tutorialsCompleted,
        );
        debugPrint('TutorialDatabaseService: ✅ Successfully synced tutorial progress to Supabase');
      } catch (e) {
        debugPrint('TutorialDatabaseService: ❌ Background sync to Supabase failed: $e');
      }
    });
  }

  /// Create a default profile for new users
  PlayerProfile _createDefaultProfile() {
    return PlayerProfile()
      ..userId = _currentUserId
      ..createdAt = DateTime.now()
      ..lastActiveAt = DateTime.now()
      ..tutorialsCompleted = {};
  }



}