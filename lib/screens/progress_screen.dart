import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/widgets/universal_stats_row.dart';

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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 16),
              UniversalStatsRow(),
              SizedBox(height: 20),
              _DetailedMetrics(),
            ],
          ),
        ),
      ),
    );
  }
}




/// Detailed metrics section - performance analytics
class _DetailedMetrics extends ConsumerWidget {
  const _DetailedMetrics();

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
          style: AppTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: CartoonDesignSystem.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
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

            return Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Words',
                        value: '$masteredWords',
                        subtitle: 'learned',
                        icon: Icons.text_fields,
                        color: CartoonDesignSystem.sunshineYellow,
                        progress: totalWords > 0 ? masteredWords / totalWords : 0.0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Accuracy',
                        value: '${(averageScore * 100).toInt()}%',
                        subtitle: 'average',
                        icon: Icons.trending_up,
                        color: CartoonDesignSystem.forestGreen,
                        progress: averageScore,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        title: 'Characters',
                        value: '$masteredCharacters',
                        subtitle: 'mastered',
                        icon: Icons.text_format,
                        color: CartoonDesignSystem.cherryRed,
                        progress: totalWords > 0 ? masteredCharacters / totalWords : 0.0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MetricCard(
                        title: 'Sessions',
                        value: '${phrases.fold(0, (sum, p) => sum + p.timesPracticed)}',
                        subtitle: 'total',
                        icon: Icons.timer,
                        color: CartoonDesignSystem.skyBlue,
                        progress: 0.7,
                      ),
                    ),
                  ],
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
      height: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: AppTheme.textTheme.bodySmall?.copyWith(
                  color: CartoonDesignSystem.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          Text(
            subtitle,
            style: AppTheme.textTheme.bodySmall?.copyWith(
              color: CartoonDesignSystem.textMuted,
              fontSize: 10,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: 3,
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

