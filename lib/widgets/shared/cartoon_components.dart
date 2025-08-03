import 'package:flutter/material.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';

/// A reusable cartoon container with bouncy animations and warm colors
class CartoonContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final List<BoxShadow>? boxShadow;
  final bool enable3DEffect;

  const CartoonContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = CartoonDesignSystem.radiusMedium,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 2.0,
    this.boxShadow,
    this.enable3DEffect = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? CartoonDesignSystem.softPeach,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.3),
          width: borderWidth,
        ),
        boxShadow: boxShadow ?? [
          // Main shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          // 3D cartoon effect
          if (enable3DEffect)
            BoxShadow(
              color: CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.2),
              blurRadius: 0,
              offset: const Offset(2, 2),
            ),
        ],
      ),
      child: child,
    );
  }
}

/// A cartoon button with bouncy animations and playful styling  
class CartoonInteractiveButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;
  final bool isLoading;
  final bool isEnabled;
  final CartoonButtonStyle style;

  const CartoonInteractiveButton({
    super.key,
    required this.text,
    this.onPressed,
    this.width,
    this.height,
    this.padding,
    this.borderRadius = CartoonDesignSystem.radiusSmall,
    this.backgroundColor,
    this.textColor,
    this.icon,
    this.isLoading = false,
    this.isEnabled = true,
    this.style = CartoonButtonStyle.primary,
  });

  @override
  State<CartoonInteractiveButton> createState() => _CartoonInteractiveButtonState();
}

class _CartoonInteractiveButtonState extends State<CartoonInteractiveButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: CartoonDesignSystem.quickTransition,
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: CartoonDesignSystem.cardPressScale,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onTapDown() {
    if (widget.isEnabled && !widget.isLoading) {
      _animationController.forward();
      CartoonDesignSystem.triggerSelectionFeedback();
    }
  }

  void _onTapUp() {
    _animationController.reverse();
    if (widget.isEnabled && !widget.isLoading) {
      widget.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final bounceScale = 1.0 + (_bounceAnimation.value * 0.05);
        final finalScale = _scaleAnimation.value * bounceScale;
        
        return Transform.scale(
          scale: finalScale,
          child: GestureDetector(
            onTapDown: widget.isEnabled ? (_) => _onTapDown() : null,
            onTapUp: widget.isEnabled ? (_) => _onTapUp() : null,
            onTapCancel: widget.isEnabled ? () => _animationController.reverse() : null,
            child: CartoonButton(
              text: widget.text,
              onPressed: null, // Handle via gesture detector for custom animation
              isLoading: widget.isLoading,
              style: widget.style,
              icon: widget.icon,
              width: widget.width,
            ),
          ),
        );
      },
    );
  }
}

/// A cartoon card with elevated styling and bouncy interactions
class CartoonInteractiveCard extends StatefulWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool isSelected;
  final Color? selectedColor;
  final Color? backgroundColor;

  const CartoonInteractiveCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = CartoonDesignSystem.radiusMedium,
    this.onTap,
    this.isSelected = false,
    this.selectedColor,
    this.backgroundColor,
  });

  @override
  State<CartoonInteractiveCard> createState() => _CartoonInteractiveCardState();
}

class _CartoonInteractiveCardState extends State<CartoonInteractiveCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: CartoonDesignSystem.standardTransition,
      vsync: this,
    );
    _bounceController = AnimationController(
      duration: CartoonDesignSystem.bounceTransition,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: CartoonDesignSystem.cardHoverScale,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.elasticOut,
    ));
    
    _elevationAnimation = Tween<double>(
      begin: 4.0,
      end: 12.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    ));
    
    _bounceAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onTapDown() {
    _bounceController.forward();
    CartoonDesignSystem.triggerSelectionFeedback();
  }

  void _onTapUp() {
    if (widget.onTap != null) {
      widget.onTap!();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_hoverController, _bounceController]),
      builder: (context, child) {
        final bounceScale = 1.0 + (_bounceAnimation.value * 0.03);
        final finalScale = _scaleAnimation.value * bounceScale;
        
        return Transform.scale(
          scale: finalScale,
          child: MouseRegion(
            onEnter: (_) => _hoverController.forward(),
            onExit: (_) => _hoverController.reverse(),
            child: GestureDetector(
              onTapDown: widget.onTap != null ? (_) => _onTapDown() : null,
              onTapUp: widget.onTap != null ? (_) => _onTapUp() : null,
              onTapCancel: () => _bounceController.reverse(),
              child: CartoonCard(
                width: widget.width,
                height: widget.height,
                padding: widget.padding,
                isSelected: widget.isSelected,
                backgroundColor: widget.backgroundColor,
                borderRadius: widget.borderRadius,
                onTap: null, // Handle via gesture detector
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A cartoon progress bar with playful animations
class CartoonProgress extends StatefulWidget {
  final double value;
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double borderRadius;
  final bool isIndeterminate;

  const CartoonProgress({
    super.key,
    required this.value,
    this.width,
    this.height,
    this.backgroundColor,
    this.foregroundColor,
    this.borderRadius = CartoonDesignSystem.radiusSmall,
    this.isIndeterminate = false,
  });

  @override
  State<CartoonProgress> createState() => _CartoonProgressState();
}

class _CartoonProgressState extends State<CartoonProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
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
        return CartoonContainer(
          width: widget.width ?? double.infinity,
          height: widget.height ?? 12,
          borderRadius: widget.borderRadius,
          backgroundColor: widget.backgroundColor ?? CartoonDesignSystem.softPeach.withValues(alpha: 0.3),
          borderColor: CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.2),
          borderWidth: 1,
          enable3DEffect: false,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            child: LinearProgressIndicator(
              value: widget.isIndeterminate ? null : widget.value,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                (widget.foregroundColor ?? CartoonDesignSystem.sunshineYellow).withValues(
                  alpha: _pulseAnimation.value,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A circular cartoon progress indicator
class CartoonCircularProgress extends StatefulWidget {
  final double value;
  final double size;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double strokeWidth;
  final bool isIndeterminate;

  const CartoonCircularProgress({
    super.key,
    required this.value,
    this.size = 60,
    this.backgroundColor,
    this.foregroundColor,
    this.strokeWidth = 6.0,
    this.isIndeterminate = false,
  });

  @override
  State<CartoonCircularProgress> createState() => _CartoonCircularProgressState();
}

class _CartoonCircularProgressState extends State<CartoonCircularProgress>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 0.8,
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
        return CartoonContainer(
          width: widget.size,
          height: widget.size,
          padding: const EdgeInsets.all(8),
          borderRadius: widget.size / 2,
          backgroundColor: widget.backgroundColor ?? CartoonDesignSystem.softPeach.withValues(alpha: 0.3),
          borderColor: CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.2),
          borderWidth: 2,
          child: CircularProgressIndicator(
            value: widget.isIndeterminate ? null : widget.value,
            backgroundColor: Colors.transparent,
            valueColor: AlwaysStoppedAnimation<Color>(
              (widget.foregroundColor ?? CartoonDesignSystem.cherryRed).withValues(
                alpha: _pulseAnimation.value,
              ),
            ),
            strokeWidth: widget.strokeWidth,
          ),
        );
      },
    );
  }
}