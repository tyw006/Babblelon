import 'package:flutter/foundation.dart';
import 'package:babblelon/providers/tutorial_database_providers.dart';
import 'package:babblelon/services/tutorial_database_service.dart';

/// Service for managing tutorial sequences and determining next tutorials to show
class TutorialSequenceService {
  static final TutorialSequenceService _instance = TutorialSequenceService._internal();
  factory TutorialSequenceService() => _instance;
  TutorialSequenceService._internal();

  final TutorialDatabaseService _databaseService = TutorialDatabaseService();

  /// Get the next tutorial ID to show for a specific category
  /// Returns null if all tutorials in the category are completed
  Future<String?> getNextTutorialInCategory(TutorialCategory category) async {
    try {
      final sequence = tutorialSequences[category];
      if (sequence == null || sequence.isEmpty) {
        debugPrint('TutorialSequenceService: No tutorials defined for category $category');
        return null;
      }

      // Check each tutorial in sequence to find the first incomplete one
      for (final tutorialId in sequence) {
        final isCompleted = await _databaseService.isTutorialCompleted(tutorialId);
        if (!isCompleted) {
          debugPrint('TutorialSequenceService: Next tutorial for $category is $tutorialId');
          return tutorialId;
        }
      }

      debugPrint('TutorialSequenceService: All tutorials completed for category $category');
      return null;
    } catch (e) {
      debugPrint('TutorialSequenceService: Error getting next tutorial for $category: $e');
      return null;
    }
  }

  /// Check if a tutorial category has any incomplete tutorials
  Future<bool> hasIncompleteTutorials(TutorialCategory category) async {
    final nextTutorial = await getNextTutorialInCategory(category);
    return nextTutorial != null;
  }

  /// Get progress information for a tutorial category
  /// Returns {progress: completedCount, total: totalCount, completed: isFullyCompleted}
  Future<Map<String, dynamic>> getCategoryProgress(TutorialCategory category) async {
    try {
      final sequence = tutorialSequences[category];
      if (sequence == null || sequence.isEmpty) {
        return {'progress': 0, 'total': 0, 'completed': true};
      }

      int completedCount = 0;
      for (final tutorialId in sequence) {
        final isCompleted = await _databaseService.isTutorialCompleted(tutorialId);
        if (isCompleted) {
          completedCount++;
        }
      }

      final total = sequence.length;
      final isFullyCompleted = completedCount == total;

      final progress = {
        'progress': completedCount,
        'total': total,
        'completed': isFullyCompleted,
      };

      debugPrint('TutorialSequenceService: Progress for $category: $progress');
      return progress;
    } catch (e) {
      debugPrint('TutorialSequenceService: Error getting category progress for $category: $e');
      return {'progress': 0, 'total': 0, 'completed': false};
    }
  }

  /// Mark a tutorial as completed with a specific completion method
  Future<void> completeTutorial(String tutorialId, String completionMethod) async {
    try {
      debugPrint('TutorialSequenceService: Completing tutorial $tutorialId via $completionMethod');
      
      // Mark tutorial as completed
      await _databaseService.markTutorialCompleted(tutorialId);
      
      // Record completion method
      await _databaseService.setTutorialCompletionMethod(tutorialId, completionMethod);
      
      debugPrint('TutorialSequenceService: Successfully completed tutorial $tutorialId');
    } catch (e) {
      debugPrint('TutorialSequenceService: Error completing tutorial $tutorialId: $e');
    }
  }

  /// Skip a tutorial (marks it as completed with "skipped" method)
  Future<void> skipTutorial(String tutorialId) async {
    await completeTutorial(tutorialId, 'skipped');
  }

  /// Auto-skip remaining tutorials in a category
  Future<void> autoSkipRemainingTutorials(TutorialCategory category) async {
    try {
      final sequence = tutorialSequences[category];
      if (sequence == null || sequence.isEmpty) {
        debugPrint('TutorialSequenceService: No tutorials to skip for category $category');
        return;
      }

      // Find remaining incomplete tutorials and mark them as auto-skipped
      for (final tutorialId in sequence) {
        final isCompleted = await _databaseService.isTutorialCompleted(tutorialId);
        if (!isCompleted) {
          await completeTutorial(tutorialId, 'auto_skipped');
        }
      }

      debugPrint('TutorialSequenceService: Auto-skipped remaining tutorials for $category');
    } catch (e) {
      debugPrint('TutorialSequenceService: Error auto-skipping tutorials for $category: $e');
    }
  }

  /// Update group progress for all categories and sync to database
  Future<void> updateGroupProgress() async {
    try {
      final Map<String, Map<String, dynamic>> allProgress = {};

      // Calculate progress for each category
      for (final category in TutorialCategory.values) {
        final progress = await getCategoryProgress(category);
        allProgress[category.name] = progress;
      }

      // Save to database
      await _databaseService.saveGroupProgress(allProgress);
      
      debugPrint('TutorialSequenceService: Updated group progress for ${allProgress.length} categories');
    } catch (e) {
      debugPrint('TutorialSequenceService: Error updating group progress: $e');
    }
  }

  /// Get comprehensive tutorial status for debugging
  Future<Map<String, dynamic>> getTutorialSystemStatus() async {
    try {
      final Map<String, dynamic> status = {
        'categories': {},
        'completion_methods': {},
      };

      // Get progress for each category
      for (final category in TutorialCategory.values) {
        final progress = await getCategoryProgress(category);
        final nextTutorial = await getNextTutorialInCategory(category);
        
        status['categories'][category.name] = {
          ...progress,
          'next_tutorial': nextTutorial,
        };
      }

      // Get completion methods for debugging
      final completedTutorials = await _databaseService.getCompletedTutorials();
      for (final tutorialId in completedTutorials.keys) {
        final method = await _databaseService.getTutorialCompletionMethod(tutorialId);
        status['completion_methods'][tutorialId] = method;
      }

      return status;
    } catch (e) {
      debugPrint('TutorialSequenceService: Error getting system status: $e');
      return {'error': e.toString()};
    }
  }
}