import 'package:posthog_flutter/posthog_flutter.dart';
import 'dart:math';
import 'dart:developer' as developer;

class PostHogService {
  static String? _userId;
  static String? _sessionId;

  /// Initialize user session for tracking
  static void initializeUser({String? userId}) {
    _userId = userId ?? _generateUserId();
    _sessionId = _generateSessionId();
    
    // Identify user in PostHog
    Posthog().identify(userId: _userId!);
    developer.log('✅ PostHog: User identified - userId: $_userId', name: 'PostHogService');
    
    // Track session start
    Posthog().capture(
      eventName: 'session_start',
      properties: {
        'session_id': _sessionId!,
        'platform': 'mobile_flutter',
        'app_version': '0.1.0',
        'session_start_time': DateTime.now().toIso8601String(),
      },
    );
    developer.log('✅ PostHog: Session start tracked - sessionId: $_sessionId', name: 'PostHogService');
  }

  /// Update user profile properties
  static void updateUserProfile({
    String? username,
    int? playerLevel,
    int? experiencePoints,
    int? gold,
    String? avatarUrl,
  }) {
    // For Flutter SDK, we can only identify with userId
    // User properties are not supported in the same way as web SDK
    if (_userId != null) {
      Posthog().identify(userId: _userId!);
    }
  }

  /// Set device/platform specific properties (stored for event tracking)
  static void setDeviceProperties({
    String? deviceModel,
    String? deviceOs,
    String? deviceLanguage,
    bool? soundEffectsEnabled,
    String? preferredLanguage,
  }) {
    // Flutter SDK doesn't support super properties like register()
    // We'll include these in individual event properties instead
    // Store them for later use in tracking methods
  }

  /// Get current user ID
  static String? get userId => _userId;
  
  /// Get current session ID  
  static String? get sessionId => _sessionId;

  /// Track NPC conversation events
  static void trackNPCConversation({
    required String npcName,
    required String event,
    String? playerMessage,
    String? npcResponse,
    int? charmLevel,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = <String, Object>{
      'npc_name': npcName,
      if (_userId != null) 'user_id': _userId!,
      if (_sessionId != null) 'session_id': _sessionId!,
      if (playerMessage != null) 'player_message_length': playerMessage.length,
      if (npcResponse != null) 'npc_response_length': npcResponse.length,
      if (charmLevel != null) 'charm_level': charmLevel,
      'timestamp': DateTime.now().toIso8601String(),
      if (additionalProperties != null) ...additionalProperties.cast<String, Object>(),
    };

    Posthog().capture(
      eventName: 'npc_conversation_$event',
      properties: properties,
    );
    developer.log('✅ PostHog: NPC conversation tracked - event: npc_conversation_$event, npc: $npcName, userId: $_userId', name: 'PostHogService');
  }

  /// Track pronunciation assessment interactions
  static void trackPronunciationAssessment({
    required String event,
    String? referenceText,
    double? pronunciationScore,
    double? accuracyScore,
    String? itemType,
    int? complexity,
    bool? success,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = <String, Object>{
      if (_userId != null) 'user_id': _userId!,
      if (_sessionId != null) 'session_id': _sessionId!,
      if (referenceText != null) 'reference_text_length': referenceText.length,
      if (pronunciationScore != null) 'pronunciation_score': pronunciationScore,
      if (accuracyScore != null) 'accuracy_score': accuracyScore,
      if (itemType != null) 'item_type': itemType,
      if (complexity != null) 'complexity': complexity,
      if (success != null) 'success': success,
      'timestamp': DateTime.now().toIso8601String(),
      if (additionalProperties != null) ...additionalProperties.cast<String, Object>(),
    };

    Posthog().capture(
      eventName: 'pronunciation_assessment_$event',
      properties: properties,
    );
    developer.log('✅ PostHog: Pronunciation assessment tracked - event: pronunciation_assessment_$event, success: $success, userId: $_userId', name: 'PostHogService');
  }

  /// Track audio interactions (STT/TTS)
  static void trackAudioInteraction({
    required String service, // 'stt' or 'tts'
    required String event,
    int? durationMs,
    bool? success,
    String? error,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = <String, Object>{
      'service': service,
      if (_userId != null) 'user_id': _userId!,
      if (_sessionId != null) 'session_id': _sessionId!,
      if (durationMs != null) 'duration_ms': durationMs,
      if (success != null) 'success': success,
      if (error != null) 'error': error,
      'timestamp': DateTime.now().toIso8601String(),
      if (additionalProperties != null) ...additionalProperties.cast<String, Object>(),
    };

    Posthog().capture(
      eventName: '${service}_$event',
      properties: properties,
    );
    developer.log('✅ PostHog: Audio interaction tracked - event: ${service}_$event, success: $success, userId: $_userId', name: 'PostHogService');
  }

  /// Track game events (menu navigation, level progression, etc.)
  static void trackGameEvent({
    required String event,
    String? screen,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = <String, Object>{
      if (_userId != null) 'user_id': _userId!,
      if (_sessionId != null) 'session_id': _sessionId!,
      if (screen != null) 'screen': screen,
      'timestamp': DateTime.now().toIso8601String(),
      if (additionalProperties != null) ...additionalProperties.cast<String, Object>(),
    };

    Posthog().capture(
      eventName: 'game_$event',
      properties: properties,
    );
    developer.log('✅ PostHog: Game event tracked - event: game_$event, screen: $screen, userId: $_userId', name: 'PostHogService');
  }

  /// Track boss fight events
  static void trackBossFight({
    required String event,
    String? bossName,
    int? playerHealth,
    int? bossHealth,
    Map<String, dynamic>? additionalProperties,
  }) {
    final properties = <String, Object>{
      if (_userId != null) 'user_id': _userId!,
      if (_sessionId != null) 'session_id': _sessionId!,
      if (bossName != null) 'boss_name': bossName,
      if (playerHealth != null) 'player_health': playerHealth,
      if (bossHealth != null) 'boss_health': bossHealth,
      'timestamp': DateTime.now().toIso8601String(),
      if (additionalProperties != null) ...additionalProperties.cast<String, Object>(),
    };

    Posthog().capture(
      eventName: 'boss_fight_$event',
      properties: properties,
    );
    developer.log('✅ PostHog: Boss fight tracked - event: boss_fight_$event, boss: $bossName, userId: $_userId', name: 'PostHogService');
  }

  /// Track session end
  static void trackSessionEnd() {
    if (_sessionId != null) {
      final properties = <String, Object>{
        'session_id': _sessionId!,
        if (_userId != null) 'user_id': _userId!,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      Posthog().capture(
        eventName: 'session_end',
        properties: properties,
      );
      developer.log('✅ PostHog: Session end tracked - sessionId: $_sessionId, userId: $_userId', name: 'PostHogService');
    }
  }

  /// Generate a unique user ID
  static String _generateUserId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'user_${timestamp}_$random';
  }

  /// Generate a unique session ID
  static String _generateSessionId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = Random().nextInt(999999);
    return 'session_${timestamp}_$random';
  }
}