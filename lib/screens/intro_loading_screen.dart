import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/theme/modern_design_system.dart';
import 'package:babblelon/services/asset_preload_service.dart';
import 'package:babblelon/screens/intro_splash_screen.dart';
import 'package:babblelon/providers/tutorial_database_providers.dart';
import 'package:babblelon/services/background_audio_service.dart';

/// Initial loading screen that preloads all necessary assets before showing the intro
/// Ensures 3D earth model and other critical assets are ready to prevent lag
class IntroLoadingScreen extends ConsumerStatefulWidget {
  const IntroLoadingScreen({super.key});

  @override
  ConsumerState<IntroLoadingScreen> createState() => _IntroLoadingScreenState();
}

class _IntroLoadingScreenState extends ConsumerState<IntroLoadingScreen> 
    with SingleTickerProviderStateMixin {
  final AssetPreloadService _preloadService = AssetPreloadService();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  double _loadingProgress = 0.0;
  String _loadingMessage = 'Initializing...';
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    // Start preloading immediately
    _startPreloading();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startPreloading() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Step 1: Preload critical assets including 3D earth model
      await _preloadService.preloadAssets(
        context: context,
        onProgress: (progress, message) {
          if (mounted) {
            setState(() {
              _loadingProgress = progress * 0.7; // 70% of total progress
              _loadingMessage = message;
            });
          }
        },
      );

      // Step 2: Preload tutorial data in the background
      if (mounted) {
        setState(() {
          _loadingProgress = 0.75;
          _loadingMessage = 'Loading tutorial system...';
        });
        
        // Trigger tutorial data loading
        try {
          await ref.read(tutorialCompletionProvider.notifier).refreshFromDatabase();
        } catch (e) {
          // Non-critical error, continue
          debugPrint('Tutorial preload failed (non-critical): $e');
        }
      }

      // Step 3: Initialize audio service
      if (mounted) {
        setState(() {
          _loadingProgress = 0.85;
          _loadingMessage = 'Preparing audio...';
        });
        
        try {
          final audioService = BackgroundAudioService();
          await audioService.initialize();
        } catch (e) {
          // Non-critical error, continue
          debugPrint('Audio initialization failed (non-critical): $e');
        }
      }

      // Step 4: Final preparation
      if (mounted) {
        setState(() {
          _loadingProgress = 0.95;
          _loadingMessage = 'Almost ready...';
        });
        
        // Small delay to ensure smooth transition
        await Future.delayed(const Duration(milliseconds: 500));
        
        setState(() {
          _loadingProgress = 1.0;
          _loadingMessage = 'Welcome to BabbleOn!';
        });
        
        // Wait a moment to show completion
        await Future.delayed(const Duration(milliseconds: 800));
        
        // Navigate to intro splash screen
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => 
                IntroSplashScreen(audioService: BackgroundAudioService()),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 600),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to load resources. Please try again.';
          _isLoading = false;
        });
        debugPrint('Critical loading error: $e');
      }
    }
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
              Color(0xFF0A0D12), // Very dark blue-black
              Color(0xFF000000), // Pure black
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated logo
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              ModernDesignSystem.primaryAccent.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.language,
                          size: 60,
                          color: ModernDesignSystem.primaryAccent,
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: ModernDesignSystem.spaceXXL),
                
                // BabbleOn text
                Text(
                  'BabbleOn',
                  style: ModernDesignSystem.displayMedium.copyWith(
                    color: ModernDesignSystem.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                
                const SizedBox(height: ModernDesignSystem.spaceXL),
                
                // Loading progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: ModernDesignSystem.spaceXXL * 2),
                  child: Column(
                    children: [
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(ModernDesignSystem.radiusSmall),
                        child: LinearProgressIndicator(
                          value: _loadingProgress,
                          minHeight: 6,
                          backgroundColor: ModernDesignSystem.primarySurface,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _hasError ? ModernDesignSystem.error : ModernDesignSystem.primaryAccent,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: ModernDesignSystem.spaceMD),
                      
                      // Loading message
                      Text(
                        _hasError ? _errorMessage : _loadingMessage,
                        style: ModernDesignSystem.bodyMedium.copyWith(
                          color: _hasError ? ModernDesignSystem.error : ModernDesignSystem.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      
                      // Retry button if error
                      if (_hasError) ...[
                        const SizedBox(height: ModernDesignSystem.spaceXL),
                        ModernButton(
                          text: 'Retry',
                          onPressed: _startPreloading,
                          style: ModernButtonStyle.outline,
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: ModernDesignSystem.spaceXXL * 2),
                
                // Fun loading tip at the bottom
                if (!_hasError)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: ModernDesignSystem.spaceXL),
                    child: Text(
                      'Did you know? Thai has 5 tones that can change word meanings!',
                      style: ModernDesignSystem.bodySmall.copyWith(
                        color: ModernDesignSystem.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}