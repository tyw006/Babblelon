import 'package:flutter/material.dart';

/// Base class for consistent popup styling and behavior
abstract class BasePopup {
  /// Standard popup styling configuration
  static BoxDecoration get standardDecoration => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.3),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ],
  );

  /// Standard button style for popups
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
    backgroundColor: Colors.orange,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  /// Standard secondary button style for popups
  static ButtonStyle get secondaryButtonStyle => TextButton.styleFrom(
    foregroundColor: Colors.grey[600],
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  );

  /// Creates a standard popup dialog container
  static Widget buildPopupContainer({
    required Widget child,
    EdgeInsets? padding,
    double? maxWidth,
    double? maxHeight,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: padding ?? const EdgeInsets.all(24),
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? 400,
          maxHeight: maxHeight ?? 600,
        ),
        decoration: standardDecoration,
        child: child,
      ),
    );
  }

  /// Shows a popup with consistent styling
  static Future<T?> showPopup<T>(
    BuildContext context, {
    required Widget child,
    bool barrierDismissible = true,
    EdgeInsets? padding,
    double? maxWidth,
    double? maxHeight,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (context) => buildPopupContainer(
        padding: padding,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
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