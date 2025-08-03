import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/widgets/cartoon_design_system.dart';
import 'package:babblelon/theme/app_theme.dart';
import 'package:babblelon/providers/game_providers.dart';

class CartoonGameButton extends ConsumerStatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final bool isLoading;
  final IconData? icon;
  final double? width;
  final double height;

  const CartoonGameButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isEnabled = true,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 56,
  });

  @override
  ConsumerState<CartoonGameButton> createState() => _CartoonGameButtonState();
}

class _CartoonGameButtonState extends ConsumerState<CartoonGameButton>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _pressController;
  late AnimationController _glowController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _pressController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _hoverController,
      curve: Curves.easeOut,
    ));

    _glowAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));

    // Start the pulsing glow animation
    if (widget.isEnabled && !widget.isLoading) {
      _glowController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(CartoonGameButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isEnabled && !widget.isLoading && !_glowController.isAnimating) {
      _glowController.repeat(reverse: true);
    } else if ((!widget.isEnabled || widget.isLoading) && _glowController.isAnimating) {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _pressController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    if (widget.isEnabled && !widget.isLoading) {
      _pressController.forward();
      _hoverController.forward();
    }
  }

  void _onTapUp(TapUpDetails details) {
    _pressController.reverse();
    if (widget.isEnabled && !widget.isLoading) {
      ref.playButtonSound();
      widget.onPressed?.call();
    }
  }

  void _onTapCancel() {
    _pressController.reverse();
    _hoverController.reverse();
  }

  void _onHoverEnter(PointerEvent event) {
    if (widget.isEnabled && !widget.isLoading) {
      _hoverController.forward();
    }
  }

  void _onHoverExit(PointerEvent event) {
    _hoverController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isInteractive = widget.isEnabled && !widget.isLoading;
    
    return MouseRegion(
      onEnter: _onHoverEnter,
      onExit: _onHoverExit,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _scaleAnimation,
            _pressController,
            _glowAnimation,
          ]),
          builder: (context, child) {
            final scale = _scaleAnimation.value * (1.0 - _pressController.value * 0.05);
            
            return Transform.scale(
              scale: scale,
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  gradient: isInteractive
                      ? CartoonDesignSystem.primaryGradient
                      : LinearGradient(
                          colors: [
                            CartoonDesignSystem.textMuted.withValues(alpha: 0.5),
                            CartoonDesignSystem.textMuted.withValues(alpha: 0.3),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(CartoonDesignSystem.radiusMedium),
                  border: Border.all(
                    color: isInteractive
                        ? CartoonDesignSystem.sunshineYellow.withValues(
                            alpha: 0.3 + (_glowAnimation.value * 0.4),
                          )
                        : CartoonDesignSystem.textMuted.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: isInteractive
                      ? [
                          BoxShadow(
                            color: CartoonDesignSystem.sunshineYellow.withValues(
                              alpha: 0.2 + (_glowAnimation.value * 0.3),
                            ),
                            blurRadius: 20 + (_glowAnimation.value * 10),
                            spreadRadius: 2 + (_glowAnimation.value * 3),
                          ),
                          BoxShadow(
                            color: CartoonDesignSystem.textPrimary.withValues(alpha: 0.8),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: CartoonDesignSystem.textPrimary.withValues(alpha: 0.5),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Center(
                  child: widget.isLoading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              CartoonDesignSystem.textOnBright,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.icon != null) ...[
                              Icon(
                                widget.icon,
                                color: isInteractive
                                    ? CartoonDesignSystem.textPrimary
                                    : CartoonDesignSystem.textMuted,
                                size: 20,
                              ),
                              const SizedBox(width: CartoonDesignSystem.spaceSM),
                            ],
                            Text(
                              widget.text,
                              style: AppTheme.textTheme.titleMedium?.copyWith(
                                color: isInteractive
                                    ? CartoonDesignSystem.textPrimary
                                    : CartoonDesignSystem.textMuted,
                                fontWeight: FontWeight.w600,
                                shadows: isInteractive
                                    ? [
                                        Shadow(
                                          color: CartoonDesignSystem.textOnBright.withValues(alpha: 0.8),
                                          blurRadius: 2,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}