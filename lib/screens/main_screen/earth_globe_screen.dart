import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/main_screen/widgets/earth_globe_widget.dart';
import 'package:babblelon/screens/main_screen/widgets/language_dropdown.dart';
import 'package:babblelon/screens/main_screen/widgets/twinkling_stars.dart';
import 'package:babblelon/screens/main_screen/thailand_map_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:textuality/textuality.dart';
import 'package:flutter_animate/flutter_animate.dart';

class EarthGlobeScreen extends ConsumerStatefulWidget {
  const EarthGlobeScreen({super.key});

  @override
  ConsumerState<EarthGlobeScreen> createState() => _EarthGlobeScreenState();
}

class _EarthGlobeScreenState extends ConsumerState<EarthGlobeScreen> 
    with TickerProviderStateMixin {
  late AnimationController _globeRotationController;
  late AnimationController _capybaraController;
  late AnimationController _zoomController;
  late Animation<double> _zoomAnimation;
  bool _isRotatingToThailand = false;
  
  @override
  void initState() {
    super.initState();
    
    _globeRotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _capybaraController = AnimationController(
      duration: const Duration(milliseconds: 15000), // Slower for better performance
      vsync: this,
    )..repeat();
    
    _zoomController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _zoomAnimation = Tween<double>(
      begin: 1.0,
      end: 5.0,
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _globeRotationController.dispose();
    _capybaraController.dispose();
    _zoomController.dispose();
    super.dispose();
  }

  void _onLanguageSelected(String language) {
    if (language == 'thai' && !_isRotatingToThailand) {
      setState(() {
        _isRotatingToThailand = true;
      });
      
      _globeRotationController.forward().then((_) {
        _zoomController.forward();
        
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ThailandMapScreen()),
            );
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Space background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [Color(0xFF001122), Color(0xFF000000)],
                ),
              ),
            ),
          ),

          // Twinkling stars (reduced for performance)
          const Positioned.fill(
            child: TwinklingStars(
              starCount: 25,
              minSize: 1.0,
              maxSize: 2.0,
              duration: Duration(seconds: 6),
            ),
          ),

          // Title and tagline
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Main title with elaborate styling
                RepaintBoundary(
                  child: Stack(
                    children: [
                      // Deep shadow for 3D effect
                      Transform.translate(
                        offset: const Offset(4, 4),
                        child: Text(
                          'BabbleOn',
                          style: GoogleFonts.fredoka(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: const Color(0xFF2D1810),
                          ),
                        ),
                      ),
                      // Thick dark brown outline
                      StrokeText(
                        text: 'BabbleOn',
                        strokeColor: const Color(0xFF4A2C17),
                        strokeWidth: 6.0,
                        style: GoogleFonts.fredoka(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Colors.transparent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Medium brown outline
                      StrokeText(
                        text: 'BabbleOn',
                        strokeColor: const Color(0xFF6B3E2A),
                        strokeWidth: 4.0,
                        style: GoogleFonts.fredoka(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Colors.transparent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Light brown highlight outline
                      StrokeText(
                        text: 'BabbleOn',
                        strokeColor: const Color(0xFF8B5A3C),
                        strokeWidth: 2.0,
                        style: GoogleFonts.fredoka(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          color: Colors.transparent,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Main gradient text
                      GradientText(
                        text: 'BabbleOn',
                        giveGradient: const [
                          Color(0xFFFFA726),
                          Color(0xFFFFCC80),
                          Color(0xFFF57C00),
                          Color(0xFFFFB74D),
                        ],
                        style: GoogleFonts.fredoka(
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      // Top highlight
                      Transform.translate(
                        offset: const Offset(0, -1),
                        child: GradientText(
                          text: 'BabbleOn',
                          giveGradient: const [
                            Color(0xFFFFE0B2),
                            Color(0xFFFFF3E0),
                          ],
                          style: GoogleFonts.fredoka(
                            fontSize: 56,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Tagline (optimized with RepaintBoundary)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: RepaintBoundary(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // "Live" with green styling
                            RepaintBoundary(
                              child: Stack(
                                children: [
                                  StrokeText(
                                    text: 'Live',
                                    strokeColor: const Color(0xFF2D1810),
                                    strokeWidth: 4.0,
                                    style: GoogleFonts.fredoka(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.transparent,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  GradientText(
                                    text: 'Live',
                                    giveGradient: const [
                                      Color(0xFF66BB6A),
                                      Color(0xFF4CAF50),
                                    ],
                                    style: GoogleFonts.fredoka(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              ' the City',
                              style: GoogleFonts.fredoka(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 1.2,
                                shadows: [
                                  const Shadow(
                                    color: Color(0xFF2D1810),
                                    blurRadius: 2,
                                    offset: Offset(2, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            // "Learn" with blue styling
                            RepaintBoundary(
                              child: Stack(
                                children: [
                                  StrokeText(
                                    text: 'Learn',
                                    strokeColor: const Color(0xFF2D1810),
                                    strokeWidth: 4.0,
                                    style: GoogleFonts.fredoka(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.transparent,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  GradientText(
                                    text: 'Learn',
                                    giveGradient: const [
                                      Color(0xFF29B6F6),
                                      Color(0xFF03A9F4),
                                    ],
                                    style: GoogleFonts.fredoka(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              ' the Language',
                              style: GoogleFonts.fredoka(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: 1.2,
                                shadows: [
                                  const Shadow(
                                    color: Color(0xFF2D1810),
                                    blurRadius: 2,
                                    offset: Offset(2, 2),
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
              ],
            ).animate()
              .fadeIn(duration: 1200.ms)
              .slideY(begin: -30, duration: 1000.ms),
          ),

          // Earth Globe Widget
          Center(
            child: AnimatedBuilder(
              animation: _zoomAnimation,
              builder: (context, child) => Transform.scale(
                scale: _zoomAnimation.value,
                child: child!,
              ),
              child: EarthGlobeWidget(
                rotationController: _globeRotationController,
                capybaraController: _capybaraController,
                isRotatingToThailand: _isRotatingToThailand,
                zoomLevel: 1.0,
              ),
            ),
          ),

          // Language dropdown
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: LanguageDropdown(
              onLanguageSelected: _onLanguageSelected,
              isRotating: _isRotatingToThailand,
            ),
          ),
        ],
      ),
    );
  }
}