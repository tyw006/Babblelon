import 'package:posthog_flutter/posthog_flutter.dart';
import 'dart:math';
import 'dart:developer' as developer;

class PostHogService {
  static String? _userId;
  static String? _sessionId;
  static DateTime? _lastActiveDate;
  static Map<String, dynamic> _userProperties = {};

  /// Initialize user session for tracking
  static void initializeUser({
    String? userId,
    String? username,
    int? playerLevel,
    DateTime? accountCreatedAt,
  }) {
    _userId = userId ?? _generateUserId();
    _sessionId = _generateSessionId();
    
    // Set up user properties with PostHog reserved properties
    final now = DateTime.now();
    final userProps = <String, dynamic>{
      '\$created_at': (accountCreatedAt ?? now).toIso8601String(),
      'platform': 'mobile_flutter',
      'app_version': '0.1.0',
      'device_type': 'mobile',
      'game_name': 'BabbleOn',
      'first_seen': now.toIso8601String(),
      'total_sessions': 1,
    };
    
    // Add optional user properties
    if (username != null) userProps['\$name'] = username;
    if (playerLevel != null) userProps['player_level'] = playerLevel;
    
    // Store properties for later use
    _userProperties = userProps;
    
    // Identify user in PostHog with properties
    Posthog().identify(
      userId: _userId!,
      userProperties: userProps.cast<String, Object>(),
    );
    developer.log('✅ PostHog: User identified with properties - userId: $_userId, username: $username', name: 'PostHogService');
    
    // Track daily active user event
    _trackDailyActiveUser();
    
    // Track session start with enhanced properties
    Posthog().capture(
      eventName: 'session_start',
      properties: {
        'session_id': _sessionId!,
        'user_id': _userId!,
        'session_start_time': now.toIso8601String(),
        'is_new_user': accountCreatedAt == null,
        ...userProps,
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
    int? totalSessions,
  }) {
    if (_userId == null) return;
    
    // Build updated properties
    final updatedProps = <String, dynamic>{};
    
    if (username != null) {
      updatedProps['\$name'] = username;
      _userProperties['\$name'] = username;
    }
    if (playerLevel != null) {
      updatedProps['player_level'] = playerLevel;
      _userProperties['player_level'] = playerLevel;
    }
    if (experiencePoints != null) {
      updatedProps['experience_points'] = experiencePoints;
      _userProperties['experience_points'] = experiencePoints;
    }
    if (gold != null) {
      updatedProps['gold'] = gold;
      _userProperties['gold'] = gold;
    }
    if (avatarUrl != null) {
      updatedProps['avatar_url'] = avatarUrl;
      _userProperties['avatar_url'] = avatarUrl;
    }
    if (totalSessions != null) {
      updatedProps['total_sessions'] = totalSessions;
      _userProperties['total_sessions'] = totalSessions;
    }
    
    // Always update last active
    final now = DateTime.now();
    updatedProps['last_active'] = now.toIso8601String();
    _userProperties['last_active'] = now.toIso8601String();
    
    // Update user properties in PostHog
    Posthog().identify(
      userId: _userId!,
      userProperties: updatedProps.cast<String, Object>(),
    );
    
    developer.log('✅ PostHog: User profile updated - userId: $_userId, properties: ${updatedProps.keys.join(", ")}', name: 'PostHogService');
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

  /// Track daily active user (DAU) - only once per day per user
  static void _trackDailyActiveUser() {
    if (_userId == null) return;
    
    final today = DateTime.now();
    final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    // Check if we already tracked today
    if (_lastActiveDate != null) {
      final lastActiveStr = '${_lastActiveDate!.year}-${_lastActiveDate!.month.toString().padLeft(2, '0')}-${_lastActiveDate!.day.toString().padLeft(2, '0')}';
      if (lastActiveStr == todayStr) {
        return; // Already tracked today
      }
    }
    
    _lastActiveDate = today;
    
    // Track DAU event
    Posthog().capture(
      eventName: 'daily_active_user',
      properties: {
        'user_id': _userId!,
        if (_sessionId != null) 'session_id': _sessionId!,
        'date': todayStr,
        'timestamp': today.toIso8601String(),
        'platform': 'mobile_flutter',
        ..._userProperties,
      },
    );
    
    developer.log('✅ PostHog: Daily active user tracked - userId: $_userId, date: $todayStr', name: 'PostHogService');
  }

  /// Track app lifecycle events
  static void trackAppLifecycle({
    required String event, // 'app_opened', 'app_backgrounded', 'app_resumed', 'app_closed'
    Map<String, dynamic>? additionalProperties,
  }) {
    if (_userId == null) return;
    
    final properties = <String, Object>{
      'user_id': _userId!,
      if (_sessionId != null) 'session_id': _sessionId!,
      'timestamp': DateTime.now().toIso8601String(),
      'platform': 'mobile_flutter',
      if (additionalProperties != null) ...additionalProperties.cast<String, Object>(),
    };

    Posthog().capture(
      eventName: 'app_$event',
      properties: properties,
    );
    
    // Track DAU when app is opened or resumed
    if (event == 'opened' || event == 'resumed') {
      _trackDailyActiveUser();
    }
    
    developer.log('✅ PostHog: App lifecycle tracked - event: app_$event, userId: $_userId', name: 'PostHogService');
  }

  /// Track user return (for retention analysis)
  static void trackUserReturn({
    int? daysSinceLastSession,
    String? returnType, // 'same_day', 'next_day', 'weekly', 'monthly'
  }) {
    if (_userId == null) return;
    
    final properties = <String, Object>{
      'user_id': _userId!,
      if (_sessionId != null) 'session_id': _sessionId!,
      if (daysSinceLastSession != null) 'days_since_last_session': daysSinceLastSession,
      if (returnType != null) 'return_type': returnType,
      'timestamp': DateTime.now().toIso8601String(),
      ..._userProperties,
    };

    Posthog().capture(
      eventName: 'user_return',
      properties: properties,
    );
    
    developer.log('✅ PostHog: User return tracked - userId: $_userId, returnType: $returnType, daysSince: $daysSinceLastSession', name: 'PostHogService');
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