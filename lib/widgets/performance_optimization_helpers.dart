import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// GPU Performance optimization helpers for BabbleOn game
/// These utilities help improve rendering performance through better GPU utilization

/// Wraps expensive widgets with RepaintBoundary to prevent unnecessary repaints
class OptimizedRepaintBoundary extends StatelessWidget {
  final Widget child;
  final String? debugLabel;

  const OptimizedRepaintBoundary({
    super.key,
    required this.child,
    this.debugLabel,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: child,
    );
  }
}

/// GPU-optimized animated container that uses Transform instead of rebuilding layout
class GPUOptimizedAnimatedContainer extends StatelessWidget {
  final Widget child;
  final Animation<double> animation;
  final Offset? translation;
  final double? scale;
  final double? rotation;
  final bool enable3D;

  const GPUOptimizedAnimatedContainer({
    super.key,
    required this.child,
    required this.animation,
    this.translation,
    this.scale,
    this.rotation,
    this.enable3D = false,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedRepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          Matrix4 transform = Matrix4.identity();
          
          // Add 3D perspective for better GPU acceleration
          if (enable3D) {
            transform.setEntry(3, 2, 0.001);
          }
          
          // Apply transforms in optimal order for GPU
          if (translation != null) {
            transform.translate(
              translation!.dx * animation.value,
              translation!.dy * animation.value,
            );
          }
          
          if (scale != null) {
            final scaleValue = 1.0 + (scale! - 1.0) * animation.value;
            transform.scale(scaleValue);
          }
          
          if (rotation != null) {
            transform.rotateZ(rotation! * animation.value);
          }
          
          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: child,
      ),
    );
  }
}

/// Optimized particle system that uses custom painter for better GPU performance
class GPUOptimizedParticleSystem extends StatefulWidget {
  final int particleCount;
  final Size area;
  final Color baseColor;
  final double speed;
  final bool enableBlending;

  const GPUOptimizedParticleSystem({
    super.key,
    this.particleCount = 50,
    required this.area,
    this.baseColor = Colors.white,
    this.speed = 1.0,
    this.enableBlending = true,
  });

  @override
  State<GPUOptimizedParticleSystem> createState() => _GPUOptimizedParticleSystemState();
}

class _GPUOptimizedParticleSystemState extends State<GPUOptimizedParticleSystem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<Particle> _particles;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
    
    _particles = List.generate(
      widget.particleCount,
      (index) => Particle.random(widget.area),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OptimizedRepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: widget.area,
            painter: ParticleSystemPainter(
              particles: _particles,
              animation: _controller,
              baseColor: widget.baseColor,
              speed: widget.speed,
              enableBlending: widget.enableBlending,
            ),
          );
        },
      ),
    );
  }
}

class Particle {
  late Offset position;
  late Offset velocity;
  late double size;
  late double opacity;
  late double life;

  Particle.random(Size area) {
    position = Offset(
      area.width * (0.5 + (0.5 - 1.0) * 0.5),
      area.height * (0.5 + (0.5 - 1.0) * 0.5),
    );
    velocity = Offset(
      (0.5 - 1.0) * 2.0,
      (0.5 - 1.0) * 2.0,
    );
    size = 1.0 + 3.0 * 0.5;
    opacity = 0.3 + 0.7 * 0.5;
    life = 0.5;
  }

  void update(double deltaTime, Size area, double speed) {
    position += velocity * deltaTime * speed;
    life += deltaTime * 0.1;
    
    // Wrap around screen
    if (position.dx < 0) position = Offset(area.width, position.dy);
    if (position.dx > area.width) position = Offset(0, position.dy);
    if (position.dy < 0) position = Offset(position.dx, area.height);
    if (position.dy > area.height) position = Offset(position.dx, 0);
    
    // Cycle life
    if (life > 1.0) life = 0.0;
  }
}

class ParticleSystemPainter extends CustomPainter {
  final List<Particle> particles;
  final Animation<double> animation;
  final Color baseColor;
  final double speed;
  final bool enableBlending;

  ParticleSystemPainter({
    required this.particles,
    required this.animation,
    required this.baseColor,
    required this.speed,
    required this.enableBlending,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Use GPU-friendly painting operations
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = false; // Disable for better GPU performance
    
    // Enable GPU blending if requested
    if (enableBlending) {
      paint.blendMode = BlendMode.screen;
    }

    for (final particle in particles) {
      particle.update(0.016, size, speed); // 60 FPS delta
      
      final alpha = (particle.opacity * (1.0 - particle.life)).clamp(0.0, 1.0);
      paint.color = baseColor.withValues(alpha: alpha);
      
      // Use simple shapes for better GPU performance
      canvas.drawCircle(
        particle.position,
        particle.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(ParticleSystemPainter oldDelegate) {
    return animation.value != oldDelegate.animation.value;
  }
}

/// Optimized shader-based gradient background
class GPUOptimizedGradientBackground extends StatelessWidget {
  final List<Color> colors;
  final List<double>? stops;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final bool useShader;

  const GPUOptimizedGradientBackground({
    super.key,
    required this.colors,
    this.stops,
    this.begin = Alignment.topCenter,
    this.end = Alignment.bottomCenter,
    this.useShader = true,
  });

  @override
  Widget build(BuildContext context) {
    return OptimizedRepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: begin,
            end: end,
            colors: colors,
            stops: stops,
          ),
        ),
      ),
    );
  }
}

/// Performance monitoring widget for development
class PerformanceMonitor extends StatefulWidget {
  final Widget child;
  final bool showFPS;
  final bool showMemory;

  const PerformanceMonitor({
    super.key,
    required this.child,
    this.showFPS = false,
    this.showMemory = false,
  });

  @override
  State<PerformanceMonitor> createState() => _PerformanceMonitorState();
}

class _PerformanceMonitorState extends State<PerformanceMonitor> {
  double _fps = 0.0;
  int _frameCount = 0;
  DateTime _lastTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.showFPS) {
      _startFPSMonitoring();
    }
  }

  void _startFPSMonitoring() {
    WidgetsBinding.instance.addPostFrameCallback(_onFrame);
  }

  void _onFrame(Duration timestamp) {
    _frameCount++;
    final now = DateTime.now();
    final elapsed = now.difference(_lastTime);
    
    if (elapsed.inMilliseconds >= 1000) {
      setState(() {
        _fps = _frameCount * 1000 / elapsed.inMilliseconds;
        _frameCount = 0;
        _lastTime = now;
      });
    }
    
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback(_onFrame);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (widget.showFPS)
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'FPS: ${_fps.toStringAsFixed(1)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Helper to batch widget rebuilds for better performance
class BatchedRebuildWrapper extends StatefulWidget {
  final Widget child;
  final Duration batchDuration;

  const BatchedRebuildWrapper({
    super.key,
    required this.child,
    this.batchDuration = const Duration(milliseconds: 16), // 60 FPS
  });

  @override
  State<BatchedRebuildWrapper> createState() => _BatchedRebuildWrapperState();
}

class _BatchedRebuildWrapperState extends State<BatchedRebuildWrapper> {
  bool _needsRebuild = false;

  void requestRebuild() {
    if (!_needsRebuild) {
      _needsRebuild = true;
      Future.delayed(widget.batchDuration, () {
        if (mounted && _needsRebuild) {
          setState(() {
            _needsRebuild = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}