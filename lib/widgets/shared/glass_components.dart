import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:babblelon/widgets/modern_design_system.dart';

/// A reusable glass container with backdrop blur and transparency effects
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double sigmaX;
  final double sigmaY;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 16.0,
    this.sigmaX = 10.0,
    this.sigmaY = 10.0,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 1.0,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigmaX, sigmaY: sigmaY),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: backgroundColor ?? ModernDesignSystem.surfaceCard.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: borderColor ?? Colors.white.withValues(alpha: 0.2),
                width: borderWidth,
              ),
              boxShadow: boxShadow ?? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A glass button with interactive effects and liquid glass styling
class GlassButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? pressedColor;
  final IconData? icon;
  final bool isLoading;
  final bool isEnabled;

  const GlassButton({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height,
    this.padding,
    this.borderRadius = 16.0,
    this.backgroundColor,
    this.textColor,
    this.pressedColor,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
  });

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.7,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: GestureDetector(
              onTapDown: widget.isEnabled ? (_) => _animationController.forward() : null,
              onTapUp: widget.isEnabled ? (_) => _animationController.reverse() : null,
              onTapCancel: widget.isEnabled ? () => _animationController.reverse() : null,
              onTap: widget.isEnabled && !widget.isLoading ? widget.onPressed : null,
              child: GlassContainer(
                width: widget.width,
                height: widget.height ?? 56,
                padding: widget.padding ?? const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                borderRadius: widget.borderRadius,
                backgroundColor: widget.backgroundColor ?? ModernDesignSystem.primaryIndigo.withValues(alpha: 0.8),
                borderColor: ModernDesignSystem.primaryIndigo.withValues(alpha: 0.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null && !widget.isLoading) ...[
                      Icon(
                        widget.icon,
                        color: widget.textColor ?? Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (widget.isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    else
                      Text(
                        widget.text,
                        style: ModernDesignSystem.bodyLarge.copyWith(
                          color: widget.textColor ?? Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A glass card with elevated styling and interactive effects
class GlassCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? selectedColor;

  const GlassCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = 20.0,
    this.onTap,
    this.isSelected = false,
    this.selectedColor,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _elevationAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _elevationAnimation = Tween<double>(
      begin: 8.0,
      end: 16.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            onTapDown: widget.onTap != null ? (_) => _animationController.forward() : null,
            onTapUp: widget.onTap != null ? (_) => _animationController.reverse() : null,
            onTapCancel: widget.onTap != null ? () => _animationController.reverse() : null,
            child: GlassContainer(
              width: widget.width,
              height: widget.height,
              padding: widget.padding ?? const EdgeInsets.all(16),
              margin: widget.margin,
              borderRadius: widget.borderRadius,
              backgroundColor: widget.isSelected 
                  ? (widget.selectedColor ?? ModernDesignSystem.primaryIndigo.withValues(alpha: 0.3))
                  : ModernDesignSystem.surfaceCard.withValues(alpha: 0.1),
              borderColor: widget.isSelected 
                  ? ModernDesignSystem.primaryIndigo.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.2),
              boxShadow: [
                BoxShadow(
                  color: widget.isSelected 
                      ? ModernDesignSystem.primaryIndigo.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.3),
                  blurRadius: _elevationAnimation.value,
                  offset: Offset(0, _elevationAnimation.value / 2),
                ),
              ],
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}

/// A glass progress indicator with liquid animation
class GlassProgress extends StatefulWidget {
  final double value;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final bool isIndeterminate;

  const GlassProgress({
    super.key,
    required this.value,
    this.width,
    this.height,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = 8.0,
    this.isIndeterminate = false,
  });

  @override
  State<GlassProgress> createState() => _GlassProgressState();
}

class _GlassProgressState extends State<GlassProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    if (widget.isIndeterminate) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GlassContainer(
          width: widget.width ?? double.infinity,
          height: widget.height ?? 8,
          borderRadius: widget.borderRadius,
          backgroundColor: widget.backgroundColor ?? ModernDesignSystem.surfaceCard.withValues(alpha: 0.2),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: LinearProgressIndicator(
              value: widget.isIndeterminate ? null : widget.value,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                (widget.foregroundColor ?? ModernDesignSystem.primaryIndigo).withValues(
                  alpha: _glowAnimation.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A circular glass progress indicator
class GlassCircularProgress extends StatefulWidget {
  final double value;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double strokeWidth;
  final bool isIndeterminate;

  const GlassCircularProgress({
    super.key,
    required this.value,
    this.size = 60,
    this.backgroundColor,
    this.foregroundColor,
    this.strokeWidth = 4.0,
    this.isIndeterminate = false,
  });

  @override
  State<GlassCircularProgress> createState() => _GlassCircularProgressState();
}

class _GlassCircularProgressState extends State<GlassCircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return GlassContainer(
          width: widget.size,
          height: widget.size,
          padding: const EdgeInsets.all(12),
          borderRadius: widget.size / 2,
          backgroundColor: widget.backgroundColor ?? ModernDesignSystem.surfaceCard.withValues(alpha: 0.2),
          child: CircularProgressIndicator(
            value: widget.isIndeterminate ? null : widget.value,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              (widget.foregroundColor ?? ModernDesignSystem.primaryIndigo).withValues(
                alpha: _glowAnimation.value,
              ),
            ),
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}