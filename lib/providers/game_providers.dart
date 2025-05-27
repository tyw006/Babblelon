import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'game_providers.g.dart';

class GameStateData {
  final bool isPaused;
  final bool musicEnabled;
  final bool bgmIsPlaying;

  GameStateData({
    this.isPaused = false,
    this.musicEnabled = true,
    this.bgmIsPlaying = true,
  });

  GameStateData copyWith({bool? isPaused, bool? musicEnabled, bool? bgmIsPlaying}) => GameStateData(
    isPaused: isPaused ?? this.isPaused,
    musicEnabled: musicEnabled ?? this.musicEnabled,
    bgmIsPlaying: bgmIsPlaying ?? this.bgmIsPlaying,
  );
}

@Riverpod(keepAlive: true)
class GameState extends _$GameState {
  @override
  GameStateData build() => GameStateData();

  void pause() => state = state.copyWith(isPaused: true);
  void resume() => state = state.copyWith(isPaused: false);
  void toggleMusic() => state = state.copyWith(musicEnabled: !state.musicEnabled);
  void setBgmPlaying(bool playing) => state = state.copyWith(bgmIsPlaying: playing);
} 