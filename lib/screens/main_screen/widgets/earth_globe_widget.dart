import 'package:flutter/material.dart';
import 'dart:math' as math;
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
  late AnimationController _earthSpinController;
  static const double earthRadius = 145.0;

  @override
  void initState() {
    super.initState();
    earth3DController = Flutter3DController();
    
    // Create realistic Earth rotation (slower for performance)
    _earthSpinController = AnimationController(
      duration: const Duration(seconds: 120), // Slower rotation for better performance
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _earthSpinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 300,
      child: Transform.scale(
        scale: widget.zoomLevel,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 3D Earth model with rotation (optimized)
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _earthSpinController,
                builder: (context, child) {
                  return Transform.rotate(
                    angle: _earthSpinController.value * 2 * math.pi,
                    child: child!,
                  );
                },
                child: RepaintBoundary(
                  child: Flutter3DViewer(
                    controller: earth3DController,
                    src: 'assets/images/main_screen/earth_3d.glb',
                    enableTouch: false,
                    progressBarColor: Colors.transparent,
                    onError: (error) {
                      debugPrint('Flutter3DViewer error: $error');
                    },
                    onLoad: (modelAddress) {
                      debugPrint('Earth model loaded successfully');
                    },
                  ),
                ),
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
      ),
    );
  }
}