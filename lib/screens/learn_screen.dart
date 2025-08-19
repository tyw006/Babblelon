import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/screens/main_screen/combined_selection_screen.dart';

/// Learn screen that connects to existing game flow
/// Performance optimized with direct navigation to game
class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: CartoonDesignSystem.creamWhite,
      appBar: AppBar(
        title: Text(
          'Learn Thai',
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
              _GameModeSection(),
              SizedBox(height: 24),
              _LearningOptionsSection(),
              SizedBox(height: 24),
              _QuickStartSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Main game mode section
class _GameModeSection extends ConsumerWidget {
  const _GameModeSection();

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
                  builder: (context) => const CombinedSelectionScreen(),
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

/// Learning options section with different study modes
class _LearningOptionsSection extends StatelessWidget {
  const _LearningOptionsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Learning Modes',
          style: AppTheme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        _LearningOptionCard(
          title: 'Conversation Practice',
          description: 'Chat with NPCs to improve speaking skills',
          icon: Icons.chat_bubble_outline,
          color: CartoonDesignSystem.warmOrange,
          isAvailable: true,
        ),
        const SizedBox(height: 12),
        _LearningOptionCard(
          title: 'Character Writing',
          description: 'Learn to write Thai characters',
          icon: Icons.edit_outlined,
          color: CartoonDesignSystem.sunshineYellow,
          isAvailable: true,
        ),
        const SizedBox(height: 12),
        _LearningOptionCard(
          title: 'Pronunciation Training',
          description: 'Perfect your Thai pronunciation',
          icon: Icons.record_voice_over_outlined,
          color: CartoonDesignSystem.cherryRed,
          isAvailable: true,
        ),
      ],
    );
  }
}

/// Individual learning option card
class _LearningOptionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isAvailable;

  const _LearningOptionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CartoonDesignSystem.softPeach.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
        border: Border.all(
          color: isAvailable 
            ? color.withValues(alpha: 0.5)
            : CartoonDesignSystem.textMuted.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isAvailable 
                ? color.withValues(alpha: 0.2)
                : CartoonDesignSystem.textMuted.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusSmall),
            ),
            child: Icon(
              icon,
              color: isAvailable ? color : CartoonDesignSystem.textMuted,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.textTheme.titleMedium?.copyWith(
                    color: isAvailable 
                      ? CartoonDesignSystem.textPrimary
                      : CartoonDesignSystem.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTheme.textTheme.bodySmall?.copyWith(
                    color: CartoonDesignSystem.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isAvailable)
            Icon(
              Icons.arrow_forward_ios,
              color: color,
              size: 16,
            ),
        ],
      ),
    );
  }
}

/// Quick start section with recent lessons
class _QuickStartSection extends StatelessWidget {
  const _QuickStartSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Start',
          style: AppTheme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: CartoonDesignSystem.softPeach.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
            border: Border.all(
              color: CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.play_circle_outline,
                color: CartoonDesignSystem.textSecondary,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                'No recent lessons',
                style: AppTheme.textTheme.bodyLarge?.copyWith(
                  color: CartoonDesignSystem.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start your first adventure to begin learning',
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