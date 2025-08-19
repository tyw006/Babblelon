import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';
import 'package:babblelon/widgets/modern_design_system.dart';
import 'package:babblelon/screens/main_screen/widgets/earth_globe_widget.dart';
import 'package:babblelon/screens/main_screen/widgets/twinkling_stars.dart';
import 'package:babblelon/screens/enhanced_onboarding_screen.dart';
import 'package:babblelon/screens/main_navigation_screen.dart';
import 'package:babblelon/providers/profile_providers.dart';
import 'package:babblelon/widgets/modern_logo.dart';
import 'package:babblelon/widgets/bouncing_entrance.dart';
import 'package:babblelon/providers/motion_preferences_provider.dart';
import 'package:babblelon/services/background_audio_service.dart';
import 'package:babblelon/services/auth_service_interface.dart';
import 'package:babblelon/screens/authentication_screen.dart';

/// Cartoon splash screen following BabbleOn UI Design Guide v2.0 (July 2025)
/// Implements cartoon-themed design with playful animations and warm colors
class CartoonSplashScreen extends ConsumerStatefulWidget {
  final BackgroundAudioService? audioService;
  
  const CartoonSplashScreen({super.key, this.audioService});

  @override
  ConsumerState<CartoonSplashScreen> createState() => _CartoonSplashScreenState();
}

class _CartoonSplashScreenState extends ConsumerState<CartoonSplashScreen> 
    with TickerProviderStateMixin {
  late AnimationController _globeRotationController;
  late AnimationController _capybaraController;
  late AnimationController _titleController;
  late AnimationController _buttonController;
  late AnimationController _zoomController;
  
  @override
  void initState() {
    super.initState();
    
    _globeRotationController = AnimationController(
      duration: const Duration(seconds: 60), // Calm 60s rotation from design guide
      vsync: this,
    )..repeat();
    
    _capybaraController = AnimationController(
      duration: const Duration(seconds: 20), // Moderate orbit speed
      vsync: this,
    )..repeat();
    
    _titleController = AnimationController(
      duration: CartoonDesignSystem.slowTransition,
      vsync: this,
    );
    
    _buttonController = AnimationController(
      duration: CartoonDesignSystem.standardTransition,
      vsync: this,
    );
    
    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    
    // Progressive animation sequence
    _startAnimationSequence();
  }
  
  void _startAnimationSequence() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      _titleController.forward();
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        _buttonController.forward();
      }
    }
  }

  @override
  void dispose() {
    _globeRotationController.dispose();
    _capybaraController.dispose();
    _titleController.dispose();
    _buttonController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  void _onStartJourney() async {
    CartoonDesignSystem.triggerSuccessFeedback();
    
    // Start zoom animation first
    _zoomController.forward();
    
    // Play sound effect during zoom animation (not on button click)
    widget.audioService?.playStartGameSound();
    
    // Wait for zoom to complete
    await Future.delayed(const Duration(milliseconds: 600));
    
    // Wait for animations to complete
    await Future.delayed(const Duration(milliseconds: 1000));
    
    if (mounted) {
      // Check authentication status first
      final authService = AuthServiceFactory.getInstance();
      
      Widget destination;
      if (!authService.isAuthenticated) {
        // User not authenticated - show authentication screen
        destination = const AuthenticationScreen();
      } else {
        // Check profile completion asynchronously
        try {
          final profileState = await ref.read(profileCompletionProvider.future);
          if (profileState.isCompleted) {
            // Returning user - go to main navigation
            destination = const MainNavigationScreen();
          } else {
            // First-time user - show enhanced onboarding
            destination = const EnhancedOnboardingScreen();
          }
        } catch (e) {
          // On error, show onboarding to be safe
          destination = const EnhancedOnboardingScreen();
        }
      }
      
      if (mounted) {
        Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => destination,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: ModernDesignSystem.spaceGradient,
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Twinkling stars background
              const Positioned.fill(
                child: TwinklingStars(
                  starCount: 30,
                  minSize: 1.0,
                  maxSize: 3.0,
                  duration: Duration(seconds: 8),
                ),
              ),

              // Main content with proper spacing (8pt grid)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _zoomController,
                  builder: (context, child) {
                    final zoomScale = 1.0 + (_zoomController.value * 4.0); // Increased from 2.0 to 4.0 for more dramatic zoom
                    final translateY = -MediaQuery.of(context).size.height * 0.20 * _zoomController.value; // Increased translation for better effect
                    
                    return Transform.translate(
                      offset: Offset(0, translateY),
                      child: Transform.scale(
                        scale: zoomScale,
                        child: Padding(
                        padding: const EdgeInsets.all(CartoonDesignSystem.spaceXL),
                        child: Column(
                          children: [
                      // Logo and tagline section with bouncing entrance
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Modern logo with smooth animations and emphasized O
                            ConditionalAnimation(
                              animationBuilder: (context, child) => VoxieStyleEntrance(
                                duration: const Duration(milliseconds: 800),
                                enableBounce: false,
                                enableFade: true,
                                child: child,
                              ),
                              child: const ModernLogo(
                                text: 'BabbleOn',
                                enableAnimations: true,
                                fontSize: 56.0,
                              ),
                            ),
                            
                            const SizedBox(height: CartoonDesignSystem.spaceXL),
                            
                            // Modern tagline with staggered animations and clean typography
                            ConditionalAnimation(
                              animationBuilder: (context, child) => VoxieStyleEntrance(
                                duration: const Duration(milliseconds: 600),
                                enableBounce: false,
                                enableFade: true,
                                child: child,
                              ),
                              child: const ModernTagline(
                                enableAnimations: true,
                                fontSize: 24.0,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Globe section (45% of screen height as per design guide)
                      Expanded(
                        flex: 3,
                        child: Center(
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: AspectRatio(
                              aspectRatio: 1.0,
                              child: EarthGlobeWidget(
                                rotationController: _globeRotationController,
                                capybaraController: _capybaraController,
                                isRotatingToThailand: false,
                                zoomLevel: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // CTA button section (sticky at bottom)
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Primary CTA button with Cherry Red gradient
                            AnimatedBuilder(
                              animation: _buttonController,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _buttonController.value,
                                  child: Transform.translate(
                                    offset: Offset(0, 50 * (1 - _buttonController.value)),
                                    child: Semantics(
                                      label: 'Start Your Journey button',
                                      hint: 'Tap to begin your language learning adventure',
                                      button: true,
                                      child: CartoonButton(
                                        text: 'Start Your Journey!',
                                        onPressed: _onStartJourney,
                                        style: CartoonButtonStyle.accent,
                                        width: double.infinity,
                                        icon: Icons.explore,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            const SizedBox(height: CartoonDesignSystem.spaceXL),
                          ],
                        ),
                      ),
                    ],
                          ),
                        ),
                      ),
                    );
                    },
                  ),
                ),
              
            ],
          ),
        ),
      ),
    );
  }
}