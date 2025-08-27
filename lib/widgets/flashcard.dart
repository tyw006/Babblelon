import 'dart:math' as math;
import 'package:babblelon/models/supabase_models.dart';
import 'package:babblelon/widgets/complexity_rating.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/providers/game_providers.dart';
import 'package:babblelon/theme/modern_design_system.dart';

class Flashcard extends ConsumerStatefulWidget {
  final Vocabulary vocabulary;
  final bool isFlippable;
  final VoidCallback? onTap;
  final VoidCallback? onReveal;
  final bool isRevealed;
  final Widget? revealedChild;
  final bool showAudioButton;
  final bool isBossFightContext;
  final bool isDialog;

  const Flashcard({
    super.key,
    required this.vocabulary,
    this.isFlippable = true,
    this.onTap,
    this.onReveal,
    this.isRevealed = false,
    this.revealedChild,
    this.showAudioButton = true,
    this.isBossFightContext = false,
    this.isDialog = false,
  });

  @override
  ConsumerState<Flashcard> createState() => _FlashcardState();
}

class _FlashcardState extends ConsumerState<Flashcard>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = false;
  final just_audio.AudioPlayer _audioPlayer = just_audio.AudioPlayer();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _bounceAnimation = Tween<double>(begin: 0.0, end: 8.0).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );
    
    _scrollController.addListener(_onScroll);
    
    if (widget.isRevealed) {
      _controller.value = 1;
      _checkScrollableContent();
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      
      if (maxScroll > 0 && currentScroll >= maxScroll - 20) {
        setState(() {
          _showScrollIndicator = false;
        });
        _bounceController.stop();
      }
    }
  }

  void _checkScrollableContent() {
    // Use addPostFrameCallback to ensure the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted) {
        final isScrollable = _scrollController.position.maxScrollExtent > 0;
        if (isScrollable != _showScrollIndicator) {
          setState(() {
            _showScrollIndicator = isScrollable;
          });
          if (_showScrollIndicator) {
            _bounceController.repeat(reverse: true);
          } else {
            _bounceController.stop();
          }
        }
      } else {
        // If no clients, try again after a short delay
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _checkScrollableContent();
        });
      }
    });
  }

  @override
  void didUpdateWidget(Flashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRevealed != oldWidget.isRevealed) {
      // Don't flip cards in boss fight context - only show visual indicators
      if (!widget.isBossFightContext) {
        if (widget.isRevealed) {
          _controller.forward();
          _checkScrollableContent();
        } else {
          _controller.reverse();
          setState(() {
            _showScrollIndicator = false;
          });
          _bounceController.stop();
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _bounceController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final soundEffectsEnabled = ref.read(gameStateProvider).soundEffectsEnabled;
    
    return GestureDetector(
      onTap: () {
        if (widget.onTap != null) {
          widget.onTap!();
          return;
        }
        ref.playButtonSound();
      },
      onDoubleTap: () {
        // Handle flipping animation for dialog cards with a double tap
        if (widget.isFlippable) {
          // Play reveal sound effect on every flip (front <-> back)
          if (soundEffectsEnabled) {
            ref.playSound('soundeffects/soundeffect_flashcardreveal.mp3', volume: 1.0);
          }
          if (_controller.isCompleted) {
            _controller.reverse();
          } else {
            _controller.forward();
            // Trigger the onReveal callback when flipping to back for the first time
            if (widget.onReveal != null && !widget.isRevealed) {
              widget.onReveal!();
            }
          }
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final angle = _controller.value * math.pi;
          final isFront = _controller.value < 0.5;

          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001) // Perspective
            ..rotateY(angle);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isFront
                ? _buildFront()
                : Transform( // Counter-rotate the back
                    transform: Matrix4.identity()..rotateY(math.pi),
                    alignment: Alignment.center,
                    child: _buildBack(),
                  ),
          );
        },
      ),
    );
  }

  Widget _buildFront() {
    return Container(
      decoration: BoxDecoration(
        color: ModernDesignSystem.primarySurface,
        borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
        border: Border.all(
          color: widget.isBossFightContext && widget.isRevealed 
            ? Colors.green.shade400 
            : ModernDesignSystem.borderPrimary,
          width: widget.isBossFightContext && widget.isRevealed ? 2.0 : 1.0,
        ),
        boxShadow: widget.isBossFightContext && widget.isRevealed ? [
          BoxShadow(
            color: Colors.green.shade400.withValues(alpha: 0.2),
            blurRadius: 8,
            spreadRadius: 1,
            offset: const Offset(0, 0),
          ),
        ] : null,
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
              child: Text(
                widget.vocabulary.english,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 3,
                style: ModernDesignSystem.headlineMedium.copyWith(
                  fontSize: widget.isDialog ? 26.0 : 17.0,
                  color: Colors.white,
                  height: 1.2,
                ),
                softWrap: true,
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: ComplexityRating(
                complexity: widget.vocabulary.complexity,
                size: 14,
                isDialog: widget.isDialog,
              ),
            ),
          ),
          if (widget.isBossFightContext && widget.isRevealed)
            Positioned(
              top: 3,
              right: 3,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.green.shade500,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.green.shade400.withValues(alpha: 0.5),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: BoxDecoration(
        color: ModernDesignSystem.primarySurface,
        borderRadius: BorderRadius.circular(ModernDesignSystem.radiusMedium),
        border: Border.all(color: ModernDesignSystem.borderPrimary),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          SingleChildScrollView(
            controller: _scrollController,
            child: widget.revealedChild ??
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                widget.vocabulary.thai,
                                textAlign: TextAlign.center,
                                style: ModernDesignSystem.headlineMedium.copyWith(
                                  fontSize: widget.isDialog ? 28.0 : 20.0,
                                  color: ModernDesignSystem.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                            ),
                            if (widget.showAudioButton && widget.vocabulary.audioPath != null && widget.vocabulary.audioPath!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: IconButton(
                                  icon: const Icon(Icons.volume_up, color: ModernDesignSystem.textPrimary),
                                  onPressed: () async {
                                    try {
                                      // Use the specific audio path from the vocabulary
                                      await _audioPlayer.setAsset(widget.vocabulary.audioPath!);
                                      _audioPlayer.play();
                                    } catch (e) {
                                      // Handle potential errors, e.g., file not found
                                      debugPrint("Error playing audio: $e");
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                        // Add extra space at the bottom to ensure scrollability
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
          ),
          // Scroll Down Indicator
          Positioned(
            bottom: 8,
            child: IgnorePointer(
              child: Opacity(
                opacity: _showScrollIndicator ? 1.0 : 0.0,
                child: Transform.translate(
                  offset: Offset(0, _bounceAnimation.value),
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: ModernDesignSystem.textTertiary,
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 