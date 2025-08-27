import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/screens/main_screen/widgets/location_marker_widget.dart';
import 'package:babblelon/screens/game_loading_screen.dart';
import 'package:babblelon/services/background_audio_service.dart';
import 'package:babblelon/theme/modern_design_system.dart' as modern;
import 'package:babblelon/widgets/popups/base_popup_widget.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:babblelon/services/supabase_service.dart';
import 'package:babblelon/services/game_save_service.dart';
import 'package:babblelon/widgets/resume_game_dialog.dart';
import 'package:babblelon/models/local_storage_models.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:babblelon/services/static_game_loader.dart';
import 'package:babblelon/models/boss_data.dart';
import 'package:babblelon/screens/boss_fight_screen.dart';
import 'package:babblelon/game/babblelon_game.dart';
import 'package:babblelon/models/battle_item.dart';
import 'package:babblelon/models/npc_data.dart';

class ThailandMapScreen extends ConsumerStatefulWidget {
  const ThailandMapScreen({super.key});

  @override
  ConsumerState<ThailandMapScreen> createState() => _ThailandMapScreenState();
}

class _ThailandMapScreenState extends ConsumerState<ThailandMapScreen> 
    with TickerProviderStateMixin {
  late AnimationController _mapController;
  late AnimationController _markersController;
  
  final BackgroundAudioService _audioService = BackgroundAudioService();
  
  final List<LocationData> _locations = [
    const LocationData(
      name: 'Cultural District',
      id: 'cultural_district',
      levelId: 'yaowarat_level', // Currently the only available level
      position: Offset(0.50, 0.55), // Central position for main adventure
      isAvailable: true,
      description: 'Explore vibrant cultural environments',
    ),
    const LocationData(
      name: 'Chiang Mai',
      id: 'chiang_mai',
      levelId: 'chiang_mai_level', // Future level
      position: Offset(0.35, 0.35), // Keep northern Thailand positioning
      isAvailable: false,
      description: 'Northern cultural capital',
    ),
    const LocationData(
      name: 'Phuket',
      id: 'phuket',
      levelId: 'phuket_level', // Future level
      position: Offset(0.30, 0.72), // Moved up from 0.85 to 0.78, and left from 0.32 to 0.28
      isAvailable: false,
      description: 'Beautiful island paradise',
    ),
  ];

  @override
  void initState() {
    super.initState();
    
    _mapController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _markersController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    // Start animations
    _mapController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      _markersController.forward();
    });
  }

  @override
  void dispose() {
    _mapController.dispose();
    _markersController.dispose();
    super.dispose();
  }

  Future<void> _onLocationSelected(LocationData location) async {
    if (!location.isAvailable) {
      _showComingSoonDialog(location);
      return;
    }
    
    // Navigate to game directly - save checking happens in _navigateToGame
    await _navigateToGame(location);
  }

  Future<void> _navigateToGame(LocationData location) async {
    debugPrint('🗺️ ThailandMapScreen: _navigateToGame called for ${location.name}');
    debugPrint('📍 Navigation stack trace:');
    debugPrint(StackTrace.current.toString());
    
    // Store context early before any async operations
    final navigatorContext = context;
    final isInitiallyMounted = mounted;
    debugPrint('🗺️ ThailandMapScreen: Initial mounted state: $isInitiallyMounted');
    
    // Stop background music before transitioning to game
    _audioService.stopBackgroundMusic();
    
    // Check for existing save data for this level
    final saveService = GameSaveService();
    final explorationSave = await saveService.loadGameState(location.levelId);
    final bossSave = await saveService.loadGameState('boss_tuk-tuk monster');
    
    // Prioritize boss save if it exists (player was in boss fight when exiting)
    final existingSave = bossSave ?? explorationSave;
    GameSaveState? finalSave = existingSave;
    
    // Show appropriate dialog based on save state
    if (existingSave != null) {
      debugPrint('🗺️ ThailandMapScreen: Found existing save, checking mounted state');
      debugPrint('🗺️ ThailandMapScreen: Mounted state before dialog: $mounted');
      if (!mounted) {
        debugPrint('⚠️ ThailandMapScreen: Widget not mounted after save loading, returning early');
        return;
      }
      
      debugPrint('🗺️ ThailandMapScreen: About to show resume dialog');
      // Show resume dialog for existing saves using stored context
      final shouldResume = await showDialog<bool>(
        context: navigatorContext,
        barrierDismissible: false,
        builder: (dialogContext) => ResumeGameDialog(
          levelId: location.levelId,
          saveData: existingSave,
          onResume: () => Navigator.of(dialogContext).pop(true),
          onStartNew: () => Navigator.of(dialogContext).pop(false),
        ),
      );
      
      debugPrint('🗺️ ThailandMapScreen: Dialog returned with value: $shouldResume');
      debugPrint('🗺️ ThailandMapScreen: Mounted state after dialog: $mounted');
      
      if (shouldResume == null) {
        debugPrint('⚠️ ThailandMapScreen: Dialog was dismissed, returning');
        return; // Dialog was dismissed
      }
      
      if (shouldResume == false) {
        debugPrint('🗺️ ThailandMapScreen: User chose start over, deleting saves');
        // Delete ALL saves related to this level (exploration + all boss fights)
        await saveService.deleteAllLevelSaves(location.levelId);
        finalSave = null;
        
        // Reset game singleton and all providers for completely fresh start
        BabblelonGame.resetInstance();
        if (mounted) {
          // Use WidgetRef to access reset methods - we need a provider context
          // The reset will be handled in GameScreen when existingSave is null
        }
        
        // Reset StaticGameLoader to ensure fresh game start
        final staticLoader = StaticGameLoader();
        staticLoader.reset();
        debugPrint('🔄 ThailandMapScreen: Reset game instance, StaticGameLoader and deleted all saves for fresh start');
      }
      
      debugPrint('🗺️ ThailandMapScreen: Mounted state after save operations: $mounted');
      if (!mounted) {
        debugPrint('⚠️ ThailandMapScreen: Widget not mounted after save operations, returning early');
        return;
      }
    } else {
      // First time playing this level - show welcome dialog
      debugPrint('🗺️ ThailandMapScreen: No existing save, showing welcome dialog');
      if (!mounted) {
        debugPrint('⚠️ ThailandMapScreen: Widget not mounted for welcome dialog, returning early');
        return;
      }
      
      final shouldStart = await _showWelcomeDialog(location, navigatorContext);
      debugPrint('🗺️ ThailandMapScreen: Welcome dialog returned: $shouldStart');
      if (!shouldStart) {
        debugPrint('🗺️ ThailandMapScreen: User cancelled welcome dialog');
        return; // User cancelled
      }
      
      debugPrint('🗺️ ThailandMapScreen: Mounted state after welcome dialog: $mounted');
      if (!mounted) {
        debugPrint('⚠️ ThailandMapScreen: Widget not mounted after welcome dialog, returning early');
        return;
      }
    }
    
    // Get selected character from user profile  
    final isarService = IsarService();
    final userId = SupabaseService.client.auth.currentUser?.id;
    String selectedCharacter = 'male'; // Default character
    
    if (userId != null) {
      final profile = await isarService.getPlayerProfile(userId);
      selectedCharacter = profile?.selectedCharacter ?? 'male';
    }
    
    // Check if context is still valid after async operation
    debugPrint('🗺️ ThailandMapScreen: Final mounted state check: $mounted');
    debugPrint('🗺️ ThailandMapScreen: About to navigate to GameLoadingScreen with character: $selectedCharacter');
    debugPrint('🗺️ ThailandMapScreen: Using stored navigator context for reliable navigation');
    
    // Use try-catch to handle any navigation errors gracefully
    try {
      debugPrint('🗺️ ThailandMapScreen: Calling Navigator.push with MaterialPageRoute...');
      
      // Check if we're resuming a boss fight (only if user chose resume)
      if (finalSave != null && finalSave.gameType == 'boss_fight') {
        debugPrint('🗺️ ThailandMapScreen: Resuming boss fight directly');
        
        // Get saved inventory to create proper battle items
        final savedInventory = finalSave.inventoryData;
        BattleItem attackItem;
        BattleItem defenseItem;
        
        if (savedInventory.isNotEmpty && savedInventory['attack'] != null && savedInventory['defense'] != null) {
          // Create battle items from saved inventory
          attackItem = _createBattleItemFromPath(savedInventory['attack']!);
          defenseItem = _createBattleItemFromPath(savedInventory['defense']!);
        } else {
          // Fallback to default items if inventory not found (shouldn't happen)
          attackItem = const BattleItem(name: 'Golden Steamed Bun', assetPath: 'assets/images/items/steambun_special.png', isSpecial: true);
          defenseItem = const BattleItem(name: 'Golden Pork Belly', assetPath: 'assets/images/items/porkbelly_special.png', isSpecial: true);
        }
        
        // Import BossData and navigate to BossFightScreen
        const tuktukBoss = BossData(
          name: "Tuk-Tuk Monster",
          spritePath: 'assets/images/bosses/tuktuk/sprite_tuktukmonster.png',
          maxHealth: 500,
          vocabularyPath: 'assets/data/beginner_food_vocabulary.json',
          backgroundPath: 'assets/images/background/bossfight_tuktuk_bg.png',
          languageName: 'Thai',
          languageFlag: '🇹🇭',
        );
        
        await Navigator.push(
          navigatorContext,
          MaterialPageRoute(
            builder: (context) => BossFightScreen(
              bossData: tuktukBoss,
              attackItem: attackItem,
              defenseItem: defenseItem,
              game: BabblelonGame.instance,
              existingSave: finalSave, // Pass the final save state
            ),
          ),
        );
      } else {
        // Resume exploration or start new game
        await Navigator.push(
          navigatorContext, // Use stored context instead of current context
          MaterialPageRoute(
            builder: (context) => GameLoadingScreen(
              selectedCharacter: selectedCharacter,
              existingSave: finalSave,
            ),
          ),
        );
      }
      debugPrint('✅ ThailandMapScreen: Navigation completed successfully');
    } catch (error) {
      debugPrint('❌ ThailandMapScreen: Navigation failed with error: $error');
      // If navigation fails with stored context, try with current context as fallback
      if (mounted) {
        debugPrint('🔄 ThailandMapScreen: Retrying with current context as fallback');
        try {
          if (bossSave != null && finalSave?.gameType == 'boss_fight') {
            // Fallback boss fight navigation
            const tuktukBoss = BossData(
              name: "Tuk-Tuk Monster",
              spritePath: 'assets/images/bosses/tuktuk/sprite_tuktukmonster.png',
              maxHealth: 500,
              vocabularyPath: 'assets/data/beginner_food_vocabulary.json',
              backgroundPath: 'assets/images/background/bossfight_tuktuk_bg.png',
              languageName: 'Thai',
              languageFlag: '🇹🇭',
            );
            
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BossFightScreen(
                  bossData: tuktukBoss,
                  attackItem: const BattleItem(name: 'Golden Steamed Bun', assetPath: 'assets/images/items/steambun_special.png', isSpecial: true),
                  defenseItem: const BattleItem(name: 'Golden Pork Belly', assetPath: 'assets/images/items/porkbelly_special.png', isSpecial: true),
                  game: BabblelonGame.instance,
                  existingSave: bossSave,
                ),
              ),
            );
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => GameLoadingScreen(
                  selectedCharacter: selectedCharacter,
                  existingSave: finalSave,
                ),
              ),
            );
          }
          debugPrint('✅ ThailandMapScreen: Fallback navigation completed successfully');
        } catch (fallbackError) {
          debugPrint('❌ ThailandMapScreen: Fallback navigation also failed: $fallbackError');
        }
      }
    }
  }

  void _showComingSoonDialog(LocationData location) {
    BasePopup.showPopup(
      context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.construction,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  location.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'This adventure is coming soon!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            location.description,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: BasePopup.primaryButtonStyle,
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showWelcomeDialog(LocationData location, BuildContext navigatorContext) async {
    return await showDialog<bool>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(
              constraints: const BoxConstraints(
                maxWidth: 400,
                maxHeight: 600,
              ),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1a1a2e),
                    Color(0xFF16213e),
                    Color(0xFF0f3460),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.deepPurple,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(
                        Icons.explore,
                        color: Colors.deepPurple[300],
                        size: 32,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Welcome to ${location.name}!',
                          style: GoogleFonts.orbitron(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    location.description,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // Adventure message
                  Text(
                    'Are you ready to begin your Thai language adventure?',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: Colors.white38,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Text(
                            'Not Yet',
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepPurple,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 8,
                          ),
                          child: Text(
                            "Let's Go!",
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ) ?? false;
  }

  void _handleBackNavigation() {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: modern.ModernDesignSystem.backgroundGradient,
        ),
        child: Stack(
          children: [
            // Thailand static map with markers (Full Screen)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _mapController,
                builder: (context, child) {
                  final screenSize = MediaQuery.of(context).size;
                  
                  return Stack(
                    children: [
                      // Thailand map image (Full Screen with BoxFit.cover, optimized for 1280x1920)
                      Positioned(
                          left: -30, // Reduced shift for new aspect ratio
                          top: 0,
                          right: -30,
                          bottom: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/maps/map_thailand.png',
                              fit: BoxFit.cover, // Use cover to fill entire screen
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: modern.ModernDesignSystem.primaryBackground,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.map,
                                          color: Colors.white,
                                          size: 64,
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'Thailand Map',
                                          style: modern.ModernDesignSystem.headlineMedium.copyWith(
                                            color: modern.ModernDesignSystem.tertiaryAccent,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        
                      // Location markers (positioned based on screen proportions)
                      ...(_locations.map((location) {
                        return AnimatedBuilder(
                          animation: _markersController,
                          builder: (context, child) {
                            final delay = _locations.indexOf(location) * 0.3;
                            
                            // Calculate pin position based on screen size and location proportions
                            // Center the 60x60 pin widget
                            final pinX = (location.position.dx * screenSize.width) - 30;
                            final pinY = (location.position.dy * screenSize.height) - 30;
                            
                            final fade = CurvedAnimation(
                              parent: _markersController,
                              curve: Interval(delay, 1.0),
                            );
                            
                            return Positioned(
                              left: pinX,
                              top: pinY,
                              child: ScaleTransition(
                                scale: fade,
                                child: GestureDetector(
                                  onTap: () => _onLocationSelected(location),
                                  child: LocationMarkerWidget(
                                    location: location,
                                    onTap: () => _onLocationSelected(location),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      }).toList()),
                    ],
                  );
                },
              ),
            ),
            
            // Back button (positioned on top of map)
            Positioned(
              top: 60,
              left: 20,
              child: Container(
                decoration: BoxDecoration(
                  color: modern.ModernDesignSystem.primaryBackground.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: modern.ModernDesignSystem.tertiaryAccent.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: modern.ModernDesignSystem.tertiaryAccent.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _handleBackNavigation,
                  icon: const Icon(
                    Icons.arrow_back_ios_rounded,
                    color: modern.ModernDesignSystem.tertiaryAccent,
                    size: 24,
                  ),
                ),
              ),
            ),
            
            // Title (positioned on top of map, matching Select Language style)
            Positioned(
              top: 60,
              left: 80, // Leave space for back button
              right: 20,
              child: Text(
                'Choose Your Destination',
                style: modern.ModernDesignSystem.headlineMedium.copyWith(
                  fontSize: 18,
                  color: modern.ModernDesignSystem.tertiaryAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Helper function to create BattleItem from asset path
  BattleItem _createBattleItemFromPath(String assetPath) {
    // Extract item name from asset path by checking against known items
    for (var npcData in npcDataMap.values) {
      if (npcData.regularItemAsset == assetPath) {
        return BattleItem(name: npcData.regularItemName, assetPath: assetPath, isSpecial: false);
      }
      if (npcData.specialItemAsset == assetPath) {
        return BattleItem(name: npcData.specialItemName, assetPath: assetPath, isSpecial: true);
      }
    }
    
    // Fallback: extract name from path
    final fileName = assetPath.split('/').last.split('.').first;
    final itemName = fileName.replaceAll('_', ' ').split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
    
    return BattleItem(name: itemName, assetPath: assetPath);
  }
}

class LocationData {
  final String name;
  final String id;
  final String levelId; // Save game level ID for this location
  final Offset position; // Relative position on the map (0.0 to 1.0)
  final bool isAvailable;
  final String description;

  const LocationData({
    required this.name,
    required this.id,
    required this.levelId,
    required this.position,
    required this.isAvailable,
    required this.description,
  });
}