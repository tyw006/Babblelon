import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:math' as math;

class AnimatedGradientBackground extends StatefulWidget {
  final List<Color> colors;
  final Duration animationDuration;
  
  const AnimatedGradientBackground({
    super.key,
    required this.colors,
    this.animationDuration = const Duration(seconds: 15),
  });

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller1;
  late AnimationController _controller2;
  late Animation<double> _animation1;
  late Animation<double> _animation2;

  @override
  void initState() {
    super.initState();
    
    // First gradient animation
    _controller1 = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );
    
    _animation1 = Tween<double>(
      begin: 0.0,
      end: 2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller1,
      curve: Curves.linear,
    ));
    
    // Second gradient animation (opposite direction)
    _controller2 = AnimationController(
      duration: Duration(seconds: widget.animationDuration.inSeconds + 5),
      vsync: this,
    );
    
    _animation2 = Tween<double>(
      begin: 0.0,
      end: -2 * math.pi,
    ).animate(CurvedAnimation(
      parent: _controller2,
      curve: Curves.linear,
    ));
    
    _controller1.repeat();
    _controller2.repeat();
  }

  @override
  void dispose() {
    _controller1.dispose();
    _controller2.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_animation1, _animation2]),
      builder: (context, child) {
        return Stack(
          children: [
            // Base gradient layer
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.colors,
                  stops: _generateStops(widget.colors.length),
                ),
              ),
            ),
            
            // First animated gradient layer
            Opacity(
              opacity: 0.6,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      math.cos(_animation1.value) * 0.5,
                      math.sin(_animation1.value) * 0.5,
                    ),
                    radius: 1.5,
                    colors: [
                      widget.colors[0].withAlpha(100),
                      widget.colors[widget.colors.length ~/ 2].withAlpha(50),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            // Second animated gradient layer
            Opacity(
              opacity: 0.4,
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(
                      math.cos(_animation2.value) * 0.7,
                      math.sin(_animation2.value) * 0.7,
                    ),
                    radius: 1.2,
                    colors: [
                      widget.colors[widget.colors.length - 1].withAlpha(150),
                      widget.colors[1].withAlpha(80),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            
            // Soft blur overlay
            BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 30,
                sigmaY: 30,
              ),
              child: Container(
                color: Colors.black.withAlpha(10),
              ),
            ),
          ],
        );
      },
    );
  }
  
  List<double> _generateStops(int colorCount) {
    if (colorCount <= 1) return [1.0];
    
    final List<double> stops = [];
    for (int i = 0; i < colorCount; i++) {
      stops.add(i / (colorCount - 1));
    }
    return stops;
  }
}