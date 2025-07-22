import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/navigation_provider.dart';
import 'package:babblelon/screens/home_screen.dart';
import 'package:babblelon/screens/learn_screen.dart';
import 'package:babblelon/screens/progress_screen.dart';
import 'package:babblelon/screens/premium_screen.dart';
import 'package:babblelon/screens/settings_screen.dart';
import 'package:babblelon/widgets/modern_design_system.dart';

/// Main navigation screen with bottom tab navigation
/// Optimized for performance with minimal animations
class MainNavigationScreen extends ConsumerWidget {
  const MainNavigationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    
    return Scaffold(
      backgroundColor: ModernDesignSystem.deepSpaceBlue,
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
      case AppTab.progress:
        return const ProgressScreen();
      case AppTab.premium:
        return const PremiumScreen();
      case AppTab.settings:
        return const SettingsScreen();
    }
  }

  /// Build the bottom navigation bar with space theme
  Widget _buildBottomNavigation(BuildContext context, WidgetRef ref, AppTab currentTab) {
    return Container(
      decoration: BoxDecoration(
        color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: ModernDesignSystem.electricCyan.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
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
        selectedItemColor: ModernDesignSystem.electricCyan,
        unselectedItemColor: ModernDesignSystem.slateGray,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontFamily: 'Poppins',
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontFamily: 'Poppins',
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
            icon: Icon(Icons.trending_up_outlined, size: 24),
            activeIcon: Icon(Icons.trending_up, size: 24),
            label: 'Progress',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_outline, size: 24),
            activeIcon: Icon(Icons.star, size: 24),
            label: 'Premium',
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