import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/screens/premium/premium_npc_chat_screen.dart';
import 'package:babblelon/screens/premium/premium_boss_battle_screen.dart';

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeroSection(),
              SizedBox(height: 32),
              _FeatureCards(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hero section with premium branding
class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFD700), // Gold
            Color(0xFFFFA500), // Orange
            Color(0xFFFF8C00), // Dark Orange
          ],
        ),
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.star,
            color: CartoonDesignSystem.creamWhite,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            'Practice Anytime, Anywhere',
            style: AppTheme.textTheme.headlineSmall?.copyWith(
              color: CartoonDesignSystem.creamWhite,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Chat with NPCs and battle bosses outside of the main adventure',
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: CartoonDesignSystem.creamWhite.withValues(alpha: 0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Feature cards for NPC chat and boss battles
class _FeatureCards extends StatelessWidget {
  const _FeatureCards();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _NPCChatCard(),
        SizedBox(height: 24),
        _BossBattleCard(),
      ],
    );
  }
}

/// NPC conversations feature card
class _NPCChatCard extends StatelessWidget {
  const _NPCChatCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CartoonDesignSystem.creamWhite.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusSmall),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline,
                  color: Color(0xFFFFD700),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NPC Conversations',
                      style: AppTheme.textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chat with your favorite NPCs',
                      style: AppTheme.textTheme.bodyMedium?.copyWith(
                        color: CartoonDesignSystem.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Practice conversations with Amara, Somchai, and other NPCs outside of the main game. Perfect for focused language practice!',
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: CartoonDesignSystem.textPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💬 Unlimited conversations\n🎤 Voice practice\n📝 Conversation history',
                style: AppTheme.textTheme.bodySmall?.copyWith(
                  color: CartoonDesignSystem.textSecondary,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PremiumNPCChatScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: CartoonDesignSystem.creamWhite,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Start Chat'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Boss battle training feature card
class _BossBattleCard extends StatelessWidget {
  const _BossBattleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CartoonDesignSystem.creamWhite.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD700).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusSmall),
                ),
                child: const Icon(
                  Icons.sports_mma,
                  color: Color(0xFFFFD700),
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Boss Battle Training',
                      style: AppTheme.textTheme.headlineSmall?.copyWith(
                        color: const Color(0xFFFFD700),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Practice pronunciation battles',
                      style: AppTheme.textTheme.bodyMedium?.copyWith(
                        color: CartoonDesignSystem.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Train against boss monsters in focused pronunciation battles. Perfect your accent and earn high scores!',
            style: AppTheme.textTheme.bodyMedium?.copyWith(
              color: CartoonDesignSystem.textPrimary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '⚔️ Quick battles\n🏆 Score tracking\n📊 Difficulty levels',
                style: AppTheme.textTheme.bodySmall?.copyWith(
                  color: CartoonDesignSystem.textSecondary,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const PremiumBossBattleScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: CartoonDesignSystem.creamWhite,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Start Battle'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}