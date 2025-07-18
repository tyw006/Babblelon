import 'package:flutter/material.dart';
import 'package:babblelon/screens/main_screen/widgets/running_capybara_animation.dart';
import 'package:babblelon/services/asset_preload_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Lightweight loading overlay with running capybara animation
class CapybaraLoadingOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  
  const CapybaraLoadingOverlay({
    super.key,
    required this.onComplete,
  });

  @override
  State<CapybaraLoadingOverlay> createState() => _CapybaraLoadingOverlayState();
}

class _CapybaraLoadingOverlayState extends State<CapybaraLoadingOverlay> 
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _progressController;
  late Animation<double> _fadeAnimation;
  
  final AssetPreloadService _preloadService = AssetPreloadService();
  double _progress = 0.0;
  String _loadingText = 'Preparing your language adventure...';
  bool _isComplete = false;
  
  final List<String> _loadingTips = [
    'Immersive gaming makes language learning more effective!',
    'Many languages use different tones that change word meanings.',
    'Cultural context helps you understand language better.',
    'Practice speaking from day one for faster progress.',
    'Different writing systems offer unique learning challenges.',
    'Language learning opens doors to new cultures and opportunities!',
  ];
  
  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    ));
    
    _startLoading();
  }
  
  Future<void> _startLoading() async {
    await Future.delayed(const Duration(milliseconds: 200));
    
    // Start timing to enforce minimum 2-second duration
    final startTime = DateTime.now();
    const minimumDuration = Duration(seconds: 2);
    
    final success = await _preloadService.preloadAssets(
      context: mounted ? context : null,
      onProgress: (progress, step) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _loadingText = _getLoadingText(step);
          });
          _progressController.animateTo(progress);
        }
      },
    );
    
    if (success && mounted) {
      setState(() {
        _isComplete = true;
        _loadingText = 'Ready to start your adventure!';
      });
      
      // Calculate remaining time to reach minimum duration
      final elapsedTime = DateTime.now().difference(startTime);
      final remainingTime = minimumDuration - elapsedTime;
      
      // Wait for remaining time if less than minimum duration has passed
      if (remainingTime.inMilliseconds > 0) {
        await Future.delayed(remainingTime);
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      _fadeController.forward();
      
      await Future.delayed(const Duration(milliseconds: 400));
      widget.onComplete();
    }
  }
  
  String _getLoadingText(String step) {
    if (step.contains('UI')) return 'Setting up the interface...';
    if (step.contains('game')) return 'Loading immersive game scenes...';
    if (step.contains('audio')) return 'Preparing audio lessons...';
    if (step.contains('data')) return 'Loading vocabulary database...';
    if (step.contains('complete')) return 'Almost ready!';
    return 'Preparing your language adventure...';
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          // Gradient background - Dark blue space theme
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF0F1419), // Deep space dark
                  Color(0xFF1A2332), // Dark blue
                  Color(0xFF243447), // Medium blue
                  Color(0xFF2D4A7A), // Lighter blue
                ],
              ),
            ),
          ),
          
          // Subtle particle effect (much lighter than before)
          ...List.generate(15, (index) {
            return Positioned(
              left: (index * 60.0) % MediaQuery.of(context).size.width,
              top: (index * 80.0) % MediaQuery.of(context).size.height,
              child: Container(
                width: 2,
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ).animate(onPlay: (controller) => controller.repeat())
                .fadeIn(duration: 2000.ms)
                .fadeOut(duration: 2000.ms, delay: 1000.ms),
            );
          }),
          
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  
                  // Title
                  const Text(
                    'BabbleOn',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: Colors.black,
                          offset: Offset(2.0, 2.0),
                        ),
                      ],
                    ),
                  ).animate()
                    .fadeIn(duration: 1500.ms)
                    .slideY(begin: -30, duration: 1200.ms),
                  
                  const SizedBox(height: 16),
                  
                  // Subtitle - removed since tagline replaces it
                  const SizedBox.shrink(),
                  
                  const SizedBox(height: 16),
                  
                  // Tagline - Live the City, Learn the Language
                  Column(
                    children: [
                      Text(
                        'Live the City',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Learn the Language',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ).animate()
                    .fadeIn(duration: 1500.ms, delay: 800.ms)
                    .slideY(begin: 20, duration: 1200.ms),
                  
                  const Spacer(flex: 3),
                  
                  // Running Capybara Animation
                  const RunningCapybaraAnimation(
                    size: 100,
                    shadowColor: Colors.black,
                  ).animate()
                    .fadeIn(duration: 1200.ms, delay: 800.ms)
                    .scale(begin: const Offset(0.8, 0.8), duration: 1000.ms, delay: 800.ms),
                  
                  const SizedBox(height: 40),
                  
                  // Progress percentage
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF29B6F6),
                      shadows: [
                        Shadow(
                          blurRadius: 8,
                          color: Color(0xFF29B6F6),
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                  ).animate()
                    .fadeIn(duration: 1000.ms, delay: 1200.ms),
                  
                  const SizedBox(height: 16),
                  
                  // Loading text
                  SizedBox(
                    height: 50,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        child: Text(
                          _loadingText,
                          key: ValueKey(_loadingText),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            letterSpacing: 0.8,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Progress bar
                  Container(
                    width: double.infinity,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return LinearProgressIndicator(
                            value: _progressController.value,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _isComplete 
                                ? const Color(0xFF66BB6A)
                                : const Color(0xFF29B6F6),
                            ),
                          );
                        },
                      ),
                    ),
                  ).animate()
                    .fadeIn(duration: 1000.ms, delay: 1500.ms)
                    .slideY(begin: 20, duration: 1000.ms, delay: 1500.ms),
                  
                  const Spacer(flex: 2),
                  
                  // Loading tips
                  AnimatedBuilder(
                    animation: _fadeController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _isComplete ? 0.0 : 1.0,
                        child: LoadingTipsWidget(
                          tips: _loadingTips,
                        ),
                      );
                    },
                  ).animate()
                    .fadeIn(duration: 1200.ms, delay: 2000.ms),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          
          // Fade overlay for transition
          AnimatedBuilder(
            animation: _fadeAnimation,
            builder: (context, child) {
              return IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: _fadeAnimation.value),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}