import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:babblelon/models/supabase_models.dart';
import 'package:babblelon/services/isar_service.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:flame_audio/flame_audio.dart';
import '../services/background_audio_service.dart';
import '../models/popup_models.dart';
import 'package:babblelon/services/posthog_service.dart';

part 'game_providers.g.dart';

// --- Screen Music System ---
enum ScreenType {
  intro,      // MainNavigationScreen (tabs)
  game,       // BabblelonGame (game world)
  bossFight,  // BossFightScreen
}

enum MusicTrack {
  intro('bg/background_introscreen.wav'),
  game('bg/background_yaowarat.wav'), 
  bossFight('bg/background_tuktukbossfight.wav');
  
  const MusicTrack(this.path);
  final String path;
}

// --- Game State ---
@immutable
class GameStateData {
  final bool isPaused;
  final bool bgmIsPlaying;
  final bool musicEnabled;
  final bool hasNewItem;
  final bool soundEffectsEnabled;
  final ScreenType currentScreen;
  final MusicTrack? currentMusicTrack;

  const GameStateData({
    this.isPaused = false,
    this.bgmIsPlaying = false,
    this.musicEnabled = true,
    this.hasNewItem = false,
    this.soundEffectsEnabled = true,
    this.currentScreen = ScreenType.intro,
    this.currentMusicTrack,
  });

  GameStateData copyWith({
    bool? isPaused,
    bool? musicEnabled,
    bool? bgmIsPlaying,
    bool? hasNewItem,
    bool? soundEffectsEnabled,
    ScreenType? currentScreen,
    MusicTrack? currentMusicTrack,
  }) {
    return GameStateData(
      isPaused: isPaused ?? this.isPaused,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      bgmIsPlaying: bgmIsPlaying ?? this.bgmIsPlaying,
      hasNewItem: hasNewItem ?? this.hasNewItem,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
      currentScreen: currentScreen ?? this.currentScreen,
      currentMusicTrack: currentMusicTrack ?? this.currentMusicTrack,
    );
  }
}

@Riverpod(keepAlive: true)
class GameState extends _$GameState {
  @override
  GameStateData build() {
    // Start with default state
    const initialState = GameStateData(
      musicEnabled: true,
      soundEffectsEnabled: true,
    );
    
    // Load settings asynchronously and update state
    _loadSettingsAsync();
    
    return initialState;
  }

  void pauseGame() => state = state.copyWith(isPaused: true);
  void resumeGame() => state = state.copyWith(isPaused: false);
  void setBgmPlaying(bool playing) => state = state.copyWith(bgmIsPlaying: playing);
  void toggleMusic() {
    setMusicEnabled(!state.musicEnabled);
    
    // If we're enabling music and BGM was playing before, restart it
    if (state.musicEnabled && state.bgmIsPlaying) {
      FlameAudio.bgm.play('bg/background_yaowarat.wav', volume: 0.5);
    }
  }
  void setNewItem() => state = state.copyWith(hasNewItem: true);
  void clearNewItem() => state = state.copyWith(hasNewItem: false);

  /// Switch to a specific screen and play appropriate music
  void switchScreen(ScreenType screenType) {
    // Get the appropriate music track for this screen
    final MusicTrack targetTrack;
    switch (screenType) {
      case ScreenType.intro:
        targetTrack = MusicTrack.intro;
        break;
      case ScreenType.game:
        targetTrack = MusicTrack.game;
        break;
      case ScreenType.bossFight:
        targetTrack = MusicTrack.bossFight;
        break;
    }

    debugPrint('🎵 GameStateProvider: Switching to screen: $screenType, track: ${targetTrack.path}');

    // Update the current screen
    state = state.copyWith(
      currentScreen: screenType,
      currentMusicTrack: targetTrack,
    );

    // Play the appropriate music if music is enabled
    if (state.musicEnabled) {
      _playScreenMusic(targetTrack);
    }
  }

  /// Play music for the current screen
  void _playScreenMusic(MusicTrack track) {
    try {
      FlameAudio.bgm.stop(); // Stop current music first
      FlameAudio.bgm.play(track.path, volume: 0.5);
      state = state.copyWith(bgmIsPlaying: true);
      debugPrint('🎵 GameStateProvider: Playing ${track.path}');
    } catch (e) {
      debugPrint('🎵 GameStateProvider: Failed to play ${track.path}: $e');
    }
  }

  void setMusicEnabled(bool isEnabled) {
    state = state.copyWith(musicEnabled: isEnabled);
    _saveSettings();
    
    debugPrint('🎵 GameStateProvider: Music setting changed to: $isEnabled');
    
    // Control FlameAudio.bgm directly
    if (!isEnabled) {
      // Stop all background music when disabled
      FlameAudio.bgm.stop();
      state = state.copyWith(bgmIsPlaying: false);
      debugPrint('🎵 GameStateProvider: Stopped background music');
    } else {
      // When enabling music, play the appropriate music for current screen
      final currentTrack = state.currentMusicTrack;
      if (currentTrack != null) {
        _playScreenMusic(currentTrack);
        debugPrint('🎵 GameStateProvider: Restarted music for current screen: ${currentTrack.path}');
      } else {
        debugPrint('🎵 GameStateProvider: No current track set, music will start when screen is selected');
      }
    }
  }

  void setSoundEffectsEnabled(bool isEnabled) {
    state = state.copyWith(soundEffectsEnabled: isEnabled);
    _saveSettings();
    
    debugPrint('🔊 GameStateProvider: Sound effects setting changed to: $isEnabled');
    
    // Individual sound effects will check this setting before playing
    // FlameAudio doesn't have a global stop for all sound effects
  }

  Future<void> _loadSettingsAsync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final musicEnabled = prefs.getBool('music_enabled') ?? true;
      final soundEffectsEnabled = prefs.getBool('sound_effects_enabled') ?? true;
      
      debugPrint('🎵 GameStateProvider: Loading settings - music: $musicEnabled, effects: $soundEffectsEnabled');
      
      // Update state with loaded settings
      state = state.copyWith(
        musicEnabled: musicEnabled,
        soundEffectsEnabled: soundEffectsEnabled,
      );
      
      debugPrint('🎵 GameStateProvider: Settings loaded successfully');
      
    } catch (e) {
      // If loading fails, keep defaults
      debugPrint('🎵 GameStateProvider: Failed to load audio settings, using defaults: $e');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('music_enabled', state.musicEnabled);
      await prefs.setBool('sound_effects_enabled', state.soundEffectsEnabled);
      debugPrint('🎵 GameStateProvider: Settings saved - music: ${state.musicEnabled}, effects: ${state.soundEffectsEnabled}');
    } catch (e) {
      debugPrint('🎵 GameStateProvider: Failed to save settings: $e');
    }
  }
}

// --- Dialogue Settings ---
@immutable
class DialogueSettingsData {
  final bool showWordByWordAnalysis;
  final bool showEnglishTranslation;
  final bool showTransliteration;
  final bool enableParallelProcessing;
  final bool isMicEnabled;

  const DialogueSettingsData({
    this.showWordByWordAnalysis = false,
    this.showEnglishTranslation = false,
    this.showTransliteration = false,
    this.enableParallelProcessing = false,
    this.isMicEnabled = true,
  });

  DialogueSettingsData copyWith({
    bool? showWordByWordAnalysis,
    bool? showEnglishTranslation,
    bool? showTransliteration,
    bool? enableParallelProcessing,
    bool? isMicEnabled,
  }) {
    return DialogueSettingsData(
      showWordByWordAnalysis: showWordByWordAnalysis ?? this.showWordByWordAnalysis,
      showEnglishTranslation: showEnglishTranslation ?? this.showEnglishTranslation,
      showTransliteration: showTransliteration ?? this.showTransliteration,
      enableParallelProcessing: enableParallelProcessing ?? this.enableParallelProcessing,
      isMicEnabled: isMicEnabled ?? this.isMicEnabled,
    );
  }
}

@Riverpod(keepAlive: true)
class DialogueSettings extends _$DialogueSettings {
  @override
  DialogueSettingsData build() => const DialogueSettingsData();

  void toggleWordByWordAnalysis() {
    state = state.copyWith(showWordByWordAnalysis: !state.showWordByWordAnalysis);
  }

  void toggleShowEnglishTranslation() {
    state = state.copyWith(showEnglishTranslation: !state.showEnglishTranslation);
  }

  void toggleShowTransliteration() {
    state = state.copyWith(showTransliteration: !state.showTransliteration);
  }

  void toggleParallelProcessing() {
    state = state.copyWith(enableParallelProcessing: !state.enableParallelProcessing);
  }

  void toggleMicUsage() => state = state.copyWith(isMicEnabled: !state.isMicEnabled);
}

// --- Dialogue Overlay Visibility ---
final dialogueOverlayVisibilityProvider = StateProvider<bool>((ref) => false);

// Provider to hold the active NPC ID for dialogue
final activeNpcIdProvider = StateProvider<String?>((ref) => null);

// Provider to hold the turn count in a battle
final turnCounterProvider = StateProvider<int>((ref) => 1);

// Provider to hold the player's score
final scoreProvider = StateProvider<int>((ref) => 0);

// Provider to hold the list of temporary file paths to be cleaned up on exit
final tempFilePathsProvider = StateProvider<List<String>>((ref) => []);

// --- Inventory State ---
// Holds the asset path for items in 'attack' and 'defense' slots.
final inventoryProvider = StateProvider<Map<String, String?>>((ref) => {
  'attack': null,
  'defense': null,
});

// Provider for the current charm level, now specific to each NPC
final currentCharmLevelProvider = StateProvider.family<int, String>((ref, npcId) => 50);

// Provider for the shared preferences instance
@riverpod
Future<SharedPreferences> sharedPreferences(AutoDisposeFutureProviderRef ref) async {
  return SharedPreferences.getInstance();
}

// Provider for the Isar service instance
@Riverpod(keepAlive: true)
IsarService isarService(IsarServiceRef ref) {
  return IsarService();
}

// Provider to track if a special item has been received from an NPC
final specialItemReceivedProvider = StateProvider.family<bool, String>((ref, npcId) => false);


class VocabularyProvider with ChangeNotifier {
  List<Vocabulary> _vocabulary = [];
  bool _isLoading = false;

  List<Vocabulary> get vocabulary => _vocabulary;
  bool get isLoading => _isLoading;

  Future<void> loadVocabulary(String path) async {
    if (_vocabulary.isNotEmpty) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final String response = await rootBundle.loadString(path);
      final data = json.decode(response);
      
      // Correctly cast the list from json
      _vocabulary = (data['vocabulary'] as List)
          .map((item) => Vocabulary.fromJson(item))
          .toList();

    } catch (e) {
      // Handle potential errors, e.g., file not found or JSON parsing error
      debugPrint("Error loading vocabulary: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// Helper function to play sound effects that respects the toggle
void playSoundEffect(String path, WidgetRef ref, {double volume = 1.0}) {
  final soundEffectsEnabled = ref.read(gameStateProvider).soundEffectsEnabled;
  if (soundEffectsEnabled) {
    FlameAudio.play(path, volume: volume);
  }
}

// Extension on WidgetRef for convenient sound effect playing
extension WidgetRefSoundEffects on WidgetRef {
  void playButtonSound() {
    playSound('soundeffects/soundeffect_button.mp3');
  }
  
  void playSound(String path, {double volume = 1.0}) {
    final soundEffectsEnabled = read(gameStateProvider).soundEffectsEnabled;
    if (soundEffectsEnabled) {
      FlameAudio.play(path, volume: volume);
    }
  }
}

// Provider for app lifecycle management
@Riverpod(keepAlive: true)
class AppLifecycleManager extends _$AppLifecycleManager {
  @override
  void build() {
    // Initialize app lifecycle tracking
    PostHogService.trackAppLifecycle(event: 'opened');
  }

  void appResumed() {
    PostHogService.trackAppLifecycle(
      event: 'resumed',
      additionalProperties: {
        'previous_state': 'background',
      },
    );
  }

  void appPaused() {
    PostHogService.trackAppLifecycle(
      event: 'backgrounded',
      additionalProperties: {
        'previous_state': 'foreground',
      },
    );
  }

  void appInactive() {
    PostHogService.trackAppLifecycle(event: 'inactive');
  }

  void appHidden() {
    PostHogService.trackAppLifecycle(event: 'hidden');
  }

  void appClosed() {
    PostHogService.trackAppLifecycle(event: 'closed');
    PostHogService.trackSessionEnd();
  }
}

// --- Developer Settings ---
@immutable
class DeveloperSettingsData {
  final bool useElevenLabsSTT;

  const DeveloperSettingsData({
    this.useElevenLabsSTT = false, // Default to Google Cloud STT for production safety
  });

  DeveloperSettingsData copyWith({
    bool? useElevenLabsSTT,
  }) {
    return DeveloperSettingsData(
      useElevenLabsSTT: useElevenLabsSTT ?? this.useElevenLabsSTT,
    );
  }
}

@Riverpod(keepAlive: true)
class DeveloperSettings extends _$DeveloperSettings {
  static const String _keyUseElevenLabsSTT = 'dev_use_elevenlabs_stt';

  @override
  DeveloperSettingsData build() {
    _loadSettings();
    return const DeveloperSettingsData();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final useElevenLabsSTT = prefs.getBool(_keyUseElevenLabsSTT) ?? false;
      
      state = state.copyWith(useElevenLabsSTT: useElevenLabsSTT);
    } catch (e) {
      print('DEBUG: Failed to load developer settings: $e');
    }
  }

  Future<void> toggleSTTService() async {
    final newValue = !state.useElevenLabsSTT;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyUseElevenLabsSTT, newValue);
      
      state = state.copyWith(useElevenLabsSTT: newValue);
      
      print('DEBUG: STT service toggled to: ${newValue ? "ElevenLabs" : "Google Cloud"}');
    } catch (e) {
      print('DEBUG: Failed to save STT service setting: $e');
    }
  }

  String get currentSTTService => state.useElevenLabsSTT ? 'ElevenLabs' : 'Google Cloud';
}

// --- Tutorial System Providers ---

// Provider to track if the main tutorial has been completed
@Riverpod(keepAlive: true)
class TutorialCompleted extends _$TutorialCompleted {
  @override
  bool build() {
    _loadTutorialStatus();
    return false;
  }

  void markCompleted() {
    state = true;
    _saveTutorialStatus();
  }

  void reset() {
    state = false;
    _saveTutorialStatus();
  }

  Future<void> _loadTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('tutorial_completed') ?? false;
    state = completed;
  }

  Future<void> _saveTutorialStatus() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', state);
  }
}

// Provider to track tutorial progress through steps
@Riverpod(keepAlive: true)
class TutorialProgress extends _$TutorialProgress {
  @override
  Set<String> build() {
    // Load tutorial progress asynchronously after initialization
    // Using Future.microtask to avoid blocking but load quickly
    Future.microtask(() => _loadTutorialProgress());
    return <String>{};
  }

  void markStepCompleted(String stepId) {
    debugPrint('🎓 TutorialProgress: Marking step completed: $stepId');
    state = {...state, stepId};
    _saveTutorialProgress();
    debugPrint('🎓 TutorialProgress: Step marked as completed. Total completed steps: ${state.length}');
  }

  void resetProgress() {
    state = <String>{};
    _saveTutorialProgress();
  }

  bool isStepCompleted(String stepId) {
    return state.contains(stepId);
  }

  Future<void> _loadTutorialProgress() async {
    try {
      debugPrint('🎓 TutorialProgress: Starting to load tutorial progress from SharedPreferences');
      final prefs = await SharedPreferences.getInstance();
      final progressJson = prefs.getString('tutorial_progress');
      if (progressJson != null) {
        final List<dynamic> progressList = json.decode(progressJson);
        state = Set<String>.from(progressList);
        debugPrint('🎓 TutorialProgress: Loaded tutorial progress - completed steps: ${progressList.length}');
        debugPrint('🎓 TutorialProgress: Completed steps: $progressList');
      } else {
        debugPrint('🎓 TutorialProgress: No tutorial progress found in SharedPreferences (first time)');
      }
    } catch (e) {
      debugPrint('🎓 TutorialProgress: Failed to load tutorial progress: $e');
      // If loading fails, continue with empty progress
    }
  }
  
  // Debug method to reset dialogue tutorials for testing
  void resetDialogueTutorials() {
    state = state.difference({'charm_explanation', 'item_types', 'regular_vs_special'});
    _saveTutorialProgress();
    // Dialogue tutorials reset for testing
  }

  Future<void> _saveTutorialProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final progressList = state.toList();
    await prefs.setString('tutorial_progress', json.encode(progressList));
    debugPrint('🎓 TutorialProgress: Saved tutorial progress to SharedPreferences: $progressList');
  }
}

// Provider to track if tutorial is currently active
final tutorialActiveProvider = StateProvider<bool>((ref) => false);

// Provider to track current tutorial step
final currentTutorialStepProvider = StateProvider<String?>((ref) => null);

// Provider to track if the game has finished loading (onLoad completed)
final gameLoadingCompletedProvider = StateProvider<bool>((ref) => false);

// Provider to track if this is the first NPC dialogue encounter ever
final firstNpcDialogueEncounteredProvider = StateProvider<bool>((ref) => false);
