import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/performance_optimization_helpers.dart';
import 'package:babblelon/providers/game_providers.dart';

/// Cartoon design system with bright, engaging colors
/// Red and yellow cartoony theme for playful language learning experience
/// Implements BabbleOn Cartoon UI Design Guide v1.0 (July 2025)
class CartoonDesignSystem {
  // Primary Cartoony Color Palette
  static const Color sunshineYellow = Color(0xFFFFD700); // Primary buttons, highlights
  static const Color cherryRed = Color(0xFFFF4757); // Accents, important actions
  static const Color warmOrange = Color(0xFFFFA726); // Secondary actions, success states
  static const Color skyBlue = Color(0xFF42A5F5); // Information, links
  
  // Background Colors
  static const Color creamWhite = Color(0xFFFFF8DC); // Main backgrounds
  static const Color softPeach = Color(0xFFFFE5B4); // Card backgrounds
  static const Color lightBlue = Color(0xFFE3F2FD); // Alternative sections
  
  // Supporting Colors
  static const Color forestGreen = Color(0xFF4CAF50); // Success, available items
  static const Color coralPink = Color(0xFFFF7043); // Warnings, special highlights
  static const Color lavenderPurple = Color(0xFFAB47BC); // Premium features
  static const Color chocolateBrown = Color(0xFF8D6E63); // Text, borders
  
  // Text Colors
  static const Color textPrimary = Color(0xFF3E2723); // Primary text - dark brown
  static const Color textSecondary = Color(0xFF5D4037); // Secondary text
  static const Color textOnBright = Colors.white; // Text on bright backgrounds
  static const Color textMuted = Color(0xFF8D6E63); // Muted text
  
  // Gradient Collections
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [sunshineYellow, Color(0xFFFFA000)], // Sunshine to amber
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cherryRed, Color(0xFFE53E3E)], // Cherry red to deeper red
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [warmOrange, Color(0xFFFF8A65)], // Orange to coral
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [creamWhite, softPeach], // Cream to peach
  );
  
  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFE082), // Light yellow
      Color(0xFFFFCC02), // Golden yellow
      Color(0xFFFFB300), // Amber
      Color(0xFFFF8F00), // Orange
    ],
  );
  
  static const RadialGradient glowGradient = RadialGradient(
    center: Alignment.center,
    radius: 0.8,
    colors: [sunshineYellow, Colors.transparent],
  );

  static const RadialGradient buttonGlowGradient = RadialGradient(
    center: Alignment.center,
    radius: 1.0,
    colors: [cherryRed, Colors.transparent],
  );

  // Typography Scale - Friendly, rounded fonts
  static const TextStyle displayLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.5,
    fontFamily: 'Quicksand', // Rounded, friendly font
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.3,
    fontFamily: 'Quicksand',
  );

  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
    fontFamily: 'Quicksand',
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.1,
    fontFamily: 'Quicksand',
  );

  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.4,
    letterSpacing: 0.1,
    fontFamily: 'Nunito',
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
    fontFamily: 'Nunito',
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
    fontFamily: 'Nunito',
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.2,
    fontFamily: 'Nunito',
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.2,
    fontFamily: 'Nunito',
  );

  // Spacing Scale - 8pt Grid System with cartoon feel
  static const double spaceXXS = 4;  // 0.5 × 8pt
  static const double spaceXS = 6;   // 0.75 × 8pt
  static const double spaceSM = 8;   // 1 × 8pt base
  static const double spaceMD = 16;  // 2 × 8pt
  static const double spaceLG = 24;  // 3 × 8pt
  static const double spaceXL = 32;  // 4 × 8pt
  static const double spaceXXL = 48; // 6 × 8pt
  static const double spaceXXXL = 64; // 8 × 8pt

  // Touch Target Sizes - Cartoon-friendly
  static const double touchTargetMin = 48; // Minimum touch target
  static const double touchTargetButton = 56; // Standard button height
  static const double touchTargetLarge = 72; // Large touch area
  static const double touchTargetHuge = 88; // Extra large for cartoon style

  // Border Radius - Rounded, friendly shapes
  static const double radiusSmall = 20;  // More rounded than modern
  static const double radiusMedium = 28; // Standard cards
  static const double radiusLarge = 36;  // Large containers
  static const double radiusXLarge = 44; // Hero elements
  static const double radiusRound = 100; // Fully rounded

  // Animation & Motion Constants - Bouncy, playful
  static const Duration microInteraction = Duration(milliseconds: 16);
  static const Duration quickTransition = Duration(milliseconds: 200);
  static const Duration standardTransition = Duration(milliseconds: 400);
  static const Duration slowTransition = Duration(milliseconds: 800);
  static const Duration bounceTransition = Duration(milliseconds: 600);
  
  // Cartoon Motion Constants
  static const double bounceOffset = 16; // Bounce animation offset
  static const double cardHoverScale = 1.05; // More pronounced scale
  static const double cardPressScale = 0.95; // Press scale
  static const double wobbleAngle = 0.05; // Subtle wobble rotation

  // Haptic Feedback Patterns
  static Future<void> lightHaptic() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> mediumHaptic() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> heavyHaptic() async {
    await HapticFeedback.heavyImpact();
  }

  static Future<void> selectionHaptic() async {
    await HapticFeedback.selectionClick();
  }

  // Cartoon interaction helpers
  static void triggerSelectionFeedback() {
    mediumHaptic(); // Stronger feedback for cartoon feel
  }

  static void triggerSuccessFeedback() {
    heavyHaptic(); // Celebrate success!
  }

  static void triggerPlayfulFeedback() {
    lightHaptic();
  }
}

/// Cartoon Card Component with bouncy, 3D feel
class CartoonCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final bool isSelected;
  final Gradient? gradient;
  final Color? backgroundColor;
  final double borderRadius;
  final bool enableHover;
  final bool enable3DEffect;

  const CartoonCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.isSelected = false,
    this.gradient,
    this.backgroundColor,
    this.borderRadius = CartoonDesignSystem.radiusMedium,
    this.enableHover = true,
    this.enable3DEffect = true,
  });

  @override
  State<CartoonCard> createState() => _CartoonCardState();
}

class _CartoonCardState extends State<CartoonCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _tapController;
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
    _tapController = AnimationController(
      duration: CartoonDesignSystem.quickTransition,
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
      end: 16.0,
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
    _tapController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _tapController.forward();
    _bounceController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _tapController.reverse();
    if (widget.onTap != null) {
      CartoonDesignSystem.triggerSelectionFeedback();
      widget.onTap!.call();
    }
  }

  void _onTapCancel() {
    _tapController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return OptimizedRepaintBoundary(
      debugLabel: 'CartoonCard',
      child: MouseRegion(
        onEnter: widget.enableHover ? (_) => _hoverController.forward() : null,
        onExit: widget.enableHover ? (_) => _hoverController.reverse() : null,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedBuilder(
            animation: Listenable.merge([_hoverController, _tapController, _bounceController]),
            builder: (context, child) {
              final bounceScale = 1.0 + (_bounceAnimation.value * 0.1);
              final tapScale = 1.0 - (_tapController.value * 0.05);
              final finalScale = _scaleAnimation.value * bounceScale * tapScale;

              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..scale(finalScale)
                  ..rotateZ(_bounceAnimation.value * CartoonDesignSystem.wobbleAngle),
                child: Container(
                  width: widget.width,
                  height: widget.height,
                  padding: widget.padding ?? const EdgeInsets.all(CartoonDesignSystem.spaceLG),
                  decoration: BoxDecoration(
                    gradient: widget.gradient ?? 
                      (widget.isSelected ? CartoonDesignSystem.primaryGradient : null),
                    color: widget.backgroundColor ?? 
                      (widget.isSelected ? null : CartoonDesignSystem.creamWhite),
                    borderRadius: BorderRadius.circular(widget.borderRadius),
                    boxShadow: [
                      // Main shadow
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: _elevationAnimation.value,
                        offset: Offset(0, _elevationAnimation.value / 2),
                      ),
                      // Cartoon 3D effect
                      if (widget.enable3DEffect)
                        BoxShadow(
                          color: CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.3),
                          blurRadius: 0,
                          offset: const Offset(2, 2),
                        ),
                      // Selection glow
                      if (widget.isSelected)
                        BoxShadow(
                          color: CartoonDesignSystem.sunshineYellow.withValues(alpha: 0.4),
                          blurRadius: 25,
                          offset: const Offset(0, 0),
                        ),
                    ],
                    border: widget.isSelected
                      ? Border.all(
                          color: CartoonDesignSystem.cherryRed,
                          width: 3,
                        )
                      : Border.all(
                          color: CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.2),
                          width: 1,
                        ),
                  ),
                  child: widget.child,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Cartoon Button Component with 3D, bouncy style
class CartoonButton extends ConsumerStatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final CartoonButtonStyle style;
  final IconData? icon;
  final double? width;
  final bool isLarge;

  const CartoonButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.style = CartoonButtonStyle.primary,
    this.icon,
    this.width,
    this.isLarge = false,
  });

  @override
  ConsumerState<CartoonButton> createState() => _CartoonButtonState();
}

enum CartoonButtonStyle { primary, secondary, accent, outline }

class _CartoonButtonState extends ConsumerState<CartoonButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late AnimationController _bounceController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: CartoonDesignSystem.quickTransition,
      vsync: this,
    );
    _bounceController = AnimationController(
      duration: CartoonDesignSystem.bounceTransition,
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: CartoonDesignSystem.cardPressScale,
    ).animate(CurvedAnimation(
      parent: _pressController,
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
    _pressController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _pressController.reverse();
    _bounceController.forward().then((_) {
      _bounceController.reverse();
    });
    
    if (!widget.isLoading && widget.onPressed != null) {
      CartoonDesignSystem.triggerSelectionFeedback();
      ref.playButtonSound();
      widget.onPressed!.call();
    }
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final buttonHeight = widget.isLarge 
      ? CartoonDesignSystem.touchTargetLarge 
      : CartoonDesignSystem.touchTargetButton;
    
    return GestureDetector(
      onTapDown: isEnabled ? _onTapDown : null,
      onTapUp: isEnabled ? _onTapUp : null,
      onTapCancel: isEnabled ? _onTapCancel : null,
      child: AnimatedBuilder(
        animation: Listenable.merge([_scaleAnimation, _bounceAnimation]),
        builder: (context, child) {
          final bounceScale = 1.0 + (_bounceAnimation.value * 0.05);
          final finalScale = _scaleAnimation.value * bounceScale;

          return Transform.scale(
            scale: finalScale,
            child: Container(
              width: widget.width,
              height: buttonHeight,
              decoration: BoxDecoration(
                gradient: _getGradient(),
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusSmall),
                border: _getBorder(),
                boxShadow: isEnabled ? [
                  // Main shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                  // 3D effect
                  BoxShadow(
                    color: _get3DShadowColor(),
                    blurRadius: 0,
                    offset: const Offset(0, 3),
                  ),
                  // Glow effect
                  if (widget.style == CartoonButtonStyle.primary)
                    BoxShadow(
                      color: CartoonDesignSystem.sunshineYellow.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                ] : null,
              ),
              child: Center(
                child: widget.isLoading
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: _getTextColor(),
                            size: 22,
                          ),
                          const SizedBox(width: CartoonDesignSystem.spaceSM),
                        ],
                        Text(
                          widget.text,
                          style: CartoonDesignSystem.bodyLarge.copyWith(
                            color: _getTextColor(),
                            fontWeight: FontWeight.w700,
                            fontSize: widget.isLarge ? 18 : 16,
                          ),
                        ),
                      ],
                    ),
              ),
            ),
          );
        },
      ),
    );
  }

  Gradient? _getGradient() {
    if (!_isEnabled()) return null;
    switch (widget.style) {
      case CartoonButtonStyle.primary:
        return CartoonDesignSystem.primaryGradient;
      case CartoonButtonStyle.accent:
        return CartoonDesignSystem.accentGradient;
      default:
        return null;
    }
  }

  Color? _getBackgroundColor() {
    if (!_isEnabled()) return CartoonDesignSystem.textMuted.withValues(alpha: 0.3);
    switch (widget.style) {
      case CartoonButtonStyle.secondary:
        return CartoonDesignSystem.creamWhite;
      case CartoonButtonStyle.outline:
        return Colors.transparent;
      default:
        return null;
    }
  }

  Border? _getBorder() {
    switch (widget.style) {
      case CartoonButtonStyle.outline:
        return Border.all(
          color: _isEnabled() 
            ? CartoonDesignSystem.cherryRed 
            : CartoonDesignSystem.textMuted,
          width: 3,
        );
      case CartoonButtonStyle.secondary:
        return Border.all(
          color: CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.3),
          width: 2,
        );
      default:
        return null;
    }
  }

  Color _get3DShadowColor() {
    switch (widget.style) {
      case CartoonButtonStyle.primary:
        return CartoonDesignSystem.warmOrange.withValues(alpha: 0.8);
      case CartoonButtonStyle.accent:
        return CartoonDesignSystem.cherryRed.withValues(alpha: 0.6).withRed(180);
      default:
        return CartoonDesignSystem.chocolateBrown.withValues(alpha: 0.4);
    }
  }

  Color _getTextColor() {
    if (!_isEnabled()) return CartoonDesignSystem.textMuted;
    switch (widget.style) {
      case CartoonButtonStyle.primary:
      case CartoonButtonStyle.accent:
        return CartoonDesignSystem.textOnBright;
      case CartoonButtonStyle.outline:
        return CartoonDesignSystem.cherryRed;
      default:
        return CartoonDesignSystem.textPrimary;
    }
  }

  bool _isEnabled() {
    return widget.onPressed != null && !widget.isLoading;
  }
}