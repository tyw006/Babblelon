import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Service for managing background music and sound effects
class BackgroundAudioService {
  static final BackgroundAudioService _instance = BackgroundAudioService._internal();
  factory BackgroundAudioService() => _instance;
  BackgroundAudioService._internal();

  final AudioPlayer _musicPlayer = AudioPlayer();
  final AudioPlayer _effectsPlayer = AudioPlayer();
  
  bool _isMusicEnabled = true;
  bool _areEffectsEnabled = true;
  double _musicVolume = 0.6;
  double _effectsVolume = 0.8;
  
  String? _currentBackgroundMusic;
  bool _isMusicPlaying = false;

  /// Initialize the audio service with game settings
  Future<void> initialize({
    bool musicEnabled = true,
    bool soundEffectsEnabled = true,
  }) async {
    try {
      _isMusicEnabled = musicEnabled;
      _areEffectsEnabled = soundEffectsEnabled;
      
      await _musicPlayer.setVolume(_musicVolume);
      await _effectsPlayer.setVolume(_effectsVolume);
      
      // Set release mode to keep audio playing when app is backgrounded
      await _musicPlayer.setReleaseMode(ReleaseMode.loop);
      await _effectsPlayer.setReleaseMode(ReleaseMode.stop);
      
      // Stop music if it was disabled
      if (!_isMusicEnabled && _isMusicPlaying) {
        stopBackgroundMusic();
      }
      
      debugPrint('BackgroundAudioService: Initialized with music volume $_musicVolume, effects volume $_effectsVolume');
      debugPrint('BackgroundAudioService: Music enabled: $_isMusicEnabled, effects enabled: $_areEffectsEnabled');
      debugPrint('BackgroundAudioService: Received musicEnabled: $musicEnabled, soundEffectsEnabled: $soundEffectsEnabled');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error during initialization: $e');
    }
  }
  
  /// Update audio settings
  void updateSettings({
    required bool musicEnabled,
    required bool soundEffectsEnabled,
  }) {
    _isMusicEnabled = musicEnabled;
    _areEffectsEnabled = soundEffectsEnabled;
    
    // Stop music if it was disabled
    if (!_isMusicEnabled && _isMusicPlaying) {
      stopBackgroundMusic();
    }
    
    debugPrint('BackgroundAudioService: Updated settings - music: $_isMusicEnabled, effects: $_areEffectsEnabled');
  }

  /// Play background music for the intro screen
  Future<void> playIntroMusic() async {
    if (!_isMusicEnabled) return;
    
    const musicPath = 'audio/bg/background_introscreen.wav';
    
    try {
      // Stop any currently playing music
      await stopBackgroundMusic();
      
      // Play the intro music
      await _musicPlayer.play(AssetSource(musicPath));
      _currentBackgroundMusic = musicPath;
      _isMusicPlaying = true;
      
      debugPrint('BackgroundAudioService: Started playing intro music');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error playing intro music: $e');
    }
  }
  
  /// Play background music for the game
  Future<void> playGameMusic() async {
    if (!_isMusicEnabled) return;
    
    const musicPath = 'audio/bg/background_yaowarat.wav';
    
    try {
      // Stop any currently playing music
      await stopBackgroundMusic();
      
      // Play the game music
      await _musicPlayer.play(AssetSource(musicPath));
      _currentBackgroundMusic = musicPath;
      _isMusicPlaying = true;
      
      debugPrint('BackgroundAudioService: Started playing game music');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error playing game music: $e');
    }
  }
  
  /// Play background music for boss fight
  Future<void> playBossFightMusic() async {
    if (!_isMusicEnabled) return;
    
    const musicPath = 'audio/bg/background_tuktukbossfight.wav';
    
    try {
      // Stop any currently playing music
      await stopBackgroundMusic();
      
      // Play the boss fight music
      await _musicPlayer.play(AssetSource(musicPath));
      _currentBackgroundMusic = musicPath;
      _isMusicPlaying = true;
      
      debugPrint('BackgroundAudioService: Started playing boss fight music');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error playing boss fight music: $e');
    }
  }

  /// Play sound effect for the start game zoom animation
  Future<void> playStartGameSound() async {
    if (!_areEffectsEnabled) return;
    
    const soundPath = 'audio/soundeffects/soundeffect_startgame.mp3';
    
    try {
      // Stop any currently playing sound effect
      await _effectsPlayer.stop();
      
      // Play the sound effect
      await _effectsPlayer.play(AssetSource(soundPath));
      
      debugPrint('BackgroundAudioService: Played start game sound effect');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error playing start game sound: $e');
    }
  }

  /// Play portal sound effect
  Future<void> playPortalSound() async {
    if (!_areEffectsEnabled) return;
    
    const soundPath = 'audio/soundeffects/soundeffect_portal_v2.mp3';
    
    try {
      await _effectsPlayer.stop();
      await _effectsPlayer.play(AssetSource(soundPath));
      
      debugPrint('BackgroundAudioService: Played portal sound effect');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error playing portal sound: $e');
    }
  }
  
  /// Play any sound effect by path
  Future<void> playSoundEffect(String path, {double volume = 1.0}) async {
    if (!_areEffectsEnabled) return;
    
    try {
      await _effectsPlayer.stop();
      await _effectsPlayer.setVolume(volume * _effectsVolume);
      await _effectsPlayer.play(AssetSource(path));
      
      debugPrint('BackgroundAudioService: Played sound effect: $path');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error playing sound effect $path: $e');
    }
  }

  /// Stop background music
  Future<void> stopBackgroundMusic() async {
    try {
      await _musicPlayer.stop();
      _currentBackgroundMusic = null;
      _isMusicPlaying = false;
      
      debugPrint('BackgroundAudioService: Stopped background music');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error stopping background music: $e');
    }
  }

  /// Pause background music
  Future<void> pauseBackgroundMusic() async {
    try {
      await _musicPlayer.pause();
      _isMusicPlaying = false;
      
      debugPrint('BackgroundAudioService: Paused background music');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error pausing background music: $e');
    }
  }

  /// Resume background music
  Future<void> resumeBackgroundMusic() async {
    try {
      await _musicPlayer.resume();
      _isMusicPlaying = true;
      
      debugPrint('BackgroundAudioService: Resumed background music');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error resuming background music: $e');
    }
  }

  /// Fade out background music
  Future<void> fadeOutMusic({Duration duration = const Duration(seconds: 2)}) async {
    if (!_isMusicPlaying) return;
    
    try {
      const steps = 20;
      final stepDuration = duration.inMilliseconds ~/ steps;
      final volumeStep = _musicVolume / steps;
      
      for (int i = steps; i > 0; i--) {
        await _musicPlayer.setVolume(volumeStep * i);
        await Future.delayed(Duration(milliseconds: stepDuration));
      }
      
      await stopBackgroundMusic();
      await _musicPlayer.setVolume(_musicVolume); // Reset volume
      
      debugPrint('BackgroundAudioService: Faded out background music');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error fading out music: $e');
    }
  }

  /// Fade in background music
  Future<void> fadeInMusic({Duration duration = const Duration(seconds: 2)}) async {
    if (!_isMusicEnabled || _currentBackgroundMusic == null) return;
    
    try {
      await _musicPlayer.setVolume(0);
      await _musicPlayer.play(AssetSource(_currentBackgroundMusic!));
      _isMusicPlaying = true;
      
      const steps = 20;
      final stepDuration = duration.inMilliseconds ~/ steps;
      final volumeStep = _musicVolume / steps;
      
      for (int i = 1; i <= steps; i++) {
        await _musicPlayer.setVolume(volumeStep * i);
        await Future.delayed(Duration(milliseconds: stepDuration));
      }
      
      debugPrint('BackgroundAudioService: Faded in background music');
    } catch (e) {
      debugPrint('BackgroundAudioService: Error fading in music: $e');
    }
  }

  /// Set music volume (0.0 to 1.0)
  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    await _musicPlayer.setVolume(_musicVolume);
    debugPrint('BackgroundAudioService: Set music volume to $_musicVolume');
  }

  /// Set effects volume (0.0 to 1.0)
  Future<void> setEffectsVolume(double volume) async {
    _effectsVolume = volume.clamp(0.0, 1.0);
    await _effectsPlayer.setVolume(_effectsVolume);
    debugPrint('BackgroundAudioService: Set effects volume to $_effectsVolume');
  }

  /// Enable/disable music
  void setMusicEnabled(bool enabled) {
    _isMusicEnabled = enabled;
    if (!enabled && _isMusicPlaying) {
      stopBackgroundMusic();
    }
    debugPrint('BackgroundAudioService: Music enabled: $_isMusicEnabled');
  }

  /// Enable/disable sound effects
  void setEffectsEnabled(bool enabled) {
    _areEffectsEnabled = enabled;
    if (!enabled) {
      _effectsPlayer.stop();
    }
    debugPrint('BackgroundAudioService: Effects enabled: $_areEffectsEnabled');
  }

  /// Get current music status
  bool get isMusicPlaying => _isMusicPlaying;
  bool get isMusicEnabled => _isMusicEnabled;
  bool get areEffectsEnabled => _areEffectsEnabled;
  double get musicVolume => _musicVolume;
  double get effectsVolume => _effectsVolume;
  String? get currentBackgroundMusic => _currentBackgroundMusic;

  /// Get audio service status
  Map<String, dynamic> getStatus() {
    return {
      'isMusicPlaying': _isMusicPlaying,
      'isMusicEnabled': _isMusicEnabled,
      'areEffectsEnabled': _areEffectsEnabled,
      'musicVolume': _musicVolume,
      'effectsVolume': _effectsVolume,
      'currentBackgroundMusic': _currentBackgroundMusic,
    };
  }

  /// Dispose of audio resources
  void dispose() {
    _musicPlayer.dispose();
    _effectsPlayer.dispose();
    debugPrint('BackgroundAudioService: Disposed audio resources');
  }
}