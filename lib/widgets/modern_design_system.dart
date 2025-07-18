import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:babblelon/widgets/performance_optimization_helpers.dart';

/// Modern design system following 2025 UI/UX trends
/// Space-themed, futuristic design with clean aesthetics
/// Implements BabbleOn UI Design Guide v1.1 (July 2025)
class ModernDesignSystem {
  // 2025 Design Guide Color Palette
  static const Color primaryIndigo = Color(0xFF3A67FF); // Aura Indigo - Primary/Focused states
  static const Color butterYellow = Color(0xFFFFE07B); // Butter Yellow - Highlights/Badge glow
  static const Color cherryRed = Color(0xFFFF4F4F); // Cherry Red - Primary buttons/Active pins
  static const Color dillGreen = Color(0xFF4CD964); // Dill Green - Success states
  static const Color surfaceCard = Color(0xFF101421); // Surface Card - 90% opacity
  static const Color textOnSurface = Color(0xFFFFFFFF); // Text on Surface - 90%/70% alpha variants
  
  // Space-Themed Color Palette (maintained for compatibility)
  static const Color deepSpaceBlue = Color(0xFF0D122E); // Primary Background
  static const Color electricCyan = Color(0xFF00FFFF); // Secondary Action/Highlight
  static const Color warmOrange = Color(0xFFFFA500); // Tertiary Accent
  static const Color ghostWhite = Color(0xFFF8F8FF); // Text & UI Elements
  static const Color slateGray = Color(0xFF708090); // Disabled/Muted State
  
  // Legacy colors for backward compatibility (to be phased out)
  static const Color primaryBlue = primaryIndigo; // Updated to use design guide primary
  static const Color secondaryTeal = electricCyan;
  static const Color accentOrange = warmOrange;
  static const Color softPurple = Color(0xFF8B7EFF);
  static const Color warmWhite = ghostWhite;
  static const Color softGray = slateGray;
  static const Color darkBlue = deepSpaceBlue;
  static const Color backgroundDark = deepSpaceBlue;

  // Gradient Collections - Design Guide 2025
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryIndigo, Color(0xFF2E4EDF)], // Aura Indigo to deeper variant
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cherryRed, Color(0xFFE63946)], // Cherry Red to deeper variant
  );

  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [butterYellow, Color(0xFFFFD23F)], // Butter Yellow to warmer variant
  );

  static const LinearGradient spaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [deepSpaceBlue, Color(0xFF000000)], // Deep Space to Black
  );
  
  static const RadialGradient glowGradient = RadialGradient(
    center: Alignment.center,
    radius: 0.8,
    colors: [primaryIndigo, Colors.transparent],
  );

  static const RadialGradient buttonGlowGradient = RadialGradient(
    center: Alignment.center,
    radius: 1.0,
    colors: [butterYellow, Colors.transparent],
  );

  // Typography Scale - Material 3 + Design Guide 2025
  // Display Styles (Logo, Large Headings)
  static const TextStyle displayLarge = TextStyle(
    fontSize: 40, // Logo size from design guide
    fontWeight: FontWeight.w800, // Baloo 2 Bold equivalent
    height: 1.1,
    letterSpacing: -0.8,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.5,
  );

  // Heading Styles
  static const TextStyle headlineLarge = TextStyle(
    fontSize: 24, // Headings & CTA from design guide
    fontWeight: FontWeight.w600, // Poppins SemiBold equivalent
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const TextStyle headlineMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: -0.2,
  );

  // Body Styles
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 18, // Button label from design guide
    fontWeight: FontWeight.w700, // Poppins Bold equivalent
    height: 1.4,
    letterSpacing: 0.2,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16, // Body copy from design guide
    fontWeight: FontWeight.w400, // Poppins Regular
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // Label & Caption Styles
  static const TextStyle labelLarge = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.3,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.3,
    letterSpacing: 0.2,
  );

  // Spacing Scale - 8pt Grid System (Design Guide 2025)
  static const double spaceXXS = 2;  // 0.25 × 8pt
  static const double spaceXS = 4;   // 0.5 × 8pt
  static const double spaceSM = 8;   // 1 × 8pt base
  static const double spaceMD = 16;  // 2 × 8pt
  static const double spaceLG = 24;  // 3 × 8pt (vertical rhythm)
  static const double spaceXL = 32;  // 4 × 8pt
  static const double spaceXXL = 48; // 6 × 8pt
  static const double spaceXXXL = 64; // 8 × 8pt

  // Touch Target Sizes (WCAG 2.2 + Android UX)
  static const double touchTargetMin = 48; // Minimum touch target
  static const double touchTargetButton = 56; // Standard button height
  static const double touchTargetLarge = 72; // Large touch area

  // Border Radius - Design Guide 2025 (≥16dp requirement)
  static const double radiusSmall = 16;  // Minimum 16dp from design guide
  static const double radiusMedium = 20; // Standard cards
  static const double radiusLarge = 28;  // Large containers
  static const double radiusXLarge = 36; // Hero elements

  // Animation & Motion Constants - Design Guide 2025
  static const Duration microInteraction = Duration(milliseconds: 12); // Haptic feedback duration
  static const Duration quickTransition = Duration(milliseconds: 150);
  static const Duration standardTransition = Duration(milliseconds: 300);
  static const Duration slowTransition = Duration(milliseconds: 600);
  
  // Parallax Motion Constants
  static const double parallaxOffset = 12; // ±12px tilt from design guide
  static const double cardHoverScale = 1.02; // Card lift scale
  static const double cardPressScale = 0.98; // Card press scale

  // Haptic Feedback Patterns - Design Guide 2025
  static Future<void> lightHaptic() async {
    await HapticFeedback.lightImpact();
  }

  static Future<void> mediumHaptic() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> selectionHaptic() async {
    await HapticFeedback.selectionClick();
  }

  // Micro-interaction Helper Functions
  static void triggerSelectionFeedback() {
    lightHaptic();
  }

  static void triggerSuccessFeedback() {
    mediumHaptic();
  }
}

/// Modern Card Component - Replaces Glass Morphism
class ModernCard extends StatefulWidget {
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

  const ModernCard({
    super.key,
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.onTap,
    this.isSelected = false,
    this.gradient,
    this.backgroundColor,
    this.borderRadius = ModernDesignSystem.radiusMedium,
    this.enableHover = true,
  });

  @override
  State<ModernCard> createState() => _ModernCardState();
}

class _ModernCardState extends State<ModernCard>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _tapController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _elevationAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _tapController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.02,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    ));

    _elevationAnimation = Tween<double>(
      begin: 4.0,
      end: 12.0,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _tapController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _tapController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _tapController.reverse();
    if (widget.onTap != null) {
      ModernDesignSystem.triggerSelectionFeedback(); // Haptic feedback on selection
      widget.onTap!.call();
    }
  }

  void _onTapCancel() {
    _tapController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return OptimizedRepaintBoundary(
      debugLabel: 'ModernCard',
      child: MouseRegion(
        onEnter: widget.enableHover ? (_) => _hoverController.forward() : null,
        onExit: widget.enableHover ? (_) => _hoverController.reverse() : null,
        child: GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          child: AnimatedBuilder(
            animation: Listenable.merge([_hoverController, _tapController]),
            builder: (context, child) {
              // Use GPU-optimized transform
              return Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Enable GPU acceleration
                  ..scale(_scaleAnimation.value * (1.0 - _tapController.value * 0.02)),
                child: Container(
                width: widget.width,
                height: widget.height,
                padding: widget.padding ?? const EdgeInsets.all(ModernDesignSystem.spaceLG),
                decoration: BoxDecoration(
                  gradient: widget.gradient ?? 
                    (widget.isSelected ? ModernDesignSystem.primaryGradient : null),
                  color: widget.backgroundColor ?? 
                    (widget.isSelected ? null : ModernDesignSystem.warmWhite),
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: _elevationAnimation.value,
                      offset: Offset(0, _elevationAnimation.value / 2),
                    ),
                    if (widget.isSelected)
                      BoxShadow(
                        color: ModernDesignSystem.primaryBlue.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                  ],
                  border: widget.isSelected
                    ? Border.all(
                        color: ModernDesignSystem.primaryBlue.withValues(alpha: 0.3),
                        width: 2,
                      )
                    : null,
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

/// Modern Button Component
class ModernButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final ButtonStyle style;
  final IconData? icon;
  final double? width;

  const ModernButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.style = ButtonStyle.primary,
    this.icon,
    this.width,
  });

  @override
  State<ModernButton> createState() => _ModernButtonState();
}

enum ButtonStyle { primary, secondary, outline }

class _ModernButtonState extends State<ModernButton>
    with TickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _pressController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _pressController.reverse();
    if (!widget.isLoading && widget.onPressed != null) {
      ModernDesignSystem.triggerSelectionFeedback(); // Haptic feedback on button press
      widget.onPressed!.call();
    }
  }

  void _onTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    
    return GestureDetector(
      onTapDown: isEnabled ? _onTapDown : null,
      onTapUp: isEnabled ? _onTapUp : null,
      onTapCancel: isEnabled ? _onTapCancel : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.width,
              height: ModernDesignSystem.touchTargetButton, // Use design guide height
              decoration: BoxDecoration(
                gradient: _getGradient(),
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(ModernDesignSystem.radiusSmall), // 16dp radius
                border: _getBorder(),
                boxShadow: isEnabled ? [
                  BoxShadow(
                    color: _getShadowColor(),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  // Add button glow effect for primary buttons
                  if (widget.style == ButtonStyle.primary)
                    BoxShadow(
                      color: ModernDesignSystem.butterYellow.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 0),
                    ),
                ] : null,
              ),
              child: Center(
                child: widget.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            color: _getTextColor(),
                            size: 20,
                          ),
                          const SizedBox(width: ModernDesignSystem.spaceSM),
                        ],
                        Text(
                          widget.text,
                          style: ModernDesignSystem.bodyLarge.copyWith(
                            color: _getTextColor(),
                            fontWeight: FontWeight.w700, // Poppins Bold from design guide
                            fontSize: 16, // Design guide button text size
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
      case ButtonStyle.primary:
        return ModernDesignSystem.accentGradient; // Cherry Red for primary CTAs
      default:
        return null;
    }
  }

  Color? _getBackgroundColor() {
    if (!_isEnabled()) return ModernDesignSystem.softGray.withValues(alpha: 0.3);
    switch (widget.style) {
      case ButtonStyle.secondary:
        return ModernDesignSystem.warmWhite;
      case ButtonStyle.outline:
        return Colors.transparent;
      default:
        return null;
    }
  }

  Border? _getBorder() {
    switch (widget.style) {
      case ButtonStyle.outline:
        return Border.all(
          color: _isEnabled() 
            ? ModernDesignSystem.primaryBlue 
            : ModernDesignSystem.softGray,
          width: 2,
        );
      default:
        return null;
    }
  }

  Color _getShadowColor() {
    switch (widget.style) {
      case ButtonStyle.primary:
        return ModernDesignSystem.cherryRed.withValues(alpha: 0.3); // Cherry Red shadow
      default:
        return Colors.black.withValues(alpha: 0.1);
    }
  }

  Color _getTextColor() {
    if (!_isEnabled()) return ModernDesignSystem.softGray;
    switch (widget.style) {
      case ButtonStyle.primary:
        return Colors.white;
      case ButtonStyle.outline:
        return ModernDesignSystem.primaryBlue;
      default:
        return ModernDesignSystem.darkBlue;
    }
  }

  bool _isEnabled() {
    return widget.onPressed != null && !widget.isLoading;
  }
}

/// Modern Input Field Component
class ModernInputField extends StatefulWidget {
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool isPassword;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final Function(String)? onChanged;

  const ModernInputField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.isPassword = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onSuffixTap,
    this.onChanged,
  });

  @override
  State<ModernInputField> createState() => _ModernInputFieldState();
}

class _ModernInputFieldState extends State<ModernInputField> {
  late FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: ModernDesignSystem.bodyMedium.copyWith(
              color: ModernDesignSystem.darkBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: ModernDesignSystem.spaceSM),
        ],
        Container(
          decoration: BoxDecoration(
            color: ModernDesignSystem.warmWhite,
            borderRadius: BorderRadius.circular(ModernDesignSystem.radiusSmall),
            border: Border.all(
              color: _isFocused 
                ? ModernDesignSystem.primaryBlue 
                : ModernDesignSystem.softGray.withValues(alpha: 0.3),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused ? [
              BoxShadow(
                color: ModernDesignSystem.primaryBlue.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            obscureText: widget.isPassword,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: ModernDesignSystem.bodyMedium.copyWith(
                color: ModernDesignSystem.softGray,
              ),
              prefixIcon: widget.prefixIcon != null 
                ? Icon(
                    widget.prefixIcon,
                    color: _isFocused 
                      ? ModernDesignSystem.primaryBlue 
                      : ModernDesignSystem.softGray,
                  )
                : null,
              suffixIcon: widget.suffixIcon != null 
                ? GestureDetector(
                    onTap: widget.onSuffixTap,
                    child: Icon(
                      widget.suffixIcon,
                      color: ModernDesignSystem.softGray,
                    ),
                  )
                : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(ModernDesignSystem.spaceLG),
            ),
          ),
        ),
      ],
    );
  }
}