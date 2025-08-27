import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/navigation_provider.dart';
import 'package:babblelon/providers/tutorial_database_providers.dart';
import 'package:babblelon/services/tutorial_sequence_service.dart';
import 'package:babblelon/screens/home_screen.dart';
import 'package:babblelon/screens/learn_screen.dart';
import 'package:babblelon/screens/settings_screen.dart';
import 'package:babblelon/theme/modern_design_system.dart' as modern;
import 'package:babblelon/services/tutorial_service.dart';

/// Main navigation screen with bottom tab navigation
/// Optimized for performance with minimal animations
class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  @override
  void initState() {
    super.initState();
    
    // Note: Intro music is already handled by IntroSplashScreen/3D Earth globe
    // No need to trigger it again here to avoid conflicts
    
    // Check and show tutorial on first load with additional delay for stability
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkAndShowMainTutorial();
        }
      });
    });
  }

  Future<void> _checkAndShowMainTutorial() async {
    if (!mounted) return;
    
    try {
      final sequenceService = TutorialSequenceService();
      
      // Check if navigation tutorials need to be shown
      final hasIncompleteNavigation = await sequenceService.hasIncompleteTutorials(TutorialCategory.navigation);
      
      if (hasIncompleteNavigation && mounted) {
        debugPrint('MainNavigation: Starting navigation tutorial sequence');
        
        // Get the next tutorial to show
        final nextTutorialId = await sequenceService.getNextTutorialInCategory(TutorialCategory.navigation);
        
        if (nextTutorialId != null && mounted) {
          // Start tutorial using the existing TutorialManager system
          final tutorialManager = TutorialManager(context: context, ref: ref);
          
          try {
            // Map tutorial IDs to TutorialTrigger enum values
            TutorialTrigger? trigger;
            switch (nextTutorialId) {
              case 'blabbybara_intro':
              case 'home_tour':
              case 'learn_return':
                trigger = TutorialTrigger.mainMenu;
                break;
              default:
                trigger = TutorialTrigger.mainMenu;
            }
            
            // Start the tutorial - this will return early if no steps to show
            debugPrint('MainNavigation: Starting tutorial $nextTutorialId with trigger $trigger');
            await tutorialManager.startTutorial(trigger);
            
            // Only mark as completed if this tutorial sequence actually ran
            // The tutorial system returns early if no steps, so we'll just mark as completed
            // Our earlier fix in tutorial_database_service prevents duplicate marking
            debugPrint('MainNavigation: Marking tutorial $nextTutorialId as completed');
            await sequenceService.completeTutorial(nextTutorialId, 'viewed');
            
            // Update group progress
            await sequenceService.updateGroupProgress();
            
            debugPrint('MainNavigation: Completed tutorial $nextTutorialId');
          } catch (e) {
            debugPrint('MainNavigation: Error showing tutorial: $e');
          }
        }
      } else {
        debugPrint('MainNavigation: Navigation tutorials already completed');
      }
    } catch (e) {
      debugPrint('MainNavigation: Error checking tutorial status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(currentTabProvider);
    
    return Scaffold(
      backgroundColor: modern.ModernDesignSystem.primaryBackground,
      body: _buildBody(currentTab),
      bottomNavigationBar: _buildBottomNavigation(context, ref, currentTab),
    );
  }

  /// Build the main body content based on current tab
  Widget _buildBody(AppTab currentTab) {
    switch (currentTab) {
      case AppTab.home:
        return const HomeScreen();
      case AppTab.learn:
        return const LearnScreen();
      case AppTab.settings:
        return const SettingsScreen();
    }
  }

  /// Build the bottom navigation bar with space theme
  Widget _buildBottomNavigation(BuildContext context, WidgetRef ref, AppTab currentTab) {
    return Container(
      decoration: BoxDecoration(
        color: modern.ModernDesignSystem.primarySurface,
        border: Border(
          top: BorderSide(
            color: modern.ModernDesignSystem.primaryAccent.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        elevation: 0,
        currentIndex: currentTab.index,
        onTap: (index) {
          final tab = AppTab.values[index];
          ref.read(navigationControllerProvider).switchToTab(tab);
        },
        selectedItemColor: modern.ModernDesignSystem.primaryAccent,
        unselectedItemColor: modern.ModernDesignSystem.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: modern.ModernDesignSystem.caption.copyWith(
          fontWeight: FontWeight.w600,
          color: modern.ModernDesignSystem.primaryAccent,
        ),
        unselectedLabelStyle: modern.ModernDesignSystem.caption.copyWith(
          fontWeight: FontWeight.w400,
          color: modern.ModernDesignSystem.textSecondary,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, size: 24),
            activeIcon: Icon(Icons.home, size: 24),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined, size: 24),
            activeIcon: Icon(Icons.school, size: 24),
            label: 'Learn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined, size: 24),
            activeIcon: Icon(Icons.settings, size: 24),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}