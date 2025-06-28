import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:math' as math;

class DamageIndicator extends StatefulWidget {
  final double damage;
  final bool isHealing;
  final bool isDefense;
  final Offset position;
  final VoidCallback? onComplete;
  final bool isCritical;
  final bool isGreatDefense;
  final double attackBonus;
  final double defenseBonus;

  const DamageIndicator({
    super.key,
    required this.damage,
    required this.position,
    this.isHealing = false,
    this.isDefense = false,
    this.onComplete,
    this.isCritical = false,
    this.isGreatDefense = false,
    this.attackBonus = 0.0,
    this.defenseBonus = 0.0,
  });

  @override
  State<DamageIndicator> createState() => _DamageIndicatorState();
}

class _DamageIndicatorState extends State<DamageIndicator>
    with TickerProviderStateMixin {
  late AnimationController _lottieController;
  late AnimationController _textController;
  late AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    
    _lottieController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _textController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Start animations
    _textController.forward();
    _scaleController.forward();
    
    // Start shiny effect for critical hits and great defense
    if (widget.isCritical || widget.isGreatDefense) {
      _lottieController.repeat();
    }

    // Auto-complete after animation
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (mounted && widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  @override
  void dispose() {
    _lottieController.dispose();
    _textController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Color _getDamageColor(double damage) {
    if (widget.isHealing) return Colors.green.shade200;
    if (widget.isDefense) return Colors.cyan.shade200;
    
    // More vibrant colors for damage
    if (damage >= 50) return Colors.red.shade200;
    if (damage >= 30) return Colors.orange.shade200;
    if (damage >= 15) return Colors.yellow.shade200;
    return Colors.white;
  }

  double _getFontSize(double damage) {
    // Base font size that's consistent for all damage
    final baseSize = 36.0;
    
    // Scale factor based on damage amount
    final damageScaleFactor = math.min(1.0 + (damage / 80), 2.2);
    
    // Critical hit or great defense gets an additional size boost
    final specialBoost = (widget.isCritical || widget.isGreatDefense) ? 1.3 : 1.0;
    
    return baseSize * damageScaleFactor * specialBoost;
  }

  @override
  Widget build(BuildContext context) {
    final damageText = widget.damage.round().toString();
    final damageColor = _getDamageColor(widget.damage);
    final fontSize = _getFontSize(widget.damage);

    return SizedBox(
      width: 300,
      height: 400,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background shiny effect animation for critical hits and great defense
          if (widget.isCritical || widget.isGreatDefense)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _lottieController,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          (widget.isCritical ? Colors.orange : Colors.cyan).withOpacity(0.3),
                          (widget.isCritical ? Colors.red : Colors.blue).withOpacity(0.1),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ).animate().fadeOut(delay: 2000.ms, duration: 1000.ms),

          // Main damage number with enhanced styling
          _buildMainDamageText(damageText, damageColor, fontSize),
          
          // Critical hit text - positioned independently
          if (widget.isCritical)
            Positioned(
              top: 140, 
              child: _buildCriticalHitText(),
            ),
          
          // Great defense text - positioned independently
          if (widget.isGreatDefense)
            Positioned(
              top: 200,
              right: 0,
              child: _buildGreatDefenseText(),
            ),

          // Additional sparkle effects for critical hits
          if (widget.isCritical)
            _buildSparkleParticles(),
        ],
      ),
    );
  }

  Widget _buildMainDamageText(String damageText, Color damageColor, double fontSize) {
    return AnimatedBuilder(
      animation: _scaleController,
      builder: (context, child) {
        final scaleValue = Curves.elasticOut.transform(_scaleController.value);
        return Transform.scale(
          scale: 0.3 + (scaleValue * 0.7),
          child: Text(
            damageText,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              color: damageColor,
              fontFamily: 'Roboto',
              letterSpacing: 2.0,
              decoration: TextDecoration.none,
              shadows: [
                // Strong black outline for readability
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: const Offset(-2, -2),
                ),
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: const Offset(2, -2),
                ),
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: const Offset(-2, 2),
                ),
                Shadow(
                  color: Colors.black,
                  blurRadius: 4,
                  offset: const Offset(2, 2),
                ),
                // Glowing effect
                Shadow(
                  color: damageColor.withOpacity(0.8),
                  blurRadius: 12,
                  offset: Offset.zero,
                ),
                Shadow(
                  color: damageColor.withOpacity(0.6),
                  blurRadius: 20,
                  offset: Offset.zero,
                ),
                // White inner glow for critical hits and great defense
                if (widget.isCritical || widget.isGreatDefense)
                  Shadow(
                    color: Colors.white.withOpacity(0.9),
                    blurRadius: 8,
                    offset: Offset.zero,
                  ),
              ],
            ),
          )
            .animate()
            .slideY(
              duration: 2500.ms,
              curve: Curves.easeOutCubic,
              begin: 0,
              end: -4.0,
            )
            .fadeOut(
              delay: 1500.ms,
              duration: 1500.ms,
              curve: Curves.easeOut,
            ),
        );
      },
    );
  }

  Widget _buildCriticalHitText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: [
            Colors.red.withOpacity(0.8),
            Colors.orange.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        "CRITICAL HIT!",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.0,
          decoration: TextDecoration.none,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
            Shadow(
              color: Colors.yellow.withOpacity(0.8),
              blurRadius: 6,
              offset: Offset.zero,
            ),
          ],
        ),
      ),
    )
      .animate()
      .scale(
        duration: 600.ms,
        curve: Curves.elasticOut,
        begin: const Offset(0.3, 0.3),
        end: const Offset(1.0, 1.0),
      )
      .shimmer(
        duration: 1200.ms,
        color: Colors.white.withOpacity(0.7),
      )
      .fadeOut(
        delay: 2200.ms,
        duration: 800.ms,
      );
  }

  Widget _buildGreatDefenseText() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: LinearGradient(
          colors: [
            Colors.blue.withOpacity(0.8),
            Colors.cyan.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.6),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Text(
        "GREAT DEFENSE!",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 1.0,
          decoration: TextDecoration.none,
          shadows: [
            Shadow(
              color: Colors.black.withOpacity(0.8),
              blurRadius: 3,
              offset: const Offset(1, 1),
            ),
            Shadow(
              color: Colors.lightBlue.withOpacity(0.8),
              blurRadius: 6,
              offset: Offset.zero,
            ),
          ],
        ),
      ),
    )
      .animate()
      .scale(
        duration: 600.ms,
        curve: Curves.elasticOut,
        begin: const Offset(0.3, 0.3),
        end: const Offset(1.0, 1.0),
      )
      .shimmer(
        duration: 1200.ms,
        color: Colors.white.withOpacity(0.7),
      )
      .fadeOut(
        delay: 2200.ms,
        duration: 800.ms,
      );
  }

  Widget _buildSparkleParticles() {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: List.generate(12, (index) {
          final angle = (index * 30.0) * (math.pi / 180);
          final distance = 35.0 + (index % 3) * 8.0;
          final offsetX = math.cos(angle) * distance;
          final offsetY = math.sin(angle) * distance;
          
          return Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: index % 2 == 0 ? Colors.yellow.shade300 : Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (index % 2 == 0 ? Colors.yellow : Colors.white).withOpacity(0.8),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            )
              .animate()
              .scale(
                delay: Duration(milliseconds: index * 80),
                duration: 400.ms,
                curve: Curves.easeOut,
              )
              .fade(
                delay: Duration(milliseconds: index * 80 + 300),
                duration: 1200.ms,
                curve: Curves.easeOut,
              ),
          );
        }),
      ),
    );
  }
}

 