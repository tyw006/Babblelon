import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';

/// Progress screen with performance-optimized charts and statistics
/// Uses built-in Flutter widgets for efficient rendering
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: CartoonDesignSystem.creamWhite,
      appBar: AppBar(
        title: Text(
          'Your Progress',
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
              _OverviewSection(),
              SizedBox(height: 24),
              _ProgressMetricsSection(),
              SizedBox(height: 24),
              _AchievementsSection(),
              SizedBox(height: 24),
              _DetailedStatsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overview section with main progress indicators
class _OverviewSection extends StatelessWidget {
  const _OverviewSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CartoonDesignSystem.softPeach,
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
        border: Border.all(
          color: CartoonDesignSystem.cherryRed.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning Overview',
            style: AppTheme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ProgressCircle(
                  title: 'Overall Progress',
                  progress: 0.35,
                  color: CartoonDesignSystem.sunshineYellow,
                  centerText: '35%',
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _ProgressCircle(
                  title: 'Weekly Goal',
                  progress: 0.68,
                  color: CartoonDesignSystem.cherryRed,
                  centerText: '68%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular progress indicator widget
class _ProgressCircle extends StatelessWidget {
  final String title;
  final double progress;
  final Color color;
  final String centerText;

  const _ProgressCircle({
    required this.title,
    required this.progress,
    required this.color,
    required this.centerText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: progress,
                strokeWidth: 8,
                backgroundColor: color.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
              Text(
                centerText,
                style: AppTheme.textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: AppTheme.textTheme.bodyMedium?.copyWith(
            color: CartoonDesignSystem.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Progress metrics section with statistics
class _ProgressMetricsSection extends ConsumerWidget {
  const _ProgressMetricsSection();

  /// Get all mastered phrases from the database
  Future<List<MasteredPhrase>> _getAllMasteredPhrases() async {
    final isarService = IsarService();
    return await isarService.getAllMasteredPhrases();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learning Metrics',
          style: AppTheme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<MasteredPhrase>>(
          future: _getAllMasteredPhrases(),
          builder: (context, snapshot) {
            final phrases = snapshot.data ?? [];
            final totalWords = phrases.length;
            final masteredWords = phrases.where((p) => p.isMastered).length;
            final masteredCharacters = phrases.where((p) => p.isCharacterMastered).length;
            final averageScore = phrases.isNotEmpty 
              ? phrases.map((p) => p.lastScore).fold(0.0, (a, b) => a + (b ?? 0.0)) / phrases.length
              : 0.0;

            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.8, // Adjusted from 2.0 to 1.8 for more height
              children: [
                _MetricCard(
                  title: 'Words Learned',
                  value: '$masteredWords',
                  subtitle: 'of $totalWords practiced',
                  icon: Icons.text_fields,
                  color: CartoonDesignSystem.sunshineYellow,
                  progress: totalWords > 0 ? masteredWords / totalWords : 0.0,
                ),
                _MetricCard(
                  title: 'Characters',
                  value: '$masteredCharacters',
                  subtitle: 'mastered',
                  icon: Icons.text_format,
                  color: CartoonDesignSystem.cherryRed,
                  progress: totalWords > 0 ? masteredCharacters / totalWords : 0.0,
                ),
                _MetricCard(
                  title: 'Accuracy',
                  value: '${(averageScore * 100).toInt()}%',
                  subtitle: 'average score',
                  icon: Icons.trending_up,
                  color: CartoonDesignSystem.forestGreen,
                  progress: averageScore,
                ),
                _MetricCard(
                  title: 'Practice Time',
                  value: '${phrases.fold(0, (sum, p) => sum + p.timesPracticed)}',
                  subtitle: 'sessions',
                  icon: Icons.timer,
                  color: CartoonDesignSystem.lavenderPurple,
                  progress: 0.7, // Placeholder progress
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Individual metric card with progress indicator
class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double progress;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8), // Reduced from 10 to 8
      decoration: BoxDecoration(
        color: CartoonDesignSystem.softPeach.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 14, // Reduced from 16 to 14
              ),
              const SizedBox(width: 2), // Reduced from 3 to 2
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                    color: CartoonDesignSystem.textSecondary,
                    fontSize: 11, // Explicitly set font size
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2), // Reduced from 4 to 2
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppTheme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 20, // Explicitly set font size
              ),
            ),
          ),
          Text(
            subtitle,
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: CartoonDesignSystem.textMuted,
              fontSize: 9, // Reduced from 10 to 9
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2), // Reduced from 4 to 2
          SizedBox(
            height: 3, // Fixed height for progress bar
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: color.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Achievements section with unlocked badges
class _AchievementsSection extends StatelessWidget {
  const _AchievementsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements',
          style: AppTheme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CartoonDesignSystem.softPeach,
            borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
            border: Border.all(
              color: CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                color: CartoonDesignSystem.textSecondary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'No achievements yet',
                style: AppTheme.textTheme.bodyLarge?.copyWith(
                  color: CartoonDesignSystem.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start learning to unlock your first achievement',
                style: AppTheme.textTheme.bodyMedium?.copyWith(
                  color: CartoonDesignSystem.textMuted,
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

/// Detailed statistics section
class _DetailedStatsSection extends StatelessWidget {
  const _DetailedStatsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Detailed Statistics',
          style: AppTheme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        _StatRow(
          label: 'Total Study Sessions',
          value: '0',
          icon: Icons.school_outlined,
        ),
        const SizedBox(height: 12),
        _StatRow(
          label: 'Longest Streak',
          value: '0 days',
          icon: Icons.local_fire_department_outlined,
        ),
        const SizedBox(height: 12),
        _StatRow(
          label: 'Words Per Session',
          value: '0.0',
          icon: Icons.speed_outlined,
        ),
        const SizedBox(height: 12),
        _StatRow(
          label: 'Improvement Rate',
          value: '0%',
          icon: Icons.trending_up_outlined,
        ),
      ],
    );
  }
}

/// Statistics row widget
class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CartoonDesignSystem.softPeach.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusSmall),
        border: Border.all(
          color: CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: CartoonDesignSystem.cherryRed,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: AppTheme.textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: CartoonDesignSystem.cherryRed,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}