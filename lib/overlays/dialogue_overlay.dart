import 'dart:math' as math; // Added for math.min
import 'package:flutter/material.dart';
import '../game/babblelon_game.dart';

// Convert to StatefulWidget to manage isExpanded state
class DialogueOverlay extends StatefulWidget {
  final BabblelonGame game;
  const DialogueOverlay({Key? key, required this.game}) : super(key: key);

  @override
  _DialogueOverlayState createState() => _DialogueOverlayState();
}

class _DialogueOverlayState extends State<DialogueOverlay> {
  bool _isExpanded = false; // State for textbox expansion
  final ScrollController _scrollController = ScrollController(); // For auto-scrolling

  // Dummy list of dialogue lines - replace with actual game state
  List<String> _dialogueLines = [
    'Player: Hi! What do you have today?',
    'NPC: Hello there, welcome to my stall!',
    'Player: I am looking for some delicious dumplings.',
    'NPC: You have come to the right place! We have the best in town.',
    'Player: Great! I will take a dozen.',
    'NPC: Coming right up!',
    'Player: Thanks!',
    'NPC: Enjoy!',
  ];

  @override
  void initState() {
    super.initState();
    // After the first frame, position the scroll at the end so text starts bottom-aligned
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Always scroll to the bottom on first load to show the latest messages
        final double offset = _scrollController.position.maxScrollExtent;
        _scrollController.jumpTo(offset);
      }
    });
    // Example: Add a new line and scroll to bottom after a delay
    // Future.delayed(Duration(seconds: 2), () {
    //   if (mounted) {
    //     setState(() {
    //       _dialogueLines.insert(0, "NPC: Here are some more thoughts..."); // Insert at start for reverse list
    //     });
    //     _scrollToBottom();
    //   }
    // });
  }

  void _scrollToEnd() { // Renamed and updated for conditional reverse
    if (_scrollController.hasClients) {
      final position = !_isExpanded // When collapsed, reverse is true
          ? _scrollController.position.minScrollExtent // Scroll to top of reversed list (visual bottom)
          : _scrollController.position.maxScrollExtent; // Scroll to bottom of normal list
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _showTranslationDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Translate to Thai'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Enter text to translate:'),
                const TextField(
                  decoration: InputDecoration(
                    hintText: 'Type here...',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Translate'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double outerHorizontalPadding = screenWidth * 0.01;
    final String npcName = 'Ploy';

    final double minTextboxHeight = 200.0;
    final double minTextboxWidth = 368.0;
    final double collapsedTextboxHeight = 200.0;
    final double expandedTextboxHeight = math.min(screenHeight * 0.9, 500.0);

    // Target height for the AnimatedContainer, respecting min/max logic
    final double targetAnimatedHeight = _isExpanded
        ? math.max(expandedTextboxHeight, minTextboxHeight)
        : math.max(collapsedTextboxHeight, minTextboxHeight);

    // Max height for ConstrainedBox should accommodate the fully expanded state
    final double maxConstrainedHeight = math.max(expandedTextboxHeight, minTextboxHeight);

    final EdgeInsets dialogueListPadding = _isExpanded
      ? const EdgeInsets.only(left: 30.0, top: 10.0, right: 15.0, bottom: 25.0) // Expanded padding, increased bottom to 25.0
      : const EdgeInsets.only(left: 30.0, top: 5.0, right: 15.0, bottom: 25.0); // Collapsed padding, increased bottom to 25.0

    return Material(
      color: Colors.transparent, // Ensure transparency if debugging colors are removed
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: Image.asset(
                'assets/images/background/convo_yaowarat_bg.png',
                fit: BoxFit.cover,
              ),
            ),
            Align(
              alignment: Alignment(0.0, -0.5),
              child: Image.asset(
                'assets/images/npcs/sprite_dimsum_vendor_female_portrait.png',
                height: screenHeight * 0.80,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: EdgeInsets.only(
                  left: outerHorizontalPadding,
                  right: outerHorizontalPadding,
                  bottom: MediaQuery.of(context).padding.bottom + 10.0,
                ),
                child: Container( // DEBUG: visualize horizontal padding area (can be removed)
                  color: Colors.blue.withOpacity(0.0), // Set opacity to 0.0 to hide debug color
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minWidth: minTextboxWidth,
                          minHeight: minTextboxHeight, // Enforce minimum height
                          maxHeight: maxConstrainedHeight, // Allow space for full expansion
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut, // Added for smoother animation
                          width: math.max(screenWidth * 0.95, minTextboxWidth),
                          height: targetAnimatedHeight, // This height drives the animation
                          clipBehavior: Clip.hardEdge, // Added to ensure text clipping
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.0), // DEBUG: Set opacity to 0.0 to hide
                            image: DecorationImage(
                              image: AssetImage('assets/images/ui/textbox_hdpi.9.png'), // Changed to 9-patch
                              fit: BoxFit.fill,
                              centerSlice: Rect.fromLTWH(22, 22, 324, 229),
                            ),
                          ),
                          child: Column(
                            children: <Widget>[
                              SizedBox(height: 30.0), // Spacer to move header row lower
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 0.0),
                                child: Stack(
                                  children: [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        npcName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.black, // Ensure NPC name is clearly visible
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: IconButton(
                                        icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                                        iconSize: 24.0, // Explicit icon size
                                        padding: EdgeInsets.zero, // Remove default padding
                                        constraints: const BoxConstraints(), // Allow button to shrink
                                        color: Colors.black54,
                                        onPressed: () {
                                          setState(() {
                                            _isExpanded = !_isExpanded;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: dialogueListPadding,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 10.0), // Shift scrollbar left
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return Scrollbar(
                                          thumbVisibility: true,
                                          controller: _scrollController,
                                          child: SingleChildScrollView(
                                            controller: _scrollController,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                minHeight: constraints.maxHeight,
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: _dialogueLines.map((line) {
                                                  return Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                                    child: Text(
                                                      line,
                                                      textAlign: TextAlign.left,
                                                      style: TextStyle(
                                                        color: line.startsWith('$npcName:') ? Colors.black : Colors.black54,
                                                        fontSize: 16,
                                                      ),
                                                    ),
                                                  );
                                                }).toList(),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: SizedBox(
                              width: 70,
                              height: 70,
                              child: Image.asset(
                                'assets/images/ui/button_back.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            onPressed: () {
                              widget.game.overlays.remove('dialogue');
                              widget.game.resumeGame();
                            },
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: SizedBox(
                              width: 90,
                              height: 90,
                              child: Image.asset(
                                'assets/images/ui/button_mic.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            onPressed: () {},
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: SizedBox(
                              width: 80,
                              height: 80,
                              child: Image.asset(
                                'assets/images/ui/button_translate.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            onPressed: () => _showTranslationDialog(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 