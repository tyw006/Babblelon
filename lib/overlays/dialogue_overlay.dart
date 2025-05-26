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
    'NPC: Hello there, welcome to my stall!', // NPC lines will be identified as Amara
    'Player: I am looking for some delicious dumplings.',
    'NPC: You have come to the right place! We have the best in town.',
    'Player: Great! I will take a dozen.',
    'NPC: Coming right up!',
    'Player: Thanks!',
    'NPC: Enjoy!',
  ];

  // Function to get the speaker from the line
  String _getSpeaker(String line) {
    if (line.startsWith('Player:')) return 'Player';
    if (line.startsWith('NPC:')) return 'Amara'; // Identify NPC as Amara
    return ''; // Default or unknown speaker
  }

  // Function to get the actual dialogue text without the speaker prefix
  String _getDialogueText(String line) {
    if (line.contains(': ')) {
      return line.substring(line.indexOf(': ') + 2);
    }
    return line;
  }

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
    // final String npcName = 'Ploy'; // Removed as NPC name is no longer explicitly used in dialogue text styling

    final double minTextboxHeight = 150.0;
    final double minTextboxWidth = 368.0;
    final double expandedTextboxHeight = math.min(screenHeight * 0.9, 500.0);

    // Target height for the AnimatedContainer, respecting min/max logic
    final double targetAnimatedHeight = _isExpanded
        ? math.max(expandedTextboxHeight, minTextboxHeight)
        : minTextboxHeight;

    // Max height for ConstrainedBox should accommodate the fully expanded state
    final double maxConstrainedHeight = math.max(expandedTextboxHeight, minTextboxHeight);

    final EdgeInsets dialogueListPadding = _isExpanded
      ? const EdgeInsets.only(left: 30.0, top: 10.0, right: 25.0, bottom: 25.0)
      : const EdgeInsets.only(left: 30.0, top: 5.0, right: 25.0, bottom: 25.0);

    return Material(
      color: Colors.transparent, // Ensure transparency if debugging colors are removed
      child: Stack( // Move Stack to be the direct child of Material for full-screen background
        children: <Widget>[
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/convo_yaowarat_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea( // Apply SafeArea only to content that needs to avoid notches/insets
            bottom: false, // Already here, good
            top: true, // Ensure top safe area is respected for UI elements placed near top if any
            child: Stack( // This stack is for the foreground elements
              children: <Widget>[
                // NPC bar image - no changes here unless it needs to respect SafeArea differently
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: screenHeight * 0.002),
                    child: Image.asset(
                      'assets/images/npcs/sprite_dimsum_vendor_bar.png',
                      width: screenWidth * 0.7, // User adjusted this
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment(0.0, 0.0),
                  child: Image.asset(
                    'assets/images/npcs/sprite_dimsum_vendor_female_portrait.png',
                    height: screenHeight * 0.70,
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
                      bottom: MediaQuery.of(context).padding.bottom + 0.0, // Adjusted to move UI further down
                    ),
                    child: Container(
                      color: Colors.transparent,
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
                                image: DecorationImage(
                                  image: AssetImage('assets/images/ui/textbox_hdpi.9.png'), // Changed to 9-patch
                                  fit: BoxFit.fill,
                                  centerSlice: Rect.fromLTWH(22, 22, 324, 229),
                                ),
                              ),
                              child: Stack( // Use Stack to position expand/contract buttons
                                children: [
                                  Column(
                                    children: <Widget>[
                                      Padding(
                                        padding: const EdgeInsets.only(top: 30.0, left: 30.0, right: 30.0),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: dialogueListPadding,
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
                                                        final speaker = _getSpeaker(line);
                                                        final dialogueText = _getDialogueText(line);
                                                        return Padding(
                                                          padding: const EdgeInsets.symmetric(vertical: 4.0), // Increased vertical padding
                                                          child: Column( // Use Column for speaker tag + text
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              if (speaker.isNotEmpty)
                                                                Text(
                                                                  speaker,
                                                                  style: TextStyle(
                                                                    fontWeight: FontWeight.bold,
                                                                    color: speaker == 'Player' ? Colors.blueGrey : Colors.teal, // Example colors
                                                                    fontSize: 14,
                                                                  ),
                                                                ),
                                                              SizedBox(height: 2), // Space between name and text
                                                              Text(
                                                                dialogueText,
                                                                textAlign: TextAlign.left,
                                                                style: TextStyle(
                                                                  color: Colors.black,
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                            ],
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
                                    ],
                                  ),
                                  Positioned(
                                    top: 0, // Adjust to be slightly above the textbox border
                                    right: 30, // Adjust horizontal position as needed
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min, // To make buttons touch
                                      children: [
                                        SizedBox(
                                          width: 25,
                                          height: 25,
                                          child: IconButton(
                                            icon: Image.asset('assets/images/ui/button_arrow.png', width: 30, height: 30),
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints(),
                                            onPressed: () {
                                              setState(() {
                                                _isExpanded = true;
                                              });
                                            },
                                          ),
                                        ),
                                        SizedBox(
                                          width: 25,
                                          height: 25,
                                          child: IconButton(
                                            icon: Transform(
                                              alignment: Alignment.center,
                                              transform: Matrix4.rotationX(math.pi), // Flip vertically
                                              child: Image.asset('assets/images/ui/button_arrow.png', width: 30, height: 30),
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: BoxConstraints(),
                                            onPressed: () {
                                              setState(() {
                                                _isExpanded = false;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
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
        ],
      ),
    );
  }
} 