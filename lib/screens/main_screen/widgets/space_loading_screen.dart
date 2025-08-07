import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:babblelon/overlays/capybara_loading_overlay.dart';
import 'package:babblelon/screens/cartoon_splash_screen.dart';
import 'package:babblelon/services/background_audio_service.dart';
import 'package:babblelon/providers/game_providers.dart';

/// Space loading screen wrapper that shows loading overlay over 3D earth background
class SpaceLoadingScreen extends ConsumerStatefulWidget {
  const SpaceLoadingScreen({super.key});

  @override
  ConsumerState<SpaceLoadingScreen> createState() => _SpaceLoadingScreenState();
}

class _SpaceLoadingScreenState extends ConsumerState<SpaceLoadingScreen> {
  bool _isLoadingComplete = false;
  bool _earthRenderingComplete = false;
  final BackgroundAudioService _audioService = BackgroundAudioService();
  
  @override
  void initState() {
    super.initState();
    _initializeAudioService();
    _checkEarthRenderingStatus();
  }
  
  Future<void> _initializeAudioService() async {
    // Get current settings from GameStateProvider to sync with BackgroundAudioService
    final gameState = ref.read(gameStateProvider);
    await _audioService.initialize(
      musicEnabled: gameState.musicEnabled,
      soundEffectsEnabled: gameState.soundEffectsEnabled,
    );
    debugPrint('🎵 SpaceLoadingScreen: Initialized BackgroundAudioService with settings - music: ${gameState.musicEnabled}, effects: ${gameState.soundEffectsEnabled}');
  }
  
  Future<void> _checkEarthRenderingStatus() async {
    // Earth rendering is now considered complete immediately
    if (mounted) {
      setState(() {
        _earthRenderingComplete = true;
      });
    }
  }
  
  void _onLoadingComplete() {
    setState(() {
      _isLoadingComplete = true;
    });
    
    // Start playing intro music when main menu loads (respects global music toggle)
    _audioService.playIntroMusic(ref);
  }
  
  bool get _showOverlay => !_isLoadingComplete || !_earthRenderingComplete;
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background: 3D Earth renders immediately but may not be visible
        CartoonSplashScreen(
          key: const ValueKey('cartoon_splash_screen'),
          audioService: _audioService,
        ),
        
        // Overlay: Capybara loading screen that hides until earth is ready
        if (_showOverlay)
          CapybaraLoadingOverlay(
            key: const ValueKey('capybara_loading_overlay'),
            onComplete: _onLoadingComplete,
          ),
      ],
    );
  }
}

class SpaceAssetPreloader {
  static final SpaceAssetPreloader _instance = SpaceAssetPreloader._internal();
  factory SpaceAssetPreloader() => _instance;
  SpaceAssetPreloader._internal();

  bool _isLoading = false;
  bool _isLoaded = false;
  double _progress = 0.0;
  
  final List<String> _criticalAssets = [
    'assets/images/main_screen/earth_3d.glb',
    'assets/images/player/sprite_male_tourist.png',
    'assets/images/player/sprite_female_tourist.png',
    'assets/images/player/capybara.png',
  ];

  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;
  double get progress => _progress;

  Future<void> preloadAssets() async {
    if (_isLoading || _isLoaded) return;
    
    _isLoading = true;
    _progress = 0.0;
    
    try {
      for (int i = 0; i < _criticalAssets.length; i++) {
        _progress = (i + 1) / _criticalAssets.length;
        
        // In a real implementation, you would preload actual assets here
        // For example: await precacheImage(AssetImage(asset), context);
      }
      
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error preloading assets: $e');
    } finally {
      _isLoading = false;
    }
  }

  void reset() {
    _isLoading = false;
    _isLoaded = false;
    _progress = 0.0;
  }
}