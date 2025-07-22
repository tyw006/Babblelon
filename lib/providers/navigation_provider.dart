import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Navigation tabs available in the app
enum AppTab {
  home,
  learn,
  progress,
  premium,
  settings,
}

/// Current tab state provider
/// Uses StateProvider for simple, efficient tab switching
final currentTabProvider = StateProvider<AppTab>((ref) => AppTab.home);

/// Tab navigation methods
class NavigationController {
  final Ref ref;
  
  NavigationController(this.ref);
  
  /// Switch to a specific tab instantly
  void switchToTab(AppTab tab) {
    ref.read(currentTabProvider.notifier).state = tab;
  }
  
  /// Switch to home tab
  void goToHome() => switchToTab(AppTab.home);
  
  /// Switch to learn tab (connects to existing game flow)
  void goToLearn() => switchToTab(AppTab.learn);
  
  /// Switch to progress tab
  void goToProgress() => switchToTab(AppTab.progress);
  
  /// Switch to premium tab
  void goToPremium() => switchToTab(AppTab.premium);
  
  /// Switch to settings tab
  void goToSettings() => switchToTab(AppTab.settings);
}

/// Navigation controller provider
final navigationControllerProvider = Provider<NavigationController>((ref) {
  return NavigationController(ref);
});