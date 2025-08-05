import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/navigation_provider.dart';
import '../providers/game_providers.dart';
import '../models/npc_data.dart';
import '../widgets/popups/tutorial_popup_widget.dart';

enum TutorialTrigger {
  startAdventure,
  firstDialogue,
  bossPortal,
  bossFight,
  mainMenu,
  npcInteraction,
  premiumFeatures,
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
  });
}

class TutorialManager {
  final BuildContext context;
  final WidgetRef ref;
  final String? npcId; // Added NPC context
  bool _skipEntireTutorial = false;
  TutorialTrigger? _currentTutorialTrigger; // Track current tutorial trigger
  
  TutorialManager({required this.context, required this.ref, this.npcId});

  static final List<TutorialStep> tutorialSteps = [
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
      targetTab: AppTab.progress,
      delay: Duration(milliseconds: 500),
    ),
    TutorialStep(
      id: 'premium_tour',
      title: "Discover Premium Adventures!",
      content: "The Premium section unlocks additional levels, exclusive content, and advanced learning features beyond our Bangkok adventure.\n\nIf you want to explore more locations and dive deeper into Thai culture, this is where you'll find those exciting opportunities!",
      trigger: TutorialTrigger.startAdventure,
      targetTab: AppTab.premium,
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
    // Bangkok level specific tutorials (triggers when game loads)
    TutorialStep(
      id: 'bangkok_intro',
      title: "Welcome to Bangkok's Yaowarat!",
      content: "Now we're in the exciting Bangkok level! This vibrant Yaowarat night market district is where you'll practice Thai with friendly vendors.\n\nTap the left side of your screen to move left, right side to move right. Look for those glowing speech bubbles - that's where we'll meet the locals and practice your Thai!",
      trigger: TutorialTrigger.npcInteraction,
      isStandalone: true,
    ),
    // Dialogue system tutorials
    TutorialStep(
      id: 'charm_explanation',
      title: "Let me explain Charm!",
      content: "See that colorful bar at the top? That's your charm level with each vendor! The better you speak Thai - with clear pronunciation and good word choice - the more impressed they'll be with you.\n\nI've learned that higher charm means better rewards! Think of it like making friends - the more they like you, the more they want to help you succeed in BabbleOn!",
      trigger: TutorialTrigger.firstDialogue,
    ),
    TutorialStep(
      id: 'item_types',
      title: "Attack vs Defense - My Battle Wisdom!",
      content: "Listen carefully, my friend! These kind vendors offer two types of magical items for the boss battles ahead in BabbleOn:\n\nAttack Items: Perfect for dealing damage to those challenging bosses!\nDefense Items: These will shield you from boss attacks!\n\nTrust me, you'll want both types when we face the level bosses together! I'll be right there cheering you on!",
      trigger: TutorialTrigger.firstDialogue,
      visualElements: [], // Will be populated dynamically with NPC items
    ),
    TutorialStep(
      id: 'regular_vs_special',
      title: "My Secret: Regular vs Special Items!",
      content: "Here's something exciting I've discovered during my time in BabbleOn! Each vendor offers two item tiers:\n\nRegular Items: You can get these once you reach 60+ charm with a vendor\nSpecial Items: These golden beauties need maximum charm (100), but they are incredibly powerful!\n\nI get so excited when I see those golden effects! Special items are like finding treasure in BabbleOn - they pack a much bigger punch in battle!",
      trigger: TutorialTrigger.firstDialogue,
      visualElements: [], // Will be populated dynamically with NPC items
    ),
    // Boss portal approach tutorial
    TutorialStep(
      id: 'portal_approach',
      title: "Boss Portal Ahead!",
      content: "Whoa there, friend! That swirling portal leads to a boss battle!\n\nBefore you can enter, you'll need both an attack item AND a defense item equipped. Talk to the friendly vendors around Yaowarat to collect these magical items:\n\nOnce you have both types equipped, come back and tap the portal to enter!",
      trigger: TutorialTrigger.bossPortal,
      headerIcon: Icons.warning_amber_rounded,
      visualElements: [
        TutorialVisual.itemIcon('assets/images/items/steambun_regular.png', 'Attack Item'),
        TutorialVisual.itemIcon('assets/images/items/porkbelly_regular.png', 'Defense Item'),
      ],
      isStandalone: true,
    ),
    // Boss fight tutorial series
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
    ),
    TutorialStep(
      id: 'pronunciation_system',
      title: "Pronunciation Assessment Magic!",
      content: "Here's the secret to winning battles: Your pronunciation accuracy determines your battle power!\n\nWhen you speak Thai words clearly, the game assesses your pronunciation and converts it into attack/defense strength. Poor pronunciation = weaker moves, while excellent pronunciation = devastating attacks!",
      trigger: TutorialTrigger.bossFight,
      headerIcon: Icons.record_voice_over,
      visualElements: [
        TutorialVisual.icon(Icons.volume_up, 'Clear Speech'),
        TutorialVisual.icon(Icons.trending_up, 'Higher Accuracy'),
        TutorialVisual.icon(Icons.bolt, 'More Damage'),
      ],
    ),
    TutorialStep(
      id: 'flashcard_battle_system',
      title: "Flashcard Battle Strategy!",
      content: "You'll see Thai vocabulary flashcards during battle. Here's how to use them effectively:\n\n1. Read the Thai text carefully\n2. Speak it clearly into your microphone\n3. The pronunciation assessment powers your attack/defense\n4. Take your time - quality over speed wins battles!\n\nRemember: Good pronunciation = victory in BabbleOn!",
      trigger: TutorialTrigger.bossFight,
      headerIcon: Icons.style,
      visualElements: [
        TutorialVisual.icon(Icons.visibility, 'Read Thai'),
        TutorialVisual.icon(Icons.mic, 'Speak Clearly'),
        TutorialVisual.icon(Icons.timer, 'Take Your Time'),
      ],
    ),
  ];

  Future<void> startTutorial(TutorialTrigger trigger) async {
    final steps = tutorialSteps.where((step) => step.trigger == trigger).toList();
    _skipEntireTutorial = false; // Reset skip flag
    _currentTutorialTrigger = trigger; // Track current tutorial
    
    debugPrint('Tutorial: Starting tutorial for trigger: $trigger');
    debugPrint('Tutorial: Found ${steps.length} steps for this trigger');
    
    for (int i = 0; i < steps.length; i++) {
      final step = _enhanceStepWithNpcContext(steps[i]);
      
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
          await _showTutorialPopup(step, i == steps.length - 1);
          
          // Check again if user skipped during popup
          if (_skipEntireTutorial) {
            break;
          }
          
          // Mark step as completed
          if (context.mounted) {
            ref.read(tutorialProgressProvider.notifier).markStepCompleted(step.id);
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
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return TutorialPopup(
          step: step,
          isLastStep: isLastStep,
          onSkipEntireTutorial: () => _skipTutorial(),
        );
      },
    );
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
          ref.read(tutorialProgressProvider.notifier).markStepCompleted(step.id);
        }
        
        debugPrint('Tutorial: Marked ${currentTutorialSteps.length} steps for trigger $_currentTutorialTrigger as completed due to skip');
      } else {
        debugPrint('Tutorial: Skip called but no active tutorial found or no current trigger - not marking steps as completed');
      }
    }
  }
  
  // Enhance tutorial steps with real NPC item data
  TutorialStep _enhanceStepWithNpcContext(TutorialStep step) {
    // Skip NPC item enhancement for boss fight tutorials
    if (step.trigger == TutorialTrigger.bossFight) {
      return step; // Boss fight tutorials don't need NPC items
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

