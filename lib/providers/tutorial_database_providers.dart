import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:babblelon/services/tutorial_database_service.dart';
import 'package:babblelon/screens/tutorial_settings_screen.dart';

/// Enhanced tutorial completion provider that uses database instead of SharedPreferences
class TutorialCompletionNotifier extends StateNotifier<Map<String, bool>> {
  TutorialCompletionNotifier() : super({}) {
    _loadTutorialCompletions();
  }

  final TutorialDatabaseService _tutorialService = TutorialDatabaseService();

  /// Check if a specific tutorial is completed
  bool isTutorialCompleted(String tutorialId) {
    return state[tutorialId] ?? false;
  }

  /// Mark a tutorial as completed
  Future<void> markTutorialCompleted(String tutorialId) async {
    debugPrint('TutorialCompletion: Marking tutorial $tutorialId as completed');
    
    // Update database
    await _tutorialService.markTutorialCompleted(tutorialId);
    
    // Update local state
    state = {
      ...state,
      tutorialId: true,
    };
    
    debugPrint('TutorialCompletion: Tutorial $tutorialId marked as completed');
  }

  /// Reset a specific tutorial
  Future<void> resetTutorial(String tutorialId) async {
    debugPrint('TutorialCompletion: Resetting tutorial $tutorialId');
    
    // Update database
    await _tutorialService.resetTutorial(tutorialId);
    
    // Update local state
    final updatedState = Map<String, bool>.from(state);
    updatedState.remove(tutorialId);
    state = updatedState;
    
    debugPrint('TutorialCompletion: Tutorial $tutorialId reset');
  }

  /// Reset all tutorials
  Future<void> resetAllTutorials() async {
    debugPrint('TutorialCompletion: Resetting all tutorials');
    
    // Update database
    await _tutorialService.resetAllTutorials();
    
    // Clear local state
    state = {};
    
    // Force reload from database to ensure all providers see the reset state
    await refreshFromDatabase();
    
    debugPrint('TutorialCompletion: All tutorials reset and state refreshed');
  }

  /// Load tutorial completions from database
  Future<void> _loadTutorialCompletions() async {
    try {
      final completedTutorials = await _tutorialService.getCompletedTutorials();
      final tutorialState = <String, bool>{};
      
      // Convert dynamic map to bool map
      completedTutorials.forEach((key, value) {
        tutorialState[key] = value == true;
      });
      
      state = tutorialState;
      debugPrint('TutorialCompletion: Loaded ${tutorialState.length} completed tutorials from database');
    } catch (e) {
      debugPrint('TutorialCompletion: Error loading tutorial completions: $e');
    }
  }

  /// Refresh tutorial state from database
  Future<void> refreshFromDatabase() async {
    await _loadTutorialCompletions();
  }

  /// Get tutorial statistics
  Future<Map<String, dynamic>> getTutorialStats() async {
    return await _tutorialService.getTutorialStats();
  }
}

/// Provider for tutorial completion state
final tutorialCompletionProvider = StateNotifierProvider<TutorialCompletionNotifier, Map<String, bool>>(
  (ref) => TutorialCompletionNotifier(),
);

/// Tutorial-specific convenience providers
final isMainNavigationTutorialCompletedProvider = Provider<bool>((ref) {
  return ref.watch(tutorialCompletionProvider.notifier).isTutorialCompleted('main_navigation_intro');
});

final isGameIntroTutorialCompletedProvider = Provider<bool>((ref) {
  return ref.watch(tutorialCompletionProvider.notifier).isTutorialCompleted('game_loading_intro');
});

final isBossFightTutorialCompletedProvider = Provider<bool>((ref) {
  return ref.watch(tutorialCompletionProvider.notifier).isTutorialCompleted('boss_fight_intro');
});

final isNpcDialogueTutorialCompletedProvider = Provider<bool>((ref) {
  return ref.watch(tutorialCompletionProvider.notifier).isTutorialCompleted('first_dialogue_session');
});

final isCharacterTracingTutorialCompletedProvider = Provider<bool>((ref) {
  return ref.watch(tutorialCompletionProvider.notifier).isTutorialCompleted('character_tracing_tutorial');
});


/// Legacy compatibility provider (maintains existing interface for gradual migration)
class TutorialProgressLegacyNotifier extends StateNotifier<Set<String>> {
  TutorialProgressLegacyNotifier(this.ref) : super(<String>{}) {
    // Watch the new tutorial completion provider and convert format
    ref.listen<Map<String, bool>>(tutorialCompletionProvider, (previous, next) {
      final completedTutorials = next.entries
          .where((entry) => entry.value == true)
          .map((entry) => entry.key)
          .toSet();
      state = completedTutorials;
    });
  }

  final StateNotifierProviderRef<TutorialProgressLegacyNotifier, Set<String>> ref;

  /// Legacy method for marking step completed
  void markStepCompleted(String stepId) {
    ref.read(tutorialCompletionProvider.notifier).markTutorialCompleted(stepId);
  }

  /// Legacy method for checking completion
  bool isStepCompleted(String stepId) {
    return ref.read(tutorialCompletionProvider.notifier).isTutorialCompleted(stepId);
  }

  /// Legacy method for resetting progress
  void resetProgress() {
    ref.read(tutorialCompletionProvider.notifier).resetAllTutorials();
  }
}

/// Legacy provider for backwards compatibility with existing code
final tutorialProgressProvider = StateNotifierProvider<TutorialProgressLegacyNotifier, Set<String>>(
  (ref) => TutorialProgressLegacyNotifier(ref),
);

/// Helper provider to determine if we should show a tutorial
/// Checks both tutorial completion and test user state
final shouldShowTutorialProvider = Provider.family<bool, String>((ref, tutorialId) {
  final tutorialCompleted = ref.watch(tutorialCompletionProvider.notifier).isTutorialCompleted(tutorialId);
  return !tutorialCompleted; // Show tutorial if not completed
});

/// Provider for tutorial statistics
final tutorialStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  return await ref.read(tutorialCompletionProvider.notifier).getTutorialStats();
});

// --- Tutorial Group System ---

/// Tutorial categories for organizing tutorials
enum TutorialCategory {
  navigation,  // App navigation and interface
  gameplay,    // Basic game mechanics and controls
  dialogue,    // NPC interactions and voice features
  combat,      // Boss battles and item system
  learning,    // Language learning features
  achievements // Milestones and rewards
}

/// Tutorial group progress data
class TutorialGroupProgress {
  final bool completed;
  final int totalSteps;
  final int completedSteps;
  final String? lastShown;
  final DateTime? lastShownAt;
  final int skippedCount;
  final String completionMethod; // 'viewed', 'skipped', 'auto_skipped'

  const TutorialGroupProgress({
    required this.completed,
    required this.totalSteps,
    required this.completedSteps,
    this.lastShown,
    this.lastShownAt,
    this.skippedCount = 0,
    this.completionMethod = 'viewed',
  });

  TutorialGroupProgress copyWith({
    bool? completed,
    int? totalSteps,
    int? completedSteps,
    String? lastShown,
    DateTime? lastShownAt,
    int? skippedCount,
    String? completionMethod,
  }) {
    return TutorialGroupProgress(
      completed: completed ?? this.completed,
      totalSteps: totalSteps ?? this.totalSteps,
      completedSteps: completedSteps ?? this.completedSteps,
      lastShown: lastShown ?? this.lastShown,
      lastShownAt: lastShownAt ?? this.lastShownAt,
      skippedCount: skippedCount ?? this.skippedCount,
      completionMethod: completionMethod ?? this.completionMethod,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'completed': completed,
      'total_steps': totalSteps,
      'completed_steps': completedSteps,
      'last_shown': lastShown,
      'last_shown_at': lastShownAt?.toIso8601String(),
      'skipped_count': skippedCount,
      'completion_method': completionMethod,
    };
  }

  factory TutorialGroupProgress.fromJson(Map<String, dynamic> json) {
    return TutorialGroupProgress(
      completed: json['completed'] ?? false,
      totalSteps: json['total_steps'] ?? 0,
      completedSteps: json['completed_steps'] ?? 0,
      lastShown: json['last_shown'],
      lastShownAt: json['last_shown_at'] != null 
          ? DateTime.parse(json['last_shown_at']) 
          : null,
      skippedCount: json['skipped_count'] ?? 0,
      completionMethod: json['completion_method'] ?? 'viewed',
    );
  }

  static TutorialGroupProgress empty(int totalSteps) {
    return TutorialGroupProgress(
      completed: false,
      totalSteps: totalSteps,
      completedSteps: 0,
    );
  }
}

/// Tutorial sequences organized by category
const Map<TutorialCategory, List<String>> tutorialSequences = {
  TutorialCategory.navigation: [
    'blabbybara_intro',
    'home_tour',
    'progress_tour', 
    'premium_tour',
    'settings_tour',
    'learn_return',
  ],
  TutorialCategory.gameplay: [
    'game_loading_intro',
    'cultural_intro',
    'startAdventure',
  ],
  TutorialCategory.dialogue: [
    'first_npc_interaction',
    'first_dialogue_session',
    'voice_setup_guide',
    'pronunciation_confidence_guide',
    'first_npc_response_tutorial',
  ],
  TutorialCategory.combat: [
    'charm_explanation',
    'item_types',
    'regular_vs_special',
    'boss_prerequisites_warning',
    'boss_fight_intro',
    'portal_approach',
  ],
  TutorialCategory.learning: [
    'character_tracing_tutorial',
    'pos_color_system',
    'transliteration_system',
    'first_language_tools_tutorial',
  ],
  TutorialCategory.achievements: [
    'charm_thresholds_explained',
    'item_giving_tutorial',
    'special_item_celebration',
  ],
};

/// Tutorial group management provider
class TutorialGroupNotifier extends StateNotifier<Map<TutorialCategory, TutorialGroupProgress>> {
  TutorialGroupNotifier() : super({}) {
    _loadGroupProgress();
  }

  final TutorialDatabaseService _tutorialService = TutorialDatabaseService();

  /// Check if a tutorial group is completed
  bool isGroupCompleted(TutorialCategory category) {
    return state[category]?.completed ?? false;
  }

  /// Get progress for a specific group
  TutorialGroupProgress? getGroupProgress(TutorialCategory category) {
    return state[category];
  }

  /// Get next tutorial in sequence for a group
  Future<String?> getNextTutorialInGroup(TutorialCategory category) async {
    final sequence = tutorialSequences[category];
    if (sequence == null) return null;

    final progress = state[category];
    int startIndex = 0;

    // If we have a last shown tutorial, start after it
    if (progress?.lastShown != null) {
      final lastIndex = sequence.indexOf(progress!.lastShown!);
      if (lastIndex >= 0) {
        startIndex = lastIndex + 1;
      }
    }

    // Find first uncompleted tutorial
    for (int i = startIndex; i < sequence.length; i++) {
      final tutorialId = sequence[i];
      final isCompleted = await _tutorialService.isTutorialCompleted(tutorialId);
      if (!isCompleted) {
        return tutorialId;
      }
    }

    return null; // All completed
  }

  /// Mark a tutorial as completed and update group progress
  Future<void> markTutorialCompleted(String tutorialId, {String method = 'viewed'}) async {
    // Find which category this tutorial belongs to
    TutorialCategory? category;
    for (final entry in tutorialSequences.entries) {
      if (entry.value.contains(tutorialId)) {
        category = entry.key;
        break;
      }
    }

    if (category == null) return;

    // Update individual tutorial completion
    await _tutorialService.markTutorialCompleted(tutorialId);

    // Update group progress
    await _updateGroupProgress(category, tutorialId, method);
  }

  /// Skip a specific tutorial
  Future<void> skipTutorial(String tutorialId) async {
    await markTutorialCompleted(tutorialId, method: 'skipped');
  }

  /// Skip entire tutorial group
  Future<void> skipAllInGroup(TutorialCategory category) async {
    final sequence = tutorialSequences[category];
    if (sequence == null) return;

    int skippedCount = 0;
    for (final tutorialId in sequence) {
      final isCompleted = await _tutorialService.isTutorialCompleted(tutorialId);
      if (!isCompleted) {
        await _tutorialService.markTutorialCompleted(tutorialId);
        skippedCount++;
      }
    }

    // Mark group as completed
    final currentProgress = state[category] ?? TutorialGroupProgress.empty(sequence.length);
    final newProgress = currentProgress.copyWith(
      completed: true,
      completedSteps: sequence.length,
      skippedCount: currentProgress.skippedCount + skippedCount,
      completionMethod: 'auto_skipped',
      lastShownAt: DateTime.now(),
    );

    state = {...state, category: newProgress};
    await _saveGroupProgress();
  }

  /// Reset a tutorial group
  Future<void> resetGroup(TutorialCategory category) async {
    final sequence = tutorialSequences[category];
    if (sequence == null) return;

    // Reset all tutorials in group
    for (final tutorialId in sequence) {
      await _tutorialService.resetTutorial(tutorialId);
    }

    // Reset group progress
    state = {...state, category: TutorialGroupProgress.empty(sequence.length)};
    await _saveGroupProgress();
  }

  /// Update group progress after tutorial completion
  Future<void> _updateGroupProgress(TutorialCategory category, String tutorialId, String method) async {
    final sequence = tutorialSequences[category];
    if (sequence == null) return;

    // Count completed tutorials in this group
    int completedCount = 0;
    int skippedCount = 0;
    
    for (final id in sequence) {
      final isCompleted = await _tutorialService.isTutorialCompleted(id);
      if (isCompleted) {
        completedCount++;
        // You might want to track skip method per tutorial in the future
        if (method == 'skipped' && id == tutorialId) {
          skippedCount++;
        }
      }
    }

    final isGroupCompleted = completedCount == sequence.length;
    final currentProgress = state[category] ?? TutorialGroupProgress.empty(sequence.length);

    final newProgress = currentProgress.copyWith(
      completed: isGroupCompleted,
      completedSteps: completedCount,
      lastShown: tutorialId,
      lastShownAt: DateTime.now(),
      skippedCount: currentProgress.skippedCount + (method == 'skipped' ? 1 : 0),
      completionMethod: method,
    );

    state = {...state, category: newProgress};
    await _saveGroupProgress();
  }

  /// Load group progress from database
  Future<void> _loadGroupProgress() async {
    try {
      final groupProgressData = await _tutorialService.getGroupProgress();
      final Map<TutorialCategory, TutorialGroupProgress> newState = {};

      for (final category in TutorialCategory.values) {
        final sequence = tutorialSequences[category];
        if (sequence == null) continue;

        final categoryName = category.name;
        final progressData = groupProgressData[categoryName];

        if (progressData != null) {
          newState[category] = TutorialGroupProgress.fromJson(progressData);
        } else {
          // Calculate progress from individual tutorial completions
          newState[category] = await _calculateGroupProgressFromIndividual(category, sequence);
        }
      }

      state = newState;
      debugPrint('TutorialGroup: Loaded group progress for ${newState.length} categories');
    } catch (e) {
      debugPrint('TutorialGroup: Error loading group progress: $e');
      // Initialize empty progress for all groups
      final Map<TutorialCategory, TutorialGroupProgress> emptyState = {};
      for (final category in TutorialCategory.values) {
        final sequence = tutorialSequences[category];
        if (sequence != null) {
          emptyState[category] = TutorialGroupProgress.empty(sequence.length);
        }
      }
      state = emptyState;
    }
  }

  /// Calculate group progress from individual tutorial completions
  Future<TutorialGroupProgress> _calculateGroupProgressFromIndividual(
    TutorialCategory category, 
    List<String> sequence
  ) async {
    int completedCount = 0;
    String? lastCompleted;
    DateTime? lastCompletedAt;

    for (final tutorialId in sequence) {
      final isCompleted = await _tutorialService.isTutorialCompleted(tutorialId);
      if (isCompleted) {
        completedCount++;
        lastCompleted = tutorialId; // Assume order represents completion order
        lastCompletedAt = DateTime.now(); // We don't have exact timestamps for old data
      }
    }

    return TutorialGroupProgress(
      completed: completedCount == sequence.length,
      totalSteps: sequence.length,
      completedSteps: completedCount,
      lastShown: lastCompleted,
      lastShownAt: lastCompletedAt,
    );
  }

  /// Save group progress to database
  Future<void> _saveGroupProgress() async {
    try {
      final Map<String, Map<String, dynamic>> progressData = {};
      
      for (final entry in state.entries) {
        progressData[entry.key.name] = entry.value.toJson();
      }

      await _tutorialService.saveGroupProgress(progressData);
      debugPrint('TutorialGroup: Saved group progress for ${progressData.length} categories');
    } catch (e) {
      debugPrint('TutorialGroup: Error saving group progress: $e');
    }
  }

  /// Refresh progress from database (useful after sync)
  Future<void> refreshFromDatabase() async {
    await _loadGroupProgress();
  }
}

/// Provider for tutorial group management
final tutorialGroupProvider = StateNotifierProvider<TutorialGroupNotifier, Map<TutorialCategory, TutorialGroupProgress>>(
  (ref) => TutorialGroupNotifier(),
);

/// Convenience providers for specific group completion status
final navigationTutorialCompletedProvider = Provider<bool>((ref) {
  return ref.watch(tutorialGroupProvider.notifier).isGroupCompleted(TutorialCategory.navigation);
});

final gameplayTutorialCompletedProvider = Provider<bool>((ref) {
  return ref.watch(tutorialGroupProvider.notifier).isGroupCompleted(TutorialCategory.gameplay);
});

final dialogueTutorialCompletedProvider = Provider<bool>((ref) {
  return ref.watch(tutorialGroupProvider.notifier).isGroupCompleted(TutorialCategory.dialogue);
});

final combatTutorialCompletedProvider = Provider<bool>((ref) {
  return ref.watch(tutorialGroupProvider.notifier).isGroupCompleted(TutorialCategory.combat);
});

final learningTutorialCompletedProvider = Provider<bool>((ref) {
  return ref.watch(tutorialGroupProvider.notifier).isGroupCompleted(TutorialCategory.learning);
});

final achievementsTutorialCompletedProvider = Provider<bool>((ref) {
  return ref.watch(tutorialGroupProvider.notifier).isGroupCompleted(TutorialCategory.achievements);
});