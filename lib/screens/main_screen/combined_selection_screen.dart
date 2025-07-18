import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:babblelon/screens/main_screen/widgets/twinkling_stars.dart';
import 'package:babblelon/screens/main_screen/thailand_map_screen.dart';
import 'package:babblelon/screens/splash_screen.dart';
import 'package:babblelon/widgets/modern_design_system.dart' as modern;
import 'package:babblelon/theme/font_extensions.dart';
import 'package:babblelon/services/background_audio_service.dart';

class CombinedSelectionScreen extends ConsumerStatefulWidget {
  const CombinedSelectionScreen({super.key});

  @override
  ConsumerState<CombinedSelectionScreen> createState() => _CombinedSelectionScreenState();
}

class _CombinedSelectionScreenState extends ConsumerState<CombinedSelectionScreen> 
    with TickerProviderStateMixin {
  String? _selectedLanguage;
  String? _selectedCharacter;
  bool _isNavigating = false;
  
  final BackgroundAudioService _audioService = BackgroundAudioService();
  
  // Language to country mapping for dynamic button text
  final Map<String, String> _languageToCountry = {
    'thai': 'Thailand',
    'chinese': 'China',
    'japanese': 'Japan',
    'korean': 'South Korea',
    'vietnamese': 'Vietnam',
  };
  
  late AnimationController _slideController;
  late AnimationController _buttonController;
  late AnimationController _pulseController;
  late AnimationController _zoomController;
  late AnimationController _fadeController;
  
  // Asian languages in alphabetical order
  final List<LanguageData> _languages = [
    const LanguageData(
      code: 'chinese',
      name: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
      isAvailable: false,
    ),
    // Indonesian removed
    const LanguageData(
      code: 'japanese',
      name: 'Japanese',
      nativeName: '日本語',
      flag: '🇯🇵',
      isAvailable: false,
    ),
    const LanguageData(
      code: 'korean',
      name: 'Korean',
      nativeName: '한국어',
      flag: '🇰🇷',
      isAvailable: false,
    ),
    const LanguageData(
      code: 'thai',
      name: 'Thai',
      nativeName: 'ไทย',
      flag: '🇹🇭',
      isAvailable: true,
    ),
    const LanguageData(
      code: 'vietnamese',
      name: 'Vietnamese',
      nativeName: 'Tiếng Việt',
      flag: '🇻🇳',
      isAvailable: false,
    ),
  ];

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

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _slideController.dispose();
    _buttonController.dispose();
    _pulseController.dispose();
    _zoomController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  bool get _canContinue => _selectedLanguage != null && _selectedCharacter != null;

  Future<void> _onContinue() async {
    if (!_canContinue || _isNavigating) return;

    setState(() {
      _isNavigating = true;
    });

    _buttonController.forward();

    // Play start game sound effect
    _audioService.playStartGameSound();
    
    // Start zoom and fade animations
    _zoomController.forward();
    await Future.delayed(const Duration(milliseconds: 500));
    _fadeController.forward();

    // Save selections
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', _selectedLanguage!);
    await prefs.setString('selected_character', _selectedCharacter!);
    // Clear the flag to ensure map screen is always shown when coming from combined selection
    await prefs.setBool('has_selected_character', false);

    // Wait for animations to complete
    await Future.delayed(const Duration(milliseconds: 1000));

    // Navigate to appropriate map based on selected language
    if (mounted) {
      Widget destinationScreen;
      
      if (_selectedLanguage == 'thai') {
        destinationScreen = const ThailandMapScreen();
      } else {
        // For other languages, show a placeholder or coming soon screen
        destinationScreen = _buildComingSoonScreen();
      }
      
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destinationScreen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  /// Build coming soon screen for non-Thai languages
  Widget _buildComingSoonScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: modern.ModernDesignSystem.spaceGradient,
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.construction,
                  size: 80,
                  color: modern.ModernDesignSystem.butterYellow,
                ),
                const SizedBox(height: 24),
                Text(
                  'Coming Soon!',
                  style: modern.ModernDesignSystem.headlineLarge.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${_languageToCountry[_selectedLanguage]} adventures are\nunder construction',
                  textAlign: TextAlign.center,
                  style: modern.ModernDesignSystem.bodyMedium.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 32),
                modern.ModernButton(
                  text: 'Back to Selection',
                  onPressed: _handleBackNavigation,
                  style: modern.ButtonStyle.secondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Handle back navigation - go back to Splash screen
  void _handleBackNavigation() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SplashScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_zoomController, _fadeController]),
        builder: (context, child) {
          final zoomValue = Tween<double>(begin: 1.0, end: 3.0).animate(
            CurvedAnimation(parent: _zoomController, curve: Curves.easeInOut)
          ).value;
          
          final fadeValue = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: _fadeController, curve: Curves.easeIn)
          ).value;
          
          return Stack(
            children: [
              // Main content with zoom effect
              Transform.scale(
                scale: zoomValue,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: modern.ModernDesignSystem.spaceGradient,
                  ),
                  child: SafeArea(
                    child: Stack(
                      children: [
                        // Twinkling stars background - reduced for performance
                        const Positioned.fill(
                          child: TwinklingStars(
                            starCount: 15,
                            minSize: 0.8,
                            maxSize: 1.8,
                            duration: Duration(seconds: 10),
                          ),
                        ),
                        
                        // Main content with split layout
                        Column(
                          children: [
                            // Header
                            _buildHeader(context),
                            
                            // Top half - Language selection (scrollable)
                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  _buildSectionHeader(
                                    'Select Language',
                                    Icons.language,
                                    300,
                                  ),
                                  Expanded(
                                    child: GridView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 1.2,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                      itemCount: _languages.length,
                                      itemBuilder: (context, index) => _buildLanguageCard(_languages[index], index),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            // Bottom half - Character selection (larger sprites)
                            Expanded(
                              flex: 1,
                              child: Column(
                                children: [
                                  _buildSectionHeader(
                                    'Choose Character',
                                    Icons.person,
                                    600,
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 20),
                                      child: Row(
                                        children: _characters.map((character) {
                                          final index = _characters.indexOf(character);
                                          return Expanded(
                                            child: Padding(
                                              padding: EdgeInsets.only(
                                                right: index == 0 ? 6 : 0,
                                                left: index == 1 ? 6 : 0,
                                              ),
                                              child: _buildCharacterCard(character, index),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                                  
                                  // Button at bottom
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: _buildContinueButton(),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                      ],
                    ),
                  ),
                ),
              ),
              
              // White fade overlay
              if (fadeValue > 0)
                Positioned.fill(
                  child: Container(
                    color: Colors.white.withValues(alpha: fadeValue),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: _handleBackNavigation,
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Choose Your Journey',
              style: BabbleFonts.logo.copyWith(
                fontSize: 24,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms)
      .slideY(begin: -0.2, duration: 600.ms);
  }

  Widget _buildSectionHeader(String title, IconData icon, int delay) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: modern.ModernDesignSystem.primaryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: BabbleFonts.taglineVerb.copyWith(
              fontSize: 18,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ).animate()
      .fadeIn(duration: 600.ms, delay: Duration(milliseconds: delay))
      .slideX(begin: -0.2, duration: 600.ms);
  }

  Widget _buildLanguageCard(LanguageData language, int index) {
    final isSelected = _selectedLanguage == language.code;
    
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = isSelected 
            ? 1.0 + (_pulseController.value * 0.02)
            : 1.0;
            
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: language.isAvailable 
                ? () {
                    setState(() {
                      // Toggle selection - deselect if already selected
                      _selectedLanguage = _selectedLanguage == language.code 
                          ? null 
                          : language.code;
                    });
                    modern.ModernDesignSystem.triggerSelectionFeedback();
                  }
                : null,
            child: Container(
              decoration: BoxDecoration(
                gradient: isSelected 
                    ? modern.ModernDesignSystem.primaryGradient
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.04),
                        ],
                      ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.12),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected 
                        ? modern.ModernDesignSystem.primaryIndigo.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.1),
                    blurRadius: isSelected ? 20 : 8,
                    offset: const Offset(0, 4),
                  ),
                  if (isSelected)
                    BoxShadow(
                      color: modern.ModernDesignSystem.electricCyan.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                ],
              ),
              child: Stack(
                children: [
                  // Main content - centered independently of Soon tag
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            language.flag,
                            style: const TextStyle(fontSize: 32),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            language.name,
                            style: modern.ModernDesignSystem.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isSelected ? Colors.white : modern.ModernDesignSystem.textOnSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            language.nativeName,
                            style: modern.ModernDesignSystem.caption.copyWith(
                              fontSize: 12,
                              color: isSelected 
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : modern.ModernDesignSystem.softGray,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Status indicator - positioned absolutely to not affect layout
                  Positioned(
                    top: 8,
                    right: 8,
                    child: language.isAvailable 
                        ? Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.green.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Soon',
                              style: modern.ModernDesignSystem.caption.copyWith(
                                fontSize: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).animate()
      .fadeIn(duration: 600.ms, delay: Duration(milliseconds: 300 + (index * 100)))
      .scale(begin: const Offset(0.8, 0.8), duration: 600.ms);
  }

  Widget _buildCharacterCard(CharacterData character, int index) {
    final isSelected = _selectedCharacter == character.id;
    
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = isSelected 
            ? 1.0 + (_pulseController.value * 0.02)
            : 1.0;
            
        return Transform.scale(
          scale: scale,
          child: GestureDetector(
            onTap: () {
              setState(() {
                // Toggle selection - deselect if already selected
                _selectedCharacter = _selectedCharacter == character.id 
                    ? null 
                    : character.id;
              });
              modern.ModernDesignSystem.triggerSelectionFeedback();
            },
            child: Container(
              decoration: BoxDecoration(
                gradient: isSelected 
                    ? modern.ModernDesignSystem.primaryGradient
                    : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.white.withValues(alpha: 0.05),
                        ],
                      ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected 
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.15),
                  width: isSelected ? 2 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected 
                        ? modern.ModernDesignSystem.primaryIndigo.withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.15),
                    blurRadius: isSelected ? 20 : 10,
                    offset: const Offset(0, 4),
                  ),
                  if (isSelected)
                    BoxShadow(
                      color: modern.ModernDesignSystem.electricCyan.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Image.asset(
                    character.assetPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Icon(
                        character.id == 'male' ? Icons.person : Icons.person_4,
                        size: 80,
                        color: isSelected 
                            ? Colors.white
                            : modern.ModernDesignSystem.slateGray,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ).animate()
      .fadeIn(duration: 600.ms, delay: Duration(milliseconds: 900 + (index * 100)))
      .slideY(begin: 0.2, duration: 600.ms);
  }

  Widget _buildContinueButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = _canContinue ? _pulseController.value : 0.0;
        
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: _canContinue ? [
              BoxShadow(
                color: modern.ModernDesignSystem.cherryRed.withValues(alpha: glow * 0.3),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ] : [],
          ),
          child: modern.ModernButton(
            text: _canContinue 
                ? 'Travel to ${_languageToCountry[_selectedLanguage] ?? 'Adventure'}!' 
                : 'Select Language & Character',
            onPressed: _canContinue && !_isNavigating ? _onContinue : null,
            isLoading: _isNavigating,
            style: modern.ButtonStyle.primary,
            width: double.infinity,
            icon: _canContinue && !_isNavigating ? Icons.arrow_forward_rounded : null,
          ),
        );
      },
    ).animate()
      .fadeIn(duration: 600.ms, delay: 1200.ms)
      .slideY(begin: 0.2, duration: 600.ms);
  }
}


class LanguageData {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final bool isAvailable;

  const LanguageData({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.isAvailable,
  });
}

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