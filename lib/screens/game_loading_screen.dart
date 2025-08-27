import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/services/static_game_loader.dart';
import 'package:babblelon/screens/game_screen.dart';
import 'package:babblelon/models/local_storage_models.dart';

/// Game loading screen with Thai cultural theme
/// Shows between Thailand map selection and actual game
class GameLoadingScreen extends ConsumerStatefulWidget {
  final String selectedCharacter; // 'male' or 'female'
  final GameSaveState? existingSave; // Save data to pass to GameScreen
  
  const GameLoadingScreen({
    super.key,
    required this.selectedCharacter,
    this.existingSave,
  });

  @override
  ConsumerState<GameLoadingScreen> createState() => _GameLoadingScreenState();
}

class _GameLoadingScreenState extends ConsumerState<GameLoadingScreen>
    with TickerProviderStateMixin {
  
  late AnimationController _characterController;
  late AnimationController _capybaraController;
  late AnimationController _progressController;
  late AnimationController _particleController;
  late AnimationController _walkController;
  late AnimationController _followController;
  late List<AnimationController> _thaiCharControllers;
  
  late Animation<double> _characterBounce;
  late Animation<double> _capybaraBounce;
  late Animation<double> _progressAnimation;
  late Animation<double> _particleAnimation;
  late Animation<double> _characterWalk;
  late Animation<double> _capybaraFollow;
  late List<Animation<double>> _thaiCharAnimations;
  
  final StaticGameLoader _staticGameLoader = StaticGameLoader();
  
  double _totalProgress = 0.0;
  double _lastProgress = 0.0;
  String _loadingText = 'Preparing your language adventure...';
  bool _isComplete = false;
  bool _isLoading = false;
  bool _hasStartedLoading = false; // Guard to prevent duplicate loading calls
  int _currentTipIndex = 0;
  
  // Character positions for walking animation
  double _characterX = 0.0;
  double _capybaraX = 0.0;
  
  final List<String> _culturalTips = [
    'Learning the wai greeting shows respect in Thai culture...',
    'Street food is a cornerstone of Bangkok social life...',
    'Yaowarat is Bangkok\'s vibrant Chinatown district...',
    'Tones in Thai can completely change word meanings...',
    'Practice makes perfect - เรียนรู้ด้วยกัน (learn together)!',
    'Thai script flows beautifully from left to right...',
    'Bangkok\'s markets come alive with energy at night...',
  ];
  
  // Culturally significant Thai characters (basic consonants)
  final List<String> _thaiChars = [
    'ก', 'ข', 'ค', 'ง', 'จ', 'ฉ', 'ช', 'ซ', 'ญ', 'ด', 'ต', 'ถ', 'ท', 'น', 'บ', 'ป', 'ผ', 'ฝ', 'พ', 'ฟ', 'ภ', 'ม', 'ย', 'ร', 'ล', 'ว', 'ศ', 'ษ', 'ส', 'ห', 'ฬ', 'อ', 'ฮ'
  ];
  
  @override
  void initState() {
    super.initState();
    
    debugPrint('🏗️ GameLoadingScreen: initState() called with character: ${widget.selectedCharacter}');
    
    _characterController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    
    _capybaraController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();
    
    _walkController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();
    
    _followController = AnimationController(
      duration: const Duration(milliseconds: 2200),
      vsync: this,
    )..repeat();
    
    // Thai character controllers for graceful animation
    _thaiCharControllers = List.generate(_thaiChars.length, (index) {
      return AnimationController(
        duration: Duration(milliseconds: 1500 + (index * 100)),
        vsync: this,
      )..repeat(reverse: true);
    });
    
    _characterBounce = Tween<double>(begin: -8.0, end: 8.0).animate(
      CurvedAnimation(parent: _characterController, curve: Curves.easeInOut),
    );
    
    _capybaraBounce = Tween<double>(begin: -6.0, end: 6.0).animate(
      CurvedAnimation(parent: _capybaraController, curve: Curves.easeInOut),
    );
    
    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    
    _particleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _particleController, curve: Curves.linear),
    );
    
    _characterWalk = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _walkController, curve: Curves.linear),
    );
    
    _capybaraFollow = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _followController, curve: Curves.linear),
    );
    
    // Thai character animations with staggered timing
    _thaiCharAnimations = _thaiCharControllers.map((controller) {
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: controller, curve: Curves.easeInOut),
      );
    }).toList();
    
    // Loading will be started in didChangeDependencies() to avoid MediaQuery context issues
    
    // Start cultural tip rotation
    Timer.periodic(const Duration(seconds: 4), (timer) {
      if (mounted && !_isComplete) {
        setState(() {
          _currentTipIndex = (_currentTipIndex + 1) % _culturalTips.length;
        });
      } else {
        timer.cancel();
      }
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Start loading only once, after the widget tree is built and MediaQuery is available
    if (!_hasStartedLoading) {
      _hasStartedLoading = true;
      _startLoading();
    }
  }
  
  Future<void> _startLoading() async {
    debugPrint('🎮 GameLoadingScreen: Starting loading with StaticGameLoader');
    
    // Check if StaticGameLoader is already loading
    if (_staticGameLoader.isLoading) {
      debugPrint('🚫 GameLoadingScreen: StaticGameLoader already loading');
      return;
    }
    
    // Check if game is already loaded
    if (_staticGameLoader.isLoaded) {
      debugPrint('✅ GameLoadingScreen: Game already loaded, deferring navigation to next frame');
      debugPrint('🎮 GameLoadingScreen: StaticGameLoader state - isLoaded=${_staticGameLoader.isLoaded}, isLoading=${_staticGameLoader.isLoading}');
      debugPrint('🎮 GameLoadingScreen: existingSave data: ${widget.existingSave?.levelId ?? 'null'}');
      _isComplete = true; // Set completion flag before navigation
      // Defer navigation to after build completes to avoid navigation during build cycle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint('📍 GameLoadingScreen: Post-frame callback executing');
        debugPrint('📍 GameLoadingScreen: Widget mounted: $mounted');
        debugPrint('📍 GameLoadingScreen: _isComplete: $_isComplete');
        if (mounted) {
          debugPrint('✅ GameLoadingScreen: Post-frame callback - navigating to game');
          _navigateToGame();
        } else {
          debugPrint('⚠️ GameLoadingScreen: Widget no longer mounted during post-frame callback');
        }
      });
      return;
    }
    
    // Prevent duplicate loading calls on this instance
    if (_isLoading) {
      debugPrint('🚫 GameLoadingScreen: This instance already loading');
      return;
    }
    
    _isLoading = true;
    debugPrint('🎮 GameLoadingScreen: Starting StaticGameLoader process...');
    
    // Start loading with StaticGameLoader
    await _staticGameLoader.startLoading(
      selectedCharacter: widget.selectedCharacter,
      onComplete: () {
        if (mounted) {
          debugPrint('✅ GameLoadingScreen: StaticGameLoader completed, navigating to game');
          _isComplete = true;
          _navigateToGame();
        }
      },
      onError: (error) {
        if (mounted) {
          debugPrint('❌ GameLoadingScreen: StaticGameLoader failed - $error');
          setState(() {
            _loadingText = 'Loading failed: $error';
          });
        }
      },
      onProgress: (progress, step) {
        if (mounted) {
          setState(() {
            _totalProgress = progress;
            _loadingText = _getLanguageLoadingText(step);
            _updateCharacterPositions(progress);
          });
          _progressController.animateTo(_totalProgress);
        }
      },
    );
  }

  void _updateCharacterPositions(double progress) {
    // Only update if we're mounted and have access to context
    if (!mounted) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Character walks from right to left based on progress
    _characterX = screenWidth + 120 - (progress * (screenWidth + 240));
    _capybaraX = _characterX + 100; // Capybara follows 100 pixels behind
    
    // Control walking animation based on progress change
    if (progress > _lastProgress) {
      // Progress is increasing, character should walk
      if (!_walkController.isAnimating) {
        _walkController.repeat();
      }
    } else {
      // Progress stopped, character stops walking
      if (_walkController.isAnimating) {
        _walkController.stop();
      }
    }
    _lastProgress = progress;
  }

  void _navigateToGame() async {
    debugPrint('🎮 GameLoadingScreen: _navigateToGame() called');
    debugPrint('🎮 GameLoadingScreen: mounted=$mounted, _isComplete=$_isComplete');
    debugPrint('🎮 GameLoadingScreen: existingSave=${widget.existingSave?.levelId ?? 'null'}');
    
    if (!mounted || _isComplete == false) {
      debugPrint('⚠️ GameLoadingScreen: Early return - mounted=$mounted, _isComplete=$_isComplete');
      return;
    }
    
    debugPrint('🎮 GameLoadingScreen: All checks passed, navigating to GameScreen');
    
    // Pass existingSave (already handled by ThailandMapScreen) directly to GameScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(existingSave: widget.existingSave),
      ),
    );
  }

  String _getLanguageLoadingText(String step) {
    // Add cultural flair to loading messages
    final loadingPhrases = {
      'Initializing': 'Starting your language adventure...',
      'Loading': 'Loading resources...',
      'Preparing': 'Preparing your experience...',
      'assets': 'Loading images and sounds...',
      'audio': 'Preparing audio...',
      'game': 'Starting game...',
      'ready': 'Ready to learn!',
    };
    
    for (final phrase in loadingPhrases.entries) {
      if (step.toLowerCase().contains(phrase.key.toLowerCase())) {
        return phrase.value;
      }
    }
    
    return step; // Fallback to original text
  }

  @override
  void dispose() {
    debugPrint('🗑️ GameLoadingScreen: dispose() called');
    
    _characterController.dispose();
    _capybaraController.dispose();
    _progressController.dispose();
    _particleController.dispose();
    _walkController.dispose();
    _followController.dispose();
    
    for (final controller in _thaiCharControllers) {
      controller.dispose();
    }
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: Stack(
        children: [
          // Blurred Yaowarat background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/background/yaowarat_bg2.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  color: Colors.black.withOpacity(0.5),
                ),
              ),
            ),
          ),
          
          // Animated space content
          Container(
            child: Stack(
              children: [
                // Floating particles background
                ...List.generate(12, (index) => _buildFloatingParticle(index)),
                
                // Thai characters floating around
                ...List.generate(8, (index) => _buildFloatingThaiChar(index)),
                
                // Main content
                SafeArea(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 1),
                        
                        // Main character animation
                        _buildCharacterSection(),
                        
                        const SizedBox(height: 30), // Reduced from 60
                        
                        // Progress section
                        _buildProgressSection(),
                        
                        const SizedBox(height: 20), // Reduced from 40
                        
                        // Cultural tips section
                        _buildCulturalTipsSection(),
                        
                        const Spacer(flex: 1), // Reduced from flex: 2
                      ],
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

  Widget _buildFloatingParticle(int index) {
    return AnimatedBuilder(
      animation: _particleAnimation,
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        final xOffset = (screenWidth * 0.1) + 
                       (screenWidth * 0.8 * (index / 12)) +
                       (30 * math.sin(_particleAnimation.value * 2 * math.pi + index));
        final yOffset = (screenHeight * 0.1) + 
                       (screenHeight * 0.8 * ((index % 3) / 3)) +
                       (20 * math.cos(_particleAnimation.value * 2 * math.pi + index * 0.7));
        
        // Create geometric shapes for modern theme
        final isTriangle = index % 3 == 0;
        final isHexagon = index % 3 == 1;
        final size = 4.0 + (index % 3) * 2;
        
        return Positioned(
          left: xOffset,
          top: yOffset,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0x4400FFFF), // Transparent cyan
              shape: isTriangle || isHexagon ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: isHexagon ? BorderRadius.circular(2) : null,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x3300FFFF), // Cyan glow
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: isTriangle 
              ? CustomPaint(
                  painter: TrianglePainter(),
                  size: Size(size, size),
                )
              : null,
          ),
        );
      },
    );
  }

  Widget _buildFloatingThaiChar(int index) {
    if (index >= _thaiCharAnimations.length) return const SizedBox.shrink();
    
    return AnimatedBuilder(
      animation: _thaiCharAnimations[index],
      builder: (context, child) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        
        final xOffset = (screenWidth * 0.05) + 
                       (screenWidth * 0.9 * (index / 8)) +
                       (40 * math.sin(_thaiCharAnimations[index].value * 2 * math.pi));
        final yOffset = (screenHeight * 0.05) + 
                       (screenHeight * 0.9 * ((index % 4) / 4)) +
                       (25 * math.cos(_thaiCharAnimations[index].value * 2 * math.pi));
        
        return Positioned(
          left: xOffset,
          top: yOffset,
          child: Opacity(
            opacity: 0.1 + (_thaiCharAnimations[index].value * 0.3),
            child: Text(
              _thaiChars[index % _thaiChars.length],
              style: TextStyle(
                fontSize: 24 + (index % 3) * 8,
                color: Colors.orange.withOpacity(0.6),
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCharacterSection() {
    return SizedBox(
      height: 200,
      child: Stack(
        children: [
          // Character walking from right to left
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            left: _characterX,
            top: 40,
            child: AnimatedBuilder(
              animation: Listenable.merge([_characterBounce, _characterWalk]),
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _characterBounce.value * 0.5), // Reduced bounce for walking
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(60),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x6600FFFF), // Cyan glow
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(60),
                      child: Image.asset(
                        widget.selectedCharacter == 'female' 
                          ? 'assets/images/player/sprite_female_tourist.png'
                          : 'assets/images/player/sprite_male_tourist.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Capybara following behind
          AnimatedPositioned(
            duration: const Duration(milliseconds: 400), // Slightly slower follow
            left: _capybaraX,
            top: 80,
            child: AnimatedBuilder(
              animation: Listenable.merge([_capybaraBounce, _capybaraFollow]),
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _capybaraBounce.value * 0.3), // Even smaller bounce
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0x66FF9800), // Orange glow
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: Image.asset(
                        'assets/images/player/capybara.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          // Modern neon progress bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Container(
                width: double.infinity,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: const Color(0x2200FFFF),
                  border: Border.all(
                    color: const Color(0x4400FFFF),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x2200FFFF),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _totalProgress,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF00FFFF), Color(0xFF0088FF)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x6600FFFF),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Progress percentage with neon effect
          Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: const Color(0x6600FFFF),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Text(
              '${(_totalProgress * 100).toInt()}%',
              style: const TextStyle(
                color: Color(0xFF00FFFF),
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Loading text
          Text(
            _loadingText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCulturalTipsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        child: Container(
          key: ValueKey(_currentTipIndex),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white.withOpacity(0.05),
            border: Border.all(
              color: Colors.orange.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            _culturalTips[_currentTipIndex],
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for triangle geometric particles
class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x6600FFFF) // Semi-transparent cyan
      ..style = PaintingStyle.fill;
    
    final path = Path();
    path.moveTo(size.width / 2, 0); // Top point
    path.lineTo(0, size.height); // Bottom left
    path.lineTo(size.width, size.height); // Bottom right
    path.close();
    
    canvas.drawPath(path, paint);
    
    // Add glow effect
    final glowPaint = Paint()
      ..color = const Color(0x3300FFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2);
    
    canvas.drawPath(path, glowPaint);
  }
  
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}