import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart' as cartoon;
import 'package:babblelon/providers/navigation_provider.dart';
import 'package:babblelon/providers/player_data_providers.dart';
import 'package:babblelon/services/auth_service_interface.dart';

/// Home screen dashboard with fast-loading stats
/// Performance optimized with minimal animations
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: cartoon.CartoonDesignSystem.creamWhite,
      appBar: AppBar(
        title: Text(
          'BabbleOn',
          style: cartoon.CartoonDesignSystem.headlineLarge.copyWith(
            color: cartoon.CartoonDesignSystem.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WelcomeSection(),
              SizedBox(height: 24),
              _StatsGrid(),
              SizedBox(height: 24),
              _ContinueLearningSection(),
              SizedBox(height: 24),
              _RecentActivitySection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Welcome section with user greeting
class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: cartoon.CartoonDesignSystem.primaryGradient,
        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
        border: Border.all(
          color: cartoon.CartoonDesignSystem.cherryRed.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: cartoon.CartoonDesignSystem.warmOrange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back!',
            style: cartoon.CartoonDesignSystem.headlineMedium.copyWith(
              color: cartoon.CartoonDesignSystem.textOnBright,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to continue your Thai learning journey?',
            style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
              color: cartoon.CartoonDesignSystem.textOnBright.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stats grid with player progress
class _StatsGrid extends ConsumerWidget {
  const _StatsGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current authenticated user ID
    final authService = AuthServiceFactory.getInstance();
    final currentUserId = authService.currentUserId;
    
    // If no authenticated user, show sign-in prompt
    if (currentUserId == null) {
      return _buildSignInPrompt();
    }
    
    // Use the playerProfileProvider with the authenticated user ID
    final profileAsyncValue = ref.watch(playerProfileProvider(currentUserId));
    
    return profileAsyncValue.when(
      data: (profile) => _buildStatsGrid(profile),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _buildErrorState(error),
    );
  }
  
  Widget _buildSignInPrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 64,
            color: cartoon.CartoonDesignSystem.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'Please sign in to view your progress',
            style: cartoon.CartoonDesignSystem.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Your game progress is saved to your account',
            style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
              color: cartoon.CartoonDesignSystem.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: cartoon.CartoonDesignSystem.cherryRed,
          ),
          const SizedBox(height: 16),
          Text(
            'Unable to load profile',
            style: cartoon.CartoonDesignSystem.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
              color: cartoon.CartoonDesignSystem.textMuted,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatsGrid(PlayerProfile? profile) {
    // If profile is null, show placeholder
    if (profile == null) {
      return _buildSignInPrompt();
    }
    
    return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.2,
          children: [
            _StatCard(
              title: 'Level',
              value: '${profile.playerLevel}',
              icon: Icons.star_outlined,
              color: cartoon.CartoonDesignSystem.sunshineYellow,
            ),
            _StatCard(
              title: 'XP',
              value: '${profile.experiencePoints}',
              icon: Icons.psychology_outlined,
              color: cartoon.CartoonDesignSystem.skyBlue,
            ),
            _StatCard(
              title: 'Gold',
              value: '${profile.gold}',
              icon: Icons.monetization_on_outlined,
              color: cartoon.CartoonDesignSystem.warmOrange,
            ),
            _StatCard(
              title: 'Streak',
              value: '0', // TODO: Implement streak tracking
              icon: Icons.local_fire_department_outlined,
              color: cartoon.CartoonDesignSystem.cherryRed,
            ),
          ],
        );
  }
}

/// Individual stat card widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cartoon.CartoonDesignSystem.lightBlue.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
        border: Border.all(
          color: color.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: cartoon.CartoonDesignSystem.headlineMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
              color: cartoon.CartoonDesignSystem.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Continue learning section with main CTA
class _ContinueLearningSection extends ConsumerWidget {
  const _ContinueLearningSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: cartoon.CartoonDesignSystem.warmGradient,
        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
        border: Border.all(
          color: cartoon.CartoonDesignSystem.cherryRed,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: cartoon.CartoonDesignSystem.warmOrange.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.play_circle_filled,
            color: cartoon.CartoonDesignSystem.textOnBright,
            size: 56,
          ),
          const SizedBox(height: 16),
          Text(
            'Continue Learning',
            style: cartoon.CartoonDesignSystem.headlineLarge.copyWith(
              color: cartoon.CartoonDesignSystem.textOnBright,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jump back into your Thai adventure',
            style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
              color: cartoon.CartoonDesignSystem.textOnBright.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 16),
          cartoon.CartoonButton(
            text: 'Start Learning',
            onPressed: () {
              ref.read(navigationControllerProvider).goToLearn();
            },
            style: cartoon.CartoonButtonStyle.accent,
            isLarge: true,
            icon: Icons.rocket_launch,
          ),
        ],
      ),
    );
  }
}

/// Recent activity section with achievements
class _RecentActivitySection extends StatelessWidget {
  const _RecentActivitySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: cartoon.CartoonDesignSystem.headlineMedium.copyWith(
            color: cartoon.CartoonDesignSystem.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cartoon.CartoonDesignSystem.softPeach.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
            border: Border.all(
              color: cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: cartoon.CartoonDesignSystem.textMuted,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'No recent activity',
                style: cartoon.CartoonDesignSystem.bodyLarge.copyWith(
                  color: cartoon.CartoonDesignSystem.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start learning to see your progress here',
                style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                  color: cartoon.CartoonDesignSystem.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }
}