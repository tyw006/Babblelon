import 'package:flutter/material.dart';
import 'package:babblelon/widgets/modern_design_system.dart' as modern;
import 'package:babblelon/screens/main_screen/widgets/atmospheric_particles.dart';
import 'package:babblelon/screens/main_screen/widgets/earth_globe_widget.dart';
import 'package:babblelon/services/asset_preload_service.dart';

/// Space-themed loading overlay that preloads all game assets
class LoadingOverlay extends StatefulWidget {
  final VoidCallback onComplete;
  
  const LoadingOverlay({
    super.key,
    required this.onComplete,
  });

  @override
  State<LoadingOverlay> createState() => _LoadingOverlayState();
}

class _LoadingOverlayState extends State<LoadingOverlay> 
    with TickerProviderStateMixin {
  late AnimationController _globeRotationController;
  late AnimationController _capybaraController;
  late AnimationController _fadeController;
  late AnimationController _textPulseController;
  late AnimationController _progressBarController;
  
  final AssetPreloadService _preloadService = AssetPreloadService();
  double _progress = 0.0;
  String _loadingText = 'Initializing space portal...';
  bool _isComplete = false;
  
  @override
  void initState() {
    super.initState();
    
    _globeRotationController = AnimationController(
      duration: const Duration(seconds: 40),
      vsync: this,
    )..repeat();
    
    _capybaraController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _textPulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _progressBarController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _startLoading();
  }
  
  Future<void> _startLoading() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final success = await _preloadService.preloadAssets(
      context: mounted ? context : null,
      onProgress: (progress, step) {
        if (mounted) {
          setState(() {
            _progress = progress;
            _loadingText = _getLoadingText(step);
          });
          _progressBarController.animateTo(progress);
        }
      },
    );
    
    if (success && mounted) {
      setState(() {
        _isComplete = true;
        _loadingText = 'Portal activated! Launching...';
      });
      
      await Future.delayed(const Duration(milliseconds: 1000));
      _fadeController.forward();
      
      await Future.delayed(const Duration(milliseconds: 800));
      widget.onComplete();
    }
  }
  
  String _getLoadingText(String step) {
    if (step.contains('UI')) return 'Calibrating holographic interface...';
    if (step.contains('game')) return 'Loading Bangkok street scenes...';
    if (step.contains('audio')) return 'Tuning cosmic frequencies...';
    if (step.contains('data')) return 'Downloading language matrices...';
    if (step.contains('complete')) return 'Portal activation complete!';
    return 'Preparing interdimensional journey...';
  }
  
  @override
  void dispose() {
    _globeRotationController.dispose();
    _capybaraController.dispose();
    _fadeController.dispose();
    _textPulseController.dispose();
    _progressBarController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: Stack(
        children: [
          // Space gradient background
          Container(
            decoration: const BoxDecoration(
              gradient: modern.ModernDesignSystem.spaceGradient,
            ),
          ),
          
          // Atmospheric particles
          const Positioned.fill(
            child: AtmosphericParticles(
              earthRadius: 200,
              isActive: true,
              intensity: 0.5,
            ),
          ),
          
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(modern.ModernDesignSystem.spaceXL),
              child: Column(
                children: [
                  const Spacer(flex: 1),
                  
                  // 3D Earth globe with loading overlay
                  Expanded(
                    flex: 4,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Earth globe
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: Transform.scale(
                            scale: 0.8,
                            child: EarthGlobeWidget(
                              rotationController: _globeRotationController,
                              capybaraController: _capybaraController,
                              isRotatingToThailand: false,
                              zoomLevel: 1.0,
                            ),
                          ),
                        ),
                        
                        // Circular progress overlay
                        AspectRatio(
                          aspectRatio: 1.0,
                          child: AnimatedBuilder(
                            animation: _progressBarController,
                            builder: (context, child) {
                              return CustomPaint(
                                painter: CircularProgressPainter(
                                  progress: _progressBarController.value,
                                  strokeWidth: 4.0,
                                  color: modern.ModernDesignSystem.electricCyan,
                                  backgroundColor: Colors.white.withValues(alpha: 0.1),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: modern.ModernDesignSystem.spaceLG),
                  
                  // Tagline with subtle animation
                  AnimatedBuilder(
                    animation: _textPulseController,
                    builder: (context, child) {
                      final opacity = 0.7 + (_textPulseController.value * 0.3);
                      return Column(
                        children: [
                          Text(
                            'Live the City',
                            style: modern.ModernDesignSystem.headlineSmall.copyWith(
                              color: Colors.white.withValues(alpha: opacity),
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  blurRadius: 8,
                                  color: Colors.white.withValues(alpha: 0.3 * opacity),
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: modern.ModernDesignSystem.spaceSM),
                          Text(
                            'Learn the Language',
                            style: modern.ModernDesignSystem.headlineSmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.8 * opacity),
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                              shadows: [
                                Shadow(
                                  blurRadius: 8,
                                  color: Colors.white.withValues(alpha: 0.2 * opacity),
                                  offset: const Offset(0, 0),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: modern.ModernDesignSystem.spaceXL),
                  
                  // Progress percentage
                  AnimatedBuilder(
                    animation: _textPulseController,
                    builder: (context, child) {
                      final pulse = 0.8 + (_textPulseController.value * 0.2);
                      return Transform.scale(
                        scale: pulse,
                        child: Text(
                          '${(_progress * 100).toInt()}%',
                          style: modern.ModernDesignSystem.headlineLarge.copyWith(
                            color: modern.ModernDesignSystem.electricCyan,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 20,
                                color: modern.ModernDesignSystem.electricCyan.withValues(alpha: 0.6),
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: modern.ModernDesignSystem.spaceMD),
                  
                  // Loading text with typewriter effect
                  SizedBox(
                    height: 60,
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 600),
                        child: Text(
                          _loadingText,
                          key: ValueKey(_loadingText),
                          style: modern.ModernDesignSystem.bodyLarge.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 18,
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: modern.ModernDesignSystem.spaceLG),
                  
                  // Linear progress bar
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: AnimatedBuilder(
                        animation: _progressBarController,
                        builder: (context, child) {
                          return LinearProgressIndicator(
                            value: _progressBarController.value,
                            backgroundColor: Colors.transparent,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _isComplete 
                                ? modern.ModernDesignSystem.dillGreen
                                : modern.ModernDesignSystem.electricCyan,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Loading tips
                  AnimatedOpacity(
                    opacity: _isComplete ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Column(
                      children: [
                        Text(
                          'Did you know?',
                          style: modern.ModernDesignSystem.bodyMedium.copyWith(
                            color: modern.ModernDesignSystem.electricCyan,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: modern.ModernDesignSystem.spaceSM),
                        Text(
                          'Bangkok\'s Chinatown is one of the largest in the world!',
                          style: modern.ModernDesignSystem.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: modern.ModernDesignSystem.spaceXL),
                ],
              ),
            ),
          ),
          
          // Fade overlay for transition
          AnimatedBuilder(
            animation: _fadeController,
            builder: (context, child) {
              return IgnorePointer(
                child: Container(
                  color: Colors.white.withValues(alpha: _fadeController.value),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Custom painter for circular progress around the globe
class CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color color;
  final Color backgroundColor;
  
  CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.backgroundColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    
    const startAngle = -90 * (3.14159 / 180);
    final sweepAngle = 360 * progress * (3.14159 / 180);
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }
  
  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}