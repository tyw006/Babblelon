import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:babblelon/services/tutorial_database_service.dart';

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