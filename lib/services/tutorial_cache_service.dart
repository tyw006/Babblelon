import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:babblelon/services/tutorial_database_service.dart';

/// High-performance tutorial cache service
/// Loads tutorial completion states once after authentication and provides
/// fast in-memory lookups throughout the app session
class TutorialCacheService {
  final TutorialDatabaseService _databaseService = TutorialDatabaseService();
  
  Map<String, bool> _cache = {};
  bool _isLoaded = false;
  String? _loadedForUserId;
  
  /// Load tutorial completions for authenticated user
  /// Should be called once after successful authentication
  Future<void> loadAfterAuth(String userId) async {
    // Avoid reloading for same user
    if (_isLoaded && _loadedForUserId == userId) {
      debugPrint('TutorialCache: Already loaded for user $userId');
      return;
    }
    
    debugPrint('TutorialCache: Loading tutorial states for user $userId');
    
    try {
      // Load all tutorial completion states from database in one query
      final completedTutorials = await _databaseService.getCompletedTutorials();
      
      // Convert to bool map for fast lookups
      _cache = <String, bool>{};
      completedTutorials.forEach((key, value) {
        _cache[key] = value == true;
      });
      
      _isLoaded = true;
      _loadedForUserId = userId;
      
      debugPrint('TutorialCache: Loaded ${_cache.length} tutorial states for user $userId');
    } catch (e) {
      debugPrint('TutorialCache: Error loading tutorial states: $e');
      _cache = {};
      _isLoaded = false;
      _loadedForUserId = null;
    }
  }
  
  /// Check if a tutorial is completed (fast O(1) memory lookup)
  bool isTutorialCompleted(String tutorialId) {
    if (!_isLoaded) {
      debugPrint('TutorialCache: Warning - cache not loaded, returning false for $tutorialId');
      return false;
    }
    
    return _cache[tutorialId] ?? false;
  }
  
  /// Mark tutorial as completed in cache and queue for database sync
  void markCompleted(String tutorialId) {
    _cache[tutorialId] = true;
    
    // Async database update (don't await to maintain performance)
    _databaseService.markTutorialCompleted(tutorialId).catchError((error) {
      debugPrint('TutorialCache: Error syncing tutorial completion to database: $error');
    });
    
    debugPrint('TutorialCache: Marked $tutorialId as completed');
  }
  
  /// Reset tutorial completion in cache and queue for database sync
  void resetTutorial(String tutorialId) {
    _cache.remove(tutorialId);
    
    // Async database update
    _databaseService.resetTutorial(tutorialId).catchError((error) {
      debugPrint('TutorialCache: Error syncing tutorial reset to database: $error');
    });
    
    debugPrint('TutorialCache: Reset tutorial $tutorialId');
  }
  
  /// Clear cache (called on sign out)
  void clear() {
    _cache.clear();
    _isLoaded = false;
    _loadedForUserId = null;
    debugPrint('TutorialCache: Cache cleared');
  }
  
  /// Force refresh from database
  Future<void> refresh() async {
    if (_loadedForUserId != null) {
      _isLoaded = false;
      await loadAfterAuth(_loadedForUserId!);
    }
  }
  
  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final completedCount = _cache.values.where((completed) => completed).length;
    return {
      'loaded': _isLoaded,
      'user_id': _loadedForUserId,
      'total_tutorials': _cache.length,
      'completed_tutorials': completedCount,
      'completion_rate': _cache.isNotEmpty ? (completedCount / _cache.length * 100).round() : 0,
    };
  }
}