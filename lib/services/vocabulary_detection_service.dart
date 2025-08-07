import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/local_storage_models.dart';
import '../models/supabase_models.dart';
import 'isar_service.dart';
import 'sync_service.dart';

class VocabularyDetectionService {
  static final VocabularyDetectionService _instance = VocabularyDetectionService._internal();
  factory VocabularyDetectionService() => _instance;
  VocabularyDetectionService._internal();

  final IsarService _isarService = IsarService();
  final SyncService _syncService = SyncService();
  
  Map<String, List<Vocabulary>> _npcVocabularyCache = {};
  Set<String> _predefinedWords = {};

  // Load vocabulary for a specific NPC
  Future<void> loadNpcVocabulary(String npcId) async {
    if (_npcVocabularyCache.containsKey(npcId)) return;

    try {
      String vocabularyPath = 'assets/data/npc_vocabulary_$npcId.json';
      String jsonString = await rootBundle.loadString(vocabularyPath);
      Map<String, dynamic> jsonData = json.decode(jsonString);
      
      List<dynamic> vocabularyList = jsonData['vocabulary'] ?? [];
      List<Vocabulary> vocabularies = vocabularyList
          .map((item) => Vocabulary.fromJson(item))
          .toList();
      
      _npcVocabularyCache[npcId] = vocabularies;
      
      // Build predefined words set for this NPC
      for (final vocab in vocabularies) {
        _predefinedWords.add(vocab.thai.toLowerCase());
        _predefinedWords.add(vocab.english.toLowerCase());
        // Add individual words from word_mapping
        for (final mapping in vocab.wordMapping) {
          _predefinedWords.add(mapping.thai.toLowerCase());
          _predefinedWords.add(mapping.translation.toLowerCase());
        }
      }
    } catch (e) {
      print('Error loading vocabulary for NPC $npcId: $e');
    }
  }

  // Detect custom words from LLM input mapping
  Future<List<CustomVocabularyEntry>> detectCustomWords(
    List<dynamic> inputMappings, 
    String npcId
  ) async {
    await loadNpcVocabulary(npcId);
    
    List<CustomVocabularyEntry> customWords = [];
    
    for (final mapping in inputMappings) {
      final wordThai = mapping['word_target']?.toString().toLowerCase() ?? '';
      final wordEnglish = mapping['word_eng']?.toString().toLowerCase() ?? '';
      final transliteration = mapping['word_translit']?.toString() ?? '';
      final posTag = mapping['pos']?.toString() ?? '';
      
      // Skip empty or very short words
      if (wordThai.length < 2) continue;
      
      // Check if this word is NOT in predefined vocabulary
      if (!_isWordPredefined(wordThai, wordEnglish)) {
        // Check if we already have this custom word locally
        final existingWord = await _isarService.getCustomVocabulary(wordThai);
        
        if (existingWord != null) {
          // Update existing custom word usage
          await _updateExistingCustomWord(existingWord, npcId);
        } else {
          // Create new custom word entry
          final customWord = await _createNewCustomWord(
            wordThai: wordThai,
            wordEnglish: wordEnglish.isNotEmpty ? wordEnglish : null,
            transliteration: transliteration.isNotEmpty ? transliteration : null,
            posTag: posTag.isNotEmpty ? posTag : null,
            npcContext: npcId,
          );
          customWords.add(customWord);
        }
      }
    }
    
    return customWords;
  }

  // Check if a word exists in predefined vocabulary
  bool _isWordPredefined(String wordThai, String wordEnglish) {
    final thaiLower = wordThai.toLowerCase();
    final englishLower = wordEnglish.toLowerCase();
    
    return _predefinedWords.contains(thaiLower) || 
           (englishLower.isNotEmpty && _predefinedWords.contains(englishLower));
  }

  // Update existing custom word with new usage
  Future<void> _updateExistingCustomWord(
    CustomVocabularyEntry existingWord, 
    String npcId
  ) async {
    existingWord.timesUsed += 1;
    existingWord.lastUsedAt = DateTime.now();
    existingWord.needsSync = true;
    
    // Update NPC context if different
    if (!existingWord.npcContext.contains(npcId)) {
      existingWord.npcContext.add(npcId);
    }
    
    await _isarService.saveCustomVocabulary(existingWord);
    
    // Trigger sync if online
    if (await _syncService.hasConnectivity) {
      await _syncService.syncCustomVocabulary();
    }
  }

  // Create new custom word entry
  Future<CustomVocabularyEntry> _createNewCustomWord({
    required String wordThai,
    String? wordEnglish,
    String? transliteration,
    String? posTag,
    required String npcContext,
  }) async {
    final customWord = CustomVocabularyEntry()
      ..wordThai = wordThai
      ..wordEnglish = wordEnglish
      ..transliteration = transliteration
      ..posTag = posTag
      ..npcContext = [npcContext]
      ..timesUsed = 1
      ..firstDiscoveredAt = DateTime.now()
      ..lastUsedAt = DateTime.now()
      ..needsSync = true;

    await _isarService.saveCustomVocabulary(customWord);
    
    // Trigger sync if online
    if (await _syncService.hasConnectivity) {
      await _syncService.syncCustomVocabulary();
    }
    
    return customWord;
  }

  // Get custom vocabulary for display/review
  Future<List<CustomVocabularyEntry>> getCustomVocabularyForNpc(String npcId) async {
    final allCustomWords = await _isarService.getAllCustomVocabulary();
    return allCustomWords
        .where((word) => word.npcContext?.contains(npcId) == true)
        .toList();
  }

  // Get all custom vocabulary sorted by usage
  Future<List<CustomVocabularyEntry>> getAllCustomVocabulary() async {
    final customWords = await _isarService.getAllCustomVocabulary();
    customWords.sort((a, b) => b.timesUsed.compareTo(a.timesUsed));
    return customWords;
  }

  // Update pronunciation score for custom word
  Future<void> updateCustomWordPronunciationScore(
    String wordThai, 
    double pronunciationScore
  ) async {
    final customWord = await _isarService.getCustomVocabulary(wordThai);
    if (customWord != null) {
      customWord.pronunciationScores.add(pronunciationScore);
      customWord.isMastered = pronunciationScore >= 60.0; // Mastery threshold
      customWord.needsSync = true;
      
      await _isarService.saveCustomVocabulary(customWord);
      
      // Trigger sync if online
      if (await _syncService.hasConnectivity) {
        await _syncService.syncCustomVocabulary();
      }
    }
  }

  // Get vocabulary statistics for analytics
  Future<Map<String, dynamic>> getVocabularyStats() async {
    final customWords = await _isarService.getAllCustomVocabulary();
    final masteredWords = customWords.where((w) => w.isMastered).length;
    final totalWords = customWords.length;
    final recentWords = customWords
        .where((w) => DateTime.now().difference(w.firstDiscoveredAt).inDays <= 7)
        .length;

    return {
      'totalCustomWords': totalWords,
      'masteredWords': masteredWords,
      'masteryPercentage': totalWords > 0 ? (masteredWords / totalWords * 100) : 0,
      'recentlyDiscovered': recentWords,
      'mostUsedWords': customWords
          .take(5)
          .map((w) => {'word': w.wordThai, 'timesUsed': w.timesUsed})
          .toList(),
    };
  }

  // Clear vocabulary cache (useful for testing or memory management)
  void clearCache() {
    _npcVocabularyCache.clear();
    _predefinedWords.clear();
  }
}