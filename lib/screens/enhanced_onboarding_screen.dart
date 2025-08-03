import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/onboarding_provider.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:babblelon/screens/main_navigation_screen.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart' as cartoon;

/// Enhanced onboarding flow with user profile collection
class EnhancedOnboardingScreen extends ConsumerStatefulWidget {
  const EnhancedOnboardingScreen({super.key});

  @override
  ConsumerState<EnhancedOnboardingScreen> createState() => _EnhancedOnboardingScreenState();
}

class _EnhancedOnboardingScreenState extends ConsumerState<EnhancedOnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // Form controllers and data
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  String? _selectedMotivation;
  String? _selectedNativeLanguage;
  int _dailyGoalMinutes = 15;
  String? _selectedPace;
  
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
  
  final List<String> _nativeLanguageOptions = [
    'en', 'zh', 'ja', 'ko', 'es', 'fr', 'de', 'pt', 'ru', 'ar', 'hi', 'id', 'vi', 'my',
  ];
  
  final Map<String, String> _languageLabels = {
    'en': '🇺🇸 English',
    'zh': '🇨🇳 中文 (Chinese)',
    'ja': '🇯🇵 日本語 (Japanese)', 
    'ko': '🇰🇷 한국어 (Korean)',
    'es': '🇪🇸 Español (Spanish)',
    'fr': '🇫🇷 Français (French)',
    'de': '🇩🇪 Deutsch (German)',
    'pt': '🇵🇹 Português (Portuguese)', 
    'ru': '🇷🇺 Русский (Russian)',
    'ar': '🇸🇦 العربية (Arabic)',
    'hi': '🇮🇳 हिन्दी (Hindi)',
    'id': '🇮🇩 Bahasa Indonesia',
    'vi': '🇻🇳 Tiếng Việt (Vietnamese)',
    'my': '🇲🇾 Bahasa Melayu',
  };
  
  final List<String> _paceOptions = ['casual', 'moderate', 'intensive'];
  
  final Map<String, String> _paceLabels = {
    'casual': '🐌 Casual (5-10 min/day)',
    'moderate': '🚶‍♂️ Moderate (15-30 min/day)',
    'intensive': '🏃‍♂️ Intensive (30+ min/day)',
  };

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  bool _canProceedFromCurrentPage() {
    switch (_currentPage) {
      case 1: // Name page
        return _nameController.text.trim().isNotEmpty;
      case 2: // Age page
        final age = int.tryParse(_ageController.text);
        return age != null && age >= 5 && age <= 120;
      case 3: // Native language page
        return _selectedNativeLanguage != null;
      case 4: // Motivation page
        return _selectedMotivation != null;
      case 5: // Learning goals page
        return _selectedPace != null;
      default:
        return true;
    }
  }

  Future<void> _saveProfileAndComplete() async {
    try {
      final profile = PlayerProfile()
        ..userId = DateTime.now().millisecondsSinceEpoch.toString()
        ..username = _nameController.text.trim()
        ..displayName = _nameController.text.trim()
        ..age = int.tryParse(_ageController.text)
        ..nativeLanguage = _selectedNativeLanguage
        ..learningMotivation = _selectedMotivation
        ..learningPace = _selectedPace
        ..dailyGoalMinutes = _dailyGoalMinutes
        ..onboardingCompleted = true
        ..createdAt = DateTime.now()
        ..lastActiveAt = DateTime.now()
        ..privacyPolicyAccepted = true
        ..dataCollectionConsented = true
        ..consentDate = DateTime.now();

      final isarService = ref.read(isarServiceProvider);
      await isarService.savePlayerProfile(profile);
      
      await ref.read(onboardingCompletedProvider.notifier).completeOnboarding();
      
      if (mounted) {
        _navigateToMain();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    }
  }

  void _navigateToMain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const MainNavigationScreen(),
      ),
    );
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

  int _getPageCount() => 7; // Welcome, Name, Age, Language, Motivation, Goals, Complete

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
                  _buildNamePage(),
                  _buildAgePage(),
                  _buildNativeLanguagePage(),
                  _buildMotivationPage(),
                  _buildGoalsPage(),
                  _buildCompletionPage(),
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
      case 6: return 'Complete Setup';
      default: return 'Continue';
    }
  }

  Widget _buildWelcomePage() {
    return _OnboardingPageWidget(
      title: 'Welcome to BabbleOn!',
      description: 'Let\'s set up your personalized Thai learning experience. This will only take a few minutes.',
      icon: Icons.waving_hand,
      color: cartoon.CartoonDesignSystem.sunshineYellow,
    );
  }

  Widget _buildNamePage() {
    return _FormPageWidget(
      title: 'What should we call you?',
      description: 'Your name will be used throughout your learning journey.',
      icon: Icons.person,
      color: cartoon.CartoonDesignSystem.cherryRed,
      child: TextField(
        controller: _nameController,
        decoration: InputDecoration(
          labelText: 'Your name',
          hintText: 'Enter your name or nickname',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        style: cartoon.CartoonDesignSystem.bodyLarge,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildAgePage() {
    return _FormPageWidget(
      title: 'How old are you?',
      description: 'This helps us customize content appropriately for you.',
      icon: Icons.cake,
      color: cartoon.CartoonDesignSystem.warmOrange,
      child: TextField(
        controller: _ageController,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: 'Your age',
          hintText: 'Enter your age',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusLarge),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        style: cartoon.CartoonDesignSystem.bodyLarge,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildNativeLanguagePage() {
    return _FormPageWidget(
      title: 'What\'s your native language?',
      description: 'We\'ll use this to provide better translations and explanations.',
      icon: Icons.language,
      color: cartoon.CartoonDesignSystem.skyBlue,
      child: Column(
        children: _nativeLanguageOptions.map((lang) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _selectedNativeLanguage = lang),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedNativeLanguage == lang
                      ? cartoon.CartoonDesignSystem.skyBlue
                      : Colors.white,
                  foregroundColor: _selectedNativeLanguage == lang
                      ? Colors.white
                      : cartoon.CartoonDesignSystem.textPrimary,
                  side: BorderSide(
                    color: _selectedNativeLanguage == lang
                        ? cartoon.CartoonDesignSystem.skyBlue
                        : cartoon.CartoonDesignSystem.textMuted,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
                  ),
                ),
                child: Text(
                  _languageLabels[lang] ?? lang,
                  style: cartoon.CartoonDesignSystem.bodyMedium,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMotivationPage() {
    return _FormPageWidget(
      title: 'Why are you learning Thai?',
      description: 'Understanding your motivation helps us personalize your experience.',
      icon: Icons.rocket_launch,
      color: cartoon.CartoonDesignSystem.cherryRed,
      child: Column(
        children: _motivationOptions.map((motivation) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => setState(() => _selectedMotivation = motivation),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedMotivation == motivation
                      ? cartoon.CartoonDesignSystem.cherryRed
                      : Colors.white,
                  foregroundColor: _selectedMotivation == motivation
                      ? Colors.white
                      : cartoon.CartoonDesignSystem.textPrimary,
                  side: BorderSide(
                    color: _selectedMotivation == motivation
                        ? cartoon.CartoonDesignSystem.cherryRed
                        : cartoon.CartoonDesignSystem.textMuted,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(cartoon.CartoonDesignSystem.radiusMedium),
                  ),
                ),
                child: Text(
                  _motivationLabels[motivation] ?? motivation,
                  style: cartoon.CartoonDesignSystem.bodyMedium,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildGoalsPage() {
    return _FormPageWidget(
      title: 'What\'s your learning pace?',
      description: 'Choose a daily practice goal that fits your schedule.',
      icon: Icons.timer,
      color: cartoon.CartoonDesignSystem.warmOrange,
      child: Column(
        children: [
          ..._paceOptions.map((pace) {
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
          if (_selectedPace != null) ...[
            const SizedBox(height: 16),
            Text(
              'Daily goal: $_dailyGoalMinutes minutes',
              style: cartoon.CartoonDesignSystem.bodyMedium.copyWith(
                color: cartoon.CartoonDesignSystem.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompletionPage() {
    return _OnboardingPageWidget(
      title: 'You\'re all set!',
      description: 'Your personalized Thai learning adventure is ready to begin. Let\'s explore Bangkok together!',
      icon: Icons.celebration,
      color: cartoon.CartoonDesignSystem.sunshineYellow,
    );
  }
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