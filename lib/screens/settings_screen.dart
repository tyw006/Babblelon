import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/providers/motion_preferences_provider.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/services/background_audio_service.dart';
import 'package:babblelon/screens/tutorial_settings_screen.dart';
import 'package:babblelon/services/supabase_service.dart';

/// Settings screen with instant toggles and simple layout
/// Performance optimized with minimal animations
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: CartoonDesignSystem.creamWhite,
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
              _TutorialSection(),
              SizedBox(height: 24),
              _AccessibilitySection(),
              SizedBox(height: 24),
              _LanguageSection(),
              SizedBox(height: 24),
              _DeveloperSection(),
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
              // Play toggle sound before changing setting
              if (gameState.soundEffectsEnabled) {
                ref.playButtonSound();
              }
              ref.read(gameStateProvider.notifier).setMusicEnabled(value);
              
              // Synchronize BackgroundAudioService with the new setting
              final audioService = BackgroundAudioService();
              audioService.updateSettings(
                musicEnabled: value,
                soundEffectsEnabled: gameState.soundEffectsEnabled,
              );
              
              // If music was enabled and we're in the main menu, restart intro music
              if (value) {
                audioService.playIntroMusic(ref);
                debugPrint('🎵 SettingsScreen: Restarted intro music after enabling');
              }
              
              debugPrint('🎵 SettingsScreen: Synced BackgroundAudioService with music toggle: $value');
            },
            activeColor: CartoonDesignSystem.sunshineYellow,
          ),
        ),
        _SettingsTile(
          title: 'Sound Effects',
          subtitle: 'Play sound effects for interactions',
          trailing: Switch(
            value: gameState.soundEffectsEnabled,
            onChanged: (value) {
              // Play toggle sound before disabling sound effects (if currently enabled)
              if (gameState.soundEffectsEnabled && !value) {
                ref.playButtonSound();
              }
              ref.read(gameStateProvider.notifier).setSoundEffectsEnabled(value);
              // Play toggle sound after enabling sound effects
              if (value) {
                ref.playButtonSound();
              }
              
              // Synchronize BackgroundAudioService with the new setting
              final audioService = BackgroundAudioService();
              audioService.updateSettings(
                musicEnabled: gameState.musicEnabled,
                soundEffectsEnabled: value,
              );
              debugPrint('🔊 SettingsScreen: Synced BackgroundAudioService with sound effects toggle: $value');
            },
            activeColor: CartoonDesignSystem.sunshineYellow,
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
                activeColor: CartoonDesignSystem.sunshineYellow,
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
          title: 'Interface Language',
          subtitle: 'English (Default)',
          trailing: Icon(
            Icons.check_circle,
            color: CartoonDesignSystem.forestGreen,
            size: 20,
          ),
          onTap: () {
            // English-only app
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('App interface is available in English only'),
                backgroundColor: CartoonDesignSystem.skyBlue,
              ),
            );
          },
        ),
        // Target language selection is now handled in onboarding
        // No need for duplicate option here
      ],
    );
  }
}

/// Tutorial settings section
class _TutorialSection extends StatelessWidget {
  const _TutorialSection();

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Tutorials',
      icon: Icons.school_outlined,
      children: [
        _SettingsTile(
          title: 'Tutorial Settings',
          subtitle: 'Manage tutorial preferences and completion status',
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: CartoonDesignSystem.textSecondary,
            size: 16,
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TutorialSettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Developer section with debug and testing tools
class _DeveloperSection extends ConsumerWidget {
  const _DeveloperSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = SupabaseService.client.auth.currentUser;
    final isDebugMode = currentUser != null;
    
    if (!isDebugMode) {
      return const SizedBox.shrink(); // Hide section if not logged in
    }
    
    return _SettingsSection(
      title: 'Developer Tools',
      icon: Icons.code,
      children: [
        _SettingsTile(
          title: 'Current User',
          subtitle: currentUser.email ?? 'No email',
          trailing: Container(),
        ),
        _SettingsTile(
          title: 'User ID',
          subtitle: currentUser.id.substring(0, 8) + '...',
          trailing: IconButton(
            icon: Icon(
              Icons.copy,
              color: CartoonDesignSystem.textSecondary,
              size: 16,
            ),
            onPressed: () {
              // Copy user ID to clipboard
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('User ID copied: ${currentUser.id}'),
                  backgroundColor: CartoonDesignSystem.forestGreen,
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        _SettingsTile(
          title: 'Clear Test Data',
          subtitle: 'Delete current user from Supabase',
          trailing: Icon(
            Icons.delete_forever,
            color: CartoonDesignSystem.cherryRed,
            size: 20,
          ),
          onTap: () => _showClearDataDialog(context, ref),
        ),
        _SettingsTile(
          title: 'Sign Out',
          subtitle: 'Sign out and return to onboarding',
          trailing: Icon(
            Icons.logout,
            color: CartoonDesignSystem.warmOrange,
            size: 20,
          ),
          onTap: () => _showSignOutDialog(context, ref),
        ),
      ],
    );
  }
  
  void _showClearDataDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Clear Test Data',
          style: AppTheme.textTheme.headlineSmall,
        ),
        content: Text(
          'This will delete your account and all associated data from Supabase. This action cannot be undone.\n\nYou will be signed out and can create a new test account.',
          style: AppTheme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: CartoonDesignSystem.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _clearTestData(context, ref);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CartoonDesignSystem.cherryRed,
            ),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );
  }
  
  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sign Out',
          style: AppTheme.textTheme.headlineSmall,
        ),
        content: Text(
          'Are you sure you want to sign out? You will need to sign in again to continue.',
          style: AppTheme.textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: CartoonDesignSystem.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _signOut(context, ref);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: CartoonDesignSystem.warmOrange,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _clearTestData(BuildContext context, WidgetRef ref) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: CartoonDesignSystem.cherryRed,
                ),
                const SizedBox(height: 16),
                Text(
                  'Deleting test data...',
                  style: AppTheme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      );
      
      final currentUser = SupabaseService.client.auth.currentUser;
      if (currentUser != null) {
        // Delete player profile first
        await SupabaseService.client
            .from('players')
            .delete()
            .eq('user_id', currentUser.id);
        
        // Sign out (this doesn't delete the auth.users entry)
        await SupabaseService.client.auth.signOut();
        
        // Note: We can't delete from auth.users table directly from client
        // That would require admin/service role access
        // The user can create a new account with a different email
      }
      
      // Clear local data
      final isarService = ref.read(isarServiceProvider);
      await isarService.clearAllData();
      
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        // Navigate to onboarding
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/onboarding',
          (route) => false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Test data cleared. You can create a new account.'),
            backgroundColor: CartoonDesignSystem.forestGreen,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (context.mounted) {
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error clearing data: $e'),
            backgroundColor: CartoonDesignSystem.cherryRed,
          ),
        );
      }
    }
  }
  
  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    try {
      await SupabaseService.client.auth.signOut();
      
      if (context.mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/onboarding',
          (route) => false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Signed out successfully'),
            backgroundColor: CartoonDesignSystem.forestGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: CartoonDesignSystem.cherryRed,
          ),
        );
      }
    }
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
            color: CartoonDesignSystem.textSecondary,
            size: 16,
          ),
          onTap: () {
            // TODO: Open privacy policy URL
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Privacy policy link coming soon'),
                backgroundColor: CartoonDesignSystem.sunshineYellow,
              ),
            );
          },
        ),
        _SettingsTile(
          title: 'Terms of Service',
          subtitle: 'View our terms of service',
          trailing: Icon(
            Icons.open_in_new,
            color: CartoonDesignSystem.textSecondary,
            size: 16,
          ),
          onTap: () {
            // TODO: Open terms of service URL
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Terms of service link coming soon'),
                backgroundColor: CartoonDesignSystem.sunshineYellow,
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
            color: CartoonDesignSystem.textSecondary,
            size: 16,
          ),
          onTap: () {
            // TODO: Open support URL
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Support link coming soon'),
                backgroundColor: CartoonDesignSystem.sunshineYellow,
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
                color: CartoonDesignSystem.cherryRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTheme.textTheme.headlineSmall?.copyWith(
                  color: CartoonDesignSystem.cherryRed,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: CartoonDesignSystem.softPeach.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
            border: Border.all(
              color: CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.3),
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
        borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
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
                        color: CartoonDesignSystem.textSecondary,
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