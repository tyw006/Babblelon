import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/providers/motion_preferences_provider.dart';
import 'package:babblelon/widgets/modern_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';

/// Settings screen with instant toggles and simple layout
/// Performance optimized with minimal animations
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ModernDesignSystem.deepSpaceBlue,
      appBar: AppBar(
        title: Text(
          'Settings',
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
              _AudioSection(),
              SizedBox(height: 24),
              _AccessibilitySection(),
              SizedBox(height: 24),
              _LanguageSection(),
              SizedBox(height: 24),
              _AboutSection(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Audio settings section
class _AudioSection extends ConsumerWidget {
  const _AudioSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gameState = ref.watch(gameStateProvider);
    
    return _SettingsSection(
      title: 'Audio',
      icon: Icons.volume_up_outlined,
      children: [
        _SettingsTile(
          title: 'Background Music',
          subtitle: 'Play background music during gameplay',
          trailing: Switch(
            value: gameState.musicEnabled,
            onChanged: (value) {
              ref.read(gameStateProvider.notifier).toggleMusic();
            },
            activeColor: ModernDesignSystem.electricCyan,
          ),
        ),
        _SettingsTile(
          title: 'Sound Effects',
          subtitle: 'Play sound effects for interactions',
          trailing: Switch(
            value: gameState.soundEffectsEnabled,
            onChanged: (value) {
              ref.read(gameStateProvider.notifier).setSoundEffectsEnabled(value);
            },
            activeColor: ModernDesignSystem.electricCyan,
          ),
        ),
      ],
    );
  }
}

/// Accessibility settings section
class _AccessibilitySection extends StatelessWidget {
  const _AccessibilitySection();

  @override
  Widget build(BuildContext context) {
    return provider.Consumer<MotionPreferences>(
      builder: (context, motionPrefs, child) {
        return _SettingsSection(
          title: 'Accessibility',
          icon: Icons.accessibility_outlined,
          children: [
            _SettingsTile(
              title: 'Reduce Motion',
              subtitle: 'Minimize animations for better accessibility',
              trailing: Switch(
                value: motionPrefs.reduceMotion,
                onChanged: (value) {
                  motionPrefs.setReduceMotion(value);
                },
                activeColor: ModernDesignSystem.electricCyan,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Language settings section
class _LanguageSection extends StatelessWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Language',
      icon: Icons.language_outlined,
      children: [
        _SettingsTile(
          title: 'App Language',
          subtitle: 'English',
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: ModernDesignSystem.slateGray,
            size: 16,
          ),
          onTap: () {
            // TODO: Implement language selection
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Language selection coming soon'),
                backgroundColor: ModernDesignSystem.electricCyan,
              ),
            );
          },
        ),
        _SettingsTile(
          title: 'Target Language',
          subtitle: 'Thai',
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: ModernDesignSystem.slateGray,
            size: 16,
          ),
          onTap: () {
            // TODO: Implement target language selection
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Target language selection coming soon'),
                backgroundColor: ModernDesignSystem.electricCyan,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// About section with links and information
class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'About',
      icon: Icons.info_outline,
      children: [
        _SettingsTile(
          title: 'Privacy Policy',
          subtitle: 'View our privacy policy',
          trailing: Icon(
            Icons.open_in_new,
            color: ModernDesignSystem.slateGray,
            size: 16,
          ),
          onTap: () {
            // TODO: Open privacy policy URL
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Privacy policy link coming soon'),
                backgroundColor: ModernDesignSystem.electricCyan,
              ),
            );
          },
        ),
        _SettingsTile(
          title: 'Terms of Service',
          subtitle: 'View our terms of service',
          trailing: Icon(
            Icons.open_in_new,
            color: ModernDesignSystem.slateGray,
            size: 16,
          ),
          onTap: () {
            // TODO: Open terms of service URL
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Terms of service link coming soon'),
                backgroundColor: ModernDesignSystem.electricCyan,
              ),
            );
          },
        ),
        _SettingsTile(
          title: 'Version',
          subtitle: '1.0.0 (MVP)',
          trailing: Container(),
        ),
        _SettingsTile(
          title: 'Support',
          subtitle: 'Get help and contact support',
          trailing: Icon(
            Icons.open_in_new,
            color: ModernDesignSystem.slateGray,
            size: 16,
          ),
          onTap: () {
            // TODO: Open support URL
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Support link coming soon'),
                backgroundColor: ModernDesignSystem.electricCyan,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Settings section wrapper with title and icon
class _SettingsSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(
                icon,
                color: ModernDesignSystem.electricCyan,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTheme.textTheme.headlineSmall?.copyWith(
                  color: ModernDesignSystem.electricCyan,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: ModernDesignSystem.deepSpaceBlue.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
            border: Border.all(
              color: ModernDesignSystem.slateGray.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }
}

/// Individual settings tile
class _SettingsTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTheme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTheme.textTheme.bodySmall?.copyWith(
                        color: ModernDesignSystem.slateGray,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}