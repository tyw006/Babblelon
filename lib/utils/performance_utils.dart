import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Performance-optimized text animation using Flutter's built-in AnimationController
/// instead of Timer.periodic which causes frequent setState calls
class OptimizedTextAnimator {
  final TickerProvider tickerProvider;
  final Function(String) onTextUpdate;
  final VoidCallback? onComplete;
  
  AnimationController? _controller;
  Animation<int>? _animation;
  String _fullText = "";
  
  OptimizedTextAnimator({
    required this.tickerProvider,
    required this.onTextUpdate,
    this.onComplete,
  });

  void startAnimation(String fullText, Duration duration) {
    _fullText = fullText;
    
    _controller?.dispose();
    _controller = AnimationController(
      duration: duration,
      vsync: tickerProvider,
    );
    
    _animation = IntTween(
      begin: 0,
      end: fullText.length,
    ).animate(CurvedAnimation(
      parent: _controller!,
      curve: Curves.linear,
    ));
    
    _animation!.addListener(() {
      final currentLength = _animation!.value;
      final displayText = _fullText.substring(0, currentLength);
      onTextUpdate(displayText);
    });
    
    _animation!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        onComplete?.call();
      }
    });
    
    _controller!.forward();
  }
  
  void dispose() {
    _controller?.dispose();
  }
}

/// Performance-optimized scroll controller that batches scroll operations
class OptimizedScrollController extends ScrollController {
  Timer? _scrollTimer;
  
  void scrollToBottomBatched() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(milliseconds: 16), () {
      if (hasClients) {
        animateTo(
          position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }
  
  @override
  void dispose() {
    _scrollTimer?.cancel();
    super.dispose();
  }
}

/// Debounced ValueNotifier to reduce rebuild frequency
class DebouncedValueNotifier<T> extends ValueNotifier<T> {
  Timer? _debounceTimer;
  final Duration debounceDuration;
  
  DebouncedValueNotifier(super.value, {this.debounceDuration = const Duration(milliseconds: 100)});
  
  void debouncedUpdate(T newValue) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      value = newValue;
    });
  }
  
  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Memory-efficient audio cache
class AudioCache {
  static final Map<String, Uint8List> _cache = {};
  static const int _maxCacheSize = 10; // Limit cache size
  
  static void cache(String key, Uint8List data) {
    if (_cache.length >= _maxCacheSize) {
      // Remove oldest entry (simple FIFO strategy)
      final firstKey = _cache.keys.first;
      _cache.remove(firstKey);
    }
    _cache[key] = data;
  }
  
  static Uint8List? get(String key) {
    return _cache[key];
  }
  
  static void clear() {
    _cache.clear();
  }
}