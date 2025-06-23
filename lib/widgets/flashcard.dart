import 'dart:math' as math;
import 'package:babblelon/models/game_models.dart';
import 'package:babblelon/widgets/complexity_rating.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';

class Flashcard extends StatefulWidget {
  final Vocabulary vocabulary;
  final bool isRevealed;
  final bool isFlippable;
  final VoidCallback? onReveal;
  final VoidCallback? onTap;
  final Widget? revealedChild;

  const Flashcard({
    super.key,
    required this.vocabulary,
    this.isRevealed = false,
    this.isFlippable = true,
    this.onReveal,
    this.onTap,
    this.revealedChild,
  });

  @override
  State<Flashcard> createState() => _FlashcardState();
}

class _FlashcardState extends State<Flashcard>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnimation;
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToEnd = false;
  bool _showScrollIndicator = false;

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
          _hasScrolledToEnd = true;
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
            _hasScrolledToEnd = false;
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
      if (widget.isRevealed) {
        _controller.forward();
        _checkScrollableContent();
      } else {
        _controller.reverse();
        setState(() {
          _showScrollIndicator = false;
          _hasScrolledToEnd = false;
        });
        _bounceController.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _bounceController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // For cards on the main screen, onTap triggers the dialog.
        // It does not handle flipping.
        if (widget.onTap != null) {
          widget.onTap!();
          return;
        }
      },
      onDoubleTap: () {
        // Handle flipping animation for dialog cards with a double tap
        if (widget.isFlippable) {
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
      decoration: _buildCardDecoration(isFront: true),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                widget.vocabulary.english,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: GoogleFonts.lato(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                softWrap: true,
              ),
            ),
          ),
          Positioned(
            top: 8,
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.center,
              child: ComplexityRating(
                complexity: widget.vocabulary.complexity,
                size: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBack() {
    return Container(
      decoration: _buildCardDecoration(isFront: false),
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
                        Text(
                          widget.vocabulary.thai,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '(${widget.vocabulary.transliteration})',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.white.withOpacity(0.8),
                          ),
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
                    color: Colors.white38,
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

  BoxDecoration _buildCardDecoration({bool isFront = true}) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: [Colors.grey.shade800, Colors.grey.shade700],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(12.0),
      border: Border.all(
        color: Colors.white.withOpacity(0.2),
        width: 1.0,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 5,
          offset: const Offset(2, 2),
        ),
      ],
    );
  }
} 