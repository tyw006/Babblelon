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
  final VoidCallback? onGiftIconTap;
  final VoidCallback onResumeGame;
  final VoidCallback onShowTranslation;
  final Widget micControls;
  final bool isProcessingBackend;
  final ScrollController mainDialogueScrollController;
  final VoidCallback onShowHistory;
  final Widget? topRightAction;
  final VoidCallback onToggleEnglish;
  final VoidCallback onToggleTransliteration;
  final VoidCallback onToggleWordAnalysis;
  final bool showEnglish;
  final bool showTransliteration;
  final bool showWordAnalysis;
  final VoidCallback? onReplayAudio;

  const DialogueUI({
    super.key,
    required this.npcData,
    required this.displayedCharmLevel,
    required this.screenWidth,
    required this.screenHeight,
    required this.npcContentWidget,
    required this.giftIconAnimationController,
    required this.onRequestItem,
    this.onGiftIconTap,
    required this.onResumeGame,
    required this.onShowTranslation,
    required this.micControls,
    required this.isProcessingBackend,
    required this.mainDialogueScrollController,
    required this.onShowHistory,
    this.topRightAction,
    required this.onToggleEnglish,
    required this.onToggleTransliteration,
    required this.onToggleWordAnalysis,
    required this.showEnglish,
    required this.showTransliteration,
    required this.showWordAnalysis,
    this.onReplayAudio,
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
                                    onTap: widget.onGiftIconTap ?? widget.onRequestItem,
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
                    widget.npcData.dialoguePortraitPath,
                    height: widget.screenHeight * 0.7,
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
                // Unified speech bubble with integrated controls
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: textboxWidth,
                    height: textboxHeight + 45, // Extra height for control header
                    child: Stack(
                      children: [
                        // Speech bubble background with header
                        CustomPaint(
                          painter: SpeechBubbleWithHeaderPainter(
                            backgroundColor: const Color(0xFFF8F8F8),
                            borderColor: Colors.grey.shade500,
                            borderWidth: 2,
                            headerHeight: 45,
                          ),
                          child: Container(),
                        ),
                        // Control buttons in header area
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 45,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (widget.onReplayAudio != null)
                                  _buildIntegratedControlButton(
                                    icon: Icons.volume_up,
                                    onTap: widget.onReplayAudio,
                                    enabled: true,
                                  ),
                                _buildIntegratedControlButton(
                                  icon: Icons.history_rounded,
                                  onTap: widget.onShowHistory,
                                ),
                                _buildIntegratedToggleButton(
                                  text: "EN",
                                  isActive: widget.showEnglish,
                                  onTap: widget.onToggleEnglish,
                                ),
                                _buildIntegratedToggleButton(
                                  text: "ท",
                                  isActive: widget.showWordAnalysis,
                                  onTap: widget.onToggleWordAnalysis,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Main content area
                        Positioned(
                          top: 45,
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                            child: Scrollbar(
                              controller: widget.mainDialogueScrollController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: widget.mainDialogueScrollController,
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: textboxHeight - 45 - 20, // Adjusted for header
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
                        ),
                      ],
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
                      _buildGiveItemButton(),
                    ],
                  ),
                ),
              ],
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
          color: Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70),
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }

  Widget _buildMiniControlButton({
    required IconData icon, 
    VoidCallback? onTap, 
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(enabled ? 0.5 : 0.3),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled ? Colors.white70 : Colors.white30,
          ),
        ),
        child: Icon(
          icon, 
          color: enabled ? Colors.white : Colors.white30, 
          size: 16,
        ),
      ),
    );
  }

  Widget _buildMiniToggleButton({
    required String text,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive 
            ? Colors.white.withOpacity(0.9)
            : Colors.black.withOpacity(0.3),
          border: Border.all(
            color: isActive ? Colors.white : Colors.white54,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isActive ? Colors.black87 : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlBarButton({
    required IconData icon,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: enabled 
            ? Colors.white.withOpacity(0.15)
            : Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled 
              ? Colors.white.withOpacity(0.6) 
              : Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: enabled 
            ? Colors.white.withOpacity(0.9) 
            : Colors.white.withOpacity(0.4),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildControlBarToggleButton({
    required String text,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive 
            ? Colors.white.withOpacity(0.9)
            : Colors.white.withOpacity(0.15),
          border: Border.all(
            color: isActive 
              ? Colors.white 
              : Colors.white.withOpacity(0.6),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isActive 
                ? Colors.black87 
                : Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntegratedControlButton({
    required IconData icon,
    VoidCallback? onTap,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: enabled 
            ? Colors.grey.shade200
            : Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(
            color: enabled 
              ? Colors.grey.shade400 
              : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: enabled 
            ? Colors.grey.shade700 
            : Colors.grey.shade400,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildIntegratedToggleButton({
    required String text,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive 
            ? Colors.teal.shade600
            : Colors.grey.shade200,
          border: Border.all(
            color: isActive 
              ? Colors.teal.shade700 
              : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: isActive 
                ? Colors.white 
                : Colors.grey.shade700,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGiveItemButton() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.5),
        border: Border.all(color: Colors.white70, width: 1.5),
      ),
      child: InkWell(
        onTap: widget.onRequestItem,
        borderRadius: BorderRadius.circular(28), // Match the circular shape
        child: Center(
          child: Icon(Icons.front_hand, color: Colors.white, size: 24),
        ),
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

class SpeechBubbleWithHeaderPainter extends CustomPainter {
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final double headerHeight;

  SpeechBubbleWithHeaderPainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.borderWidth,
    required this.headerHeight,
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

    final dividerPaint = Paint()
      ..color = borderColor.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Main bubble rect with rounded corners
    final RRect bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height - 10),
      const Radius.circular(12),
    );

    // Create the main path
    final Path path = Path()..addRRect(bubbleRect);

    // Add the tail
    final Path tail = Path();
    tail.moveTo(size.width * 0.5 - 15, size.height - 10);
    tail.lineTo(size.width * 0.5, size.height);
    tail.lineTo(size.width * 0.5 + 15, size.height - 10);
    tail.close();

    path.addPath(tail, Offset.zero);

    // Draw the filled bubble
    canvas.drawPath(path, paint);
    
    // Draw the header divider line
    canvas.drawLine(
      Offset(borderWidth, headerHeight),
      Offset(size.width - borderWidth, headerHeight),
      dividerPaint,
    );
    
    // Draw the border
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
} 