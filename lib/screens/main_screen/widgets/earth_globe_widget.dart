import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

class EarthGlobeWidget extends StatefulWidget {
  final AnimationController rotationController;
  final AnimationController capybaraController;
  final bool isRotatingToThailand;
  final double zoomLevel;

  const EarthGlobeWidget({
    super.key,
    required this.rotationController,
    required this.capybaraController,
    required this.isRotatingToThailand,
    this.zoomLevel = 1.0,
  });

  @override
  State<EarthGlobeWidget> createState() => _EarthGlobeWidgetState();
}

class _EarthGlobeWidgetState extends State<EarthGlobeWidget> 
    with TickerProviderStateMixin {
  late Flutter3DController earth3DController;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late Animation<double> _glowAnimation;
  static const double earthRadius = 165.0; // Adjusted for capybara orbit

  @override
  void initState() {
    super.initState();
    earth3DController = Flutter3DController();
    
    // Initialize bounce animation
    _bounceController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
    
    _bounceAnimation = Tween<double>(
      begin: -8.0,
      end: 8.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
    ));
    
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.easeInOut,
    ));
    
    _bounceController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    // Flutter3DController doesn't have a dispose method
    // The platform view should be disposed automatically
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('earth_globe_widget'), // Add unique key
      width: 300,
      height: 300,
      child: Transform.scale(
        scale: widget.zoomLevel,
        child: AnimatedBuilder(
          animation: _bounceController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _bounceAnimation.value), // Subtle bouncing effect
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Blue glow behind Earth
                  RepaintBoundary(
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF00D4FF).withValues(alpha: _glowAnimation.value * 0.4),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                          BoxShadow(
                            color: const Color(0xFF3A67FF).withValues(alpha: _glowAnimation.value * 0.3),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                          BoxShadow(
                            color: const Color(0xFF00D4FF).withValues(alpha: _glowAnimation.value * 0.2),
                            blurRadius: 80,
                            spreadRadius: 30,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Interactive 3D Earth model with touch controls
                  RepaintBoundary(
                    child: Flutter3DViewer(
                      key: const ValueKey('earth_3d_viewer'), // Add key for proper widget lifecycle
                      controller: earth3DController,
                      src: 'assets/images/main_screen/earth_3d.glb',
                      enableTouch: true, // Enable user interaction
                      progressBarColor: Colors.transparent,
                      onError: (error) {
                        debugPrint('❌ Earth model error: $error');
                      },
                      onLoad: (modelAddress) {
                        debugPrint('✅ Interactive Earth model loaded');
                      },
                    ),
                  ),
                  // Capybara orbiting the globe
                  RepaintBoundary(
                    child: AnimatedBuilder(
                      animation: widget.capybaraController,
                      builder: (context, child) {
                        final angle = widget.capybaraController.value * 2 * math.pi;
                        const radius = earthRadius;
                        
                        final x = radius * math.cos(angle);
                        final y = radius * math.sin(angle);

                        return Transform.translate(
                          offset: Offset(x, y),
                          child: Transform.rotate(
                            angle: angle + math.pi / 2,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(math.pi),
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  image: DecorationImage(
                                    image: AssetImage('assets/images/player/capybara.png'),
                                    fit: BoxFit.contain,
                                  ),
                                ),
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
          },
        ),
      ),
    );
  }
}