import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/theme/modern_design_system.dart' as modern;
import 'package:babblelon/providers/navigation_provider.dart';
import 'package:babblelon/widgets/universal_stats_row.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/providers/player_data_providers.dart' as player_providers;
import 'package:babblelon/utils/language_utils.dart';

/// Home screen dashboard with fast-loading stats
/// Performance optimized with minimal animations
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: modern.ModernDesignSystem.creamWhite,
      appBar: AppBar(
        title: Text(
          'BabbleOn',
          style: modern.ModernDesignSystem.headlineLarge.copyWith(
            color: modern.ModernDesignSystem.textPrimary,
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 16),
              _WelcomeSection(),
              SizedBox(height: 20),
              UniversalStatsRow(),
              SizedBox(height: 24),
              _FloatingHeroButton(),
              SizedBox(height: 20),
              _DailyGoalCard(),
              SizedBox(height: 20),
              _DetailedMetrics(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Daily goal card - motivational
class _DailyGoalCard extends StatelessWidget {
  const _DailyGoalCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: modern.ModernDesignSystem.info.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(
          color: modern.ModernDesignSystem.info.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.track_changes,
            color: modern.ModernDesignSystem.info,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Goal',
                  style: modern.ModernDesignSystem.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: modern.ModernDesignSystem.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Practice for 15 minutes',
                  style: modern.ModernDesignSystem.bodyMedium.copyWith(
                    color: modern.ModernDesignSystem.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating hero learn button - modern design
class _FloatingHeroButton extends ConsumerWidget {
  const _FloatingHeroButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        ref.read(navigationControllerProvider).goToLearn();
      },
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment.topLeft,
            radius: 1.2,
            colors: [
              modern.ModernDesignSystem.sunshineYellow,
              modern.ModernDesignSystem.warmOrange,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: modern.ModernDesignSystem.warmOrange.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: 2,
            ),
            BoxShadow(
              color: modern.ModernDesignSystem.sunshineYellow.withValues(alpha: 0.3),
              blurRadius: 40,
              offset: const Offset(0, 0),
              spreadRadius: 5,
            ),
          ],
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_arrow,
              size: 36,
              color: Colors.white,
            ),
            SizedBox(height: 2),
            Text(
              'LEARN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Welcome section with greeting and motivation
class _WelcomeSection extends ConsumerWidget {
  const _WelcomeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerProfileAsync = ref.watch(player_providers.currentPlayerProfileProvider);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            modern.ModernDesignSystem.sunshineYellow.withValues(alpha: 0.15),
            modern.ModernDesignSystem.warmOrange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: modern.ModernDesignSystem.sunshineYellow.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.waving_hand,
                color: modern.ModernDesignSystem.warmOrange,
                size: 24,
              ),
              const SizedBox(width: 8),
              playerProfileAsync.when(
                data: (profile) {
                  // Debug logging to verify profile data
                  debugPrint('🔍 HomeScreen: Profile loaded - firstName: ${profile?.firstName}, lastName: ${profile?.lastName}, id: ${profile?.id}');
                  final firstName = profile?.firstName;
                  final displayName = firstName?.isNotEmpty == true ? firstName! : 'Learner';
                  debugPrint('🔍 HomeScreen: Display name resolved to: $displayName');
                  return Text(
                    'Welcome back, $displayName!',
                    style: AppTheme.textTheme.headlineSmall?.copyWith(
                      color: modern.ModernDesignSystem.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  );
                },
                loading: () => Text(
                  'Welcome back!',
                  style: AppTheme.textTheme.headlineSmall?.copyWith(
                    color: modern.ModernDesignSystem.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                error: (error, stack) => Text(
                  'Welcome back!',
                  style: AppTheme.textTheme.headlineSmall?.copyWith(
                    color: modern.ModernDesignSystem.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          playerProfileAsync.when(
            data: (profile) {
              final languageName = LanguageUtils.getLanguageName(profile?.targetLanguage);
              return Text(
                'Ready to continue your $languageName learning journey?',
                style: modern.ModernDesignSystem.bodyMedium.copyWith(
                  color: modern.ModernDesignSystem.textSecondary,
                ),
              );
            },
            loading: () => Text(
              'Ready to continue your learning journey?',
              style: modern.ModernDesignSystem.bodyMedium.copyWith(
                color: modern.ModernDesignSystem.textSecondary,
              ),
            ),
            error: (error, stack) => Text(
              'Ready to continue your learning journey?',
              style: modern.ModernDesignSystem.bodyMedium.copyWith(
                color: modern.ModernDesignSystem.textSecondary,
              ),
            ),
          ),
        ],
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
          'Learning Progress',
          style: AppTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: modern.ModernDesignSystem.textPrimary,
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
                        color: modern.ModernDesignSystem.sunshineYellow,
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
                        color: modern.ModernDesignSystem.forestGreen,
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
                        color: modern.ModernDesignSystem.cherryRed,
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
                        color: modern.ModernDesignSystem.info,
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
                  color: modern.ModernDesignSystem.textSecondary,
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
              color: modern.ModernDesignSystem.textMuted,
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

