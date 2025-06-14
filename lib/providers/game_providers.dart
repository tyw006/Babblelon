import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

part 'game_providers.g.dart';

// --- Game State ---
@immutable
class GameStateData {
  final bool isPaused;
  final bool bgmIsPlaying;
  final bool musicEnabled;
  final bool hasNewItem;
  final bool soundEffectsEnabled;

  const GameStateData({
    this.isPaused = false,
    this.bgmIsPlaying = false,
    this.musicEnabled = true,
    this.hasNewItem = false,
    this.soundEffectsEnabled = true,
  });

  GameStateData copyWith({
    bool? isPaused,
    bool? musicEnabled,
    bool? bgmIsPlaying,
    bool? hasNewItem,
    bool? soundEffectsEnabled,
  }) {
    return GameStateData(
      isPaused: isPaused ?? this.isPaused,
      musicEnabled: musicEnabled ?? this.musicEnabled,
      bgmIsPlaying: bgmIsPlaying ?? this.bgmIsPlaying,
      hasNewItem: hasNewItem ?? this.hasNewItem,
      soundEffectsEnabled: soundEffectsEnabled ?? this.soundEffectsEnabled,
    );
  }
}

@Riverpod(keepAlive: true)
class GameState extends _$GameState {
  @override
  GameStateData build() => const GameStateData();

  void pauseGame() => state = state.copyWith(isPaused: true);
  void resumeGame() => state = state.copyWith(isPaused: false);
  void setBgmPlaying(bool playing) => state = state.copyWith(bgmIsPlaying: playing);
  void toggleMusic() => setMusicEnabled(!state.musicEnabled);
  void setNewItem() => state = state.copyWith(hasNewItem: true);
  void clearNewItem() => state = state.copyWith(hasNewItem: false);

  void setMusicEnabled(bool isEnabled) {
    state = state.copyWith(musicEnabled: isEnabled);
  }

  void setSoundEffectsEnabled(bool isEnabled) {
    state = state.copyWith(soundEffectsEnabled: isEnabled);
  }
}

// --- Dialogue Settings ---
@immutable
class DialogueSettingsData {
  final bool showWordByWordAnalysis;
  final bool showEnglishTranslation;
  final bool isMicEnabled;

  const DialogueSettingsData({
    this.showWordByWordAnalysis = false,
    this.showEnglishTranslation = false,
    this.isMicEnabled = true,
  });

  DialogueSettingsData copyWith({
    bool? showWordByWordAnalysis,
    bool? showEnglishTranslation,
    bool? isMicEnabled,
  }) {
    return DialogueSettingsData(
      showWordByWordAnalysis: showWordByWordAnalysis ?? this.showWordByWordAnalysis,
      showEnglishTranslation: showEnglishTranslation ?? this.showEnglishTranslation,
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

  void toggleMicUsage() => state = state.copyWith(isMicEnabled: !state.isMicEnabled);
}

// --- Dialogue Overlay Visibility ---
final dialogueOverlayVisibilityProvider = StateProvider<bool>((ref) => false);

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

// Provider to track if a special item has been received from an NPC
final specialItemReceivedProvider = StateProvider.family<bool, String>((ref, npcId) => false);

@immutable
class PopupConfig {
  final String title;
  final String message;
  final String? confirmText;
  final void Function(BuildContext context)? onConfirm;
  final String? cancelText;
  final void Function(BuildContext context)? onCancel;

  const PopupConfig({
    required this.title,
    required this.message,
    this.confirmText,
    this.onConfirm,
    this.cancelText,
    this.onCancel,
  });
}

final popupConfigProvider = StateProvider<PopupConfig?>((ref) => null);