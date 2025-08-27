import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:babblelon/theme/modern_design_system.dart' as modern;

/// Base class for consistent popup styling and behavior
abstract class BasePopup {
  /// Standard modern popup styling configuration using ModernDesignSystem
  static BoxDecoration get standardDecoration => BoxDecoration(
    gradient: modern.ModernDesignSystem.surfaceGradient,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(
      color: modern.ModernDesignSystem.primaryAccent.withValues(alpha: 0.3),
      width: 2,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 20,
        spreadRadius: 5,
      ),
    ],
  );

  /// Standard primary button style for popups using ModernDesignSystem
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: modern.ModernDesignSystem.primaryAccent,
    foregroundColor: modern.ModernDesignSystem.textOnColor,
    elevation: 8,
    shadowColor: modern.ModernDesignSystem.primaryAccent.withValues(alpha: 0.5),
    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  );

  /// Standard secondary button style for popups using ModernDesignSystem
  static ButtonStyle get secondaryButtonStyle => OutlinedButton.styleFrom(
    foregroundColor: modern.ModernDesignSystem.textPrimary,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    side: const BorderSide(
      color: modern.ModernDesignSystem.borderPrimary,
      width: 2,
    ),
  );

  /// Creates a standard popup dialog container using ModernDesignSystem
  static Widget buildPopupContainer({
    required Widget child,
    EdgeInsets? padding,
    double? maxWidth,
    double? maxHeight,
    double blur = 15.0,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(24),
            constraints: BoxConstraints(
              maxWidth: maxWidth ?? 400,
              maxHeight: maxHeight ?? 600,
            ),
            decoration: standardDecoration,
            child: child,
          ),
        ),
      ),
    );
  }

  /// Shows a popup with consistent ModernDesignSystem styling
  static Future<T?> showPopup<T>(
    BuildContext context, {
    required Widget child,
    bool barrierDismissible = true,
    EdgeInsets? padding,
    double? maxWidth,
    double? maxHeight,
    double blur = 15.0,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => buildPopupContainer(
        padding: padding,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        blur: blur,
        child: child,
      ),
    );
  }
}

/// Animated popup widget with consistent entrance animation
class AnimatedPopup extends StatefulWidget {
  final Widget child;
  final Duration animationDuration;
  final Curve animationCurve;

  const AnimatedPopup({
    super.key,
    required this.child,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOutBack,
  });

  @override
  State<AnimatedPopup> createState() => _AnimatedPopupState();
}

class _AnimatedPopupState extends State<AnimatedPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: widget.animationCurve,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: widget.child,
          ),
        );
      },
    );
  }
}