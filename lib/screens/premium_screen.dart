import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/screens/premium/premium_npc_chat_screen.dart';
import 'package:babblelon/screens/premium/premium_boss_battle_screen.dart';
import 'package:babblelon/widgets/universal_stats_row.dart';

/// Premium features hub screen
/// Provides access to NPC chat and boss battle training outside of game context
class PremiumScreen extends ConsumerWidget {
  const PremiumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: CartoonDesignSystem.creamWhite,
      appBar: AppBar(
        title: Text(
          'Premium Features',
          style: AppTheme.textTheme.headlineMedium?.copyWith(
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: [
                  Color(0xFFFFD700), // Gold
                  Color(0xFFFFA500), // Orange
                ],
              ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
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
              _PremiumHero(),
              SizedBox(height: 24),
              UniversalStatsRow(),
              SizedBox(height: 20),
              _PremiumFeaturesGrid(),
              SizedBox(height: 16),
              _SubscriptionInfo(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Premium hero section - gold themed branding
class _PremiumHero extends StatelessWidget {
  const _PremiumHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD700), // Gold
            Color(0xFFFFA500), // Orange
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Premium Training',
            style: AppTheme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Practice with NPCs and bosses anytime',
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Premium features grid - compact feature display
class _PremiumFeaturesGrid extends StatelessWidget {
  const _PremiumFeaturesGrid();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Premium Features',
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
        const SizedBox(height: 12),
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

/// Subscription info section - pricing and benefits
class _SubscriptionInfo extends StatelessWidget {
  const _SubscriptionInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFD700).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.diamond,
                color: Color(0xFFFFD700),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Premium Benefits',
                style: AppTheme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: CartoonDesignSystem.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  '• Unlimited NPC conversations\n• Boss battle training mode\n• Advanced features coming soon',
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                    color: CartoonDesignSystem.textSecondary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Available Now',
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}