import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

class DamageIndicator extends StatefulWidget {
  final double damage;
  final bool isHealing;
  final Offset position;
  final VoidCallback? onComplete;

  const DamageIndicator({
    super.key,
    required this.damage,
    required this.position,
    this.isHealing = false,
    this.onComplete,
  });

  @override
  State<DamageIndicator> createState() => _DamageIndicatorState();
}

class _DamageIndicatorState extends State<DamageIndicator>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _scaleController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -2.0),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    ));
    
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));
    
    _startAnimation();
  }
  
  void _startAnimation() async {
    await _scaleController.forward();
    await _controller.forward();
    if (widget.onComplete != null) {
      widget.onComplete!();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final damageText = widget.damage.round().toString();
    final color = widget.isHealing ? Colors.green : Colors.red.shade300;
    
    return Positioned(
      left: widget.position.dx - 30,
      top: widget.position.dy - 20,
      child: AnimatedBuilder(
        animation: Listenable.merge([_controller, _scaleController]),
        builder: (context, child) {
          return SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.5), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isHealing ? Icons.favorite : Icons.flash_on,
                        color: color,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      AnimatedTextKit(
                        animatedTexts: [
                          ScaleAnimatedText(
                            damageText,
                            textStyle: TextStyle(
                              color: color,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.8),
                                  blurRadius: 3,
                                  offset: const Offset(1, 1),
                                ),
                              ],
                            ),
                            duration: const Duration(milliseconds: 800),
                          ),
                        ],
                        totalRepeatCount: 1,
                        pause: const Duration(milliseconds: 200),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

 