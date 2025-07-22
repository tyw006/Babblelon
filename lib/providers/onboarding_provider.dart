import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Onboarding completion state provider
final onboardingCompletedProvider = StateNotifierProvider<OnboardingNotifier, bool>((ref) {
  return OnboardingNotifier();
});

/// Onboarding state notifier for managing completion status
class OnboardingNotifier extends StateNotifier<bool> {
  OnboardingNotifier() : super(false) {
    _loadOnboardingStatus();
  }

  static const String _onboardingKey = 'onboarding_completed';

  /// Load onboarding status from local storage
  Future<void> _loadOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool(_onboardingKey) ?? false;
      
      // Also check if user has a profile (returning user)
      // For now, we'll just use SharedPreferences
      final hasProfile = false;
      
      // If user has a profile, consider onboarding completed
      state = isCompleted || hasProfile;
    } catch (e) {
      state = false;
    }
  }

  /// Mark onboarding as completed
  Future<void> completeOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_onboardingKey, true);
      state = true;
    } catch (e) {
      // Fallback to local state if SharedPreferences fails
      state = true;
    }
  }

  /// Skip onboarding (for returning users)
  Future<void> skipOnboarding() async {
    await completeOnboarding();
  }

  /// Reset onboarding status (for testing)
  Future<void> resetOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_onboardingKey);
      state = false;
    } catch (e) {
      state = false;
    }
  }
}