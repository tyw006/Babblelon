import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/tutorial_database_providers.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart' as cartoon;

/// Tutorial settings screen for managing tutorial preferences
/// Allows users to re-enable completed tutorials and view tutorial history
class TutorialSettingsScreen extends ConsumerStatefulWidget {
  const TutorialSettingsScreen({super.key});

  @override
  ConsumerState<TutorialSettingsScreen> createState() => _TutorialSettingsScreenState();
}

class _TutorialSettingsScreenState extends ConsumerState<TutorialSettingsScreen> {
  bool _showCompletedOnly = false;

  // Define all available tutorials with user-friendly names and descriptions
  // Aligned with actual tutorial system IDs from tutorial_service.dart
  static const Map<String, TutorialInfo> _availableTutorials = {
    // Navigation & Interface (Multi-step navigation tutorial)
    'navigation_tutorial_group': TutorialInfo(
      'Main Navigation Tutorial',
      'Learn how to navigate the main menu and app structure',
      Icons.navigation,
      TutorialCategory.navigation,
    ),
    
    // Gameplay Basics
    'game_loading_intro': TutorialInfo(
      'Game Introduction',
      'First-time game setup and basic controls',
      Icons.games,
      TutorialCategory.gameplay,
    ),
    'cultural_intro': TutorialInfo(
      'Cultural Level Introduction',
      'Introduction to exploring cultural environments',
      Icons.explore,
      TutorialCategory.gameplay,
    ),
    
    // Dialogue & NPCs
    'first_npc_interaction': TutorialInfo(
      'First NPC Meeting',
      'Meeting and approaching non-player characters',
      Icons.person,
      TutorialCategory.dialogue,
    ),
    'first_dialogue_session': TutorialInfo(
      'Dialogue System',
      'How to interact with NPCs and start conversations',
      Icons.record_voice_over,
      TutorialCategory.dialogue,
    ),
    'first_npc_response_tutorial': TutorialInfo(
      'NPC Response System',
      'Understanding NPC feedback and practice modes',
      Icons.feedback,
      TutorialCategory.dialogue,
    ),
    'voice_setup_guide': TutorialInfo(
      'Voice Setup Guide',
      'Setting up microphone and speech recognition',
      Icons.settings_voice,
      TutorialCategory.dialogue,
    ),
    'pronunciation_confidence_guide': TutorialInfo(
      'Pronunciation Scoring',
      'Understanding your pronunciation confidence scores',
      Icons.assessment,
      TutorialCategory.dialogue,
    ),
    
    // Combat & Battles  
    'charm_explanation': TutorialInfo(
      'Charm System',
      'How charm works and affects rewards',
      Icons.favorite,
      TutorialCategory.combat,
    ),
    'item_types': TutorialInfo(
      'Battle Items',
      'Attack and defense items for boss battles',
      Icons.inventory,
      TutorialCategory.combat,
    ),
    'regular_vs_special': TutorialInfo(
      'Item Tiers',
      'Regular vs special item differences and unlocking',
      Icons.star,
      TutorialCategory.combat,
    ),
    'boss_prerequisites_warning': TutorialInfo(
      'Boss Battle Requirements',
      'What you need before entering boss battles',
      Icons.warning_amber,
      TutorialCategory.combat,
    ),
    'boss_fight_intro': TutorialInfo(
      'Boss Battle Basics',
      'Introduction to boss battles and combat',
      Icons.sports_martial_arts,
      TutorialCategory.combat,
    ),
    'battle_mechanics_deep_dive': TutorialInfo(
      'Advanced Combat',
      'Detailed battle mechanics and strategies',
      Icons.calculate,
      TutorialCategory.combat,
    ),
    'portal_approach': TutorialInfo(
      'Boss Portal Approach',
      'Tutorial when approaching boss battle portals',
      Icons.location_on,
      TutorialCategory.combat,
    ),
    
    // Language Learning
    'character_tracing_tutorial': TutorialInfo(
      'Character Tracing',
      'Writing Thai characters with AI feedback',
      Icons.edit,
      TutorialCategory.learning,
    ),
    'pos_color_system': TutorialInfo(
      'Grammar Colors',
      'Understanding part-of-speech color coding',
      Icons.palette,
      TutorialCategory.learning,
    ),
    'transliteration_system': TutorialInfo(
      'Romanization Helper',
      'Using English letters to learn Thai pronunciation',
      Icons.translate,
      TutorialCategory.learning,
    ),
    'first_language_tools_tutorial': TutorialInfo(
      'Language Tools',
      'Advanced translation and custom content features',
      Icons.build,
      TutorialCategory.learning,
    ),
    
    // Achievements & Rewards
    'charm_thresholds_explained': TutorialInfo(
      'Charm Milestones',
      'Understanding charm thresholds and rewards',
      Icons.military_tech,
      TutorialCategory.achievements,
    ),
    'item_giving_tutorial': TutorialInfo(
      'Item Request System',
      'How to request items from NPCs',
      Icons.card_giftcard,
      TutorialCategory.achievements,
    ),
    'special_item_celebration': TutorialInfo(
      'Special Item Achievement',
      'Celebrating special item unlocks and mastery',
      Icons.emoji_events,
      TutorialCategory.achievements,
    ),
  };

  // Navigation tutorial step IDs that comprise the grouped navigation tutorial
  static const List<String> _navigationTutorialSteps = [
    'blabbybara_intro',
    'home_tour', 
    'progress_tour',
    'premium_tour',
    'settings_tour',
    'learn_return',
  ];

  /// Check if a tutorial is completed, with special handling for navigation group
  bool _isTutorialCompleted(String tutorialId, Map<String, bool> completions) {
    if (tutorialId == 'navigation_tutorial_group') {
      // Navigation tutorial is complete if ALL navigation steps are completed
      return _navigationTutorialSteps.every((stepId) => completions[stepId] == true);
    }
    return completions[tutorialId] == true;
  }
  
  /// Get completion status for display purposes
  Map<String, bool> _getEffectiveCompletions(Map<String, bool> rawCompletions) {
    final effective = Map<String, bool>.from(rawCompletions);
    
    // Add the navigation tutorial group completion status
    effective['navigation_tutorial_group'] = _isTutorialCompleted('navigation_tutorial_group', rawCompletions);
    
    return effective;
  }

  @override
  Widget build(BuildContext context) {
    final rawTutorialCompletions = ref.watch(tutorialCompletionProvider);
    // Get effective completions with navigation group handled
    final tutorialCompletions = _getEffectiveCompletions(rawTutorialCompletions);
    final tutorialStats = ref.watch(tutorialStatsProvider);

    return Scaffold(
      backgroundColor: cartoon.CartoonDesignSystem.creamWhite,
      appBar: AppBar(
        title: const Text(
          'Tutorial Settings',
          style: TextStyle(
            color: cartoon.CartoonDesignSystem.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: cartoon.CartoonDesignSystem.creamWhite,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: cartoon.CartoonDesignSystem.textPrimary,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showCompletedOnly ? Icons.check_box : Icons.check_box_outline_blank,
              color: cartoon.CartoonDesignSystem.cherryRed,
            ),
            onPressed: () => setState(() => _showCompletedOnly = !_showCompletedOnly),
            tooltip: 'Show completed only',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Statistics Card
            _buildStatsCard(tutorialStats),
            const SizedBox(height: 24),

            // Quick Actions
            _buildQuickActionsCard(),
            const SizedBox(height: 24),

            // Tutorial Categories
            ...TutorialCategory.values.map((category) =>
              _buildCategorySection(category, tutorialCompletions)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(AsyncValue<Map<String, dynamic>> tutorialStats) {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
        side: BorderSide(color: cartoon.CartoonDesignSystem.skyBlue, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics,
                  color: cartoon.CartoonDesignSystem.skyBlue,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Tutorial Progress',
                  style: cartoon.CartoonDesignSystem.headlineMedium.copyWith(
                    color: cartoon.CartoonDesignSystem.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            tutorialStats.when(
              data: (stats) {
                final totalCompleted = stats['total_completed'] ?? 0;
                final totalAvailable = _availableTutorials.length;
                final progressPercentage = totalAvailable > 0 
                    ? (totalCompleted / totalAvailable * 100).round() 
                    : 0;

                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Completed Tutorials',
                          style: cartoon.CartoonDesignSystem.bodyMedium,
                        ),
                        Text(
                          '$totalCompleted / $totalAvailable',
                          style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cartoon.CartoonDesignSystem.cherryRed,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: totalCompleted / totalAvailable,
                      backgroundColor: cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        cartoon.CartoonDesignSystem.cherryRed,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$progressPercentage% Complete',
                      style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                        color: cartoon.CartoonDesignSystem.textSecondary,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (error, stack) => Text(
                'Error loading stats: $error',
                style: TextStyle(color: cartoon.CartoonDesignSystem.cherryRed),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 4,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
        side: BorderSide(color: cartoon.CartoonDesignSystem.warmOrange, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.flash_on,
                  color: cartoon.CartoonDesignSystem.warmOrange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Quick Actions',
                  style: cartoon.CartoonDesignSystem.headlineMedium.copyWith(
                    color: cartoon.CartoonDesignSystem.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _resetAllTutorials(),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Reset All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cartoon.CartoonDesignSystem.cherryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _markAllAsCompleted(),
                    icon: const Icon(Icons.done_all),
                    label: const Text('Mark All Done'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cartoon.CartoonDesignSystem.forestGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(TutorialCategory category, Map<String, bool> completions) {
    final categoryTutorials = _availableTutorials.entries
        .where((entry) => entry.value.category == category)
        .toList();

    if (categoryTutorials.isEmpty) return const SizedBox.shrink();

    // Filter based on completion status if needed
    final filteredTutorials = _showCompletedOnly
        ? categoryTutorials.where((entry) => _isTutorialCompleted(entry.key, completions)).toList()
        : categoryTutorials;

    if (filteredTutorials.isEmpty && _showCompletedOnly) {
      return const SizedBox.shrink();
    }

    final completedCount = categoryTutorials
        .where((entry) => _isTutorialCompleted(entry.key, completions))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _getCategoryColor(category).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
            border: Border.all(color: _getCategoryColor(category), width: 1),
          ),
          child: Row(
            children: [
              Icon(
                _getCategoryIcon(category),
                color: _getCategoryColor(category),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                _getCategoryName(category),
                style: cartoon.CartoonDesignSystem.headlineMedium.copyWith(
                  color: cartoon.CartoonDesignSystem.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getCategoryColor(category),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$completedCount/${categoryTutorials.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tutorial Items
        ...filteredTutorials.map((entry) =>
          _buildTutorialItem(entry.key, entry.value, _isTutorialCompleted(entry.key, completions))),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTutorialItem(String tutorialId, TutorialInfo info, bool isCompleted) {
    return Card(
      elevation: 2,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
        side: BorderSide(
          color: isCompleted 
              ? cartoon.CartoonDesignSystem.forestGreen 
              : cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isCompleted 
                ? cartoon.CartoonDesignSystem.forestGreen.withValues(alpha: 0.1)
                : cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            isCompleted ? Icons.check_circle : info.icon,
            color: isCompleted 
                ? cartoon.CartoonDesignSystem.forestGreen
                : cartoon.CartoonDesignSystem.textSecondary,
            size: 20,
          ),
        ),
        title: Text(
          info.name,
          style: cartoon.CartoonDesignSystem.bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            color: cartoon.CartoonDesignSystem.textPrimary,
          ),
        ),
        subtitle: Text(
          info.description,
          style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
            color: cartoon.CartoonDesignSystem.textSecondary,
          ),
        ),
        trailing: Switch(
          value: isCompleted,
          onChanged: (value) => _toggleTutorial(tutorialId, value),
          activeColor: cartoon.CartoonDesignSystem.forestGreen,
        ),
      ),
    );
  }

  // Category helpers
  Color _getCategoryColor(TutorialCategory category) {
    switch (category) {
      case TutorialCategory.navigation:
        return cartoon.CartoonDesignSystem.skyBlue;
      case TutorialCategory.gameplay:
        return cartoon.CartoonDesignSystem.sunshineYellow;
      case TutorialCategory.dialogue:
        return cartoon.CartoonDesignSystem.cherryRed;
      case TutorialCategory.combat:
        return cartoon.CartoonDesignSystem.warmOrange;
      case TutorialCategory.learning:
        return cartoon.CartoonDesignSystem.forestGreen;
      case TutorialCategory.achievements:
        return cartoon.CartoonDesignSystem.cherryRed;
    }
  }

  IconData _getCategoryIcon(TutorialCategory category) {
    switch (category) {
      case TutorialCategory.navigation:
        return Icons.navigation;
      case TutorialCategory.gameplay:
        return Icons.games;
      case TutorialCategory.dialogue:
        return Icons.chat_bubble;
      case TutorialCategory.combat:
        return Icons.sports_martial_arts;
      case TutorialCategory.learning:
        return Icons.school;
      case TutorialCategory.achievements:
        return Icons.emoji_events;
    }
  }

  String _getCategoryName(TutorialCategory category) {
    switch (category) {
      case TutorialCategory.navigation:
        return 'Navigation & Interface';
      case TutorialCategory.gameplay:
        return 'Gameplay Basics';
      case TutorialCategory.dialogue:
        return 'Dialogue & NPCs';
      case TutorialCategory.combat:
        return 'Combat & Battles';
      case TutorialCategory.learning:
        return 'Language Learning';
      case TutorialCategory.achievements:
        return 'Achievements & Rewards';
    }
  }

  // Action methods
  void _toggleTutorial(String tutorialId, bool completed) async {
    if (tutorialId == 'navigation_tutorial_group') {
      // Handle navigation tutorial group specially
      if (completed) {
        // Mark all navigation steps as completed
        for (final stepId in _navigationTutorialSteps) {
          await ref.read(tutorialCompletionProvider.notifier).markTutorialCompleted(stepId);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('All navigation tutorial steps marked as completed'),
              backgroundColor: cartoon.CartoonDesignSystem.forestGreen,
            ),
          );
        }
      } else {
        // Reset all navigation steps
        for (final stepId in _navigationTutorialSteps) {
          await ref.read(tutorialCompletionProvider.notifier).resetTutorial(stepId);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('All navigation tutorial steps reset'),
              backgroundColor: cartoon.CartoonDesignSystem.warmOrange,
            ),
          );
        }
      }
    } else {
      // Handle regular tutorials
      if (completed) {
        await ref.read(tutorialCompletionProvider.notifier).markTutorialCompleted(tutorialId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tutorial "${_availableTutorials[tutorialId]?.name}" marked as completed'),
              backgroundColor: cartoon.CartoonDesignSystem.forestGreen,
            ),
          );
        }
      } else {
        await ref.read(tutorialCompletionProvider.notifier).resetTutorial(tutorialId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tutorial "${_availableTutorials[tutorialId]?.name}" reset'),
              backgroundColor: cartoon.CartoonDesignSystem.warmOrange,
            ),
          );
        }
      }
    }
  }

  void _resetAllTutorials() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset All Tutorials'),
        content: const Text(
          'This will mark all tutorials as not completed. You will see all tutorial popups again when you encounter them in the app.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: cartoon.CartoonDesignSystem.cherryRed,
            ),
            child: const Text('Reset All'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref.read(tutorialCompletionProvider.notifier).resetAllTutorials();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('All tutorials have been reset'),
          backgroundColor: cartoon.CartoonDesignSystem.cherryRed,
        ),
      );
    }
  }

  void _markAllAsCompleted() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark All as Completed'),
        content: const Text(
          'This will mark all tutorials as completed. You will not see tutorial popups unless you reset them.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: cartoon.CartoonDesignSystem.forestGreen,
            ),
            child: const Text('Mark All Done'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // Mark all tutorials as completed
      for (final tutorialId in _availableTutorials.keys) {
        await ref.read(tutorialCompletionProvider.notifier).markTutorialCompleted(tutorialId);
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('All tutorials marked as completed'),
            backgroundColor: cartoon.CartoonDesignSystem.forestGreen,
          ),
        );
      }
    }
  }
}

/// Tutorial information data class
class TutorialInfo {
  final String name;
  final String description;
  final IconData icon;
  final TutorialCategory category;

  const TutorialInfo(this.name, this.description, this.icon, this.category);
}

/// Tutorial categories for organization
enum TutorialCategory {
  navigation,
  gameplay,
  dialogue,
  combat,
  learning,
  achievements,
}