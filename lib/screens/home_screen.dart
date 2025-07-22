import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:babblelon/widgets/modern_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/providers/navigation_provider.dart';

/// Home screen dashboard with fast-loading stats
/// Performance optimized with minimal animations
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ModernDesignSystem.deepSpaceBlue,
      appBar: AppBar(
        title: Text(
          'BabbleOn',
          style: AppTheme.textTheme.headlineMedium,
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
        color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
        border: Border.all(
          color: ModernDesignSystem.electricCyan.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome back!',
            style: AppTheme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Ready to continue your Thai learning journey?',
            style: AppTheme.textTheme.bodyLarge?.copyWith(
              color: ModernDesignSystem.slateGray,
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

  /// Get default profile or create guest profile
  Future<PlayerProfile?> _getDefaultProfile() async {
    // Return a default profile structure for display
    // In a real app, this would check for existing user authentication
    return PlayerProfile()
      ..userId = 'guest'
      ..username = 'Guest Player'
      ..playerLevel = 1
      ..experiencePoints = 0
      ..gold = 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<PlayerProfile?>(
      future: _getDefaultProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        
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
              value: '${profile?.playerLevel ?? 1}',
              icon: Icons.star_outlined,
              color: ModernDesignSystem.warmOrange,
            ),
            _StatCard(
              title: 'XP',
              value: '${profile?.experiencePoints ?? 0}',
              icon: Icons.psychology_outlined,
              color: ModernDesignSystem.electricCyan,
            ),
            _StatCard(
              title: 'Gold',
              value: '${profile?.gold ?? 0}',
              icon: Icons.monetization_on_outlined,
              color: ModernDesignSystem.warmOrange,
            ),
            _StatCard(
              title: 'Streak',
              value: '0', // TODO: Implement streak tracking
              icon: Icons.local_fire_department_outlined,
              color: Colors.red,
            ),
          ],
        );
      },
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
        color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
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
            style: AppTheme.textTheme.headlineSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: ModernDesignSystem.slateGray,
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
        color: ModernDesignSystem.electricCyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
        border: Border.all(
          color: ModernDesignSystem.electricCyan.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.play_circle_filled,
            color: ModernDesignSystem.electricCyan,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Continue Learning',
            style: AppTheme.textTheme.headlineSmall?.copyWith(
              color: ModernDesignSystem.electricCyan,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Jump back into your Thai adventure',
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: ModernDesignSystem.slateGray,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.read(navigationControllerProvider).goToLearn();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernDesignSystem.electricCyan,
              foregroundColor: ModernDesignSystem.deepSpaceBlue,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            ),
            child: const Text('Start Learning'),
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
          style: AppTheme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
            border: Border.all(
              color: ModernDesignSystem.slateGray.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: ModernDesignSystem.slateGray,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'No recent activity',
                style: AppTheme.textTheme.bodyLarge?.copyWith(
                  color: ModernDesignSystem.slateGray,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start learning to see your progress here',
                style: AppTheme.textTheme.bodyMedium?.copyWith(
                  color: ModernDesignSystem.slateGray.withValues(alpha: 0.7),
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