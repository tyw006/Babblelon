import 'package:flutter/material.dart';
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
              // Pulse effect for available locations - optimized for Impeller
              if (widget.location.isAvailable)
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final pulseOpacity = 0.4 * (1 - _pulseController.value);
                    final pulseSize = 30 + (_pulseController.value * 25);
                    return AnimatedOpacity(
                      opacity: pulseOpacity,
                      duration: const Duration(milliseconds: 50),
                      child: Container(
                        width: pulseSize,
                        height: pulseSize,
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              
              // Main marker
              AnimatedBuilder(
                animation: _bounceController,
                builder: (context, child) {
                  // Enhanced bounce effect - even larger bounce for Bangkok
                  final bounceMultiplier = widget.location.id == 'cultural_district' ? 0.8 : 0.3; // Much bigger bounce for main adventure
                  final scale = 1.0 + (_bounceController.value * bounceMultiplier);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 45, // Consistent size for all markers
                      height: 45, // Consistent size for all markers
                      decoration: BoxDecoration(
                        color: widget.location.isAvailable 
                            ? Colors.orange 
                            : Colors.grey,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 3, // Consistent border for all markers
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8, // Consistent shadow blur
                            offset: const Offset(0, 3), // Consistent shadow offset
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.location.isAvailable 
                            ? Icons.location_city 
                            : Icons.lock,
                        color: Colors.white,
                        size: 24, // Consistent icon size for all markers
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
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}