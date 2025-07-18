import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:babblelon/screens/main_screen/thailand_map_screen.dart';

class LocationMarkerWidget extends StatefulWidget {
  final LocationData location;
  final VoidCallback onTap;

  const LocationMarkerWidget({
    super.key,
    required this.location,
    required this.onTap,
  });

  @override
  State<LocationMarkerWidget> createState() => _LocationMarkerWidgetState();
}

class _LocationMarkerWidgetState extends State<LocationMarkerWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000), // Slower pulse for more dramatic effect
      vsync: this,
    );
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 300), // Longer bounce for more bounce effect
      vsync: this,
    );
    
    // Start pulsing animation for available locations
    if (widget.location.isAvailable) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _bounceController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _bounceController.reverse().then((_) {
      widget.onTap();
    });
  }

  void _onTapCancel() {
    _bounceController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: SizedBox(
          width: 60, // Increased from 40 to make pins larger
          height: 60, // Increased from 40 to make pins larger
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Pulse effect for available locations
              if (widget.location.isAvailable)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 30 + (_pulseController.value * 25), // Larger pulse effect
                      height: 30 + (_pulseController.value * 25), // Larger pulse effect
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(
                          alpha: 0.4 * (1 - _pulseController.value), // Stronger pulse opacity
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
              
              // Main marker
              AnimatedBuilder(
                animation: _bounceController,
                builder: (context, child) {
                  // Enhanced bounce effect with elastic curve
                  final scale = 1.0 + (_bounceController.value * 0.3); // More pronounced bounce
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 45, // Increased from 30 to make pins larger
                      height: 45, // Increased from 30 to make pins larger
                      decoration: BoxDecoration(
                        color: widget.location.isAvailable 
                            ? Colors.orange 
                            : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3, // Thicker border for larger pins
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4), // Stronger shadow
                            blurRadius: 8, // Larger shadow blur
                            offset: const Offset(0, 3), // Larger shadow offset
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.location.isAvailable 
                            ? Icons.location_city 
                            : Icons.lock,
                        color: Colors.white,
                        size: 24, // Increased icon size from 16 to 24
                      ),
                    ),
                  );
                },
              ),
              
              // Location name tooltip on hover
              if (_isHovered)
                Positioned(
                  bottom: 45,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.location.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.location.description.isNotEmpty)
                          Text(
                            widget.location.description,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ).animate()
                    .fadeIn(duration: 200.ms)
                    .slideY(begin: 10, duration: 200.ms),
                ),
            ],
          ),
        ),
      ),
    );
  }
}