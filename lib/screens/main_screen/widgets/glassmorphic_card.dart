import 'package:flutter/material.dart';
import 'package:babblelon/theme/unified_dark_theme.dart';

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  
  const GlassmorphicCard({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.opacity = 0.1,
    this.borderRadius = 24.0,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UnifiedDarkTheme.primarySurface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: UnifiedDarkTheme.borderPrimary,
          width: 1.5,
        ),
        boxShadow: UnifiedDarkTheme.shadowLG,
      ),
      child: child,
    );
  }
}