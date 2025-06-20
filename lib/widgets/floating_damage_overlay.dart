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
  }) {
    if (!mounted) return;

    final indicator = DamageIndicatorData(
      damage: damage,
      position: position,
      isHealing: isHealing,
      key: GlobalKey(),
    );

    setState(() {
      _activeIndicators.add(indicator);
    });

    // Auto-remove after animation completes
    Future.delayed(const Duration(seconds: 3), () {
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
            left: indicator.position.dx,
            top: indicator.position.dy,
            child: DamageIndicator(
              key: indicator.key,
              damage: indicator.damage,
              position: indicator.position,
              isHealing: indicator.isHealing,
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
  final GlobalKey key;

  DamageIndicatorData({
    required this.damage,
    required this.position,
    required this.isHealing,
    required this.key,
  });
} 