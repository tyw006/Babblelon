import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/screens/boss_fight_screen.dart';
import 'package:babblelon/screens/game_screen.dart';
import 'package:babblelon/screens/enhanced_onboarding_screen.dart';
import 'package:babblelon/screens/character_selection_screen.dart';
import 'package:babblelon/game/babblelon_game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/providers/profile_providers.dart';
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/widgets/victory_report_dialog.dart';
import 'package:babblelon/widgets/defeat_dialog.dart';
import 'package:babblelon/widgets/character_tracing_test_widget.dart';
import 'package:babblelon/providers/battle_providers.dart';
import 'package:babblelon/services/posthog_service.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final soundEffectsEnabled = ref.read(gameStateProvider).soundEffectsEnabled;
    
    // Track screen view
    PostHogService.trackGameEvent(
      event: 'screen_view',
      screen: 'main_menu',
      additionalProperties: {
        'sound_effects_enabled': soundEffectsEnabled,
      },
    );
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/background/yaowarat_bg1.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'BabbleOn',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        blurRadius: 10.0,
                        color: Colors.black,
                        offset: Offset(5.0, 5.0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 50),
                
                // Debug Section (only visible in debug mode)
                if (kDebugMode) 
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300, width: 2),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.bug_report, color: Colors.orange.shade700),
                            const SizedBox(width: 8),
                            Text(
                              'DEBUG TOOLS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton(
                              onPressed: () => _resetOnboarding(context, ref),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Reset Onboarding'),
                            ),
                            ElevatedButton(
                              onPressed: () => _navigateToEnhancedOnboarding(context, ref),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Enhanced Onboarding'),
                            ),
                            ElevatedButton(
                              onPressed: () => _navigateToCharacterSelection(context, ref),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Character Selection'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 20),
                
                ElevatedButton(
                  onPressed: () {
                    ref.playButtonSound();
                    Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => GameScreen(),
                        transitionDuration: const Duration(milliseconds: 1200),
                      ),
                    );
                  },
                  child: const Text('Start Game'),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _showVictoryDialog(context),
                  child: const Text('Test Victory Dialog'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () => _showDefeatDialog(context),
                  child: const Text('Test Defeat Dialog'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _resetOnboarding(BuildContext context, WidgetRef ref) async {
    try {
      // Clear SharedPreferences (but keep this for app preferences like sound settings)
      final prefs = await SharedPreferences.getInstance();
      
      // Clear only onboarding-related keys, not all preferences
      await prefs.remove('onboarding_completed');
      
      // Clear local profile data from Isar
      final isarService = IsarService();
      final authService = AuthServiceFactory.getInstance();
      final userId = authService.currentUserId;
      
      if (userId != null) {
        final profile = await isarService.getPlayerProfile(userId);
        if (profile != null) {
          // Reset onboarding completion in local profile
          profile.onboardingCompleted = false;
          await isarService.savePlayerProfile(profile);
        }
      }
      
      // Refresh the profile completion provider to reflect changes
      final refreshProfile = ref.read(profileRefreshProvider);
      refreshProfile();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Onboarding reset successfully!'))
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to reset onboarding: $e'))
        );
      }
    }
  }

  Future<void> _navigateToEnhancedOnboarding(BuildContext context, WidgetRef ref) async {
    ref.playButtonSound();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EnhancedOnboardingScreen(),
      ),
    );
  }

  Future<void> _navigateToCharacterSelection(BuildContext context, WidgetRef ref) async {
    ref.playButtonSound();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CharacterSelectionScreen(),
      ),
    );
  }

  void _showVictoryDialog(BuildContext context) {
    final mockMetrics = BattleMetrics(
      battleStartTime: DateTime.now().subtract(const Duration(minutes: 5, seconds: 30)),
      pronunciationScores: [95.0, 88.5, 92.0, 78.0, 65.5],
      maxStreak: 7,
      totalDamageDealt: 150.0,
      finalPlayerHealth: 85,
      playerStartingHealth: 100,
      bossMaxHealth: 200,
      wordScores: {
        'hello': 95,
        'world': 88,
        'food': 92,
        'water': 78,
        'thank you': 65,
      },
      wordsUsed: {'hello', 'world', 'food', 'water', 'thank you'},
      wordFailureCount: {
        'water': 2,
        'thank you': 1,
      },
      expGained: 250,
      goldEarned: 150,
      newlyMasteredWords: {'hello', 'world', 'food'},
    );

    showDialog(
      context: context,
      builder: (context) => VictoryReportDialog(metrics: mockMetrics),
    );
  }

  void _showDefeatDialog(BuildContext context) {
    final mockDefeatMetrics = BattleMetrics(
      battleStartTime: DateTime.now().subtract(const Duration(minutes: 3, seconds: 15)),
      pronunciationScores: [65.0, 72.5, 58.0, 69.5, 61.0],
      maxStreak: 2,
      totalDamageDealt: 75.0,
      finalPlayerHealth: 0,
      playerStartingHealth: 100,
      bossMaxHealth: 200,
      wordScores: {
        'hello': 65,
        'water': 72,
        'chicken': 58,
        'spicy': 69,
        'rice': 61,
      },
      wordsUsed: {'hello', 'water', 'chicken', 'spicy', 'rice'},
      wordFailureCount: {
        'spicy': 3,
        'chicken': 2,
        'rice': 1,
      },
      expGained: 25,
      goldEarned: 10,
      newlyMasteredWords: {},
    );

    showDialog(
      context: context,
      builder: (context) => DefeatDialog(metrics: mockDefeatMetrics),
    );
  }
}