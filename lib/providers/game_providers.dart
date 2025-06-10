import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'game_providers.g.dart';

// --- Game State ---
@immutable
class GameStateData {
  final bool isPaused;
  final bool musicEnabled;
  final bool bgmIsPlaying;

  const GameStateData({
    this.isPaused = false,
    this.musicEnabled = true,
    this.bgmIsPlaying = false,
  });

  GameStateData copyWith({bool? isPaused, bool? musicEnabled, bool? bgmIsPlaying}) {
    return GameStateData(
      isPaused: isPaused ?? this.isPaused,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      bgmIsPlaying: bgmIsPlaying ?? this.bgmIsPlaying,
    );
  }
}

@Riverpod(keepAlive: true)
class GameState extends _$GameState {
  @override
  GameStateData build() => const GameStateData();

  void pauseGame() => state = state.copyWith(isPaused: true);
  void resumeGame() => state = state.copyWith(isPaused: false);
  void toggleMusic() {
    final newMusicEnabledState = !state.musicEnabled;
    state = state.copyWith(musicEnabled: newMusicEnabledState);
    if (newMusicEnabledState) {
      // Always try to play BGM if music is enabled, regardless of pause state.
      // The _playBGM method itself can check if it's already playing.
      _playBGM(); 
    } else {
      _stopBGM();
    }
  }

  void setBgmPlaying(bool playing) => state = state.copyWith(bgmIsPlaying: playing);

  void _playBGM() {
    // Implementation of _playBGM method
  }

  void _stopBGM() {
    // Implementation of _stopBGM method
  }
}

// --- Dialogue Settings ---
@immutable
class DialogueSettingsData {
  final bool showTranslation;
  final bool showTransliteration;
  final bool showPos;
  final bool isMicEnabled;

  const DialogueSettingsData({
    this.showTranslation = false,
    this.showTransliteration = false,
    this.showPos = false,
    this.isMicEnabled = true,
  });

  DialogueSettingsData copyWith({
    bool? showTranslation,
    bool? showTransliteration,
    bool? showPos,
    bool? isMicEnabled,
  }) {
    return DialogueSettingsData(
      showTranslation: showTranslation ?? this.showTranslation,
      showTransliteration: showTransliteration ?? this.showTransliteration,
      showPos: showPos ?? this.showPos,
      isMicEnabled: isMicEnabled ?? this.isMicEnabled,
    );
  }
}

@Riverpod(keepAlive: true)
class DialogueSettings extends _$DialogueSettings {
  @override
  DialogueSettingsData build() => const DialogueSettingsData();

  void toggleTranslation() => state = state.copyWith(showTranslation: !state.showTranslation);
  void toggleTransliteration() => state = state.copyWith(showTransliteration: !state.showTransliteration);
  void toggleShowPos() => state = state.copyWith(showPos: !state.showPos);
  void toggleMicUsage() => state = state.copyWith(isMicEnabled: !state.isMicEnabled);
}

// --- Dialogue Overlay Visibility ---
final dialogueOverlayVisibilityProvider = StateProvider<bool>((ref) => false);

// Provider to hold the list of temporary file paths to be cleaned up on exit
final tempFilePathsProvider = StateProvider<List<String>>((ref) => []);

// --- Inventory State ---
// Holds the asset path for items in 'attack' and 'defense' slots.
final inventoryProvider = StateProvider<Map<String, String?>>((ref) => {
  'attack': null,
  'defense': null,
}); 