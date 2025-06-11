import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/npc_data.dart';
import '../providers/game_providers.dart';
import 'charm_bar.dart';
import '../overlays/dialogue_overlay.dart';

class DialogueUI extends StatelessWidget {
  final NpcData npcData;
  final int displayedCharmLevel;
  final double screenWidth;
  final double screenHeight;
  final Widget npcContentWidget;
  final AnimationController giftIconAnimationController;
  final VoidCallback onRequestItem;
  final VoidCallback onResumeGame;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onShowTranslation;
  final Widget micButton;
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
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onShowTranslation,
    required this.micButton,
    required this.isProcessingBackend,
    required this.mainDialogueScrollController,
    required this.onShowHistory,
    this.topRightAction,
  });

  @override
  Widget build(BuildContext context) {
    final double outerHorizontalPadding = screenWidth * 0.01;
    final double textboxHeight = 150.0;
    final double textboxWidth = math.max(screenWidth * 0.95, 368.0);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(npcData.dialogueBackgroundPath, fit: BoxFit.cover),
          ),
          SafeArea(
            bottom: false,
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
                                final charmNotifier = ref.read(currentCharmLevelProvider(npcData.id).notifier);
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
                            npcId: npcData.id,
                            npcName: npcData.name,
                            maxWidth: screenWidth * 0.75,
                            height: 32,
                            nameFontSize: 28,
                            charmFontSize: 16,
                            trailing: displayedCharmLevel >= 75
                                ? GestureDetector(
                                    onTap: onRequestItem,
                                    child: AnimatedBuilder(
                                      animation: giftIconAnimationController,
                                      builder: (context, child) {
                                        final bool isMaxCharm = displayedCharmLevel >= 100;
                                        final Color glowColor = isMaxCharm ? Colors.yellow.shade700 : Colors.pink.shade400;
                                        final double maxBlur = isMaxCharm ? 20.0 : 12.0;
                                        final double maxSpread = isMaxCharm ? 5.0 : 2.0;
                                        final double glowValue = giftIconAnimationController.value;

                                        return Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withOpacity(0.5),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white70),
                                            boxShadow: [
                                              BoxShadow(
                                                color: glowColor.withOpacity(0.7 * glowValue),
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
                    npcData.dialoguePortraitPath,
                    height: screenHeight * 0.7,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
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
                              controller: mainDialogueScrollController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: mainDialogueScrollController,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: textboxHeight - 24, // Expanded text area
                                  ),
                                  child: Center(
                                    child: npcContentWidget,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (topRightAction != null)
                            topRightAction!,
                          Positioned(
                            bottom: 10,
                            right: 0,
                            child: GestureDetector(
                              onTap: onShowHistory,
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
                        onTap: onResumeGame,
                      ),
                      GestureDetector(
                        onLongPressStart: (_) => onStartRecording(),
                        onLongPressEnd: (_) => onStopRecording(),
                        onLongPressCancel: () => onStopRecording(),
                        child: micButton,
                      ),
                      _buildControlButton(
                        icon: Icons.translate,
                        onTap: onShowTranslation,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isProcessingBackend)
            const Opacity(
              opacity: 0.8,
              child: ModalBarrier(dismissible: false, color: Colors.black),
            ),
          if (isProcessingBackend)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required VoidCallback onTap, double size = 28, double padding = 12}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
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