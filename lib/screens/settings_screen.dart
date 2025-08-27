import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/providers/motion_preferences_provider.dart';
import 'package:babblelon/theme/modern_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/services/background_audio_service.dart';
import 'package:babblelon/screens/tutorial_settings_screen.dart';
import 'package:babblelon/services/supabase_service.dart';
import 'package:babblelon/widgets/character_selection_modal.dart';
import 'package:babblelon/widgets/language_selection_modal.dart';
import 'package:babblelon/providers/player_data_providers.dart' as player_providers;
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:babblelon/services/sync_service.dart';
import 'package:babblelon/widgets/universal_stats_row.dart';
import 'package:babblelon/screens/authentication_screen.dart';

/// Settings screen with instant toggles and simple layout
/// Performance optimized with minimal animations
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: ModernDesignSystem.primaryBackground,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: AppTheme.textTheme.headlineMedium?.copyWith(
            color: ModernDesignSystem.textPrimary,
          ),
        ),
        backgroundColor: ModernDesignSystem.primaryBackground,
        elevation: 0,
        iconTheme: const IconThemeData(
          color: ModernDesignSystem.textPrimary,
        ),
      ),
      body: const SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 16),
              UniversalStatsRow(),
              SizedBox(height: 24),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _AudioSection(),
                  SizedBox(height: 20),
                  _TutorialSection(),
                  SizedBox(height: 20),
                  _AccessibilitySection(),
                  SizedBox(height: 20),
                  _LanguageSection(),
                  SizedBox(height: 20),
                  _GamePreferencesSection(),
                  SizedBox(height: 20),
                  _AboutSection(),
                ],
              ),
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
            activeColor: ModernDesignSystem.sunshineYellow,
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
            activeColor: ModernDesignSystem.sunshineYellow,
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
                activeColor: ModernDesignSystem.sunshineYellow,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Language settings section
class _LanguageSection extends ConsumerWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsSection(
      title: 'Language',
      icon: Icons.language_outlined,
      children: [
        _SettingsTile(
          title: 'Interface Language',
          subtitle: 'English (Default)',
          trailing: Icon(
            Icons.check_circle,
            color: ModernDesignSystem.forestGreen,
            size: 20,
          ),
          onTap: () {
            // English-only app
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('App interface is available in English only'),
                backgroundColor: ModernDesignSystem.skyBlue,
              ),
            );
          },
        ),
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
            color: ModernDesignSystem.textSecondary,
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

/// Game preferences section with language and character settings
class _GamePreferencesSection extends ConsumerWidget {
  const _GamePreferencesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get current authenticated user ID
    final authService = AuthServiceFactory.getInstance();
    final currentUserId = authService.currentUserId;
    
    if (currentUserId == null) {
      return _SettingsSection(
        title: 'Game Preferences',
        icon: Icons.videogame_asset_outlined,
        children: [
          _SettingsTile(
            title: 'Sign in Required',
            subtitle: 'Please sign in to change game preferences',
            trailing: Container(),
          ),
        ],
      );
    }

    // Use the playerProfileProvider with the authenticated user ID
    final profileAsyncValue = ref.watch(player_providers.playerProfileProvider(currentUserId));
    
    return profileAsyncValue.when(
      data: (profile) => _buildGamePreferences(context, ref, profile),
      loading: () => _SettingsSection(
        title: 'Game Preferences',
        icon: Icons.videogame_asset_outlined,
        children: [
          _SettingsTile(
            title: 'Loading...',
            subtitle: 'Fetching your preferences',
            trailing: const CircularProgressIndicator(),
          ),
        ],
      ),
      error: (error, stackTrace) => _SettingsSection(
        title: 'Game Preferences',
        icon: Icons.videogame_asset_outlined,
        children: [
          _SettingsTile(
            title: 'Error Loading Preferences',
            subtitle: 'Please try again later',
            trailing: Container(),
          ),
        ],
      ),
    );
  }

  Widget _buildGamePreferences(BuildContext context, WidgetRef ref, profile) {
    if (profile == null) {
      return _SettingsSection(
        title: 'Game Preferences',
        icon: Icons.videogame_asset_outlined,
        children: [
          _SettingsTile(
            title: 'No Profile Found',
            subtitle: 'Complete onboarding to set preferences',
            trailing: Container(),
          ),
        ],
      );
    }

    // Get display names
    final languageDisplayName = _getLanguageDisplayName(profile.targetLanguage);
    final characterDisplayName = _getCharacterDisplayName(profile.selectedCharacter);

    return _SettingsSection(
      title: 'Game Preferences',
      icon: Icons.videogame_asset_outlined,
      children: [
        _SettingsTile(
          title: 'Learning Language',
          subtitle: 'Currently: $languageDisplayName',
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: ModernDesignSystem.textSecondary,
            size: 16,
          ),
          onTap: () {
            _showLanguageSelection(context, ref, profile.targetLanguage);
          },
        ),
        _SettingsTile(
          title: 'Character',
          subtitle: 'Currently: $characterDisplayName',
          trailing: Icon(
            Icons.arrow_forward_ios,
            color: ModernDesignSystem.textSecondary,
            size: 16,
          ),
          onTap: () {
            _showCharacterSelection(context, ref, profile.selectedCharacter);
          },
        ),
      ],
    );
  }

  String _getLanguageDisplayName(String? languageCode) {
    switch (languageCode) {
      case 'thai': return 'Thai 🇹🇭';
      case 'chinese': return 'Chinese 🇨🇳';
      case 'japanese': return 'Japanese 🇯🇵';
      case 'korean': return 'Korean 🇰🇷';
      case 'vietnamese': return 'Vietnamese 🇻🇳';
      default: return 'Thai 🇹🇭'; // Default fallback
    }
  }

  String _getCharacterDisplayName(String? characterId) {
    switch (characterId) {
      case 'male': return 'Male Tourist';
      case 'female': return 'Female Tourist';
      default: return 'Male Tourist'; // Default fallback
    }
  }

  void _showLanguageSelection(BuildContext context, WidgetRef ref, String? currentLanguage) {
    showDialog(
      context: context,
      builder: (context) => LanguageSelectionModal(
        initialLanguage: currentLanguage,
        onLanguageSelected: (languageCode) async {
          await _updateLanguage(context, ref, languageCode);
        },
      ),
    );
  }

  void _showCharacterSelection(BuildContext context, WidgetRef ref, String? currentCharacter) {
    showDialog(
      context: context,
      builder: (context) => CharacterSelectionModal(
        initialCharacter: currentCharacter,
        onCharacterSelected: (characterId) async {
          await _updateCharacter(context, ref, characterId);
        },
      ),
    );
  }

  Future<void> _updateLanguage(BuildContext context, WidgetRef ref, String languageCode) async {
    try {
      final authService = AuthServiceFactory.getInstance();
      final userId = authService.currentUserId;
      
      if (userId != null) {
        final isarService = IsarService();
        final profile = await isarService.getPlayerProfile(userId);
        
        if (profile != null) {
          profile.targetLanguage = languageCode;
          profile.needsSync = true;
          
          await isarService.savePlayerProfile(profile);
          
          // Trigger sync to Supabase immediately
          final syncService = SyncService();
          await syncService.syncPlayerProfile();
          
          // Refresh the profile provider
          ref.invalidate(player_providers.playerProfileProvider(userId));
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Learning language updated to ${_getLanguageDisplayName(languageCode)}'),
                backgroundColor: ModernDesignSystem.forestGreen,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating language: $e'),
            backgroundColor: ModernDesignSystem.cherryRed,
          ),
        );
      }
    }
  }

  Future<void> _updateCharacter(BuildContext context, WidgetRef ref, String characterId) async {
    try {
      final authService = AuthServiceFactory.getInstance();
      final userId = authService.currentUserId;
      
      if (userId != null) {
        final isarService = IsarService();
        final profile = await isarService.getPlayerProfile(userId);
        
        if (profile != null) {
          profile.selectedCharacter = characterId;
          profile.needsSync = true;
          
          await isarService.savePlayerProfile(profile);
          
          // Trigger sync to Supabase immediately
          final syncService = SyncService();
          await syncService.syncPlayerProfile();
          
          // Refresh the profile provider
          ref.invalidate(player_providers.playerProfileProvider(userId));
          
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Character updated to ${_getCharacterDisplayName(characterId)}'),
                backgroundColor: ModernDesignSystem.forestGreen,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating character: $e'),
            backgroundColor: ModernDesignSystem.cherryRed,
          ),
        );
      }
    }
  }
}

/// About section with links and information
class _AboutSection extends ConsumerWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsSection(
      title: 'About',
      icon: Icons.info_outline,
      children: [
        _SettingsTile(
          title: 'Privacy Policy',
          subtitle: 'View our privacy policy',
          trailing: Icon(
            Icons.open_in_new,
            color: ModernDesignSystem.textSecondary,
            size: 16,
          ),
          onTap: () {
            // TODO: Open privacy policy URL
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Privacy policy link coming soon'),
                backgroundColor: ModernDesignSystem.sunshineYellow,
              ),
            );
          },
        ),
        _SettingsTile(
          title: 'Terms of Service',
          subtitle: 'View our terms of service',
          trailing: Icon(
            Icons.open_in_new,
            color: ModernDesignSystem.textSecondary,
            size: 16,
          ),
          onTap: () {
            // TODO: Open terms of service URL
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Terms of service link coming soon'),
                backgroundColor: ModernDesignSystem.sunshineYellow,
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
            color: ModernDesignSystem.textSecondary,
            size: 16,
          ),
          onTap: () {
            // TODO: Open support URL
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Support link coming soon'),
                backgroundColor: ModernDesignSystem.sunshineYellow,
              ),
            );
          },
        ),
        _SettingsTile(
          title: 'Sign Out',
          subtitle: 'Sign out of your account',
          trailing: Icon(
            Icons.logout,
            color: ModernDesignSystem.cherryRed,
            size: 16,
          ),
          onTap: () {
            _showSignOutDialog(context);
          },
        ),
      ],
    );
  }

  void _showSignOutDialog(BuildContext context) {
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
              style: TextStyle(color: ModernDesignSystem.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _signOut(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ModernDesignSystem.cherryRed,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await SupabaseService.client.auth.signOut();
      
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const AuthenticationScreen()),
          (route) => false,
        );
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Signed out successfully'),
            backgroundColor: ModernDesignSystem.forestGreen,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error signing out: $e'),
            backgroundColor: ModernDesignSystem.cherryRed,
          ),
        );
      }
    }
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
                color: ModernDesignSystem.cherryRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTheme.textTheme.headlineSmall?.copyWith(
                  color: ModernDesignSystem.cherryRed,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: ModernDesignSystem.softPeach.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
            border: Border.all(
              color: ModernDesignSystem.chocolateBrown.withValues(alpha: 0.3),
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
                        color: ModernDesignSystem.textSecondary,
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