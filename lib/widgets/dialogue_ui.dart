import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/npc_data.dart';
import '../providers/game_providers.dart';
import 'charm_bar.dart';

class DialogueUI extends StatefulWidget {
  final NpcData npcData;
  final int displayedCharmLevel;
  final double screenWidth;
  final double screenHeight;
  final Widget npcContentWidget;
  final AnimationController giftIconAnimationController;
  final VoidCallback onRequestItem;
  final VoidCallback onResumeGame;
  final VoidCallback onShowTranslation;
  final Widget micControls;
  final bool isProcessingBackend;
  final ScrollController mainDialogueScrollController;
  final VoidCallback onShowHistory;
  final Widget? topRightAction;

  const DialogueUI({
    super.key,
    required this.npcData,
    required this.displayedCharmLevel,
    required this.screenWidth,
    required this.screenHeight,
    required this.npcContentWidget,
    required this.giftIconAnimationController,
    required this.onRequestItem,
    required this.onResumeGame,
    required this.onShowTranslation,
    required this.micControls,
    required this.isProcessingBackend,
    required this.mainDialogueScrollController,
    required this.onShowHistory,
    this.topRightAction,
  });

  @override
  State<DialogueUI> createState() => _DialogueUIState();
}

class _DialogueUIState extends State<DialogueUI> with TickerProviderStateMixin {
  late AnimationController _thinkingAnimationController;

  @override
  void initState() {
    super.initState();
    _thinkingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    if (widget.isProcessingBackend) {
      _thinkingAnimationController.repeat();
    }
  }

  @override
  void didUpdateWidget(DialogueUI oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isProcessingBackend != oldWidget.isProcessingBackend) {
      if (widget.isProcessingBackend) {
        _thinkingAnimationController.repeat();
      } else {
        _thinkingAnimationController.stop();
      }
    }
  }

  @override
  void dispose() {
    _thinkingAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double outerHorizontalPadding = widget.screenWidth * 0.01;
    final double textboxHeight = 150.0;
    final double textboxWidth = math.max(widget.screenWidth * 0.95, 368.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(widget.npcData.dialogueBackgroundPath, fit: BoxFit.cover),
          ),
          SafeArea(
            bottom: true, // Respect bottom safe area for home indicator
            top: true,
            child: Stack(
              children: <Widget>[
                Positioned(
                  top: 40,
                  left: 0,
                  right: 0,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Consumer(
                          builder: (context, ref, child) {
                            return GestureDetector(
                              onDoubleTap: () {
                                final charmNotifier = ref.read(currentCharmLevelProvider(widget.npcData.id).notifier);
                                if (charmNotifier.state >= 100) {
                                  charmNotifier.state = 0;
                                } else {
                                  charmNotifier.state = (charmNotifier.state + 20).clamp(0, 100);
                                }
                              },
                              child: child,
                            );
                          },
                          child: CharmBar(
                            npcId: widget.npcData.id,
                            npcName: widget.npcData.name,
                            maxWidth: widget.screenWidth * 0.75,
                            height: 32,
                            nameFontSize: 28,
                            charmFontSize: 16,
                            trailing: widget.displayedCharmLevel >= 75
                                ? GestureDetector(
                                    onTap: widget.onRequestItem,
                                    child: AnimatedBuilder(
                                      animation: widget.giftIconAnimationController,
                                      builder: (context, child) {
                                        final bool isMaxCharm = widget.displayedCharmLevel >= 100;
                                        final Color glowColor = isMaxCharm ? Colors.yellow.shade700 : Colors.pink.shade400;
                                        final double maxBlur = isMaxCharm ? 20.0 : 12.0;
                                        final double maxSpread = isMaxCharm ? 5.0 : 2.0;
                                        final double glowValue = widget.giftIconAnimationController.value;

                                        return Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.5),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white70),
                                            boxShadow: [
                                              BoxShadow(
                                                color: glowColor.withValues(alpha: 0.7 * glowValue),
                                                blurRadius: maxBlur * glowValue,
                                                spreadRadius: maxSpread * glowValue,
                                              ),
                                            ],
                                          ),
                                          child: child,
                                        );
                                      },
                                      child: const Icon(
                                        Icons.card_giftcard,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: const Alignment(0.0, 0.0),
                  child: Image.asset(
                    widget.npcData.dialoguePortraitPath,
                    height: widget.screenHeight * 0.7,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                Align(
                  alignment: Alignment.center,
                  child: CustomPaint(
                    painter: SpeechBubblePainter(
                      backgroundColor: const Color(0xFFF3F3F3),
                      borderColor: Colors.grey.shade600,
                      borderWidth: 3,
                    ),
                    child: Container(
                      width: textboxWidth,
                      height: textboxHeight,
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Scrollbar(
                              controller: widget.mainDialogueScrollController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: widget.mainDialogueScrollController,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: textboxHeight - 24, // Expanded text area
                                  ),
                                  child: Center(
                                    child: widget.isProcessingBackend
                                        ? _buildThinkingText()
                                        : widget.npcContentWidget,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (widget.topRightAction != null)
                            widget.topRightAction!,
                          Positioned(
                            bottom: 10,
                            right: 0,
                            child: GestureDetector(
                              onTap: widget.onShowHistory,
                              child: Icon(
                                Icons.history,
                                color: Colors.grey.shade600,
                                size: 30,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: outerHorizontalPadding + 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      _buildControlButton(
                        icon: Icons.arrow_back,
                        onTap: widget.onResumeGame,
                      ),
                      widget.isProcessingBackend
                          ? const CircularProgressIndicator()
                          : widget.micControls,
                      _buildControlButton(
                        icon: Icons.translate,
                        onTap: widget.onShowTranslation,
                      ),
                    ],
                  ),
                ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThinkingText() {
    return AnimatedBuilder(
      animation: _thinkingAnimationController,
      builder: (context, child) {
        // Create animated dots based on animation progress
        final int dotCount = ((_thinkingAnimationController.value * 4) % 4).floor();
        final String dots = '.' * (dotCount + 1);
        
        return Text(
          '${widget.npcData.name} is thinking$dots',
          style: const TextStyle(
            fontSize: 18,
            fontStyle: FontStyle.italic,
            color: Colors.grey,
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onTap, double size = 28, double padding = 12}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}

class SpeechBubblePainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;

  SpeechBubblePainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final RRect bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 10),
      const Radius.circular(10),
    );

    final Path path = Path()..addRRect(bubbleRect);

    final Path tail = Path();
    tail.moveTo(size.width * 0.5 - 15, size.height - 10);
    tail.lineTo(size.width * 0.5, size.height);
    tail.lineTo(size.width * 0.5 + 15, size.height - 10);
    tail.close();

    path.addPath(tail, Offset.zero);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 