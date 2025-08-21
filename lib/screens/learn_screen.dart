import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/screens/main_screen/thailand_map_screen.dart';
import 'package:babblelon/widgets/universal_stats_row.dart';
import 'package:babblelon/screens/premium/premium_npc_chat_screen.dart';
import 'package:babblelon/screens/premium/premium_boss_battle_screen.dart';
import 'package:babblelon/providers/player_data_providers.dart' as player_providers;
import 'package:babblelon/utils/language_utils.dart';

/// Learn screen that connects to existing game flow
/// Performance optimized with direct navigation to game
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerProfileAsync = ref.watch(player_providers.currentPlayerProfileProvider);
    
    return Scaffold(
      backgroundColor: CartoonDesignSystem.creamWhite,
      appBar: AppBar(
        title: playerProfileAsync.when(
          data: (profile) {
            final languageName = LanguageUtils.getLanguageName(profile?.targetLanguage);
            return Text(
              'Learn $languageName',
              style: AppTheme.textTheme.headlineMedium,
            );
          },
          loading: () => Text(
            'Learn',
            style: AppTheme.textTheme.headlineMedium,
          ),
          error: (error, stack) => Text(
            'Learn',
            style: AppTheme.textTheme.headlineMedium,
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
              _AdventureModeHero(),
              SizedBox(height: 24),
              UniversalStatsRow(),
              SizedBox(height: 20),
              _PremiumTrainingSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Adventure mode hero - primary learning path
class _AdventureModeHero extends ConsumerWidget {
  const _AdventureModeHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CartoonDesignSystem.sunshineYellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
        border: Border.all(
          color: CartoonDesignSystem.sunshineYellow.withValues(alpha: 0.6),
          width: 3,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CartoonDesignSystem.sunshineYellow.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.videogame_asset,
              color: CartoonDesignSystem.cherryRed,
              size: 48,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cultural Adventure',
            style: AppTheme.textTheme.headlineSmall?.copyWith(
              color: CartoonDesignSystem.cherryRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Explore cultural environments and practice languages with AI-powered NPCs',
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: CartoonDesignSystem.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const ThailandMapScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CartoonDesignSystem.sunshineYellow,
              foregroundColor: CartoonDesignSystem.textPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Start Adventure'),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium training section - advanced practice modes
class _PremiumTrainingSection extends StatelessWidget {
  const _PremiumTrainingSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Training',
          style: AppTheme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: CartoonDesignSystem.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: _PremiumFeatureCard(
                title: 'NPC Chat',
                subtitle: 'Unlimited conversations',
                icon: Icons.chat_bubble,
                color: Color(0xFFFFD700),
                route: PremiumNPCChatScreen(),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _PremiumFeatureCard(
                title: 'Boss Battles',
                subtitle: 'Training mode',
                icon: Icons.sports_mma,
                color: Color(0xFFFFA500),
                route: PremiumBossBattleScreen(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Premium feature card component
class _PremiumFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget? route;

  const _PremiumFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = route != null;
    
    return GestureDetector(
      onTap: isAvailable ? () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => route!),
        );
      } : null,
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isAvailable 
            ? color.withValues(alpha: 0.15)
            : CartoonDesignSystem.textMuted.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAvailable 
              ? color.withValues(alpha: 0.4)
              : CartoonDesignSystem.textMuted.withValues(alpha: 0.3),
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
                  color: isAvailable ? color : CartoonDesignSystem.textMuted,
                  size: 20,
                ),
                const Spacer(),
                if (!isAvailable)
                  const Icon(
                    Icons.lock,
                    color: CartoonDesignSystem.textMuted,
                    size: 12,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTheme.textTheme.titleMedium?.copyWith(
                color: isAvailable 
                  ? CartoonDesignSystem.textPrimary
                  : CartoonDesignSystem.textMuted,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTheme.textTheme.bodySmall?.copyWith(
                color: CartoonDesignSystem.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}