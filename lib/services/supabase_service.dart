import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/game_models.dart';

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
    required String username,
  }) async {
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'username': username},
    );
    
    if (response.user != null) {
      await _createPlayerProfile(
        userId: response.user!.id,
        username: username,
      );
    }
    
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
  Future<void> _createPlayerProfile({
    required String userId,
    required String username,
  }) async {
    final playerProfile = PlayerProfile(
      id: userId,
      name: username,
    );
    
    await client
      .from('player_profiles')
      .insert(playerProfile.toJson());
  }
  
  Future<PlayerProfile?> getPlayerProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;
    
    final response = await client
      .from('player_profiles')
      .select()
      .eq('id', user.id)
      .single();
    
    return PlayerProfile.fromJson(response);
  }
  
  Future<void> updatePlayerProfile(PlayerProfile profile) async {
    await client
      .from('player_profiles')
      .update(profile.toJson())
      .eq('id', profile.id);
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
} 