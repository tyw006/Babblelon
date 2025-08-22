import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/providers/tutorial_database_providers.dart';
import 'package:babblelon/theme/unified_dark_theme.dart';

/// Test status indicators for visual feedback
enum TestStatus {
  notRun,
  passed,
  failed,
  inProgress,
  needsReview,
}

/// Test category data structure
class TestCategory {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<TestScenario> scenarios;
  final Widget Function() screenBuilder;

  const TestCategory({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.scenarios,
    required this.screenBuilder,
  });
}

/// Individual test scenario within a category
class TestScenario {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback action;
  final TestStatus status;
  final String? notes;

  const TestScenario({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.action,
    this.status = TestStatus.notRun,
    this.notes,
  });

  TestScenario copyWith({
    String? id,
    String? title,
    String? description,
    IconData? icon,
    Color? color,
    VoidCallback? action,
    TestStatus? status,
    String? notes,
  }) {
    return TestScenario(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      action: action ?? this.action,
      status: status ?? this.status,
      notes: notes ?? this.notes,
    );
  }
}

/// Utility class for common test operations
class TestUtilities {
  
  /// Reset authentication state for fresh testing
  static Future<void> resetAuthState() async {
    try {
      final authService = AuthServiceFactory.getInstance();
      await authService.signOut();
    } catch (e) {
      debugPrint('Error clearing auth state: $e');
    }
  }

  /// Reset all tutorial progress
  static Future<void> resetAllTutorials(WidgetRef ref) async {
    try {
      await ref.read(tutorialCompletionProvider.notifier).resetAllTutorials();
    } catch (e) {
      debugPrint('Error resetting tutorials: $e');
    }
  }

  /// Mark user as returning by completing key tutorials
  static Future<void> simulateReturningUser(WidgetRef ref) async {
    try {
      final notifier = ref.read(tutorialCompletionProvider.notifier);
      await notifier.markTutorialCompleted('main_navigation_intro');
      await notifier.markTutorialCompleted('game_loading_intro');
      await notifier.markTutorialCompleted('first_npc_interaction');
    } catch (e) {
      debugPrint('Error simulating returning user: $e');
    }
  }

  /// Show success snackbar
  static void showSuccessMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show error snackbar
  static void showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show info snackbar
  static void showInfoMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Get status icon for test status
  static IconData getStatusIcon(TestStatus status) {
    switch (status) {
      case TestStatus.passed:
        return Icons.check_circle;
      case TestStatus.failed:
        return Icons.error;
      case TestStatus.inProgress:
        return Icons.hourglass_empty;
      case TestStatus.needsReview:
        return Icons.visibility;
      case TestStatus.notRun:
        return Icons.radio_button_unchecked;
    }
  }

  /// Get status color for test status
  static Color getStatusColor(TestStatus status) {
    switch (status) {
      case TestStatus.passed:
        return Colors.green;
      case TestStatus.failed:
        return Colors.red;
      case TestStatus.inProgress:
        return Colors.orange;
      case TestStatus.needsReview:
        return Colors.blue;
      case TestStatus.notRun:
        return Colors.grey;
    }
  }

  /// Build a test card widget
  static Widget buildTestCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    TestStatus status = TestStatus.notRun,
    String? notes,
  }) {
    return Card(
      color: UnifiedDarkTheme.primarySurface,
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Main icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: UnifiedDarkTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: const TextStyle(
                        color: UnifiedDarkTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    if (notes != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        style: const TextStyle(
                          color: UnifiedDarkTheme.textTertiary,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Status indicator
              Container(
                margin: const EdgeInsets.only(left: 8),
                child: Icon(
                  getStatusIcon(status),
                  color: getStatusColor(status),
                  size: 20,
                ),
              ),
              // Navigation arrow
              const Icon(
                Icons.arrow_forward_ios,
                color: UnifiedDarkTheme.textTertiary,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }


  /// Build an info box widget
  static Widget buildInfoBox(String text, {Color? color}) {
    final boxColor = color ?? UnifiedDarkTheme.info;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: boxColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: boxColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: boxColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: UnifiedDarkTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build section header
  static Widget buildSectionHeader(String title, String description) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: UnifiedDarkTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            color: UnifiedDarkTheme.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}