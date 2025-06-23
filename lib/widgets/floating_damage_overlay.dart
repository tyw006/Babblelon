import 'package:flutter/material.dart';
import 'damage_indicator.dart';

class FloatingDamageOverlay extends StatefulWidget {
  final Widget child;

  const FloatingDamageOverlay({super.key, required this.child});

  @override
  State<FloatingDamageOverlay> createState() => FloatingDamageOverlayState();
}

class FloatingDamageOverlayState extends State<FloatingDamageOverlay> {
  final List<DamageIndicatorData> _activeIndicators = [];

  void showDamageIndicator({
    required double damage,
    required Offset position,
    bool isHealing = false,
    bool isDefense = false,
    bool isCritical = false,
    bool isGreatDefense = false,
    double attackBonus = 0.0,
    double defenseBonus = 0.0,
  }) {
    if (!mounted) return;

    final indicator = DamageIndicatorData(
      damage: damage,
      position: position,
      isHealing: isHealing,
      isDefense: isDefense,
      isCritical: isCritical,
      isGreatDefense: isGreatDefense,
      attackBonus: attackBonus,
      defenseBonus: defenseBonus,
      key: GlobalKey(),
    );

    setState(() {
      _activeIndicators.add(indicator);
    });

    // Auto-remove after animation completes
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _activeIndicators.removeWhere((item) => item.key == indicator.key);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        ..._activeIndicators.map((indicator) {
          return Positioned(
            left: indicator.position.dx - 80,
            top: indicator.position.dy - 60,
            child: DamageIndicator(
              key: indicator.key,
              damage: indicator.damage,
              position: indicator.position,
              isHealing: indicator.isHealing,
              isDefense: indicator.isDefense,
              isCritical: indicator.isCritical,
              isGreatDefense: indicator.isGreatDefense,
              attackBonus: indicator.attackBonus,
              defenseBonus: indicator.defenseBonus,
              onComplete: () {
                if (mounted) {
                  setState(() {
                    _activeIndicators.removeWhere((item) => item.key == indicator.key);
                  });
                }
              },
            ),
          );
        }).toList(),
      ],
    );
  }
}

class DamageIndicatorData {
  final double damage;
  final Offset position;
  final bool isHealing;
  final bool isDefense;
  final bool isCritical;
  final bool isGreatDefense;
  final double attackBonus;
  final double defenseBonus;
  final GlobalKey key;

  DamageIndicatorData({
    required this.damage,
    required this.position,
    required this.isHealing,
    required this.isDefense,
    required this.isCritical,
    required this.isGreatDefense,
    required this.attackBonus,
    required this.defenseBonus,
    required this.key,
  });
} 