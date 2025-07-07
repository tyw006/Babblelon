import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../services/game_initialization_service.dart';
import 'game_screen.dart';

/// Loading screen that handles game initialization with progress feedback
class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _pulseController;
  
  double _progress = 0.0;
  String _currentStep = 'Initializing...';
  bool _initializationComplete = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _startInitialization();
  }

  Future<void> _startInitialization() async {
    final initService = GameInitializationService();
    
    try {
      final success = await initService.initializeGame(
        onProgress: (progress, step) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _currentStep = step;
            });
            _progressController.animateTo(progress);
          }
        },
      );
      
      if (success && mounted) {
        setState(() {
          _initializationComplete = true;
        });
        
        // Brief delay to show completion message
        await Future.delayed(const Duration(milliseconds: 800));
        
        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => GameScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
      } else if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to initialize game assets. Please try again.';
        });
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Initialization error: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1A1A1A),
              Color(0xFF2D2D2D),
              Color(0xFF1A1A1A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header Section
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Game Logo/Title
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: 1.0 + (_pulseController.value * 0.05),
                          child: const Text(
                            'BabbleOn',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4ECCA3),
                              shadows: [
                                Shadow(
                                  blurRadius: 20.0,
                                  color: Color(0xFF4ECCA3),
                                  offset: Offset(0, 0),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Thai Language Learning Adventure',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Loading Section
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!_hasError) ...[
                      // Animation Section
                      SizedBox(
                        width: 200,
                        height: 200,
                        child: _initializationComplete
                            ? _buildCompletionAnimation()
                            : _buildLoadingAnimation(),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Progress Bar
                      Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3A3A3A),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: AnimatedBuilder(
                            animation: _progressController,
                            builder: (context, child) {
                              return LinearProgressIndicator(
                                value: _progressController.value,
                                backgroundColor: Colors.transparent,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF4ECCA3),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Progress Percentage
                      Text(
                        '${(_progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4ECCA3),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Current Step
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _currentStep,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ] else ...[
                      // Error State
                      const Icon(
                        Icons.error_outline,
                        size: 80,
                        color: Colors.redAccent,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Initialization Failed',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _hasError = false;
                            _progress = 0.0;
                            _currentStep = 'Initializing...';
                          });
                          _progressController.reset();
                          _startInitialization();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4ECCA3),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 12,
                          ),
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Footer Section
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (!_hasError && !_initializationComplete) ...[
                      const Text(
                        'Setting up your language learning experience...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white54,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLoadingDot(0),
                          _buildLoadingDot(1),
                          _buildLoadingDot(2),
                        ],
                      ),
                    ],
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build completion animation - uses victory confetti or fallback icon
  Widget _buildCompletionAnimation() {
    try {
      return Lottie.asset(
        'assets/lottie/victory_confetti.json',
        repeat: false,
        onLoaded: (composition) {
          // Animation loaded successfully
        },
      );
    } catch (e) {
      // Fallback to icon if Lottie fails
      return const Icon(
        Icons.check_circle,
        size: 100,
        color: Color(0xFF4ECCA3),
      );
    }
  }

  /// Build loading animation - uses simple rotating icon
  Widget _buildLoadingAnimation() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.rotate(
          angle: _pulseController.value * 2 * 3.14159,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF4ECCA3),
                width: 3,
              ),
            ),
            child: const Icon(
              Icons.language,
              size: 50,
              color: Color(0xFF4ECCA3),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingDot(int index) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final delay = index * 0.2;
        final progress = (_pulseController.value + delay) % 1.0;
        final opacity = (progress * 2).clamp(0.3, 1.0);
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF4ECCA3).withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}