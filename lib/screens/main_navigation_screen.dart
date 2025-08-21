import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/navigation_provider.dart';
import 'package:babblelon/providers/game_providers.dart';
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
    
    // Check if tutorial data is already loaded (from preloading in splash screen)
    final tutorialProgress = ref.read(tutorialProgressProvider);
    if (tutorialProgress.isNotEmpty) {
      debugPrint('Tutorial: Tutorial progress already loaded, checking completion status');
    } else {
      // Fallback: Brief wait for tutorial sync if preloading didn't complete
      // Reduced from 3 seconds to 500ms for better UX
      int attempts = 0;
      const maxAttempts = 5; // 5 * 100ms = 500ms max wait
      
      while (attempts < maxAttempts && mounted) {
        final currentProgress = ref.read(tutorialProgressProvider);
        if (currentProgress.isNotEmpty) {
          debugPrint('Tutorial: Tutorial progress loaded during fallback wait');
          break;
        }
        
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
    }
    
    if (!mounted) return;
    
    // Now check if main tutorial has been completed using the race-condition-safe provider
    final tutorialCompleted = ref.read(tutorialCompletedProvider);
    
    debugPrint('Tutorial: Tutorial completion status: $tutorialCompleted');
    
    if (!tutorialCompleted && mounted) {
      // Start tutorial immediately
      final tutorialManager = TutorialManager(context: context, ref: ref);
      ref.read(tutorialActiveProvider.notifier).state = true;
      
      try {
        await tutorialManager.startTutorial(TutorialTrigger.startAdventure);
        // Mark tutorial as completed
        if (mounted) {
          ref.read(tutorialCompletedProvider.notifier).markCompleted();
        }
      } finally {
        if (mounted) {
          ref.read(tutorialActiveProvider.notifier).state = false;
        }
      }
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
          ref.playButtonSound();
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