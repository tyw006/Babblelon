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

class _DamageIndicatorState extends State<DamageIndicator> {
  @override
  void initState() {
    super.initState();
    // Auto-complete after animation
    Future.delayed(const Duration(milliseconds: 4000), () {
      if (mounted && widget.onComplete != null) {
        widget.onComplete!();
      }
    });
  }

  Color _getDamageColor(double damage) {
    if (widget.isHealing) return Colors.green.shade300;
    if (widget.isDefense) return Colors.blue.shade300;
    
    // Scale colors based on damage magnitude for more vibrant display
    if (damage >= 50) return Colors.red.shade300;
    if (damage >= 30) return Colors.orange.shade300;
    if (damage >= 15) return Colors.yellow.shade300;
    return Colors.white;
  }

  double _getFontSize(double damage) {
    // Scale font size based on damage for more impact
    final baseSize = widget.isCritical ? 36.0 : 28.0;
    final scaleFactor = math.min(1.0 + (damage / 100), 2.0);
    return baseSize * scaleFactor;
  }

  @override
  Widget build(BuildContext context) {
    final damageText = widget.damage.round().toString();
    final damageColor = _getDamageColor(widget.damage);
    final fontSize = _getFontSize(widget.damage);

    final textWidget = Text(
      damageText,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: damageColor,
        fontFamily: 'monospace',
        shadows: [
          // Multiple shadows for vibrant glow effect
          Shadow(
            color: Colors.black.withOpacity(0.9),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
          Shadow(
            color: damageColor.withOpacity(0.8),
            blurRadius: 12,
            offset: Offset.zero,
          ),
          if (widget.isCritical)
            Shadow(
              color: Colors.white.withOpacity(0.6),
              blurRadius: 16,
              offset: Offset.zero,
            ),
        ],
      ),
    );

    Animate animation = textWidget
        .animate()
        .scale(
          duration: widget.isCritical ? 600.ms : 400.ms,
          curve: Curves.elasticOut,
          begin: const Offset(0.3, 0.3),
          end: const Offset(1.0, 1.0),
        )
        .fadeIn(duration: 200.ms)
        .slideY(
          duration: 3000.ms,
          curve: Curves.easeOutCubic,
          begin: 0,
          end: -3.0,
        )
        .fadeOut(
          delay: 1500.ms,
          duration: 1500.ms,
          curve: Curves.easeOut,
        );

    if (widget.isCritical) {
      animation = animation
          .then()
          .shake(duration: 300.ms, hz: 8)
          .shimmer(duration: 1000.ms, color: Colors.white.withOpacity(0.4));
    }

    // Use Column layout instead of Positioned widgets to avoid conflicts
    return SizedBox(
      width: 160,
      height: 120,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Bonus indicators at top
          if (widget.attackBonus > 0 || widget.defenseBonus > 0)
            _buildBonusValueText(),
          if (widget.attackBonus > 0 || widget.defenseBonus > 0)
            const SizedBox(height: 8),
          
          // Critical hit indicator
          if (widget.isCritical)
            _buildCriticalHitText(),
          if (widget.isCritical)
            const SizedBox(height: 4),
            
          // Great defense indicator
          if (widget.isGreatDefense)
            _buildGreatDefenseText(),
          if (widget.isGreatDefense)
            const SizedBox(height: 4),
          
          // Main damage text with particles as background
          Stack(
            alignment: Alignment.center,
            children: [
              // Particle effect at bottom layer
              if (widget.isCritical) 
                _buildParticleEffect(),
              // Main damage text on top
              animation,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticleEffect() {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        children: List.generate(8, (index) {
          final angle = (index * 45.0) * (math.pi / 180);
          final distance = 15.0;
          final offsetX = math.cos(angle) * distance;
          final offsetY = math.sin(angle) * distance;
          
          return Transform.translate(
            offset: Offset(offsetX, offsetY),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: _getDamageColor(widget.damage),
                shape: BoxShape.circle,
              ),
            )
              .animate()
              .scale(delay: Duration(milliseconds: index * 50), duration: 300.ms)
              .fade(delay: Duration(milliseconds: index * 50 + 200), duration: 800.ms),
          );
        }),
      ),
    );
  }

  Widget _buildCriticalHitText() {
    return Text(
      "CRITICAL HIT!",
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.yellow.shade300,
        shadows: [
          Shadow(
            color: Colors.red.withOpacity(0.8),
            blurRadius: 8,
            offset: const Offset(0, 0),
          ),
        ],
      ),
    )
      .animate()
      .scale(duration: 400.ms, curve: Curves.elasticOut)
      .shimmer(duration: 800.ms, color: Colors.white.withOpacity(0.5))
      .fadeOut(delay: 2000.ms, duration: 1000.ms);
  }

  Widget _buildGreatDefenseText() {
    return Text(
      "GREAT DEFENSE!",
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.cyan.shade300,
        shadows: [
          Shadow(
            color: Colors.blue.withOpacity(0.8),
            blurRadius: 8,
            offset: const Offset(0, 0),
          ),
        ],
      ),
    )
      .animate()
      .scale(duration: 400.ms, curve: Curves.elasticOut)
      .shimmer(duration: 800.ms, color: Colors.white.withOpacity(0.5))
      .fadeOut(delay: 2000.ms, duration: 1000.ms);
  }

  Widget _buildBonusValueText() {
    final hasAttackBonus = widget.attackBonus > 0;
    final hasDefenseBonus = widget.defenseBonus > 0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasAttackBonus)
          Text(
            "+${widget.attackBonus.toInt()} ATK",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade300,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
          )
            .animate()
            .scale(delay: 500.ms, duration: 1200.ms, curve: Curves.easeOutCubic)
            .fadeIn(delay: 500.ms, duration: 800.ms)
            .slideY(begin: 0.5, end: 0, delay: 500.ms, duration: 1200.ms)
            .fadeOut(delay: 2500.ms, duration: 1000.ms),
        if (hasAttackBonus && hasDefenseBonus) const SizedBox(width: 8),
        if (hasDefenseBonus)
          Text(
            "+${widget.defenseBonus.toInt()} DEF",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade300,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.8),
                  blurRadius: 4,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
          )
            .animate()
            .scale(delay: 700.ms, duration: 1200.ms, curve: Curves.easeOutCubic)
            .fadeIn(delay: 700.ms, duration: 800.ms)
            .slideY(begin: 0.5, end: 0, delay: 700.ms, duration: 1200.ms)
            .fadeOut(delay: 2500.ms, duration: 1000.ms),
      ],
    );
  }
}

 