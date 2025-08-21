import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/profile_providers.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/providers/sync_providers.dart' as sync;
import 'package:babblelon/models/local_storage_models.dart';
// Removed unused imports per linter warning
import 'package:babblelon/services/supabase_service.dart';
import 'package:babblelon/services/posthog_service.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart' as cartoon;
import 'package:babblelon/services/auth_service_interface.dart';

/// Profile setup screen for authenticated users (authentication-first flow)
class EnhancedOnboardingScreen extends ConsumerStatefulWidget {
  const EnhancedOnboardingScreen({super.key});

  @override
  ConsumerState<EnhancedOnboardingScreen> createState() => _EnhancedOnboardingScreenState();
}

class _EnhancedOnboardingScreenState extends ConsumerState<EnhancedOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Form controllers and data
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _ageController = TextEditingController();
  int? _enteredAge;
  Set<String> _selectedMotivations = {};
  String? _selectedTargetLanguage = 'thai';
  String? _selectedCharacter;
  
  // Supabase service
  final SupabaseService _supabaseService = SupabaseService();
  
  String? _selectedLanguageLevel = 'beginner';
  int _dailyGoalMinutes = 15;
  String? _selectedPace;
  bool _voiceRecordingConsent = false;
  bool _personalizedContentConsent = true;
  bool _isLoading = false;
  
  final List<String> _motivationOptions = [
    'travel',
    'culture', 
    'business',
    'family',
    'personal',
    'education',
  ];
  
  final Map<String, String> _motivationLabels = {
    'travel': '🧳 Travel & Tourism',
    'culture': '🎭 Cultural Interest',
    'business': '💼 Business & Career',
    'family': '👨‍👩‍👧‍👦 Family Connections',
    'personal': '🌟 Personal Growth',
    'education': '📚 Academic Studies',
  };
  // Native language options removed - English-only app
  
  final List<String> _paceOptions = ['casual', 'moderate', 'intensive'];
  
  final List<String> _targetLanguageOptions = ['thai', 'japanese', 'korean', 'mandarin', 'vietnamese'];
  
  final Map<String, String> _targetLanguageLabels = {
    'thai': '🇹🇭 Thai - Cultural immersion',
    'japanese': '🇯🇵 Japanese - Urban exploration',
    'korean': '🇰🇷 Korean - Cultural discovery',
    'mandarin': '🇨🇳 Mandarin - Traditional experiences',
    'vietnamese': '🇻🇳 Vietnamese - Market adventures',
  };
  
  final List<String> _languageLevelOptions = ['beginner', 'elementary', 'intermediate', 'advanced'];
  
  // Character options
  final List<CharacterData> _characters = [
    const CharacterData(
      id: 'male',
      name: 'Male Tourist',
      assetPath: 'assets/images/player/sprite_male_tourist.png',
      description: 'Ready for adventure!',
    ),
    const CharacterData(
      id: 'female',
      name: 'Female Tourist',
      assetPath: 'assets/images/player/sprite_female_tourist.png',
      description: 'Excited to explore!',
    ),
  ];
  
  final Map<String, String> _languageLevelLabels = {
    'beginner': '🌱 Complete Beginner - I\'m just starting',
    'elementary': '📖 Elementary - I know basic words',
    'intermediate': '💬 Intermediate - I can have simple conversations',
    'advanced': '🎯 Advanced - I want to perfect my skills',
  };
  
  final Map<String, String> _paceLabels = {
    'casual': '🐌 Casual (5-10 min/day)',
    'moderate': '🚶‍♂️ Moderate (15-30 min/day)',
    'intensive': '🏃‍♂️ Intensive (30+ min/day)',
  };

  @override
  void initState() {
    super.initState();
    
    // No username validation needed - using email as unique identifier
  }

  @override
  void dispose() {
    _pageController.dispose();
    // Controllers already disposed above
    _ageController.dispose();
    super.dispose();
  }


  
  // Name validation helpers
  bool _isValidName(String name) {
    // Basic validation - at least 1 character, no numbers
    return name.trim().isNotEmpty && RegExp(r'^[a-zA-Z\s-]+$').hasMatch(name);
  }

  // Validate and update age from text input
  void _onAgeChanged(String value) {
    final age = int.tryParse(value);
    setState(() {
      if (age != null && age >= 5 && age <= 100) {
        _enteredAge = age;
        // Show parental guidance notice for young users
        if (age < 13) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showParentalGuidanceNotice();
          });
        }
      } else {
        _enteredAge = null;
      }
    });
  }

  bool _canProceedFromCurrentPage() {
    switch (_currentPage) {
      case 1: // Basic Info page (first name + last name + age)
        return _firstNameController.text.trim().isNotEmpty && 
               _lastNameController.text.trim().isNotEmpty &&
               _isValidName(_firstNameController.text.trim()) &&
               _isValidName(_lastNameController.text.trim()) &&
               _enteredAge != null && _enteredAge! >= 13;
      case 2: // Target Language page (Thai only for now)
        return _selectedTargetLanguage != null;
      case 3: // Character Selection page
        return _selectedCharacter != null;
      case 4: // Experience & Goals page (level + pace)
        return _selectedLanguageLevel != null && _selectedPace != null;
      case 5: // Motivation page
        return _selectedMotivations.isNotEmpty;
      case 6: // Privacy & Complete page
        return true; // Optional page
      default:
        return true;
    }
  }

  Future<void> _saveProfileAndComplete() async {
    if (_isLoading) return; // Prevent multiple attempts
    
    debugPrint('🚀 [Onboarding] Starting profile setup...');
    debugPrint('👤 [Onboarding] First name: ${_firstNameController.text.trim()}');
    debugPrint('👤 [Onboarding] Last name: ${_lastNameController.text.trim()}');
    debugPrint('🎂 [Onboarding] Age: $_enteredAge');
    
    setState(() {
      _isLoading = true;
    });
    
    String userId;
    
    try {
      // Get user ID from authenticated user
      debugPrint('🔐 [Onboarding] Using authenticated user...');
      final supabaseService = SupabaseService();
      
      // Get user ID from auth service
      final authService = AuthServiceFactory.getInstance();
      userId = authService.currentUserId!;
      debugPrint('✅ [Onboarding] Using authenticated user with ID: $userId');
        
        // Create local profile using Isar PlayerProfile
        final profile = PlayerProfile()
          ..userId = userId
          ..firstName = _firstNameController.text.trim()
          ..lastName = _lastNameController.text.trim()
          ..age = _enteredAge
          ..targetLanguage = _selectedTargetLanguage
          ..selectedCharacter = _selectedCharacter
          ..targetLanguageLevel = _selectedLanguageLevel
          ..hasPriorLearning = (_selectedLanguageLevel != 'beginner')
          ..nativeLanguage = 'en'
          ..learningMotivation = _selectedMotivations.join(', ')
          ..learningPace = _selectedPace
          ..dailyGoalMinutes = _dailyGoalMinutes
          ..voiceRecordingConsent = _voiceRecordingConsent
          ..personalizedContentConsent = _personalizedContentConsent
          ..onboardingCompleted = true
          ..onboardingCompletedAt = DateTime.now()
          ..createdAt = DateTime.now()
          ..lastActiveAt = DateTime.now()
          ..privacyPolicyAccepted = true
          ..dataCollectionConsented = true
          ..consentDate = DateTime.now();
          // Note: All users now have email-verified accounts

        // Rely on DB trigger to create Supabase player profile immediately on user insert.
        // Do not attempt direct insert here to avoid RLS when session is not yet established.
        debugPrint('🔄 [Onboarding] Checking/creating player profile...');
        await supabaseService.createPlayerProfileIfNeeded(
          userId: userId,
        );
        debugPrint('✅ [Onboarding] Player profile ready');
        
        // Save to local Isar database
        debugPrint('💾 [Onboarding] Saving to local database...');
        final isarService = ref.read(isarServiceProvider);
        await isarService.savePlayerProfile(profile);
        debugPrint('✅ [Onboarding] Local profile saved');
        
        // Update Supabase profile with onboarding data for AI backend (only if session exists)
        debugPrint('☁️ [Onboarding] Updating Supabase user metadata...');
        await supabaseService.updateProfileWithOnboardingData(
          userId: userId,
          onboardingData: {
            'first_name': _firstNameController.text.trim(),
            'last_name': _lastNameController.text.trim(),
            'age': profile.age,
            'target_language': profile.targetLanguage,
            'target_language_level': profile.targetLanguageLevel,
            'has_prior_learning': profile.hasPriorLearning,
            'native_language': profile.nativeLanguage,
            'selected_character': profile.selectedCharacter,
            'character_customization': {},
            'learning_motivation': profile.learningMotivation,
            'learning_pace': profile.learningPace,
            'daily_goal_minutes': profile.dailyGoalMinutes,
            'voice_recording_consent': profile.voiceRecordingConsent,
            'personalized_content_consent': profile.personalizedContentConsent,
            'privacy_policy_accepted': profile.privacyPolicyAccepted,
            'data_collection_consented': profile.dataCollectionConsented,
            'consent_date': profile.consentDate?.toIso8601String(),
          },
        );
        
        debugPrint('✅ [Onboarding] Supabase metadata updated');
      
      // Track onboarding completion
      PostHogService.trackGameEvent(
        event: 'onboarding_completed',
        screen: 'enhanced_onboarding',
        additionalProperties: {
          'target_language': _selectedTargetLanguage,
          'language_level': _selectedLanguageLevel,
          'device_locale': Platform.localeName, // e.g., "en_US", "th_TH"
          'timezone': DateTime.now().timeZoneName, // e.g., "PST", "ICT"
          'native_language': 'en', // English-only app
          'has_prior_learning': (_selectedLanguageLevel != 'beginner'),
          'learning_motivation': _selectedMotivations.join(', '),
          'learning_pace': _selectedPace,
          'age_group': _enteredAge != null ? 
            (_enteredAge! < 18 ? 'under_18' : 'adult') : null,
          'mode': 'production',
        },
      );
      
      debugPrint('🎉 [Onboarding] Onboarding completed successfully!');
      
      // Trigger explicit sync to ensure Supabase and Isar are synchronized
      debugPrint('🔄 [Onboarding] Triggering profile sync...');
      try {
        final syncService = ref.read(sync.syncServiceProvider);
        await syncService.syncPlayerProfile();
        debugPrint('✅ [Onboarding] Profile sync completed successfully');
      } catch (syncError) {
        debugPrint('⚠️ [Onboarding] Profile sync failed: $syncError');
        // Continue anyway - sync will retry later
      }
      
      // Refresh the profile completion provider to trigger AppController rebuild
      debugPrint('🔄 [Onboarding] Refreshing profile completion provider...');
      final refreshProfile = ref.read(profileRefreshProvider);
      refreshProfile();
      debugPrint('✅ [Onboarding] Profile completion provider refreshed');
      
      debugPrint('🔄 [Onboarding] Profile updated, synced, and refreshed - AppController will handle navigation automatically');
      
      // Note: Removed _navigateToMain() call - let AppController handle navigation flow
      // The AppController's StreamBuilder will automatically detect the completed profile
      // and navigate to the appropriate screen
    } catch (e, stackTrace) {
      debugPrint('❌ [Onboarding] Error during signup: $e');
      debugPrint('📋 [Onboarding] Stack trace: $stackTrace');
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        String errorMessage = 'Failed to save profile';
        
        // Provide specific error messages for common issues
        final errorString = e.toString().toLowerCase();
        debugPrint('🔍 [Onboarding] Analyzing error type...');
        if (errorString.contains('email') && errorString.contains('rate')) {
          errorMessage = 'Too many signup attempts. Please wait a moment and try again.';
        } else if (errorString.contains('email') && errorString.contains('already')) {
          errorMessage = 'This email is already registered. Try signing in instead.';
        } else if (errorString.contains('password')) {
          errorMessage = 'Password must be at least 6 characters long.';
        } else if (errorString.contains('network') || errorString.contains('timeout')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else if (errorString.contains('rls') || errorString.contains('policy')) {
          errorMessage = 'Account setup in progress. Please try completing onboarding again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _saveProfileAndComplete(),
            ),
          ),
        );
      }
    }
  }


  void _nextPage() {
    if (!_canProceedFromCurrentPage()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete this step before continuing')),
      );
      return;
    }

    if (_currentPage < _getPageCount() - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _saveProfileAndComplete();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showParentalGuidanceNotice() {
    // Only show notice once per session
    if (_ageController.text.length == 2) { // Only trigger when age is fully entered
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.family_restroom, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Parental guidance recommended for users under 13'),
              ),
            ],
          ),
          backgroundColor: cartoon.CartoonDesignSystem.warmOrange,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
          ),
        ),
      );
    }
  }

  int _getPageCount() => 7; // Welcome, Basic Info, Target Language, Character Selection, Experience & Goals, Motivation, Privacy & Complete

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cartoon.CartoonDesignSystem.creamWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Header with progress
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        TextButton.icon(
                          onPressed: _previousPage,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back'),
                          style: TextButton.styleFrom(
                            foregroundColor: cartoon.CartoonDesignSystem.textSecondary,
                          ),
                        )
                      else
                        const SizedBox(),
                      Text(
                        '${_currentPage + 1} of ${_getPageCount()}',
                        style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                          color: cartoon.CartoonDesignSystem.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_currentPage + 1) / _getPageCount(),
                    backgroundColor: cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(cartoon.CartoonDesignSystem.skyBlue),
                  ),
                ],
              ),
            ),
            
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomePage(),
                  _buildBasicInfoPage(),
                  _buildTargetLanguagePage(),
                  _buildCharacterSelectionPage(),
                  _buildExperienceAndGoalsPage(),
                  _buildMotivationPage(),
                  _buildPrivacyAndCompletePage(),
                ],
              ),
            ),
            
            // Bottom navigation
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canProceedFromCurrentPage() ? _nextPage : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cartoon.CartoonDesignSystem.skyBlue,
                      foregroundColor: cartoon.CartoonDesignSystem.textOnBright,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
                      ),
                      elevation: _canProceedFromCurrentPage() ? 8 : 0,
                      shadowColor: cartoon.CartoonDesignSystem.skyBlue.withValues(alpha: 0.4),
                    ),
                    child: Text(
                      _getButtonText(),
                      style: cartoon.CartoonDesignSystem.bodyLarge.copyWith(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: cartoon.CartoonDesignSystem.textOnBright,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getButtonText() {
    switch (_currentPage) {
      case 0: return 'Get Started';
      case 6: return 'Complete Setup'; // Updated index for 7 total pages
      default: return 'Continue';
    }
  }

  Widget _buildWelcomePage() {
    return _OnboardingPageWidget(
      title: 'Complete Your Profile!',
      description: 'You\'re signed in! Now let\'s set up your learning profile to personalize your language adventure.',
      icon: Icons.waving_hand,
      color: cartoon.CartoonDesignSystem.sunshineYellow,
    );
  }

  Widget _buildBasicInfoPage() {
    return _FormPageWidget(
      title: 'Tell us about yourself',
      description: 'Help us personalize your learning experience with some basic information.',
      icon: Icons.person,
      color: cartoon.CartoonDesignSystem.cherryRed,
      child: Column(
        children: [
          // First name field
          TextField(
            controller: _firstNameController,
            decoration: InputDecoration(
              labelText: 'First name',
              hintText: 'Enter your first name',
              prefixIcon: const Icon(Icons.person_outline),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
              ),
              filled: true,
              fillColor: Colors.white,
              helperText: 'Your first name',
              helperStyle: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                color: cartoon.CartoonDesignSystem.textSecondary,
              ),
            ),
            style: cartoon.CartoonDesignSystem.bodyLarge,
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          
          // Last name field
          TextField(
            controller: _lastNameController,
            decoration: InputDecoration(
              labelText: 'Last name',
              hintText: 'Enter your last name',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
              ),
              filled: true,
              fillColor: Colors.white,
              helperText: 'Your last name',
              helperStyle: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                color: cartoon.CartoonDesignSystem.textSecondary,
              ),
            ),
            style: cartoon.CartoonDesignSystem.bodyLarge,
            onChanged: (value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 16),
          
          // Age field (moved up and given context)
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  onChanged: _onAgeChanged,
                  decoration: InputDecoration(
                    labelText: 'Age',
                    hintText: 'Your age',
                    prefixIcon: Icon(
                      Icons.cake_outlined,
                      color: _enteredAge != null 
                          ? cartoon.CartoonDesignSystem.skyBlue 
                          : cartoon.CartoonDesignSystem.textSecondary,
                    ),
                    suffixIcon: _enteredAge != null && _enteredAge! >= 13
                        ? Icon(
                            Icons.check_circle,
                            color: cartoon.CartoonDesignSystem.forestGreen,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: cartoon.CartoonDesignSystem.skyBlue,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
                    ),
                    errorText: _ageController.text.isNotEmpty && _enteredAge == null 
                        ? 'Please enter a valid age (13-100)' 
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    helperText: 'Helps tailor conversations to your level',
                    helperStyle: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                      color: cartoon.CartoonDesignSystem.textSecondary,
                    ),
                  ),
                  style: cartoon.CartoonDesignSystem.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Divider with "Account Details" label
          Row(
            children: [
              Expanded(
                child: Divider(
                  color: cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.3),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Profile Setup',
                  style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                    color: cartoon.CartoonDesignSystem.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color: cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Email is used as the unique identifier - no username needed
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user, color: Colors.green, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'You\'re already signed in! Let\'s set up your learning profile.',
                    style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Info box explaining the distinction
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cartoon.CartoonDesignSystem.lightBlue.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
              border: Border.all(
                color: cartoon.CartoonDesignSystem.skyBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 18,
                      color: cartoon.CartoonDesignSystem.skyBlue,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Tips',
                      style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cartoon.CartoonDesignSystem.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Your real name is used by NPCs in conversations\n'
                  '• Username is your unique login ID\n'
                  '• Age helps us adjust content appropriately',
                  style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                    color: cartoon.CartoonDesignSystem.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildTargetLanguagePage() {
    return _FormPageWidget(
      title: 'Choose Your Adventure',
      description: 'Select the language you want to learn through immersive gameplay.',
      icon: Icons.language,
      color: cartoon.CartoonDesignSystem.forestGreen,
      child: Column(
        children: _targetLanguageOptions.map((lang) {
          final isAvailable = lang == 'thai'; // Only Thai is available
          final isSelected = _selectedTargetLanguage == lang;
          
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isAvailable 
                        ? () => setState(() => _selectedTargetLanguage = lang)
                        : null, // Disabled for coming soon languages
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSelected
                          ? cartoon.CartoonDesignSystem.forestGreen
                          : isAvailable 
                              ? Colors.white
                              : Colors.grey.shade100,
                      foregroundColor: isSelected
                          ? Colors.white
                          : isAvailable
                              ? cartoon.CartoonDesignSystem.textPrimary
                              : Colors.grey.shade400,
                      side: BorderSide(
                        color: isSelected
                            ? cartoon.CartoonDesignSystem.forestGreen
                            : isAvailable
                                ? cartoon.CartoonDesignSystem.textMuted
                                : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
                      ),
                      elevation: isSelected ? 4 : 0,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _targetLanguageLabels[lang]?.split(' - ').first ?? lang,
                                style: cartoon.CartoonDesignSystem.bodyLarge.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: isAvailable 
                                      ? (isSelected ? Colors.white : cartoon.CartoonDesignSystem.textPrimary)
                                      : Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _targetLanguageLabels[lang]?.split(' - ').last ?? '',
                                style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                                  color: isAvailable
                                      ? (isSelected ? Colors.white.withValues(alpha: 0.9) : cartoon.CartoonDesignSystem.textSecondary)
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),
                if (!isAvailable)
                  Positioned(
                    top: 8,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: cartoon.CartoonDesignSystem.warmOrange,
                        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusSmall),
                      ),
                      child: Text(
                        'COMING SOON',
                        style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCharacterSelectionPage() {
    return _FormPageWidget(
      title: 'Choose Your Adventure Companion',
      description: 'Select your character to represent you in the Thai cultural adventure.',
      icon: Icons.person_outline,
      color: cartoon.CartoonDesignSystem.lavenderPurple,
      child: Column(
        children: [
          // Character grid - 2 characters side by side
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _characters.map((character) {
              final isSelected = _selectedCharacter == character.id;
              
              return GestureDetector(
                onTap: () => setState(() => _selectedCharacter = character.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 140,
                  height: 180,
                  decoration: BoxDecoration(
                    color: isSelected 
                      ? cartoon.CartoonDesignSystem.lavenderPurple.withValues(alpha: 0.1)
                      : Colors.grey[50],
                    borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
                    border: Border.all(
                      color: isSelected 
                        ? cartoon.CartoonDesignSystem.lavenderPurple
                        : cartoon.CartoonDesignSystem.textMuted.withValues(alpha: 0.3),
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: cartoon.CartoonDesignSystem.lavenderPurple.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Character sprite
                        Expanded(
                          child: Image.asset(
                            character.assetPath,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                character.id == 'male' ? Icons.person : Icons.person_4,
                                size: 64,
                                color: isSelected 
                                    ? cartoon.CartoonDesignSystem.lavenderPurple
                                    : cartoon.CartoonDesignSystem.textSecondary,
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          character.name,
                          style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected 
                                ? cartoon.CartoonDesignSystem.lavenderPurple
                                : cartoon.CartoonDesignSystem.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          character.description,
                          style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                            fontSize: 11,
                            color: cartoon.CartoonDesignSystem.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          // Selected character indicator
          if (_selectedCharacter != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cartoon.CartoonDesignSystem.lavenderPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
                border: Border.all(
                  color: cartoon.CartoonDesignSystem.lavenderPurple,
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: cartoon.CartoonDesignSystem.lavenderPurple,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Selected: ${_characters.firstWhere((c) => c.id == _selectedCharacter).name}',
                    style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                      color: cartoon.CartoonDesignSystem.lavenderPurple,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          
          // Info about character use
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cartoon.CartoonDesignSystem.lightBlue.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: cartoon.CartoonDesignSystem.skyBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your character will represent you in conversations with Thai NPCs and can be changed later in Settings.',
                    style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                      color: cartoon.CartoonDesignSystem.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMotivationPage() {
    return _FormPageWidget(
      title: 'Why are you learning Thai?',
      description: 'Select all that apply - understanding your motivations helps us personalize your experience.',
      icon: Icons.rocket_launch,
      color: cartoon.CartoonDesignSystem.cherryRed,
      child: Column(
        children: _motivationOptions.map((motivation) {
          final isSelected = _selectedMotivations.contains(motivation);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (isSelected) {
                      _selectedMotivations.remove(motivation);
                    } else {
                      _selectedMotivations.add(motivation);
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? cartoon.CartoonDesignSystem.cherryRed
                      : Colors.white,
                  foregroundColor: isSelected
                      ? Colors.white
                      : cartoon.CartoonDesignSystem.textPrimary,
                  side: BorderSide(
                    color: isSelected
                        ? cartoon.CartoonDesignSystem.cherryRed
                        : cartoon.CartoonDesignSystem.textMuted,
                    width: isSelected ? 2 : 1,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
                  ),
                  elevation: isSelected ? 4 : 0,
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isSelected 
                          ? Colors.white 
                          : cartoon.CartoonDesignSystem.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _motivationLabels[motivation] ?? motivation,
                        style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }



  Widget _buildExperienceAndGoalsPage() {
    return _FormPageWidget(
      title: 'Experience & Learning Goals',
      description: 'Help us customize your learning path and pace.',
      icon: Icons.school,
      color: cartoon.CartoonDesignSystem.lavenderPurple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Language Level Section (no longer conditional)
          Text(
            'What\'s your current level with ${_targetLanguageLabels[_selectedTargetLanguage]?.split(' ').first ?? _selectedTargetLanguage}?',
            style: cartoon.CartoonDesignSystem.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: cartoon.CartoonDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _languageLevelOptions.map((level) {
              return SizedBox(
                width: (MediaQuery.of(context).size.width - 80) / 2,
                child: ElevatedButton(
                  onPressed: () => setState(() => _selectedLanguageLevel = level),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedLanguageLevel == level
                        ? cartoon.CartoonDesignSystem.lavenderPurple
                        : Colors.white,
                    foregroundColor: _selectedLanguageLevel == level
                        ? Colors.white
                        : cartoon.CartoonDesignSystem.textPrimary,
                    side: BorderSide(
                      color: _selectedLanguageLevel == level
                          ? cartoon.CartoonDesignSystem.lavenderPurple
                          : cartoon.CartoonDesignSystem.textMuted,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
                    ),
                  ),
                  child: Text(
                    _languageLevelLabels[level]?.split(' - ').first ?? level,
                    style: cartoon.CartoonDesignSystem.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 32),
          
          // Learning Pace Section
          Text(
            'What\'s your preferred learning pace?',
            style: cartoon.CartoonDesignSystem.bodyLarge.copyWith(
              fontWeight: FontWeight.w600,
              color: cartoon.CartoonDesignSystem.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Column(
            children: _paceOptions.map((pace) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _selectedPace = pace;
                        _dailyGoalMinutes = pace == 'casual' ? 10 : pace == 'moderate' ? 20 : 35;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPace == pace
                          ? cartoon.CartoonDesignSystem.warmOrange
                          : Colors.white,
                      foregroundColor: _selectedPace == pace
                          ? Colors.white
                          : cartoon.CartoonDesignSystem.textPrimary,
                      side: BorderSide(
                        color: _selectedPace == pace
                            ? cartoon.CartoonDesignSystem.warmOrange
                            : cartoon.CartoonDesignSystem.textMuted,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
                      ),
                    ),
                    child: Text(
                      _paceLabels[pace] ?? pace,
                      style: cartoon.CartoonDesignSystem.bodyMedium,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          
          if (_selectedPace != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cartoon.CartoonDesignSystem.lightBlue,
                borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer,
                    color: cartoon.CartoonDesignSystem.warmOrange,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Daily goal: $_dailyGoalMinutes minutes',
                    style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                      color: cartoon.CartoonDesignSystem.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildPrivacyAndCompletePage() {
    return _FormPageWidget(
      title: 'You\'re almost ready!',
      description: 'Just accept our privacy terms to start your ${_targetLanguageLabels[_selectedTargetLanguage]?.split(' ').first ?? 'language'} adventure.',
      icon: Icons.celebration,
      color: cartoon.CartoonDesignSystem.sunshineYellow,
      child: Column(
        children: [
          // Character and Language Summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cartoon.CartoonDesignSystem.lightBlue,
              borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
              border: Border.all(color: cartoon.CartoonDesignSystem.skyBlue.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: cartoon.CartoonDesignSystem.sunshineYellow.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: cartoon.CartoonDesignSystem.sunshineYellow, width: 2),
                  ),
                  child: Icon(
                    Icons.person,
                    size: 32,
                    color: cartoon.CartoonDesignSystem.sunshineYellow,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready to start your language adventure!',
                        style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_targetLanguageLabels[_selectedTargetLanguage]?.split(' - ').last ?? 'Adventure awaits'}',
                        style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                          color: cartoon.CartoonDesignSystem.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Privacy Consent
          CheckboxListTile(
            title: Text(
              'I accept the Privacy Policy and Terms of Service',
              style: cartoon.CartoonDesignSystem.bodyMedium,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // TODO: Open privacy policy URL
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Privacy Policy link will be added')),
                          );
                        },
                        child: Text(
                          'Privacy Policy',
                          style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                            color: cartoon.CartoonDesignSystem.skyBlue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    Text(' • ', style: cartoon.CartoonDesignSystem.bodySmall),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // TODO: Open terms of service URL
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Terms of Service link will be added')),
                          );
                        },
                        child: Text(
                          'Terms of Service',
                          style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                            color: cartoon.CartoonDesignSystem.skyBlue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            value: _personalizedContentConsent && _voiceRecordingConsent,
            onChanged: (value) => setState(() {
              _personalizedContentConsent = value ?? false;
              _voiceRecordingConsent = value ?? false;
            }),
            activeColor: cartoon.CartoonDesignSystem.skyBlue,
          ),
          
          const SizedBox(height: 16),
          
          // Data Collection Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cartoon.CartoonDesignSystem.lightBlue,
              borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: cartoon.CartoonDesignSystem.skyBlue,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'What we collect for personalization:',
                        style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Name and age for NPC conversations\n'
                  '• Learning progress to track improvement\n'
                  '• Voice recordings for pronunciation (processed securely)\n'
                  '• Anonymous usage data to improve the app',
                  style: cartoon.CartoonDesignSystem.bodySmall.copyWith(
                    color: cartoon.CartoonDesignSystem.textSecondary,
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

/// Character data model for character selection
class CharacterData {
  final String id;
  final String name;
  final String assetPath;
  final String description;

  const CharacterData({
    required this.id,
    required this.name,
    required this.assetPath,
    required this.description,
  });
}

/// Reusable widget for onboarding pages with static content
class _OnboardingPageWidget extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  const _OnboardingPageWidget({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 4),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, size: 64, color: color),
          ),
          const SizedBox(height: 40),
          Text(
            title,
            style: cartoon.CartoonDesignSystem.headlineLarge.copyWith(
              color: cartoon.CartoonDesignSystem.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            description,
            style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
              color: cartoon.CartoonDesignSystem.textSecondary,
              height: 1.6,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Reusable widget for onboarding pages with form content
class _FormPageWidget extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Widget child;

  const _FormPageWidget({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 3),
            ),
            child: Icon(icon, size: 40, color: color),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: cartoon.CartoonDesignSystem.headlineMedium.copyWith(
              color: cartoon.CartoonDesignSystem.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
              color: cartoon.CartoonDesignSystem.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          child,
        ],
      ),
    );
  }
}