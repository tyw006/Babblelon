import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/main_screen/widgets/space_loading_screen.dart';
import 'package:babblelon/screens/enhanced_onboarding_screen.dart';
import 'package:babblelon/providers/onboarding_provider.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:babblelon/services/isar_service.dart';

/// App controller that manages the main app flow
/// Routes to onboarding or main app based on user profile completion
class AppController extends ConsumerWidget {
  const AppController({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingCompleted = ref.watch(onboardingCompletedProvider);
    final isarService = ref.watch(isarServiceProvider);

    return FutureBuilder<bool>(
      future: _checkProfileCompletion(isarService),
      builder: (context, snapshot) {
        // Show loading while checking profile
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        final hasCompletedProfile = snapshot.data ?? false;

        // If user has completed onboarding or has a profile, go to main app
        if (onboardingCompleted || hasCompletedProfile) {
          return const SpaceLoadingScreen();
        }
        
        // Otherwise, show enhanced onboarding
        return const EnhancedOnboardingScreen();
      },
    );
  }

  Future<bool> _checkProfileCompletion(IsarService isarService) async {
    try {
      // Get count of all profiles first
      final profileCount = await isarService.isar.playerProfiles.count();
      
      // If no profiles exist, onboarding is not completed
      return profileCount > 0;
    } catch (e) {
      // On error, assume no profile exists
      return false;
    }
  }
}