import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../providers/game_providers.dart';
import '../providers/tutorial_database_providers.dart' as tutorial_db;
import '../models/npc_data.dart';
import '../widgets/popups/tutorial_popup_widget.dart';

enum TutorialTrigger {
  // Existing triggers (kept for backward compatibility)
  startAdventure,
  firstDialogue,
  bossPortal,
  bossFight,
  mainMenu,
  npcInteraction,
  premiumFeatures,
  
  // New universal triggers (map-agnostic, first-time only)
  firstGameEntry,           // Very first app launch
  firstVoiceInteraction,    // First microphone use anywhere
  firstMapNavigation,       // First time in any game map
  firstDialogueAnalysis,    // First dialogue with advanced features (POS, transliteration)
  firstCharacterTracing,    // First tracing attempt anywhere
  firstBossApproach,        // First time approaching any boss portal without items
  firstBossBattle,          // First battle with any boss
  firstCharmMilestone,      // First time reaching charm thresholds (60, 100)
  firstItemEligibility,     // First time eligible for any item
  firstSpecialItem,         // First special item unlock anywhere
  
  // Additional missing triggers
  firstNpcApproach,         // First time getting near any NPC
  firstDialogueSession,     // First time opening dialogue overlay
  firstNpcResponse,         // First time seeing NPC response modal
  firstLanguageTools,       // First time accessing language tools dialog
}

class TutorialVisual {
  final String type; // 'icon', 'image', 'widget'
  final dynamic data; // IconData, String (asset path), or Widget
  final String? label;
  final double? size;

  const TutorialVisual({
    required this.type,
    required this.data,
    this.label,
    this.size,
  });

  static TutorialVisual itemIcon(String assetPath, String label, {double size = 40}) {
    return TutorialVisual(
      type: 'image',
      data: assetPath,
      label: label,
      size: size,
    );
  }

  static TutorialVisual icon(IconData icon, String label, {double size = 32}) {
    return TutorialVisual(
      type: 'icon',
      data: icon,
      label: label,
      size: size,
    );
  }
}

class TutorialSlide {
  final String title;
  final String content;
  final List<TutorialVisual>? visualElements;
  final IconData? headerIcon;

  const TutorialSlide({
    required this.title,
    required this.content,
    this.visualElements,
    this.headerIcon,
  });
}

class TutorialStep {
  final String id;
  final String title;
  final String content;
  final TutorialTrigger trigger;
  final String? navigationTarget;
  final AppTab? targetTab;
  final Duration? delay;
  final VoidCallback? customAction;
  final List<TutorialVisual>? visualElements;
  final IconData? headerIcon;
  final bool isStandalone;
  final List<TutorialSlide>? slides; // New field for multi-slide tutorials

  const TutorialStep({
    required this.id,
    required this.title,
    required this.content,
    required this.trigger,
    this.navigationTarget,
    this.targetTab,
    this.delay,
    this.customAction,
    this.visualElements,
    this.headerIcon,
    this.isStandalone = false,
    this.slides, // Multi-slide support
  });

  // Helper to check if this tutorial has multiple slides
  bool get isMultiSlide => slides != null && slides!.isNotEmpty;
  
  // Get total slides count (including the main step as first slide)
  int get totalSlides => isMultiSlide ? slides!.length + 1 : 1;
}

class TutorialManager {
  final BuildContext context;
  final WidgetRef ref;
  final String? npcId; // Added NPC context
  bool _skipEntireTutorial = false;
  TutorialTrigger? _currentTutorialTrigger; // Track current tutorial trigger
  
  TutorialManager({required this.context, required this.ref, this.npcId});

  static final List<TutorialStep> tutorialSteps = [
    // Home navigation tutorial - kept as individual steps to preserve navigation functionality
    TutorialStep(
      id: 'blabbybara_intro',
      title: "Hi there! I'm Blabbybara!",
      content: "Welcome to BabbleOn, my friend! I'm Blabbybara, your learning companion, and I'll be right here to help you on your language learning adventure!\n\nBefore we dive into our first level, let me show you around BabbleOn so you know how to navigate and make the most of your learning experience. Ready for a quick tour?",
      trigger: TutorialTrigger.startAdventure,
    ),
    TutorialStep(
      id: 'home_tour',
      title: "This is your Home Base!",
      content: "Here's your Home screen - think of it as your learning dashboard! You can see your progress stats, recent activities, and quick access to continue your learning journey.\n\nThis is where you'll always come back to see how far you've progressed in BabbleOn. Pretty neat, right?",
      trigger: TutorialTrigger.startAdventure,
      targetTab: AppTab.home,
      delay: Duration(milliseconds: 500),
    ),
    TutorialStep(
      id: 'progress_tour',
      title: "Track Your Amazing Progress!",
      content: "This Progress screen is one of my favorites! Here you can see all your achievements, vocabulary mastered, and learning streaks.\n\nI love watching learners see their progress grow over time - it's so motivating! You'll be amazed at how much you accomplish.",
      trigger: TutorialTrigger.startAdventure,
      targetTab: AppTab.home,
      delay: Duration(milliseconds: 500),
    ),
    TutorialStep(
      id: 'premium_tour',
      title: "Discover Premium Adventures!",
      content: "The Premium section unlocks additional levels, exclusive content, and advanced learning features beyond your current adventure.\n\nIf you want to explore more locations and dive deeper into language and culture, this is where you'll find those exciting opportunities!",
      trigger: TutorialTrigger.startAdventure,
      targetTab: AppTab.learn,
      delay: Duration(milliseconds: 500),
    ),
    TutorialStep(
      id: 'settings_tour',
      title: "Customize Your Experience!",
      content: "In Settings, you can adjust music, sound effects, and other preferences to make BabbleOn perfect for your learning style.\n\nI personally recommend keeping the sound on - the authentic Thai environment sounds really help with immersion!",
      trigger: TutorialTrigger.startAdventure,
      targetTab: AppTab.settings,
      delay: Duration(milliseconds: 500),
    ),
    TutorialStep(
      id: 'learn_return',
      title: "Now, Let's Choose Your Adventure!",
      content: "Perfect! Now that you know your way around BabbleOn, let's get you set up for your first adventure. You'll choose your language (Thai is available now) and pick your character.\n\nOnce you make your selections, we'll head to your first level where the real fun begins!",
      trigger: TutorialTrigger.startAdventure,
      targetTab: AppTab.learn,
      delay: Duration(milliseconds: 500),
    ),
    // Dialogue system tutorials (split into slides)
    TutorialStep(
      id: 'charm_explanation',
      title: "Let me explain Charm!",
      content: "That colorful bar shows your charm with this vendor!",
      trigger: TutorialTrigger.firstDialogue,
      slides: [
        TutorialSlide(
          title: "How Charm Works",
          content: "Better Thai pronunciation = Higher charm!\nClear speech and good word choice impress vendors.",
          headerIcon: Icons.favorite,
        ),
        TutorialSlide(
          title: "Charm = Rewards!",
          content: "Higher charm means better rewards!\nIt's like making friends - they want to help you succeed!",
          headerIcon: Icons.card_giftcard,
        ),
      ],
    ),
    TutorialStep(
      id: 'item_types',
      title: "Battle Items Explained!",
      content: "Vendors offer magical items for boss battles!",
      trigger: TutorialTrigger.firstDialogue,
      slides: [
        TutorialSlide(
          title: "Attack Items ⚔️",
          content: "These deal damage to bosses!\nEquip one to boost your offensive power.",
          headerIcon: Icons.flash_on,
        ),
        TutorialSlide(
          title: "Defense Items 🛡️",
          content: "These protect you from boss attacks!\nEquip one to reduce incoming damage.",
          headerIcon: Icons.shield,
        ),
        TutorialSlide(
          title: "You Need Both!",
          content: "Collect BOTH types before facing bosses.\nI'll be cheering you on!",
          headerIcon: Icons.sports_martial_arts,
        ),
      ],
      visualElements: [], // Will be populated dynamically with NPC items
    ),
    TutorialStep(
      id: 'regular_vs_special',
      title: "Item Tiers Revealed!",
      content: "Each vendor has TWO item tiers!",
      trigger: TutorialTrigger.firstDialogue,
      slides: [
        TutorialSlide(
          title: "Regular Items",
          content: "Available at 60+ charm.\nGood for starting boss battles!",
          headerIcon: Icons.star_border,
        ),
        TutorialSlide(
          title: "Special Items ✨",
          content: "Unlocked at 100 charm!\nGolden effects = MUCH more powerful!",
          headerIcon: Icons.star,
        ),
        TutorialSlide(
          title: "Worth the Effort!",
          content: "Special items pack a bigger punch!\nLike finding treasure in BabbleOn!",
          headerIcon: Icons.emoji_events,
        ),
      ],
      visualElements: [], // Will be populated dynamically with NPC items
    ),
    // Boss portal approach tutorial (shortened with slides)
    TutorialStep(
      id: 'portal_approach',
      title: "Boss Portal Ahead!",
      content: "Whoa there! That swirling portal leads to a boss battle. Let me explain what you need!",
      trigger: TutorialTrigger.bossPortal,
      headerIcon: Icons.warning_amber_rounded,
      slides: [
        TutorialSlide(
          title: "Equipment Required!",
          content: "To enter the portal, you need BOTH:\n⚔️ An Attack Item\n🛡️ A Defense Item\n\nThese protect you in boss battles!",
          visualElements: [
            TutorialVisual.itemIcon('assets/images/items/steambun_regular.png', 'Attack'),
            TutorialVisual.itemIcon('assets/images/items/porkbelly_regular.png', 'Defense'),
          ],
        ),
        TutorialSlide(
          title: "How to Get Items",
          content: "Talk to the friendly vendors around town! Build charm by speaking Thai well, and they'll give you items when you reach 60+ charm.",
          headerIcon: Icons.chat_bubble,
        ),
        TutorialSlide(
          title: "Ready to Enter!",
          content: "Once you have both items equipped, tap the portal to face the boss. Good luck!",
          headerIcon: Icons.sports_martial_arts,
        ),
      ],
      isStandalone: true,
    ),
    // Boss fight tutorial (now combined into multi-slide)
    TutorialStep(
      id: 'boss_fight_intro',
      title: "Your First Boss Battle!",
      content: "Welcome to your first boss battle! I'll guide you through everything you need to know to succeed.\n\nThis is where your Thai pronunciation skills will be put to the test. The better you speak, the stronger your attacks and defense will be!",
      trigger: TutorialTrigger.bossFight,
      headerIcon: Icons.casino_outlined,
      visualElements: [
        TutorialVisual.icon(Icons.mic, 'Speak Clearly'),
        TutorialVisual.icon(Icons.flash_on, 'Strong Attacks'),
        TutorialVisual.icon(Icons.shield, 'Better Defense'),
      ],
      slides: [
        TutorialSlide(
          title: "Pronunciation Assessment Magic!",
          content: "Here's the secret to winning battles: Your pronunciation accuracy determines your battle power!\n\nWhen you speak Thai words clearly, the game assesses your pronunciation and converts it into attack/defense strength. Poor pronunciation = weaker moves, while excellent pronunciation = devastating attacks!",
          headerIcon: Icons.record_voice_over,
          visualElements: [
            TutorialVisual.icon(Icons.volume_up, 'Clear Speech'),
            TutorialVisual.icon(Icons.trending_up, 'Higher Accuracy'),
            TutorialVisual.icon(Icons.bolt, 'More Damage'),
          ],
        ),
        TutorialSlide(
          title: "Flashcard Battle Strategy!",
          content: "You'll see Thai vocabulary flashcards during battle. Here's how to use them effectively:\n\n1. Read the Thai text carefully\n2. Speak it clearly into your microphone\n3. The pronunciation assessment powers your attack/defense\n4. Take your time - quality over speed wins battles!\n\nRemember: Good pronunciation = victory in BabbleOn!",
          headerIcon: Icons.style,
          visualElements: [
            TutorialVisual.icon(Icons.visibility, 'Read Thai'),
            TutorialVisual.icon(Icons.mic, 'Speak Clearly'),
            TutorialVisual.icon(Icons.timer, 'Take Your Time'),
          ],
        ),
        TutorialSlide(
          title: "Battle Mathematics Revealed!",
          content: "Here's exactly how boss battles work:\n\n• Your pronunciation accuracy (0-100%) directly affects damage/defense\n• Attack items multiply your damage potential\n• Defense items reduce incoming boss damage\n• Better items = bigger multipliers\n• Consistent pronunciation > perfect pronunciation\n\nStrategy tip: Focus on clear, steady pronunciation rather than rushing through words!",
          headerIcon: Icons.calculate,
          visualElements: [
            TutorialVisual.icon(Icons.functions, 'Damage Formula'),
            TutorialVisual.icon(Icons.shield, 'Defense Math'),
            TutorialVisual.icon(Icons.speed, 'Consistency Wins'),
          ],
        ),
      ],
    ),
    
    // === NEW UNIVERSAL TUTORIALS (Map-Agnostic, First-Time Only) ===
    
    // Game initialization tutorial (shortened and split into slides)
    TutorialStep(
      id: 'game_loading_intro',
      title: "Welcome to BabbleOn!",
      content: "Let's learn Thai through adventure! I'll show you how to play.",
      trigger: TutorialTrigger.firstGameEntry,
      headerIcon: Icons.explore,
      slides: [
        TutorialSlide(
          title: "How to Move",
          content: "Tap LEFT side to move left ←\nTap RIGHT side to move right →\n\nSimple as that!",
          headerIcon: Icons.touch_app,
          visualElements: [
            TutorialVisual.icon(Icons.arrow_back, 'Left'),
            TutorialVisual.icon(Icons.arrow_forward, 'Right'),
          ],
        ),
        TutorialSlide(
          title: "Find NPCs to Chat!",
          content: "Look for glowing speech bubbles above characters. Tap them to practice Thai conversation!",
          headerIcon: Icons.chat_bubble,
          visualElements: [
            TutorialVisual.icon(Icons.people, 'NPCs'),
            TutorialVisual.icon(Icons.record_voice_over, 'Voice'),
          ],
        ),
        TutorialSlide(
          title: "Build Charm & Get Items",
          content: "Speaking Thai well builds charm with NPCs. At 60+ charm, they'll give you items for boss battles!",
          headerIcon: Icons.favorite,
          visualElements: [
            TutorialVisual.icon(Icons.trending_up, 'Charm'),
            TutorialVisual.icon(Icons.card_giftcard, 'Items'),
          ],
        ),
      ],
      isStandalone: true,
    ),
    
    // Voice interaction tutorials
    TutorialStep(
      id: 'voice_setup_guide',
      title: "Let's Set Up Your Voice!",
      content: "BabbleOn uses advanced speech recognition to assess your Thai pronunciation. For the best experience:\n\n• Find a quiet environment\n• Hold your device 6-12 inches from your mouth\n• Speak clearly and naturally\n• Don't worry about perfection - the AI is here to help you improve!\n\nYour microphone permission helps us provide real-time pronunciation feedback.",
      trigger: TutorialTrigger.firstVoiceInteraction,
      headerIcon: Icons.settings_voice,
      visualElements: [
        TutorialVisual.icon(Icons.mic, 'Clear Audio'),
        TutorialVisual.icon(Icons.volume_up, 'Good Distance'),
        TutorialVisual.icon(Icons.trending_up, 'Practice Makes Perfect'),
      ],
      isStandalone: true,
    ),
    
    
    // Advanced dialogue system tutorials
    TutorialStep(
      id: 'pos_color_system',
      title: "Word Colors Explained!",
      content: "Notice the colorful words in Thai sentences? Each color represents a different part of speech to help you understand Thai grammar:\n\n🔴 Red: Nouns (people, places, things)\n🟢 Green: Verbs (actions)\n🟠 Orange: Adjectives (descriptions)\n🔵 Blue: Other parts of speech\n\nThis color coding helps you see Thai sentence patterns and improve your grammar understanding!",
      trigger: TutorialTrigger.firstDialogueAnalysis,
      headerIcon: Icons.palette,
      visualElements: [
        TutorialVisual.icon(Icons.circle, 'Nouns', ),
        TutorialVisual.icon(Icons.circle, 'Verbs'),
        TutorialVisual.icon(Icons.circle, 'Adjectives'),
      ],
      isStandalone: true,
    ),
    
    TutorialStep(
      id: 'transliteration_system',
      title: "Thai Romanization Helper!",
      content: "Struggling with Thai script? The romanization (English letters) below Thai text shows you how to pronounce each word!\n\nThis isn't just any romanization - it's specially designed for English speakers learning Thai. The system helps you bridge from familiar English sounds to authentic Thai pronunciation.\n\nUse it as training wheels, but try to focus more on the Thai script as you improve!",
      trigger: TutorialTrigger.firstDialogueAnalysis,
      headerIcon: Icons.translate,
      visualElements: [
        TutorialVisual.icon(Icons.abc, 'Pronunciation Guide'),
        TutorialVisual.icon(Icons.school, 'Learning Bridge'),
        TutorialVisual.icon(Icons.visibility, 'Script Focus'),
      ],
      isStandalone: true,
    ),
    
    TutorialStep(
      id: 'pronunciation_confidence_guide',
      title: "Your Pronunciation Score!",
      content: "After you speak, you'll see a confidence score showing how accurately you pronounced the Thai words. This isn't about perfection - it's about progress!\n\n• 0-50%: Keep practicing, you're learning!\n• 50-75%: Good progress, minor tweaks needed\n• 75-90%: Great pronunciation!\n• 90%+: Native-level accuracy!\n\nDon't worry about low scores at first - every Thai learner starts here!",
      trigger: TutorialTrigger.firstVoiceInteraction,
      headerIcon: Icons.assessment,
      visualElements: [
        TutorialVisual.icon(Icons.trending_up, 'Progress Tracking'),
        TutorialVisual.icon(Icons.star, 'Accuracy Goals'),
        TutorialVisual.icon(Icons.psychology, 'Learning Process'),
      ],
      isStandalone: true,
    ),
    
    // Character tracing tutorial (consolidated)
    TutorialStep(
      id: 'character_tracing_tutorial',
      title: "Thai Character Tracing Master! ✍️",
      content: "Welcome to BabbleOn's advanced character tracing system! Here's what makes it special:\n\n🤖 AI-Powered Recognition: Machine learning analyzes your stroke patterns in real-time\n✍️ Proper Technique: Stroke order and proportions matter for readable Thai handwriting\n📚 Smart Assessment: The system checks stroke sequence, character proportions, and recognition accuracy\n\nThe AI has learned from thousands of Thai writing samples and provides instant feedback. Take your time, follow the guides, and remember - Thai writing is an art that improves with practice!",
      trigger: TutorialTrigger.firstCharacterTracing,
      headerIcon: Icons.auto_awesome,
      visualElements: [
        TutorialVisual.icon(Icons.psychology, 'AI Learning'),
        TutorialVisual.icon(Icons.format_list_numbered, 'Stroke Order'),
        TutorialVisual.icon(Icons.check_circle, 'Smart Assessment'),
      ],
      isStandalone: true,
    ),
    
    // Boss battle enhancements
    TutorialStep(
      id: 'boss_prerequisites_warning',
      title: "Boss Battle Requirements!",
      content: "Hold on there, brave adventurer! To enter a boss battle, you need to be properly equipped with BOTH types of items:\n\n⚔️ Attack Item: For dealing damage to the boss\n🛡️ Defense Item: For protecting yourself from boss attacks\n\nExplore the area and chat with local NPCs to collect both item types before approaching any boss portal!",
      trigger: TutorialTrigger.firstBossApproach,
      headerIcon: Icons.warning_amber,
      visualElements: [
        TutorialVisual.itemIcon('assets/images/items/steambun_regular.png', 'Attack Required'),
        TutorialVisual.itemIcon('assets/images/items/porkbelly_regular.png', 'Defense Required'),
      ],
      isStandalone: true,
    ),
    
    // Item system tutorials
    TutorialStep(
      id: 'charm_thresholds_explained',
      title: "Charm Milestone Reached!",
      content: "Congratulations! You've reached an important charm milestone! Here's what charm levels mean:\n\n• 60+ Charm: You can request the regular item from this NPC\n• 100 Charm: You unlock the special (golden) item - much more powerful!\n\nCharm represents how impressed the NPC is with your Thai skills. Higher pronunciation accuracy and engaging conversation build charm faster!",
      trigger: TutorialTrigger.firstCharmMilestone,
      headerIcon: Icons.favorite,
      visualElements: [
        TutorialVisual.icon(Icons.star_border, '60+ Regular'),
        TutorialVisual.icon(Icons.star, '100 Special'),
        TutorialVisual.icon(Icons.trending_up, 'Skill Progress'),
      ],
      isStandalone: true,
    ),
    
    TutorialStep(
      id: 'item_giving_tutorial',
      title: "Ready to Receive Your First Item!",
      content: "Great job building charm! You can now request an item from this NPC. Here's how it works:\n\n• Look for the gift icon in the conversation interface\n• Tap it to make your request\n• The NPC will give you their item and end the conversation\n• Items equip automatically and help in boss battles\n\nDecision time: Take the regular item now, or keep chatting to reach 100 charm for the special item?",
      trigger: TutorialTrigger.firstItemEligibility,
      headerIcon: Icons.card_giftcard,
      visualElements: [
        TutorialVisual.icon(Icons.touch_app, 'Tap Gift Icon'),
        TutorialVisual.icon(Icons.inventory, 'Auto-Equip'),
        TutorialVisual.icon(Icons.psychology, 'Strategic Choice'),
      ],
      isStandalone: true,
    ),
    
    TutorialStep(
      id: 'special_item_celebration',
      title: "Special Item Unlocked! 🌟",
      content: "AMAZING! You've unlocked your first special (golden) item! These are the most powerful items in BabbleOn, reserved for players who demonstrate excellent Thai language skills.\n\nSpecial items provide significantly stronger battle bonuses than regular items. This achievement shows your dedication to learning Thai - you should be proud of reaching maximum charm!\n\nKeep up this level of excellence as you continue your adventure!",
      trigger: TutorialTrigger.firstSpecialItem,
      headerIcon: Icons.emoji_events,
      visualElements: [
        TutorialVisual.icon(Icons.star, 'Special Power'),
        TutorialVisual.icon(Icons.trending_up, 'Elite Status'),
        TutorialVisual.icon(Icons.celebration, 'Achievement'),
      ],
      isStandalone: true,
    ),

    // === NEW MISSING TUTORIAL STEPS ===
    
    // First NPC Approach Tutorial
    TutorialStep(
      id: 'first_npc_interaction',
      title: "Meet the Locals! 👋",
      content: "You've discovered your first NPC (Non-Player Character)! These friendly locals are scattered throughout the area and are eager to chat with you in your target language.\n\nLook for NPCs with speech bubbles above their heads - this means they're ready to talk. Simply tap on them to start a conversation.\n\nEach NPC has unique stories, vocabulary, and can give you special items to help in boss battles. Get ready to make some language-learning friends!",
      trigger: TutorialTrigger.firstNpcApproach,
      headerIcon: Icons.person_pin_circle,
      visualElements: [
        TutorialVisual.icon(Icons.people, 'Friendly Locals'),
        TutorialVisual.icon(Icons.chat_bubble, 'Speech Bubbles'),
        TutorialVisual.icon(Icons.touch_app, 'Tap to Chat'),
      ],
      isStandalone: true,
    ),

    // First Dialogue Session Tutorial  
    TutorialStep(
      id: 'first_dialogue_session',
      title: "Your Thai Conversation Begins! 💬",
      content: "Welcome to BabbleOn's dialogue system! This is where the magic happens - you'll have real conversations in Thai with voice interaction.\n\nHere's what you can do:\n• Press the microphone to speak Thai\n• See English translations and romanization\n• Get pronunciation feedback\n• Practice character tracing\n\nDon't worry about making mistakes - that's how you learn! The NPC will be patient and helpful.",
      trigger: TutorialTrigger.firstDialogueSession,
      headerIcon: Icons.record_voice_over,
      visualElements: [
        TutorialVisual.icon(Icons.mic, 'Voice Input'),
        TutorialVisual.icon(Icons.translate, 'Translations'),
        TutorialVisual.icon(Icons.feedback, 'Feedback'),
      ],
      isStandalone: true,
    ),

    // First NPC Response Modal Tutorial
    TutorialStep(
      id: 'first_npc_response_tutorial',
      title: "NPC Response & Practice! 🎯",
      content: "Great job speaking Thai! This response modal shows you how well you did and gives you chances to improve.\n\nFeatures you'll see:\n• Pronunciation confidence scores\n• Word-by-word feedback with colors\n• Practice mode for difficult words\n• Romanization to help with pronunciation\n\nDon't worry if you don't get it perfect the first time - every attempt makes you better at Thai!",
      trigger: TutorialTrigger.firstNpcResponse,
      headerIcon: Icons.assessment,
      visualElements: [
        TutorialVisual.icon(Icons.score, 'Confidence Scores'),
        TutorialVisual.icon(Icons.palette, 'Color Feedback'),
        TutorialVisual.icon(Icons.repeat, 'Practice Mode'),
      ],
      isStandalone: true,
    ),


    // Language Tools Tutorial
    TutorialStep(
      id: 'first_language_tools_tutorial',
      title: "Language Tools Unlocked! 🛠️",
      content: "Welcome to BabbleOn's powerful Language Tools! This special feature gives you advanced learning capabilities:\n\n📝 TRANSLATION: Type English phrases and get Thai translations with pronunciation\n✍️ CHARACTER TRACING: Practice writing Thai characters with AI-powered feedback\n🎁 CUSTOM ITEMS: Create personalized vocabulary items for NPCs\n\nThese tools help you go beyond conversation - you can explore Thai writing, create custom content, and get detailed translations. Perfect for when you want to dive deeper into the language!",
      trigger: TutorialTrigger.firstLanguageTools,
      headerIcon: Icons.build,
      visualElements: [
        TutorialVisual.icon(Icons.translate, 'Translation Tools'),
        TutorialVisual.icon(Icons.edit, 'Character Tracing'),
        TutorialVisual.icon(Icons.inventory, 'Custom Content'),
      ],
      isStandalone: true,
    ),
  ];

  Future<void> startTutorial(TutorialTrigger trigger) async {
    final steps = tutorialSteps.where((step) => step.trigger == trigger).toList();
    _skipEntireTutorial = false; // Reset skip flag
    _currentTutorialTrigger = trigger; // Track current tutorial
    
    debugPrint('Tutorial: Starting tutorial for trigger: $trigger');
    debugPrint('Tutorial: Found ${steps.length} steps for this trigger');
    
    // Check if any steps for this trigger are already completed (using fast cache lookup)
    final completedSteps = <String>[];
    
    for (final step in steps) {
      final isCompleted = ref.read(tutorial_db.tutorialCompletionProvider.notifier).isTutorialCompleted(step.id);
      if (isCompleted) {
        completedSteps.add(step.id);
      }
    }
    
    // Filter out completed steps
    final remainingSteps = steps.where((step) => !completedSteps.contains(step.id)).toList();
    
    if (remainingSteps.isEmpty) {
      debugPrint('Tutorial: All steps for trigger $trigger are already completed, skipping tutorial');
      return;
    }
    
    debugPrint('Tutorial: ${completedSteps.length} steps already completed, showing ${remainingSteps.length} remaining steps');
    
    for (int i = 0; i < remainingSteps.length; i++) {
      final step = _enhanceStepWithNpcContext(remainingSteps[i]);
      
      // Check if user requested to skip entire tutorial
      if (_skipEntireTutorial) {
        break;
      }
      
      // Update current tutorial step safely
      if (context.mounted) {
        try {
          ref.read(currentTutorialStepProvider.notifier).state = step.id;
        } catch (e) {
          // Context might be disposed, skip tutorial
          return;
        }
      } else {
        return;
      }
      
      // Navigate to target tab if specified (for interactive navigation)
      if (step.targetTab != null && context.mounted) {
        try {
          // Use a delay to ensure context is stable before navigation
          await Future.delayed(const Duration(milliseconds: 100));
          if (context.mounted) {
            ref.read(navigationControllerProvider).switchToTab(step.targetTab!);
            if (step.delay != null) {
              await Future.delayed(step.delay!);
            }
          }
        } catch (e) {
          // Navigation context might be disposed, skip this step
          continue;
        }
      }
      
      // Execute custom action if specified
      if (step.customAction != null) {
        step.customAction!();
      }
      
      // Show tutorial popup and wait for user interaction
      if (context.mounted) {
        try {
          await _showTutorialPopup(step, i == remainingSteps.length - 1);
          
          // Check again if user skipped during popup
          if (_skipEntireTutorial) {
            break;
          }
          
          // Mark step as completed
          if (context.mounted) {
            ref.read(tutorial_db.tutorialProgressProvider.notifier).markStepCompleted(step.id);
          }
        } catch (e) {
          // Context disposed during popup, exit tutorial
          break;
        }
      } else {
        break;
      }
    }
    
    // Clear current step when tutorial is complete
    if (context.mounted) {
      try {
        ref.read(currentTutorialStepProvider.notifier).state = null;
      } catch (e) {
        // Context disposed, ignore
      }
    }
  }

  Future<void> _showTutorialPopup(TutorialStep step, bool isLastStep) async {
    final completer = Completer<void>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.1),
      builder: (BuildContext context) {
        return TutorialPopup(
          step: step,
          isLastStep: isLastStep,
          onNext: () {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onSkipEntireTutorial: () {
            _skipTutorial();
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
        );
      },
    );
    return completer.future;
  }
  
  void _skipTutorial() {
    _skipEntireTutorial = true;
    
    // Only mark tutorial steps as completed if we're actually skipping an active tutorial
    // Check if there's a current tutorial step active to prevent false completions
    if (context.mounted) {
      final currentStep = ref.read(currentTutorialStepProvider);
      
      // Only mark steps as completed if there's actually a tutorial active and we know which trigger
      if (currentStep != null && _currentTutorialTrigger != null) {
        // Get the current tutorial steps that are being skipped (use current trigger, not hardcoded)
        final currentTutorialSteps = tutorialSteps.where((step) => 
          step.trigger == _currentTutorialTrigger!
        ).toList();
        
        // Mark only the steps from the current tutorial as completed
        for (final step in currentTutorialSteps) {
          ref.read(tutorial_db.tutorialProgressProvider.notifier).markStepCompleted(step.id);
        }
        
        debugPrint('Tutorial: Marked ${currentTutorialSteps.length} steps for trigger $_currentTutorialTrigger as completed due to skip');
      } else {
        debugPrint('Tutorial: Skip called but no active tutorial found or no current trigger - not marking steps as completed');
      }
    }
  }
  
  // Enhance tutorial steps with real NPC item data
  TutorialStep _enhanceStepWithNpcContext(TutorialStep step) {
    // Skip NPC item enhancement for certain tutorial types that don't need NPC context
    final skipEnhancementTriggers = {
      TutorialTrigger.bossFight,
      TutorialTrigger.firstGameEntry,
      TutorialTrigger.firstVoiceInteraction,
      TutorialTrigger.firstMapNavigation,
      TutorialTrigger.firstDialogueAnalysis,
      TutorialTrigger.firstCharacterTracing,
      TutorialTrigger.firstBossApproach,
      TutorialTrigger.firstBossBattle,
      TutorialTrigger.firstCharmMilestone,
      TutorialTrigger.firstItemEligibility,
      TutorialTrigger.firstSpecialItem,
      TutorialTrigger.firstNpcApproach,
      TutorialTrigger.firstDialogueSession,
      TutorialTrigger.firstNpcResponse,
      TutorialTrigger.firstLanguageTools,
    };
    
    if (skipEnhancementTriggers.contains(step.trigger)) {
      return step; // These tutorials don't need NPC-specific enhancement
    }
    
    if (npcId == null || step.visualElements == null) {
      return step; // Return original step if no NPC context
    }
    
    final npcData = npcDataMap[npcId];
    if (npcData == null) {
      return step; // Return original step if NPC not found
    }
    
    // Create enhanced visual elements based on step ID
    List<TutorialVisual>? enhancedVisuals;
    
    switch (step.id) {
      case 'item_types':
        // Show actual items from current NPC
        enhancedVisuals = [
          TutorialVisual.itemIcon(npcData.regularItemAsset, '${npcData.regularItemName} (${npcData.regularItemType.toUpperCase()})'),
        ];
        break;
      case 'regular_vs_special':
        // Show both regular and special items from current NPC
        enhancedVisuals = [
          TutorialVisual.itemIcon(npcData.regularItemAsset, 'Regular: ${npcData.regularItemName}'),
          TutorialVisual.itemIcon(npcData.specialItemAsset, 'Special: ${npcData.specialItemName}'),
        ];
        break;
      default:
        enhancedVisuals = step.visualElements; // Keep original visuals
    }
    
    // Return step with enhanced visuals
    return TutorialStep(
      id: step.id,
      title: step.title,
      content: step.content,
      trigger: step.trigger,
      navigationTarget: step.navigationTarget,
      targetTab: step.targetTab,
      delay: step.delay,
      customAction: step.customAction,
      visualElements: enhancedVisuals,
      headerIcon: step.headerIcon,
      isStandalone: step.isStandalone,
    );
  }
}

