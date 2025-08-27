import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/supabase_models.dart';

class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  // Initialize Supabase
  static Future<void> initialize({
    required String url,
    required String anonKey,
  }) async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }
  
  // User Authentication
  
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
    );
    
    // Note: Player profile will be created automatically via database trigger
    // when email is confirmed. This prevents RLS policy violations during signup.
    
    return response;
  }
  
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }
  
  Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  // Player Profile
  Future<void> createPlayerProfileIfNeeded({
    required String userId,
  }) async {
    try {
      debugPrint('🔍 SupabaseService: Checking if player profile exists for user: $userId');
      
      // Rely on DB triggers to create the profile immediately on auth.users insert.
      // Only perform a no-op existence check to avoid RLS violations pre-session.
      final result = await client
          .from('players')
          .select('id')
          .eq('user_id', userId)
          .maybeSingle();
      
      debugPrint('✅ SupabaseService: Player profile check completed. Found: ${result != null}');
      
      if (result != null) {
        debugPrint('✅ SupabaseService: Player profile already exists for user: $userId');
      } else {
        debugPrint('⚠️ SupabaseService: No player profile found for user: $userId (trigger should create one)');
      }
    } catch (e) {
      debugPrint('💥 SupabaseService: Error during player profile check: $e');
      debugPrint('💥 SupabaseService: Error type: ${e.runtimeType}');
      rethrow;
    }
  }
  
  Future<PlayerProfile?> getPlayerProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    
    final response = await client
      .from('players')
      .select()
      .eq('user_id', user.id)
      .maybeSingle(); // Use maybeSingle to handle case where profile doesn't exist yet
    
    if (response == null) return null;
    return PlayerProfile.fromJson(response);
  }
  
  Future<void> updatePlayerProfile(PlayerProfile profile) async {
    profile.lastActiveAt = DateTime.now();
    
    await client
      .from('players')
      .update(profile.toJson())
      .eq('user_id', profile.id);
  }
  
  // Update profile with onboarding data
  Future<void> updateProfileWithOnboardingData({
    required String userId,
    required Map<String, dynamic> onboardingData,
  }) async {
    try {
      debugPrint('📝 SupabaseService: Starting profile update for user: $userId');
      debugPrint('📝 SupabaseService: Onboarding data keys: ${onboardingData.keys.toList()}');
      
      // Ensure we have an authenticated session before attempting any writes
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ SupabaseService: No authenticated session - skipping profile update');
        return;
      }
      
      debugPrint('✅ SupabaseService: Authenticated session found for user: ${currentUser.id}');
    } catch (e) {
      debugPrint('💥 SupabaseService: Error during profile update setup: $e');
      rethrow;
    }
    
    // Create AI-optimized data structure for backend access
    final aiProfileData = {
      'profile': {
        'first_name': onboardingData['first_name'],
        'last_name': onboardingData['last_name'],
        'age': onboardingData['age'],
        'target_language': onboardingData['target_language'],
        'language_level': onboardingData['target_language_level'],
        'motivations': onboardingData['learning_motivation']?.split(', ') ?? [],
        'learning_pace': onboardingData['learning_pace'],
        'native_language': onboardingData['native_language'],
        'has_prior_learning': onboardingData['has_prior_learning'],
        'daily_goal_minutes': onboardingData['daily_goal_minutes'],
        'voice_recording_consent': onboardingData['voice_recording_consent'],
        'personalized_content_consent': onboardingData['personalized_content_consent'],
        'privacy_policy_accepted': onboardingData['privacy_policy_accepted'],
        'data_collection_consented': onboardingData['data_collection_consented'],
        'consent_date': onboardingData['consent_date'],
        'onboarding_completed': true,
        'onboarding_completed_at': DateTime.now().toIso8601String(),
      }
    };
    
    try {
      debugPrint('📝 SupabaseService: Updating auth user metadata...');
      // Update auth.users.raw_user_meta_data with AI-friendly structure
      await client.auth.updateUser(
        UserAttributes(
          data: aiProfileData,
        ),
      );
      debugPrint('✅ SupabaseService: Auth user metadata updated successfully');
      
      debugPrint('📝 SupabaseService: Updating players table...');
      // Also update players table with basic info (including onboarding completion)
      final playersUpdateData = {
        'first_name': onboardingData['first_name'],
        'last_name': onboardingData['last_name'],
        'onboarding_completed': true,
        'onboarding_completed_at': DateTime.now().toIso8601String(),
        'last_active_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      debugPrint('📝 SupabaseService: Players update data: $playersUpdateData');
      
      await client
        .from('players')
        .update(playersUpdateData)
        .eq('user_id', userId);
      
      debugPrint('✅ SupabaseService: Players table updated successfully with onboarding completion');
    } catch (e) {
      debugPrint('💥 SupabaseService: Error during profile data update: $e');
      debugPrint('💥 SupabaseService: Error type: ${e.runtimeType}');
      rethrow;
    }
  }
  
  // Get user profile data from auth.users.raw_user_meta_data
  Future<Map<String, dynamic>?> getUserProfileData() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    
    // Profile data is stored in user.userMetadata
    return user.userMetadata?['profile'] as Map<String, dynamic>?;
  }
  
  // Game Levels
  Future<List<GameLevel>> getLevels() async {
    final response = await client
      .from('game_levels')
      .select()
      .order('difficulty');
    
    return response.map((level) => GameLevel.fromJson(level)).toList();
  }
  
  // Leaderboard
  Future<List<Map<String, dynamic>>> getLeaderboard({int limit = 10}) async {
    final response = await client
      .from('player_profiles')
      .select('id, name, high_score')
      .order('high_score', ascending: false)
      .limit(limit);
    
    return response;
  }
  
  // Game Settings
  Future<void> saveGameSettings(GameSettings settings) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    
    await client
      .from('game_settings')
      .upsert({
        'user_id': user.id,
        'settings': settings.toJson(),
      });
  }
  
  Future<GameSettings> getGameSettings() async {
    final user = client.auth.currentUser;
    if (user == null) return GameSettings();
    
    final response = await client
      .from('game_settings')
      .select('settings')
      .eq('user_id', user.id)
      .maybeSingle();
    
    if (response == null) return GameSettings();
    return GameSettings.fromJson(response['settings']);
  }
  
  
  // Delete current authenticated user's data (for production users)
  Future<void> deleteCurrentUserData() async {
    try {
      final currentUser = client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('No authenticated user to delete');
      }
      
      // Delete from players table
      await client
          .from('players')
          .delete()
          .eq('user_id', currentUser.id);
      
      // Delete from game_settings table  
      await client
          .from('game_settings')
          .delete()
          .eq('user_id', currentUser.id);
      
      debugPrint('SupabaseService: ✅ Current user data deleted for ID: ${currentUser.id}');
    } catch (e) {
      debugPrint('SupabaseService: ❌ Error deleting current user data: $e');
      rethrow;
    }
  }
  
  // Tutorial completion tracking methods
  
  /// Update tutorial completion status in Supabase
  Future<void> updateTutorialCompletion({
    required String userId,
    required Map<String, dynamic> tutorialsCompleted,
  }) async {
    try {
      await client
          .from('players')
          .update({
            'tutorials_completed': tutorialsCompleted,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      
      debugPrint('SupabaseService: ✅ Tutorial completion updated for user $userId');
    } catch (e) {
      debugPrint('SupabaseService: ❌ Error updating tutorial completion: $e');
      rethrow;
    }
  }
  
  /// Get tutorial completion status from Supabase
  Future<Map<String, dynamic>> getTutorialCompletion(String userId) async {
    try {
      final response = await client
          .from('players')
          .select('tutorials_completed')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response == null) {
        return {};
      }
      
      return (response['tutorials_completed'] as Map<String, dynamic>?) ?? {};
    } catch (e) {
      debugPrint('SupabaseService: ❌ Error getting tutorial completion: $e');
      return {};
    }
  }
  
  /// Get comprehensive tutorial metrics from Supabase
  Future<Map<String, dynamic>> getTutorialMetrics(String userId) async {
    try {
      final response = await client
          .from('players')
          .select('tutorials_completed, created_at, last_active_at, updated_at, first_name, last_name')
          .eq('user_id', userId)
          .maybeSingle();
      
      if (response == null) {
        return {
          'total_completed': 0,
          'completed_tutorials': [],
          'last_active': 'Never',
          'profile_created': 'Not set',
        };
      }
      
      final tutorialsCompleted = (response['tutorials_completed'] as Map<String, dynamic>?) ?? {};
      
      return {
        'total_completed': tutorialsCompleted.length,
        'completed_tutorials': tutorialsCompleted.keys.toList(),
        'last_active': response['last_active_at'] ?? 'Never',
        'profile_created': response['created_at'] ?? 'Not set',
        'display_name': ('${response['first_name'] ?? ''} ${response['last_name'] ?? ''}'.trim()).isEmpty ? 'Unknown' : '${response['first_name'] ?? ''} ${response['last_name'] ?? ''}'.trim(),
        'updated_at': response['updated_at'] ?? 'Never',
      };
    } catch (e) {
      debugPrint('SupabaseService: ❌ Error getting tutorial metrics: $e');
      return {
        'total_completed': 0,
        'completed_tutorials': [],
        'last_active': 'Error',
        'profile_created': 'Error',
      };
    }
  }
} 