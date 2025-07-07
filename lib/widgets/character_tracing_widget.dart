import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import '../services/character_audio_service.dart';
import '../services/game_initialization_service.dart';

/// A reusable character tracing widget that provides live stroke rendering
/// and character tracing functionality.
/// 
/// This widget is extracted from the working test implementation to ensure
/// consistent behavior across the app.
class CharacterTracingWidget extends StatefulWidget {
  /// The word mapping data containing Thai characters and their translations
  final List<Map<String, dynamic>> wordMapping;
  
  /// The original vocabulary item data (contains audio_path and other metadata)
  final Map<String, dynamic>? originalVocabularyItem;
  
  /// Called when the user wants to go back
  final VoidCallback? onBack;
  
  /// Called when tracing is completed successfully
  final VoidCallback? onComplete;
  
  /// Whether to show the back button in the header
  final bool showBackButton;
  
  /// Custom header title (if null, uses word from mapping)
  final String? headerTitle;
  
  /// Custom header subtitle (if null, uses translation from mapping)
  final String? headerSubtitle;
  
  /// Whether to show writing tips panel
  final bool showWritingTips;

  const CharacterTracingWidget({
    super.key,
    required this.wordMapping,
    this.originalVocabularyItem,
    this.onBack,
    this.onComplete,
    this.showBackButton = true,
    this.headerTitle,
    this.headerSubtitle,
    this.showWritingTips = true,
  });

  @override
  State<CharacterTracingWidget> createState() => _CharacterTracingWidgetState();
}

class _CharacterTracingWidgetState extends State<CharacterTracingWidget> {
  // Character tracing state
  int _currentCharacterIndex = 0;
  List<String> _currentCharacters = [];
  final ScrollController _characterScrollController = ScrollController();
  
  // Enhanced cluster data from backend
  List<String> _romanizationByCluster = [];
  List<Map<String, dynamic>> _constituentWordData = [];
  String _originalWord = '';
  
  // Pre-processing cache for word analysis
  Map<String, Map<String, dynamic>> _wordAnalysisCache = {};
  bool _isPreprocessingComplete = false;
  
  // Canvas overflow detection
  bool _isOverflowing = false;
  
  // Drawing state  
  final mlkit.Ink _ink = mlkit.Ink();
  mlkit.Stroke? _currentStroke;
  final List<mlkit.StrokePoint> _currentStrokePoints = [];
  final List<mlkit.Stroke> _strokeHistory = []; // For undo functionality
  
  // Writing tips and guidance
  String _writingTips = "";
  bool _isLoadingTips = false;
  bool _hasLoadingError = false;
  Map<String, dynamic> _writingGuidance = {};
  
  // Audio services
  final AudioPlayer _audioPlayer = AudioPlayer();
  final CharacterAudioService _audioService = CharacterAudioService();

  // Add Thai writing guide data cache
  Map<String, dynamic>? _thaiWritingGuideData;

  @override
  void initState() {
    super.initState();
    _initializeAsync();
  }

  /// Initialize widget with proper async sequencing
  Future<void> _initializeAsync() async {
    // Load Thai writing guide first
    await _loadThaiWritingGuide();
    // Then initialize characters (which will load writing tips)
    await _initializeCharacters();
  }

  /// Load Thai writing guide data from cached service or JSON file as fallback
  Future<void> _loadThaiWritingGuide() async {
    try {
      // First try to get cached data from GameInitializationService
      final initService = GameInitializationService();
      if (initService.isThaiWritingGuideCached()) {
        _thaiWritingGuideData = initService.getCachedThaiWritingGuide();
        print('✅ Thai writing guide loaded from cache');
        return;
      }
      
      // Fallback: load directly from assets if not cached
      print('⚠️ Loading Thai writing guide from assets (cache not available)');
      final jsonString = await rootBundle.loadString('assets/data/thai_writing_guide.json');
      _thaiWritingGuideData = json.decode(jsonString);
      print('✅ Thai writing guide loaded from assets');
      
    } catch (e) {
      print('❌ Error loading Thai writing guide: $e');
      _thaiWritingGuideData = null;
    }
  }

  @override
  void dispose() {
    _characterScrollController.dispose();
    _audioPlayer.dispose();
    // Don't dispose the singleton _audioService as it's shared across widgets
    super.dispose();
  }

  Future<void> _initializeCharacters() async {
    if (widget.wordMapping.isNotEmpty) {
      try {
        // Initialize word segments and preload analysis
        await _getWordSegments();
        await _preloadAllWordAnalysis();
        _checkTextOverflow();
      } catch (e) {
        print('Character initialization error: $e');
        // Fallback: use basic character splitting
        final itemData = widget.wordMapping[0];
        final targetWord = itemData["target"] as String? ?? "";
        _currentCharacters = targetWord.split('');
        _originalWord = targetWord;
        // Generate Thai writing guide tips immediately
        setState(() {
          _writingTips = _buildEnhancedFallbackTips(targetWord);
          _isLoadingTips = false;
        });
      }
    }
  }

  /// Get word segments using semantic word boundaries from word_mapping
  Future<void> _getWordSegments() async {
    // Since the dialogue overlay now passes semantic words directly,
    // widget.wordMapping contains the semantic word breakdown
    _constituentWordData = [];
    _currentCharacters = []; // This will store semantic words, not TCC clusters
    
    // Process each semantic word from the passed wordMapping
    for (final mapping in widget.wordMapping) {
      // Use 'target' field (which is mapped from 'thai' in NPC vocabulary)
      final semanticWord = mapping['target'] as String? ?? mapping['thai'] as String? ?? '';
      final transliteration = mapping['transliteration'] as String? ?? '';
      final translation = mapping['translation'] as String? ?? '';
      final english = mapping['english'] as String? ?? ''; // Extract english field
      
      // Store semantic word for tracing (each semantic word gets its own canvas)
      if (semanticWord.isNotEmpty) {
        _currentCharacters.add(semanticWord);
      }
      
      // Store constituent word data for display
      _constituentWordData.add({
        'word': semanticWord,
        'romanized': transliteration,
        'translation': translation,
        'english': english, // Include english field
      });
    }
    
    // Set original word as concatenation of all semantic words
    _originalWord = _currentCharacters.join('');
    
    print('Using semantic word boundaries: $_currentCharacters');
    print('Constituent word data: $_constituentWordData');
  }

  /// Pre-load comprehensive analysis for all semantic words to avoid API calls during word switching
  Future<void> _preloadAllWordAnalysis() async {
    print('Starting word analysis pre-processing for ${_currentCharacters.length} words');
    
    // Skip backend analysis for performance and use Thai writing guide directly
    for (final semanticWord in _currentCharacters) {
      if (semanticWord.isNotEmpty && !_wordAnalysisCache.containsKey(semanticWord)) {
        // Create a basic cache entry for Thai writing guide usage
        _wordAnalysisCache[semanticWord] = {
          'word': semanticWord,
          'use_thai_guide': true,
          'fallback': false, // Mark as NOT fallback since we have Thai guide data
        };
      }
    }
    
    _isPreprocessingComplete = true;
    print('Word analysis pre-processing completed using Thai writing guide. Cached ${_wordAnalysisCache.length} words');
    
    // Load initial writing tips (will use Thai writing guide data)
    await _loadWritingTipsFromCache();
  }

  /// Pre-load analysis for a single word with short timeout
  Future<void> _preloadSingleWordAnalysis(String semanticWord) async {
    if (semanticWord.isEmpty || _wordAnalysisCache.containsKey(semanticWord)) {
      return;
    }
    
    try {
      print('Pre-processing analysis for: $semanticWord');
      
      final response = await http.post(
        Uri.parse('http://localhost:8000/analyze-word-syllables'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'word': semanticWord,
          'target_language': 'th'
        }),
      ).timeout(const Duration(seconds: 10)); // Increased timeout per word
      
      if (response.statusCode == 200) {
        final analysisData = json.decode(response.body);
        _wordAnalysisCache[semanticWord] = analysisData;
        print('Successfully cached analysis for: $semanticWord');
      } else {
        print('Failed to get analysis for $semanticWord: ${response.statusCode}');
        _storeFallbackAnalysis(semanticWord);
      }
    } catch (e) {
      print('Error getting analysis for $semanticWord: $e');
      _storeFallbackAnalysis(semanticWord);
    }
  }

  /// Store fallback analysis data for a word
  void _storeFallbackAnalysis(String semanticWord) {
    _wordAnalysisCache[semanticWord] = {
      'word': semanticWord,
      'error': 'Analysis failed',
      'fallback': true
    };
  }

  /// Tokenize vocabulary words using their pre-split word_mapping
  Future<void> _tokenizeVocabularyWords(List<Map<String, dynamic>> wordMapping) async {
    _currentCharacters = [];
    _romanizationByCluster = [];
    
    try {
      // Process each constituent word from the word_mapping
      for (final mapping in wordMapping) {
        final word = mapping['target'] as String? ?? '';
        if (word.isNotEmpty) {
          // Call backend to get TCC tokenization for this individual word
          final response = await http.post(
            Uri.parse('http://localhost:8000/split-word-for-tracing'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'word': word,
              'target_language': 'th'
            }),
          ).timeout(const Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            
            // Extract TCC clusters for this word
            if (data.containsKey('subword_clusters') && data['subword_clusters'] is List) {
              final clusters = List<String>.from(data['subword_clusters']);
              _currentCharacters.addAll(clusters);
              
              // Add romanization if available
              if (data.containsKey('romanization_by_cluster') && data['romanization_by_cluster'] is List) {
                final romanizations = List<String>.from(data['romanization_by_cluster']);
                _romanizationByCluster.addAll(romanizations);
              } else {
                // Fallback: use the mapping's transliteration for the whole word
                final transliteration = mapping['transliteration'] as String? ?? '';
                for (int i = 0; i < clusters.length; i++) {
                  _romanizationByCluster.add(transliteration);
                }
              }
            } else {
              // Fallback: split word into individual characters
              _currentCharacters.addAll(word.split(''));
              final transliteration = mapping['transliteration'] as String? ?? '';
              for (int i = 0; i < word.length; i++) {
                _romanizationByCluster.add(transliteration);
              }
            }
          } else {
            // Backend failed, fallback to character splitting
            _currentCharacters.addAll(word.split(''));
            final transliteration = mapping['transliteration'] as String? ?? '';
            for (int i = 0; i < word.length; i++) {
              _romanizationByCluster.add(transliteration);
            }
          }
        }
      }
      
      print('Vocabulary word TCC tokenization result: $_currentCharacters');
      print('Romanizations: $_romanizationByCluster');
      
    } catch (e) {
      print('Error tokenizing vocabulary words: $e');
      // Fallback: split all words into characters
      for (final mapping in wordMapping) {
        final word = mapping['target'] as String? ?? '';
        _currentCharacters.addAll(word.split(''));
      }
    }
  }

  /// Use backend word_tokenize for semantic word boundaries
  Future<void> _tokenizeWordUsingBackendForSemanticWords(String targetWord) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/split-word-for-tracing'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'word': targetWord,
          'target_language': 'th'
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Use semantic_words for canvas boundaries (NOT TCC clusters)
        if (data.containsKey('semantic_words') && data['semantic_words'] is List) {
          _currentCharacters = List<String>.from(data['semantic_words']);
          print('Using semantic words from backend: $_currentCharacters');
        } else {
          // Fallback to original word as single semantic unit
          _currentCharacters = [targetWord];
        }
        
        // Store constituent word data if available
        if (data.containsKey('constituent_word_data') && data['constituent_word_data'] is List) {
          _constituentWordData = List<Map<String, dynamic>>.from(data['constituent_word_data']);
        }
        
      } else {
        print('Backend semantic word tokenization failed with status: ${response.statusCode}');
        _currentCharacters = [targetWord]; // Treat as single semantic word
      }
    } catch (e) {
      print('Error tokenizing word using backend for semantic words: $e');
      _currentCharacters = [targetWord]; // Treat as single semantic word
    }
  }

  /// Use backend TCC tokenization for custom words
  Future<void> _tokenizeWordUsingBackend(String targetWord) async {
    try {
      // Use the new split-word-for-tracing endpoint for proper TCC tokenization with timeout
      final response = await http.post(
        Uri.parse('http://localhost:8000/split-word-for-tracing'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'word': targetWord,
          'target_language': 'th'
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Store enhanced cluster data
        _originalWord = data['original_word'] ?? targetWord;
        _romanizationByCluster = data.containsKey('romanization_by_cluster')
            ? List<String>.from(data['romanization_by_cluster'])
            : [];
        _constituentWordData = data.containsKey('constituent_word_data')
            ? List<Map<String, dynamic>>.from(data['constituent_word_data'])
            : [];
        
        // Use the optimal tracing sequence (TCCs) from PyThaiNLP
        if (data.containsKey('tracing_sequence') && data['tracing_sequence'] is List) {
          _currentCharacters = List<String>.from(data['tracing_sequence']);
          print('Using TCC-based tracing sequence: $_currentCharacters');
        } else if (data.containsKey('subword_clusters') && data['subword_clusters'] is List) {
          // Fallback to subword clusters
          _currentCharacters = List<String>.from(data['subword_clusters']);
          print('Using subword clusters: $_currentCharacters');
        } else {
          // Last resort: split into individual characters
          _currentCharacters = targetWord.split('');
          print('Fallback to character splitting: $_currentCharacters');
        }
        
        print('Backend tokenization result with enhanced data: ${data.toString()}');
      } else {
        print('Backend tokenization failed with status: ${response.statusCode}');
        _currentCharacters = targetWord.split('');
      }
    } on TimeoutException catch (e) {
      print('Backend tokenization timed out: $e');
      _currentCharacters = targetWord.split('');
    } catch (e) {
      print('Error tokenizing word using backend: $e');
      _currentCharacters = targetWord.split('');
    }
  }

  /// Build highlighted Thai text showing current semantic word
  Widget _buildHighlightedThaiText() {
    if (_originalWord.isEmpty || _currentCharacters.isEmpty) {
      return const SizedBox.shrink();
    }
    
    List<TextSpan> spans = [];
    
    for (int i = 0; i < _currentCharacters.length; i++) {
      final semanticWord = _currentCharacters[i];
      final isCurrentWord = i == _currentCharacterIndex;
      final isCompleted = i < _currentCharacterIndex;
      
      Color textColor;
      FontWeight fontWeight;
      
      if (isCurrentWord) {
        textColor = const Color(0xFF4ECCA3); // Highlighted current semantic word
        fontWeight = FontWeight.bold;
      } else if (isCompleted) {
        textColor = const Color(0xFF4ECCA3).withValues(alpha: 0.6); // Completed semantic words
        fontWeight = FontWeight.w500;
      } else {
        textColor = Colors.white54; // Upcoming semantic words
        fontWeight = FontWeight.w400;
      }
      
      spans.add(TextSpan(
        text: semanticWord,
        style: TextStyle(
          color: textColor,
          fontWeight: fontWeight,
          fontSize: 36,
        ),
      ));
      
      // Add space between semantic words (except after the last one)
      if (i < _currentCharacters.length - 1) {
        spans.add(const TextSpan(
          text: ' ',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 36,
          ),
        ));
      }
    }
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }

  /// Check if text will overflow the canvas
  void _checkTextOverflow() {
    if (_currentCharacters.isEmpty) return;
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: _currentCharacters.join(''),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    
    // Get available width (screen width minus margins)
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 120; // Account for margins and padding
    
    setState(() {
      _isOverflowing = textPainter.size.width > (availableWidth * 0.8);
    });
  }

  /// Load writing tips from pre-processed cache (no API calls during word switching)
  Future<void> _loadWritingTipsFromCache() async {
    print('_loadWritingTipsFromCache called, showWritingTips: ${widget.showWritingTips}');
    print('_currentCharacters length: ${_currentCharacters.length}');
    if (_currentCharacters.isEmpty || !widget.showWritingTips) return;
    
    setState(() {
      _isLoadingTips = true;
    });

    try {
      final semanticWord = _currentCharacters[_currentCharacterIndex];
      
      if (_wordAnalysisCache.containsKey(semanticWord)) {
        // Use cached analysis (comprehensive or fallback)
        final analysisData = _wordAnalysisCache[semanticWord]!;
        print('>>> CACHE HIT for word: $semanticWord, fallback: ${analysisData['fallback'] ?? false}');
        print('Cache data keys: ${analysisData.keys}');
        
        setState(() {
          _writingGuidance = analysisData;
          _writingTips = _buildComprehensiveEducationalTips(semanticWord, analysisData);
          _isLoadingTips = false;
          _hasLoadingError = false;
        });
      } else {
        // Cache miss - create enhanced fallback directly
        print('>>> CACHE MISS for word: $semanticWord. Creating enhanced fallback.');
        print('Available cache keys: ${_wordAnalysisCache.keys.toList()}');
        setState(() {
          _writingTips = _buildEnhancedFallbackTips(semanticWord);
          _isLoadingTips = false;
          _hasLoadingError = false;
        });
      }
    } catch (e) {
      print('Error loading writing tips from cache: $e');
      setState(() {
        _writingTips = _buildEnhancedFallbackTips(_currentCharacters[_currentCharacterIndex]);
        _isLoadingTips = false;
        _hasLoadingError = false;
      });
    }
  }

  /// Legacy method for backward compatibility - now redirects to cache
  Future<void> _loadWritingTips() async {
    if (_isPreprocessingComplete) {
      await _loadWritingTipsFromCache();
    } else {
      // If pre-processing not complete, wait and try again
      setState(() {
        _writingTips = 'Loading comprehensive analysis...';
        _isLoadingTips = false;
      });
    }
  }
  
  Future<void> _loadFallbackTips(String character) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/analyze-character'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'character': character}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _writingTips = _buildTipsFromAnalysis(character, data);
          _isLoadingTips = false;
        });
      } else {
        setState(() {
          _writingTips = _getStaticCharacterTips(character);
          _isLoadingTips = false;
        });
      }
    } on TimeoutException catch (e) {
      print('Fallback tips request timed out: $e');
      setState(() {
        _writingTips = 'Request timed out. Using basic tips for this character.';
        _isLoadingTips = false;
        _hasLoadingError = true;
      });
    } catch (e) {
      setState(() {
        _writingTips = _getStaticCharacterTips(character);
        _isLoadingTips = false;
      });
    }
  }

  void _retryLoadingTips() {
    setState(() {
      _hasLoadingError = false;
    });
    _loadWritingTips();
  }

  /// Build comprehensive educational writing tips with tabbed structure
  String _buildComprehensiveEducationalTips(String semanticWord, Map<String, dynamic> analysisData) {
    print('=== Building comprehensive tips for: $semanticWord ===');
    print('Analysis data keys: ${analysisData.keys}');
    print('Has fallback flag: ${analysisData.containsKey('fallback')} = ${analysisData['fallback']}');
    print('Thai writing guide loaded: ${_thaiWritingGuideData != null}');
    
    // Check if this is fallback data (backend failed)
    if (analysisData.containsKey('fallback') && analysisData['fallback'] == true) {
      print('>>> USING FALLBACK TIPS for: $semanticWord (backend failed)');
      return _buildEnhancedFallbackTips(semanticWord);
    }
    
    // Check if we should use Thai writing guide (our preferred method)
    if (analysisData.containsKey('use_thai_guide') && analysisData['use_thai_guide'] == true) {
      print('>>> USING THAI GUIDE TIPS for: $semanticWord');
      return _buildEnhancedFallbackTips(semanticWord);
    }
    
    // For any other case, use Thai writing guide tips
    return _buildEnhancedFallbackTips(semanticWord);
  }
  
  /// Build structured content for tabbed writing tips
  Map<String, List<String>> _buildTabbedWritingContent(String semanticWord, Map<String, dynamic> analysisData) {
    final content = <String, List<String>>{
      'general': _buildGeneralGuidelines(),
      'stepByStep': _buildStepByStepInstructions(semanticWord, analysisData),
      'pronunciation': _buildPronunciationGuide(semanticWord, analysisData),
    };
    return content;
  }
  
  /// Tab 1: Get general writing guidelines from thai_writing_guide.json
  List<String> _buildGeneralGuidelines() {
    final guidelines = <String>[];
    
    if (_thaiWritingGuideData != null) {
      final writingPrinciples = _thaiWritingGuideData!['writing_principles'] as Map<String, dynamic>?;
      if (writingPrinciples != null) {
        final thaiGuidelines = writingPrinciples['thai_writing_guidelines'] as List?;
        if (thaiGuidelines != null) {
          for (final guideline in thaiGuidelines) {
            guidelines.add('• $guideline');
          }
        }
      }
    }
    
    // Fallback if no guidelines found
    if (guidelines.isEmpty) {
      guidelines.addAll([
        '• Write from left to right across the page',
        '• If there are marks above or below a character, write those first before continuing right',
        '• Start with circles and main shapes, then add lines and details',
        '• Keep characters the same height and evenly spaced',
      ]);
    }
    
    return guidelines;
  }
  
  /// Tab 2: Build step-by-step instructions using thai_writing_guide.json
  List<String> _buildStepByStepInstructions(String semanticWord, Map<String, dynamic> analysisData) {
    final steps = <String>[];
    final componentsWithPosition = <Map<String, dynamic>>[];
    
    // Extract all components with their positions from backend analysis
    final syllables = analysisData['syllables'] as List? ?? [];
    for (final syllableData in syllables) {
      final syllable = syllableData as Map<String, dynamic>;
      final components = syllable['components'] as Map<String, dynamic>? ?? {};
      
      // Collect all components with their write order positions
      _extractComponentsWithPositions(components, componentsWithPosition);
    }
    
    // Sort components by their writing position
    componentsWithPosition.sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    
    // Generate numbered steps from thai_writing_guide.json
    int stepNumber = 1;
    for (final component in componentsWithPosition) {
      final character = component['character'] as String;
      final type = component['type'] as String;
      
      // Get character info from thai_writing_guide.json
      final charInfo = _getCharacterTipsFromJSON(character);
      if (charInfo.isNotEmpty) {
        steps.add('$stepNumber. Write "$character":');
        steps.add('   $charInfo');
        stepNumber++;
      }
    }
    
    // Fallback if no steps generated
    if (steps.isEmpty) {
      steps.add('Break down "$semanticWord" into individual characters and write each one carefully.');
    }
    
    return steps;
  }
  
  /// Tab 3: Build pronunciation guide using component romanizations
  List<String> _buildPronunciationGuide(String semanticWord, Map<String, dynamic> analysisData) {
    final pronunciation = <String>[];
    
    // Get overall word pronunciation
    final wordTransliteration = analysisData['transliteration'] as String? ?? '';
    final translation = _getEnglishTranslationFromMapping() ?? analysisData['translation'] ?? '';
    
    if (wordTransliteration.isNotEmpty) {
      pronunciation.add('Full word: "$semanticWord" → $wordTransliteration');
      if (translation.isNotEmpty) {
        pronunciation.add('Meaning: $translation');
      }
      pronunciation.add('');
    }
    
    // Break down by components
    pronunciation.add('Sound breakdown:');
    final componentsWithPosition = <Map<String, dynamic>>[];
    
    // Extract components
    final syllables = analysisData['syllables'] as List? ?? [];
    for (final syllableData in syllables) {
      final syllable = syllableData as Map<String, dynamic>;
      final components = syllable['components'] as Map<String, dynamic>? ?? {};
      _extractComponentsWithPositions(components, componentsWithPosition);
    }
    
    // Sort by position and build pronunciation guide
    componentsWithPosition.sort((a, b) => (a['position'] as int).compareTo(b['position'] as int));
    
    for (final component in componentsWithPosition) {
      final character = component['character'] as String;
      final charInfo = _getDetailedCharacterInfo(character);
      
      if (charInfo != null) {
        final romanization = charInfo['romanization'] as String? ?? '';
        final soundDesc = charInfo['sound_description'] as String? ?? '';
        
        if (romanization.isNotEmpty || soundDesc.isNotEmpty) {
          pronunciation.add('• $character → $romanization${soundDesc.isNotEmpty ? " ($soundDesc)" : ""}');
        }
      }
    }
    
    return pronunciation;
  }
  
  /// Helper to extract components with their writing positions
  void _extractComponentsWithPositions(Map<String, dynamic> components, List<Map<String, dynamic>> result) {
    int position = result.length;
    
    // Process components in Thai writing order
    // 1. Leading vowels (written before consonant)
    final vowels = components['vowels'] as List? ?? [];
    for (final vowel in vowels) {
      final vowelMap = vowel as Map<String, dynamic>;
      if (vowelMap['position'] == 'before') {
        result.add({
          'character': vowelMap['character'] ?? '',
          'type': 'vowel',
          'position': position++,
          'details': vowelMap,
        });
      }
    }
    
    // 2. Initial consonants
    final initialConsonants = components['initial_consonants'] as List? ?? [];
    for (final consonant in initialConsonants) {
      final consMap = consonant as Map<String, dynamic>;
      result.add({
        'character': consMap['character'] ?? '',
        'type': 'consonant',
        'position': position++,
        'details': consMap,
      });
    }
    
    // 3. Above/below vowels (written after consonant)
    for (final vowel in vowels) {
      final vowelMap = vowel as Map<String, dynamic>;
      if (vowelMap['position'] == 'above' || vowelMap['position'] == 'below') {
        result.add({
          'character': vowelMap['character'] ?? '',
          'type': 'vowel',
          'position': position++,
          'details': vowelMap,
        });
      }
    }
    
    // 4. Following vowels (written after consonant)
    for (final vowel in vowels) {
      final vowelMap = vowel as Map<String, dynamic>;
      if (vowelMap['position'] == 'after') {
        result.add({
          'character': vowelMap['character'] ?? '',
          'type': 'vowel',
          'position': position++,
          'details': vowelMap,
        });
      }
    }
    
    // 5. Final consonants
    final finalConsonants = components['final_consonants'] as List? ?? [];
    for (final consonant in finalConsonants) {
      final consMap = consonant as Map<String, dynamic>;
      result.add({
        'character': consMap['character'] ?? '',
        'type': 'consonant',
        'position': position++,
        'details': consMap,
      });
    }
    
    // 6. Tone marks (always last)
    final toneMarks = components['tone_marks'] as List? ?? [];
    for (final tone in toneMarks) {
      final toneMap = tone as Map<String, dynamic>;
      result.add({
        'character': toneMap['character'] ?? '',
        'type': 'tone',
        'position': position++,
        'details': toneMap,
      });
    }
  }

  /// Build educational section for a single syllable
  String _buildSyllableSection(Map<String, dynamic> syllableData, int syllableNumber) {
    final List<String> sections = [];
    
    final syllable = syllableData['syllable'] ?? '';
    final romanization = syllableData['romanization'] ?? '';
    
    // Part header
    sections.add('Part $syllableNumber: Writing Syllable $syllableNumber: $syllable ($romanization)');
    
    // Components analysis
    sections.add(_buildComponentsAnalysis(syllableData));
    
    // Tone analysis
    sections.add(_buildToneAnalysis(syllableData));
    
    // Step-by-step writing process
    sections.add(_buildStepByStepWritingProcess(syllableData, syllableNumber));
    
    // Component table
    sections.add(_buildComponentTable(syllableData));
    
    return sections.join('\n');
  }

  /// Build components analysis section
  String _buildComponentsAnalysis(Map<String, dynamic> syllableData) {
    final List<String> lines = [];
    
    lines.add('Components:');
    
    final components = syllableData['components'] as Map<String, dynamic>? ?? {};
    
    // Count components by type
    final initialConsonants = components['initial_consonants'] as List? ?? [];
    final vowels = components['vowels'] as List? ?? [];
    final finalConsonants = components['final_consonants'] as List? ?? [];
    final toneMarks = components['tone_marks'] as List? ?? [];
    
    // Build component description
    if (initialConsonants.isNotEmpty) {
      final consonantChars = initialConsonants.map((c) => c['character'] ?? '').join(' + ');
      final consonantSounds = initialConsonants.map((c) => c['romanization'] ?? '').join(' + ');
      lines.add('• Initial Consonant${initialConsonants.length > 1 ? 's' : ''}: $consonantSounds sound${initialConsonants.length > 1 ? 's' : ''}, written as $consonantChars');
    }
    
    if (vowels.isNotEmpty) {
      final vowelChars = vowels.map((v) => v['character'] ?? '').join(' + ');
      final vowelSounds = vowels.map((v) => v['romanization'] ?? '').join(' + ');
      lines.add('• Vowel${vowels.length > 1 ? 's' : ''}: $vowelSounds sound${vowels.length > 1 ? 's' : ''}, written as $vowelChars');
    }
    
    if (finalConsonants.isNotEmpty) {
      final finalChars = finalConsonants.map((c) => c['character'] ?? '').join(' + ');
      final finalSounds = finalConsonants.map((c) => c['romanization'] ?? '').join(' + ');
      lines.add('• Final Consonant${finalConsonants.length > 1 ? 's' : ''}: $finalSounds sound${finalConsonants.length > 1 ? 's' : ''}, written as $finalChars');
    }
    
    if (toneMarks.isNotEmpty) {
      final toneChars = toneMarks.map((t) => t['character'] ?? '').join(' + ');
      lines.add('• Tone Mark${toneMarks.length > 1 ? 's' : ''}: $toneChars');
    }
    
    return lines.join('\n');
  }

  /// Build simplified tone guidance for beginners
  String _buildToneAnalysis(Map<String, dynamic> syllableData) {
    final toneAnalysis = syllableData['tone_analysis'] as Map<String, dynamic>? ?? {};
    
    if (toneAnalysis.isEmpty) return '';
    
    final resultingTone = toneAnalysis['resulting_tone'] ?? '';
    
    if (resultingTone.isNotEmpty && resultingTone != 'mid') {
      // Only show tone info if it's not the default mid tone
      final simplifiedTone = resultingTone.replaceAll('_', ' ');
      return 'Voice tone: Make your voice go $simplifiedTone';
    }
    
    return '';
  }

  /// Build step-by-step writing process
  String _buildStepByStepWritingProcess(Map<String, dynamic> syllableData, int syllableNumber) {
    final List<String> lines = [];
    
    lines.add('Step-by-Step Writing Process for ${syllableData['syllable'] ?? ''}:');
    
    final writingSteps = syllableData['writing_steps'] as List? ?? [];
    
    for (final stepData in writingSteps) {
      final step = stepData as Map<String, dynamic>;
      final stepNumber = step['step'] ?? 1;
      final component = step['component'] ?? '';
      final type = step['type'] ?? '';
      final instruction = step['instruction'] ?? '';
      final soundDescription = step['sound_description'] ?? '';
      final writingTips = step['writing_tips'] as List? ?? [];
      
      lines.add('');
      lines.add('Step $syllableNumber.$stepNumber: $instruction');
      
      if (soundDescription.isNotEmpty) {
        lines.add('- $soundDescription');
      }
      
      if (type == 'consonant') {
        final consonantClass = step['consonant_class'] ?? '';
        if (consonantClass.isNotEmpty) {
          lines.add('- ${consonantClass.replaceAll('_', ' ').toUpperCase()} Class Consonant');
        }
      }
      
      if (writingTips.isNotEmpty) {
        for (final tip in writingTips) {
          lines.add('- $tip');
        }
      }
      
      lines.add('Write: $component');
    }
    
    return lines.join('\n');
  }

  /// Build component table
  String _buildComponentTable(Map<String, dynamic> syllableData) {
    final List<String> lines = [];
    
    lines.add('Component Table:');
    lines.add('| Component | Thai | Transliteration | Role |');
    lines.add('|-----------|------|----------------|------|');
    
    final componentRoles = syllableData['component_roles'] as List? ?? [];
    
    for (final roleData in componentRoles) {
      final role = roleData as Map<String, dynamic>;
      final character = role['character'] ?? '';
      final romanization = role['romanization'] ?? '';
      final type = role['type'] ?? '';
      final position = role['position'] ?? '';
      final consonantClass = role['consonant_class'] ?? '';
      
      String roleDescription = type;
      if (consonantClass.isNotEmpty && type == 'consonant') {
        roleDescription += ' (${consonantClass.replaceAll('_', ' ')} class)';
      }
      if (position.isNotEmpty && position != 'initial') {
        roleDescription += ' - $position position';
      }
      
      lines.add('| $type | $character | $romanization | $roleDescription |');
    }
    
    return lines.join('\n');
  }

  /// Fallback educational tips for when comprehensive analysis fails
  String _buildFallbackEducationalTips(String semanticWord) {
    return """
High-Level Overview
Word: $semanticWord
Analysis: Basic fallback mode

Thai Writing Guidelines:
• Left to right, circles first, then straight lines
• Consonants → vowels → tone marks
• Consistent height, smooth strokes

Writing "$semanticWord":
1. Start from the leftmost character
2. Draw circles clockwise from the top
3. Add vowel marks in proper position
4. Finish with tone marks if present

Note: For detailed analysis, check your connection and try again.
""";
  }

  /// Build enhanced writing tips from TCC analysis of the entire semantic word
  String _buildEnhancedTipsFromTCCAnalysis(String semanticWord, Map<String, dynamic> analysisData) {
    final List<String> sections = [];
    
    // 1. Thai Writing Guidelines (consolidated, first)
    sections.add('Thai Writing Guidelines:');
    sections.add('• Left to right, circles first, then straight lines');
    sections.add('• Consonants → vowels → tone marks');
    sections.add('• Consistent height, smooth strokes');
    sections.add('');
    
    // 2. Word Analysis
    sections.add('Word Analysis for "$semanticWord":');
    
    // Get TCC clusters from the analysis
    final allTCCs = analysisData['all_tcc_clusters'] as List? ?? [];
    if (allTCCs.isNotEmpty) {
      sections.add('• Character clusters: ${allTCCs.join(', ')}');
      sections.add('• Total components: ${allTCCs.length}');
      sections.add('');
    }
    
    // 3. Step-by-step writing order for all TCC components
    sections.add('Writing Order for All Components:');
    int stepNumber = 1;
    
    for (int i = 0; i < allTCCs.length; i++) {
      final tcc = allTCCs[i];
      
      // Analyze each TCC component
      if (tcc.isNotEmpty) {
        sections.add('${stepNumber}. Write "$tcc"');
        
        // Add basic guidance for this TCC
        final guidance = _getTCCGuidance(tcc);
        if (guidance.isNotEmpty) {
          sections.add('   $guidance');
        }
        
        stepNumber++;
      }
    }
    
    sections.add('');
    sections.add('Tip: Practice each component separately, then combine them smoothly.');
    
    return sections.join('\n');
  }
  
  /// Get basic writing guidance for a TCC component
  String _getTCCGuidance(String tcc) {
    // Basic guidance based on character structure
    if (tcc.length == 1) {
      final char = tcc[0];
      
      // Consonants with circles
      if (['ก', 'ค', 'จ', 'ช', 'บ', 'ป', 'อ'].contains(char)) {
        return 'Start with the circular component, draw clockwise from top';
      }
      
      // Consonants with vertical strokes
      if (['น', 'ม', 'ย', 'ร', 'ล', 'ว', 'ส', 'ห'].contains(char)) {
        return 'Draw vertical strokes from top to bottom';
      }
      
      // Vowels
      if (['า', 'ิ', 'ี', 'ุ', 'ู'].contains(char)) {
        return 'Add after the consonant is complete';
      }
      
      // Leading vowels
      if (['เ', 'แ', 'โ', 'ใ', 'ไ'].contains(char)) {
        return 'Write before the consonant but pronounced after';
      }
      
      // Tone marks
      if (['่', '้', '๊', '๋'].contains(char)) {
        return 'Place carefully above the main character';
      }
    }
    
    return 'Follow the natural stroke order for this component';
  }

  String _buildTipsFromAnalysis(String character, Map<String, dynamic> analysis) {
    final List<String> sections = [];
    
    // 1. Thai Writing Guidelines (consolidated, first)
    sections.add('Thai Writing Guidelines:');
    sections.add('• Left to right, circles first, then straight lines');
    sections.add('• Consonants → vowels → tone marks');
    sections.add('• Consistent height, smooth strokes');
    sections.add('');
    
    // 2. Step-by-step instructions (beginner-friendly with romanization)
    final stepByStepInstructions = _generateBeginnerSteps(character, analysis);
    if (stepByStepInstructions.isNotEmpty) {
      sections.add('Step-by-Step Instructions:');
      for (int i = 0; i < stepByStepInstructions.length; i++) {
        sections.add('${i + 1}. ${stepByStepInstructions[i]}');
      }
      sections.add('');
    }
    
    // 3. Cultural context (moved to bottom, simplified)
    final culturalContext = _extractCulturalContext(analysis);
    if (culturalContext.isNotEmpty) {
      sections.add('About this character: $culturalContext');
    }
    
    return sections.join('\n');
  }

  /// Generate beginner-friendly step-by-step instructions with romanization
  List<String> _generateBeginnerSteps(String character, Map<String, dynamic> analysis) {
    final List<String> steps = [];
    
    final consonants = analysis['consonants'] as List? ?? [];
    final vowels = analysis['vowels'] as List? ?? [];
    final toneMarks = analysis['tone_marks'] as List? ?? [];
    
    // Handle consonants with enhanced JSON structure
    for (final consonant in consonants) {
      final char = consonant['character'] ?? '';
      final romanization = consonant['romanization'] ?? '';
      final soundDescription = consonant['sound_description'] ?? '';
      final beginnerSteps = consonant['beginner_steps'] as List? ?? [];
      final strokeOrderPrinciple = consonant['stroke_order_principle'] as String? ?? '';
      final circleGuidance = consonant['circle_guidance'] as String? ?? '';
      
      // Use enhanced beginner steps from JSON if available
      if (beginnerSteps.isNotEmpty) {
        for (final step in beginnerSteps) {
          String instruction = step.toString();
          if (romanization.isNotEmpty) {
            instruction += ' (${romanization} sound)';
          }
          steps.add(instruction);
        }
        
        // Add enhanced guidance if available
        if (circleGuidance.isNotEmpty) {
          steps.add('Tip: $circleGuidance');
        }
        if (strokeOrderPrinciple.isNotEmpty) {
          steps.add('Stroke order: $strokeOrderPrinciple');
        }
      } else {
        // Fallback instruction
        String instruction = 'Write consonant $char';
        if (soundDescription.isNotEmpty) {
          instruction += ' ($soundDescription)';
        }
        steps.add(instruction);
      }
    }
    
    // Handle vowels with enhanced JSON structure
    for (final vowel in vowels) {
      final char = vowel['character'] ?? '';
      final romanization = vowel['romanization'] ?? '';
      final position = vowel['position'] ?? '';
      final beginnerSteps = vowel['beginner_steps'] as List? ?? [];
      final positioningRule = vowel['positioning_rule'] as String? ?? '';
      final planningTip = vowel['planning_tip'] as String? ?? '';
      
      // Use enhanced beginner steps from JSON if available
      if (beginnerSteps.isNotEmpty) {
        for (final step in beginnerSteps) {
          String instruction = step.toString();
          if (romanization.isNotEmpty) {
            instruction += ' (${romanization} sound)';
          }
          steps.add(instruction);
        }
        
        // Add enhanced guidance if available
        if (positioningRule.isNotEmpty) {
          steps.add('Position: $positioningRule');
        }
        if (planningTip.isNotEmpty) {
          steps.add('📋 $planningTip');
        }
      } else {
        // Fallback instruction
        String instruction = 'Add vowel $char';
        if (romanization.isNotEmpty) {
          instruction += ' (${romanization} sound)';
        }
        if (position.isNotEmpty) {
          instruction += ' ${position == 'before' ? 'before' : 
                           position == 'above' ? 'above' : 
                           position == 'below' ? 'below' : 'after'} the consonant';
        }
        steps.add(instruction);
      }
    }
    
    // Handle tone marks with enhanced JSON structure
    for (final toneMark in toneMarks) {
      final char = toneMark['character'] ?? '';
      final romanization = toneMark['romanization'] ?? '';
      final beginnerSteps = toneMark['beginner_steps'] as List? ?? [];
      final writingOrderRule = toneMark['writing_order_rule'] as String? ?? '';
      
      // Use enhanced beginner steps from JSON if available
      if (beginnerSteps.isNotEmpty) {
        for (final step in beginnerSteps) {
          String instruction = step.toString();
          if (romanization.isNotEmpty) {
            instruction += ' (${romanization})';
          }
          steps.add(instruction);
        }
        
        // Add enhanced guidance if available
        if (writingOrderRule.isNotEmpty) {
          steps.add('Order: $writingOrderRule');
        }
      } else {
        // Fallback instruction
        String instruction = 'Add tone mark $char above';
        if (romanization.isNotEmpty) {
          instruction += ' (${romanization})';
        }
        steps.add(instruction);
      }
    }
    
    // If no components found, provide basic instruction
    if (steps.isEmpty && character.isNotEmpty) {
      steps.add('Practice writing $character as shown in the guide above');
      steps.add('Start with the main shape or circle, then add details');
    }
    
    return steps;
  }

  /// Extract cultural context from analysis (simplified and beginner-friendly)
  String _extractCulturalContext(Map<String, dynamic> analysis) {
    final culturalContexts = <String>[];
    
    // Check consonants for cultural context
    final consonants = analysis['consonants'] as List? ?? [];
    for (final consonant in consonants) {
      final culturalContext = consonant['cultural_context'] as String? ?? '';
      if (culturalContext.isNotEmpty && !culturalContext.toLowerCase().contains('traditional') && !culturalContext.toLowerCase().contains('represents')) {
        culturalContexts.add(culturalContext);
      }
    }
    
    // Check vowels for cultural context
    final vowels = analysis['vowels'] as List? ?? [];
    for (final vowel in vowels) {
      final culturalContext = vowel['cultural_context'] as String? ?? '';
      if (culturalContext.isNotEmpty) {
        culturalContexts.add(culturalContext);
      }
    }
    
    // Check tone marks for cultural context
    final toneMarks = analysis['tone_marks'] as List? ?? [];
    for (final toneMark in toneMarks) {
      final culturalContext = toneMark['cultural_context'] as String? ?? '';
      if (culturalContext.isNotEmpty) {
        culturalContexts.add(culturalContext);
      }
    }
    
    // Return the first relevant cultural context, simplified
    if (culturalContexts.isNotEmpty) {
      return culturalContexts.first;
    }
    
    return 'Common character in Thai writing';
  }

  /// Generate step-by-step writing instructions based on character analysis
  List<String> _generateWritingSteps(String character, Map<String, dynamic> analysis) {
    final List<String> steps = [];
    
    if (analysis['breakdown'] == null) {
      // Single character writing steps
      if (_hasCircularComponent(character)) {
        steps.add('Start with the circular component, draw clockwise from the top');
      }
      if (_hasVerticalStroke(character)) {
        steps.add('Draw vertical strokes from top to bottom');
      }
      steps.add('Draw the main character shape first');
      return steps;
    }
    
    final consonants = analysis['consonants'] as List? ?? [];
    final vowels = analysis['vowels'] as List? ?? [];
    final toneMarks = analysis['tone_marks'] as List? ?? [];
    
    // Step 1: Base consonants (left to right)
    if (consonants.isNotEmpty) {
      if (consonants.length == 1) {
        steps.add('Draw the base consonant first');
      } else {
        steps.add('Draw base consonants from left to right');
      }
    }
    
    // Step 2: Leading vowels (if any)
    final leadingVowels = vowels.where((v) => v['position_type'] == 'leading').toList();
    if (leadingVowels.isNotEmpty) {
      steps.add('Add leading vowels (these appear before consonants when reading)');
    }
    
    // Step 3: Above and below vowels
    final aboveVowels = vowels.where((v) => v['position_type'] == 'above').toList();
    final belowVowels = vowels.where((v) => v['position_type'] == 'below').toList();
    
    if (aboveVowels.isNotEmpty) {
      steps.add('Add vowels above the consonants');
    }
    if (belowVowels.isNotEmpty) {
      steps.add('Add vowels below the consonants');
    }
    
    // Step 4: Trailing vowels
    final trailingVowels = vowels.where((v) => v['position_type'] == 'trailing').toList();
    if (trailingVowels.isNotEmpty) {
      steps.add('Add trailing vowels after the consonants');
    }
    
    // Step 5: Tone marks (always last)
    if (toneMarks.isNotEmpty) {
      steps.add('Finally, add tone marks above (these are always written last)');
    }
    
    return steps;
  }

  /// Get cultural writing tips specific to Thai characters
  List<String> _getCulturalWritingTips(String character, Map<String, dynamic> analysis) {
    final List<String> tips = [];
    
    // Circle-based characters
    if (_hasCircularComponent(character)) {
      tips.add('Thai circles are drawn clockwise starting from the top');
    }
    
    // Leading vowels reminder
    final vowels = analysis['vowels'] as List? ?? [];
    final hasLeadingVowels = vowels.any((v) => v['position_type'] == 'leading');
    if (hasLeadingVowels) {
      tips.add('Leading vowels appear BEFORE consonants in reading order but are written after');
    }
    
    // Tone mark placement
    final toneMarks = analysis['tone_marks'] as List? ?? [];
    if (toneMarks.isNotEmpty) {
      tips.add('Tone marks always go above other marks and are written last');
    }
    
    // General Thai writing principles
    tips.add('Write from left to right, then top to bottom');
    tips.add('Keep consistent character spacing and height');
    tips.add('Make smooth, confident strokes without lifting the pen unnecessarily');
    
    return tips;
  }

  /// Check if character has circular components
  bool _hasCircularComponent(String character) {
    return ['อ', 'ด', 'ต', 'บ', 'ป', 'ภ', 'ฟ', 'ฝ', 'ล', 'ม', 'ว', 'ส', 'ห', 'ฮ'].contains(character);
  }

  /// Check if character has prominent vertical strokes
  bool _hasVerticalStroke(String character) {
    return ['ผ', 'ฝ', 'ฟ', 'ก', 'ข', 'ค', 'ง', 'จ', 'ช', 'ซ', 'ญ', 'ย'].contains(character);
  }

  String _getStaticCharacterTips(String character) {
    final List<String> sections = [];
    
    // Start with Thai Writing Guidelines from JSON or fallback
    if (_thaiWritingGuideData != null) {
      final writingPrinciples = _thaiWritingGuideData!['writing_principles'] as Map<String, dynamic>?;
      final guidelines = writingPrinciples?['thai_writing_guidelines'] as List?;
      
      if (guidelines != null && guidelines.isNotEmpty) {
        sections.add('Thai Writing Guidelines:');
        for (final guideline in guidelines) {
          sections.add('• $guideline');
        }
        sections.add('');
      }
    } else {
      // Fallback guidelines
      sections.add('How to Write Thai:');
      sections.add('• Write from left to right across the page');
      sections.add('• If there are marks above or below a character, write those first before continuing right');
      sections.add('• Start with circles and main shapes, then add lines and details');
      sections.add('• Keep characters the same height and evenly spaced');
      sections.add('');
    }
    
    // Character-specific guidance from JSON
    sections.add('Writing $character:');
    final characterTips = _getCharacterTipsFromJSON(character);
    
    if (characterTips.isNotEmpty) {
      sections.add('• $characterTips');
    } else {
      // Fallback character tips
      sections.add('• Start with circles or main shape (clockwise from top)');
      sections.add('• Add connecting lines and details');
      sections.add('• Follow left-to-right, top-to-bottom flow');
      sections.add('• Keep proportions balanced');
    }
    
    sections.add('');
    // Key principles integrated into main guidelines above
    
    return sections.join('\n');
  }

  /// Build enhanced fallback tips that include Thai guidelines plus character-specific guidance
  String _buildEnhancedFallbackTips(String semanticWord) {
    print('Building enhanced fallback tips for: $semanticWord');
    print('Thai writing guide data available: ${_thaiWritingGuideData != null}');
    final List<String> sections = [];
    
    // Start with Thai Writing Guidelines from JSON or fallback
    if (_thaiWritingGuideData != null) {
      final writingPrinciples = _thaiWritingGuideData!['writing_principles'] as Map<String, dynamic>?;
      final guidelines = writingPrinciples?['thai_writing_guidelines'] as List?;
      
      if (guidelines != null && guidelines.isNotEmpty) {
        sections.add('Thai Writing Guidelines:');
        for (final guideline in guidelines) {
          sections.add('• $guideline');
        }
        sections.add('');
      }
    } else {
      // Fallback guidelines
      sections.add('How to Write Thai:');
      sections.add('• Write from left to right across the page');
      sections.add('• If there are marks above or below a character, write those first before continuing right');
      sections.add('• Start with circles and main shapes, then add lines and details');
      sections.add('• Keep characters the same height and evenly spaced');
      sections.add('');
    }
    
    // Add character-specific guidance with rich JSON data
    sections.add('Drawing Each Character:');
    
    // Analyze characters in the semantic word for specific tips
    for (int i = 0; i < semanticWord.length; i++) {
      final char = semanticWord[i];
      final characterDetails = _getDetailedCharacterInfo(char);
      
      if (characterDetails != null) {
        sections.add('• $char (${characterDetails['romanization']}): ${characterDetails['main_tip']}');
        
        // Add practical drawing guidance only
        final strokeOrder = characterDetails['stroke_order_principle'];
        final circleGuidance = characterDetails['circle_guidance'];
        final position = characterDetails['position']; // For vowels
        final positioningRule = characterDetails['positioning_rule']; // For vowels
        final planningTip = characterDetails['planning_tip']; // For vowels
        final writingOrderRule = characterDetails['writing_order_rule']; // For tone marks
        
        if (strokeOrder != null) {
          sections.add('  Drawing: $strokeOrder');
        }
        if (circleGuidance != null) {
          sections.add('  Technique: $circleGuidance');
        }
        if (position != null) {
          sections.add('  Position: $position');
        }
        if (positioningRule != null) {
          sections.add('  Rule: $positioningRule');
        }
        if (planningTip != null) {
          sections.add('  Planning: $planningTip');
        }
        if (writingOrderRule != null) {
          sections.add('  Order: $writingOrderRule');
        }
      } else {
        // Fallback analysis
        final basicTip = _getCharacterTipsFromJSON(char);
        if (basicTip.isNotEmpty) {
          sections.add('• $char: $basicTip');
        } else if (_hasCircularComponent(char)) {
          sections.add('• $char: Start with circular component, draw clockwise from top');
        } else if (_hasVerticalStroke(char)) {
          sections.add('• $char: Draw vertical strokes from top to bottom');
        } else {
          sections.add('• $char: Follow left-to-right, smooth connected strokes');
        }
      }
    }
    
    // General tips are now integrated into main guidelines
    
    final result = sections.join('\n');
    print('Enhanced fallback tips result length: ${result.length} characters');
    
    // Ensure we always return something useful
    if (result.trim().isEmpty) {
      return 'Thai Writing Guidelines:\n• Write from left to right across the page\n• Start with circles and main shapes, then add lines and details\n• Keep characters the same height and evenly spaced';
    }
    
    return result;
  }

  /// Get detailed character information from JSON including cultural context and steps
  Map<String, dynamic>? _getDetailedCharacterInfo(String character) {
    if (_thaiWritingGuideData == null) return null;
    
    final cleanCharacter = character.trim();
    
    try {
      // Check consonants
      final consonants = _thaiWritingGuideData!['consonants'] as Map<String, dynamic>?;
      if (consonants?.containsKey(cleanCharacter) == true) {
        final charData = consonants![cleanCharacter] as Map<String, dynamic>;
        return {
          'romanization': charData['romanization'] ?? '',
          'main_tip': _extractMainTip(charData),
          'stroke_order_principle': charData['stroke_order_principle'],
          'circle_guidance': charData['circle_guidance'],
          'steps': charData['steps'],
        };
      }
      
      // Check vowels
      final vowels = _thaiWritingGuideData!['vowels'] as Map<String, dynamic>?;
      if (vowels?.containsKey(cleanCharacter) == true) {
        final charData = vowels![cleanCharacter] as Map<String, dynamic>;
        return {
          'romanization': charData['romanization'] ?? '',
          'main_tip': _extractMainTip(charData),
          'position': charData['position'],
          'positioning_rule': charData['positioning_rule'],
          'planning_tip': charData['planning_tip'],
          'steps': charData['steps'],
        };
      }
      
      // Try vowel with placeholder notation too
      String vowelKey = '◌$cleanCharacter';
      if (vowels?.containsKey(vowelKey) == true) {
        final charData = vowels![vowelKey] as Map<String, dynamic>;
        return {
          'romanization': charData['romanization'] ?? '',
          'main_tip': _extractMainTip(charData),
          'position': charData['position'],
          'positioning_rule': charData['positioning_rule'],
          'planning_tip': charData['planning_tip'],
          'steps': charData['steps'],
        };
      }
      
      // Check tone marks
      final toneMarks = _thaiWritingGuideData!['tone_marks'] as Map<String, dynamic>?;
      if (toneMarks?.containsKey(cleanCharacter) == true) {
        final charData = toneMarks![cleanCharacter] as Map<String, dynamic>;
        return {
          'romanization': charData['romanization'] ?? '',
          'main_tip': _extractMainTip(charData),
          'sound_description': charData['sound_description'],
          'writing_order_rule': charData['writing_order_rule'],
          'steps': charData['steps'],
        };
      }
      
    } catch (e) {
      print('Error getting detailed character info for "$character": $e');
    }
    
    return null;
  }
  
  /// Generate simplified step-by-step guide from JSON data (beginner-friendly)
  List<String> _generateSimpleStepsFromJSON(String word) {
    final steps = <String>[];
    
    for (int i = 0; i < word.length; i++) {
      final char = word[i];
      final charDetails = _getDetailedCharacterInfo(char);
      
      if (charDetails != null) {
        final stepNum = i + 1;
        final romanization = charDetails['romanization'] ?? '';
        final charSteps = charDetails['steps'] as List?;
        
        final soundDescription = charDetails['sound_description'] ?? '';
        
        if (charSteps != null && charSteps.isNotEmpty) {
          // Show sound description and steps
          if (soundDescription.isNotEmpty) {
            steps.add('$stepNum. Draw "$char" ($romanization) - $soundDescription:');
          } else {
            steps.add('$stepNum. Draw "$char" (sounds like "$romanization"):');
          }
          for (final step in charSteps) {
            // Simplify the step language for beginners
            final simplifiedStep = _simplifyStepLanguage(step.toString());
            steps.add('   • $simplifiedStep');
          }
        } else {
          // Show sound description as main guidance
          if (soundDescription.isNotEmpty) {
            steps.add('$stepNum. Draw "$char" ($romanization) - $soundDescription');
          } else {
            steps.add('$stepNum. Draw "$char" (sounds like "$romanization"): ${charDetails['main_tip']}');
          }
        }
      }
    }
    
    return steps;
  }

  /// Simplify technical language for beginners
  String _simplifyStepLanguage(String step) {
    return step
        .replaceAll('consonant', 'main character')
        .replaceAll('vowel', 'sound mark')
        .replaceAll('tone mark', 'accent mark')
        .replaceAll('circle at the top left', 'small circle at top-left')
        .replaceAll('circle at the top center', 'small circle at top center')
        .replaceAll('circle at the bottom', 'small circle at bottom');
  }

  /// Generate step-by-step guide from JSON data when backend data is unavailable
  List<String> _generateStepsFromJSON(String word) {
    final steps = <String>[];
    
    for (int i = 0; i < word.length; i++) {
      final char = word[i];
      final charDetails = _getDetailedCharacterInfo(char);
      
      if (charDetails != null) {
        final stepNum = i + 1;
        final romanization = charDetails['romanization'] ?? '';
        final charSteps = charDetails['steps'] as List?;
        
        if (charSteps != null && charSteps.isNotEmpty) {
          steps.add('$stepNum. Write "$char" ($romanization):');
          for (final step in charSteps) {
            steps.add('   • $step');
          }
        } else {
          steps.add('$stepNum. Write "$char" ($romanization): ${charDetails['main_tip']}');
        }
      }
    }
    
    return steps;
  }

  /// Find character in complex vowels section
  String _findInComplexVowels(String character) {
    if (_thaiWritingGuideData == null) return '';
    
    try {
      final complexVowels = _thaiWritingGuideData!['complex_vowels'] as Map<String, dynamic>?;
      if (complexVowels != null) {
        for (final entry in complexVowels.entries) {
          final vowelData = entry.value as Map<String, dynamic>;
          final components = vowelData['components'] as List?;
          
          if (components != null) {
            for (final component in components) {
              final componentMap = component as Map<String, dynamic>;
              if (componentMap['part'] == character) {
                final description = componentMap['description'] as String? ?? '';
                final position = componentMap['position'] as String? ?? '';
                return '$description' + (position.isNotEmpty ? ' (placed $position)' : '');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error searching complex vowels for "$character": $e');
    }
    
    return '';
  }

  /// Extract the main tip from character data (prioritize sound description)
  String _extractMainTip(Map<String, dynamic> charData) {
    // Prioritize sound description for main tip
    final soundDescription = charData['sound_description'] as String?;
    if (soundDescription != null && soundDescription.isNotEmpty) {
      return soundDescription;
    }
    
    // Fallback to first step
    final steps = charData['steps'] as List?;
    if (steps != null && steps.isNotEmpty) {
      return steps.first.toString();
    }
    
    // Final fallback to romanization
    final romanization = charData['romanization'] as String?;
    if (romanization != null && romanization.isNotEmpty) {
      return '$romanization sound';
    }
    
    return 'No specific guidance available';
  }

  /// Get English translation from the word mapping (prioritize 'english' field)
  String? _getEnglishTranslationFromMapping() {
    if (widget.wordMapping.isNotEmpty) {
      final wordData = widget.wordMapping[0];
      
      // Prioritize 'english' field from NPC vocabulary
      if (wordData.containsKey('english') && 
          wordData['english'] != null && 
          wordData['english'].toString().isNotEmpty) {
        print('Using english field from NPC vocabulary: ${wordData['english']}');
        return wordData['english'].toString();
      }
      
      // Fallback to translation field
      if (wordData.containsKey('translation') && 
          wordData['translation'] != null && 
          wordData['translation'].toString().isNotEmpty) {
        print('Using translation field as fallback: ${wordData['translation']}');
        return wordData['translation'].toString();
      }
    }
    return null;
  }

  /// Get character-specific tips from the Thai writing guide JSON
  String _getCharacterTipsFromJSON(String character) {
    // Strip whitespace and normalize character
    final cleanCharacter = character.trim();
    print('Getting JSON tips for character: "$character" (cleaned: "$cleanCharacter")');
    if (_thaiWritingGuideData == null) {
      print('No Thai writing guide data available');
      return '';
    }
    
    try {
      final consonants = _thaiWritingGuideData!['consonants'] as Map<String, dynamic>?;
      print('Looking for "$cleanCharacter" in consonants: ${consonants?.containsKey(cleanCharacter)}');
      if (consonants != null && consonants.containsKey(cleanCharacter)) {
        final charData = consonants[cleanCharacter] as Map<String, dynamic>;
        print('Found character data keys: ${charData.keys}');
        
        // Use steps and sound_description fields
        final steps = charData['steps'] as List?;
        final soundDescription = charData['sound_description'] as String? ?? '';
        
        if (steps != null && steps.isNotEmpty && soundDescription.isNotEmpty) {
          final result = '$soundDescription\n\nHow to write: ${steps.first}';
          print('Using steps + sound_description: $result');
          return result;
        } else if (steps != null && steps.isNotEmpty) {
          print('Found steps: ${steps.first}');
          return steps.first.toString();
        } else if (soundDescription.isNotEmpty) {
          print('Using sound description: $soundDescription');
          return soundDescription;
        }
        
        // Final fallback to romanization 
        final romanization = charData['romanization'] as String? ?? '';
        if (romanization.isNotEmpty) {
          final result = '$romanization sound';
          print('Using romanization tip: $result');
          return result;
        }
      }
      
      // Check vowels section as well (try both direct and placeholder notation)
      final vowels = _thaiWritingGuideData!['vowels'] as Map<String, dynamic>?;
      String vowelKey = cleanCharacter;
      bool foundInVowels = vowels?.containsKey(cleanCharacter) == true;
      
      // Try placeholder notation for standalone vowels
      if (!foundInVowels && vowels != null) {
        vowelKey = '◌$cleanCharacter';
        foundInVowels = vowels.containsKey(vowelKey);
      }
      
      print('Looking for "$cleanCharacter" in vowels (trying "$vowelKey"): $foundInVowels');
      if (foundInVowels) {
        final vowelData = vowels![vowelKey] as Map<String, dynamic>;
        print('Found vowel data keys: ${vowelData.keys}');
        
        // Use steps and sound_description fields for vowels
        final steps = vowelData['steps'] as List?;
        final soundDescription = vowelData['sound_description'] as String? ?? '';
        
        if (steps != null && steps.isNotEmpty && soundDescription.isNotEmpty) {
          final result = '$soundDescription\n\nHow to write: ${steps.first}';
          print('Using vowel steps + sound_description: $result');
          return result;
        } else if (steps != null && steps.isNotEmpty) {
          print('Found vowel steps: ${steps.first}');
          return steps.first.toString();
        } else if (soundDescription.isNotEmpty) {
          print('Using vowel sound description: $soundDescription');
          return soundDescription;
        }
        
        // Fallback to romanization and position
        final romanization = vowelData['romanization'] as String? ?? '';
        final position = vowelData['position'] as String? ?? '';
        if (romanization.isNotEmpty) {
          final result = '$romanization sound' + (position.isNotEmpty ? ' (placed $position consonant)' : '');
          print('Using vowel romanization tip: $result');
          return result;
        }
      } else {
        // Check if this character appears as a component in complex vowels
        final complexVowelTip = _findInComplexVowels(cleanCharacter);
        if (complexVowelTip.isNotEmpty) {
          print('Found character in complex vowels: $complexVowelTip');
          return complexVowelTip;
        }
      }
      
      // Check tone marks section
      final toneMarks = _thaiWritingGuideData!['tone_marks'] as Map<String, dynamic>?;
      print('Looking for "$cleanCharacter" in tone_marks: ${toneMarks?.containsKey(cleanCharacter)}');
      if (toneMarks != null && toneMarks.containsKey(cleanCharacter)) {
        final toneData = toneMarks[cleanCharacter] as Map<String, dynamic>;
        print('Found tone mark data keys: ${toneData.keys}');
        
        // Use steps and sound_description fields for tone marks (simplified for beginners)
        final steps = toneData['steps'] as List?;
        final soundDescription = toneData['sound_description'] as String? ?? '';
        
        if (steps != null && steps.isNotEmpty && soundDescription.isNotEmpty) {
          // Simplify tone description for beginners
          final simplifiedTone = soundDescription.replaceAll('makes ', '').replaceAll(' tone', '');
          final result = 'Makes your voice $simplifiedTone\n\nHow to write: ${steps.first}';
          print('Using tone mark steps + simplified description: $result');
          return result;
        } else if (steps != null && steps.isNotEmpty) {
          print('Found tone mark steps: ${steps.first}');
          return steps.first.toString();
        } else if (soundDescription.isNotEmpty) {
          final simplifiedTone = soundDescription.replaceAll('makes ', '').replaceAll(' tone', '');
          final result = 'Makes your voice $simplifiedTone';
          print('Using simplified tone description: $result');
          return result;
        }
        
        // Fallback 
        final romanization = toneData['romanization'] as String? ?? '';
        if (romanization.isNotEmpty) {
          final result = '$romanization';
          print('Using tone mark romanization: $result');
          return result;
        }
      }
      
    } catch (e) {
      print('Error getting character tips from JSON for "$character" (cleaned: "$cleanCharacter"): $e');
    }
    
    print('No tips found for character: "$character" (cleaned: "$cleanCharacter")');
    return '';
  }

  void _onPanStart(DragStartDetails details) {
    _currentStroke = mlkit.Stroke();
    _currentStrokePoints.clear();
    
    final point = mlkit.StrokePoint(
      x: details.localPosition.dx,
      y: details.localPosition.dy,
      t: DateTime.now().millisecondsSinceEpoch,
    );
    
    _currentStroke!.points.add(point);
    _currentStrokePoints.add(point);
    
    setState(() {});
    SchedulerBinding.instance.scheduleFrame();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_currentStroke != null) {
      final point = mlkit.StrokePoint(
        x: details.localPosition.dx,
        y: details.localPosition.dy,
        t: DateTime.now().millisecondsSinceEpoch,
      );
      
      _currentStroke!.points.add(point);
      _currentStrokePoints.add(point);
      
      setState(() {});
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (_currentStroke != null) {
      if (!_ink.strokes.contains(_currentStroke!)) {
        _ink.strokes.add(_currentStroke!);
        _strokeHistory.add(_currentStroke!);
      }
      
      _currentStroke = null;
      _currentStrokePoints.clear();
      
      setState(() {});
    }
  }

  void _clearCanvas() {
    setState(() {
      _ink.strokes.clear();
      _strokeHistory.clear();
      _currentStrokePoints.clear();
      _currentStroke = null;
    });
  }

  void _undoLastStroke() {
    if (_ink.strokes.isNotEmpty) {
      setState(() {
        _ink.strokes.removeLast();
        _strokeHistory.clear();
        _strokeHistory.addAll(_ink.strokes);
      });
    }
  }

  /// Check if the word data has an audio path available
  bool _hasAudioPath(Map<String, dynamic> wordData) {
    return wordData.containsKey('audio_path') && 
           wordData['audio_path'] != null && 
           wordData['audio_path'].toString().isNotEmpty;
  }


  /// Play vocabulary audio for NPC words or use TTS for custom words
  Future<void> _playVocabularyAudio(Map<String, dynamic> wordData) async {
    try {
      if (_hasAudioPath(wordData)) {
        // For NPC vocabulary with existing audio_path
        final audioPath = wordData['audio_path'] as String;
        print('Playing vocabulary audio: $audioPath');
        
        // Play audio file using audioplayers
        await _audioPlayer.stop(); // Stop any currently playing audio
        
        // Fix double assets/ prefix issue
        final cleanPath = audioPath.startsWith('assets/') ? audioPath.substring(7) : audioPath;
        await _audioPlayer.play(AssetSource(cleanPath));
        print('Successfully started playing: $cleanPath');
      } else {
        // For custom words, use TTS from backend
        final targetText = wordData['target'] as String? ?? '';
        if (targetText.isNotEmpty) {
          await _generateAndPlayTTS(targetText);
        }
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  /// Generate TTS audio using backend service for custom words
  Future<void> _generateAndPlayTTS(String text) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/gcloud-translate-tts/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'text': text,
          'target_language': 'th'
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final audioBase64 = data['audio_base64'] as String?;
        
        if (audioBase64 != null && audioBase64.isNotEmpty) {
          print('Generated TTS audio for: $text');
          
          // Decode base64 and play the audio
          final bytes = base64Decode(audioBase64);
          
          // Create a temporary file from bytes and play it
          await _audioPlayer.stop();
          await _audioPlayer.play(BytesSource(bytes));
          print('Successfully started playing TTS audio');
        }
      }
    } catch (e) {
      print('Error generating TTS: $e');
    }
  }


  /// Build formatted writing tips with larger Thai characters
  Widget _buildFormattedWritingTips(String tips) {
    final lines = tips.split('\n');
    final List<Widget> widgets = [];
    
    for (final line in lines) {
      if (line.trim().isEmpty) {
        widgets.add(const SizedBox(height: 8));
        continue;
      }
      
      // Check if line contains Thai characters for special formatting
      final containsThai = RegExp(r'[\u0E00-\u0E7F]').hasMatch(line);
      
      if (containsThai && (line.contains('Word:') || line.contains('"'))) {
        // Special formatting for lines with Thai characters
        final parts = <InlineSpan>[];
        final regex = RegExp(r'([\u0E00-\u0E7F]+)');
        int lastEnd = 0;
        
        for (final match in regex.allMatches(line)) {
          if (match.start > lastEnd) {
            parts.add(TextSpan(
              text: line.substring(lastEnd, match.start),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.5,
              ),
            ));
          }
          
          // Thai text with larger font
          parts.add(TextSpan(
            text: match.group(0),
            style: const TextStyle(
              fontSize: 24,
              color: Color(0xFF4ECCA3),
              height: 1.3,
              fontWeight: FontWeight.w500,
            ),
          ));
          
          lastEnd = match.end;
        }
        
        if (lastEnd < line.length) {
          parts.add(TextSpan(
            text: line.substring(lastEnd),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              height: 1.5,
            ),
          ));
        }
        
        widgets.add(RichText(
          text: TextSpan(children: parts),
        ));
      } else {
        // Regular text
        widgets.add(Text(
          line,
          style: const TextStyle(
            fontSize: 16,
            color: Colors.white,
            height: 1.5,
          ),
        ));
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentCharacters.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentSemanticWord = _currentCharacters[_currentCharacterIndex];
    final wordData = widget.wordMapping.isNotEmpty ? widget.wordMapping[0] : <String, dynamic>{};

    return Container(
      width: MediaQuery.of(context).size.width * 0.95,
      height: MediaQuery.of(context).size.height * 0.95,
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          // NEW: Full word header with highlighting and audio
          _buildFullWordHeader(),
          
          const SizedBox(height: 12),
          
          // Semantic word selection area
          _buildCharacterSelection(),
          
          const SizedBox(height: 12),
          
          // Main tracing area (clean canvas)
          Expanded(
            flex: 6, // Adjusted for new header
            child: _buildCleanTracingArea(currentSemanticWord),
          ),
          
          const SizedBox(height: 8),
          
          // NEW: Current semantic word info below canvas
          _buildClusterInfoPanel(),
          
          // Bottom buttons
          _buildBottomButton(),
        ],
      ),
    );
  }


  Widget _buildCharacterSelection() {
    return SizedBox(
      height: _isOverflowing ? 100 : 80, // Extra height for scrollbar when overflowing
      child: Column(
        children: [
          Expanded(
            child: _isOverflowing
                ? Scrollbar(
                    controller: _characterScrollController,
                    thumbVisibility: true,
                    trackVisibility: true,
                    thickness: 8.0,
                    child: SingleChildScrollView(
                      controller: _characterScrollController,
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _buildCharacterWidgets(),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _buildCharacterWidgets(),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCharacterWidgets() {
    return _currentCharacters.asMap().entries.map((entry) {
      final index = entry.key;
      final semanticWord = entry.value;
      final isSelected = index == _currentCharacterIndex;
      
      // Calculate appropriate width based on word length
      double containerWidth = 60.0; // Default for single characters
      if (semanticWord.length > 1) {
        containerWidth = (semanticWord.length * 20.0).clamp(60.0, 120.0); // Scale with word length, max 120
      }
      
      return GestureDetector(
        onTap: () {
          setState(() {
            _currentCharacterIndex = index;
          });
          _clearCanvas();
          _loadWritingTipsFromCache(); // Use cached data, no API call
        },
        child: Container(
          width: containerWidth,
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2D2D2D) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? const Color(0xFF4ECCA3) 
                  : const Color(0xFF4ECCA3).withValues(alpha: 0.3),
              width: isSelected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: isSelected ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                semanticWord,
                style: TextStyle(
                  fontSize: semanticWord.length > 2 ? 18 : 24, // Smaller font for longer words
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF4ECCA3) : Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  /// Build the new full word header with highlighting and audio
  Widget _buildFullWordHeader() {
    // Combine transliterations from all word mappings
    final combinedTransliteration = widget.wordMapping
        .where((mapping) => mapping['transliteration'] != null && mapping['transliteration'].toString().isNotEmpty)
        .map((mapping) => mapping['transliteration'].toString())
        .join(' ');
    
    // Use main English translation from first word mapping instead of combined translations
    print('DEBUG HEADER: widget.wordMapping[0] keys: ${widget.wordMapping.isNotEmpty ? widget.wordMapping[0].keys : "empty"}');
    print('DEBUG HEADER: english field value: ${widget.wordMapping.isNotEmpty ? widget.wordMapping[0]['english'] : "N/A"}');
    print('DEBUG HEADER: translation field value: ${widget.wordMapping.isNotEmpty ? widget.wordMapping[0]['translation'] : "N/A"}');
    
    final mainTranslation = widget.wordMapping.isNotEmpty && 
                           widget.wordMapping[0].containsKey('english') &&
                           widget.wordMapping[0]['english'] != null &&
                           widget.wordMapping[0]['english'].toString().isNotEmpty
        ? widget.wordMapping[0]['english'].toString()
        : widget.wordMapping.isNotEmpty && 
          widget.wordMapping[0].containsKey('translation') &&
          widget.wordMapping[0]['translation'] != null &&
          widget.wordMapping[0]['translation'].toString().isNotEmpty
          ? widget.wordMapping[0]['translation'].toString()
          : '';
    
    print('DEBUG HEADER: Using translation: "$mainTranslation"');
    
    // Check original vocabulary item for audio path first, then word mapping
    final hasAudio = (widget.originalVocabularyItem?.containsKey('audio_path') == true &&
        widget.originalVocabularyItem!['audio_path'] != null &&
        widget.originalVocabularyItem!['audio_path'].toString().isNotEmpty) ||
        widget.wordMapping.any((mapping) => 
            mapping.containsKey('audio_path') && 
            mapping['audio_path'] != null && 
            mapping['audio_path'].toString().isNotEmpty);
    
    // Use original vocabulary item for audio playback if available, otherwise fallback to word mapping
    final wordData = (widget.originalVocabularyItem?.containsKey('audio_path') == true &&
        widget.originalVocabularyItem!['audio_path'] != null &&
        widget.originalVocabularyItem!['audio_path'].toString().isNotEmpty)
        ? widget.originalVocabularyItem!
        : widget.wordMapping.isNotEmpty 
            ? widget.wordMapping[0] 
            : <String, dynamic>{};
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Full Thai word with highlighting and audio
          if (_originalWord.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHighlightedThaiText(),
                if (hasAudio) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _playVocabularyAudio(wordData),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4ECCA3).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: const Color(0xFF4ECCA3),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.volume_up,
                        color: Color(0xFF4ECCA3),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
          ],
          
          // Transliteration on second line (combined from all word mappings)
          if (combinedTransliteration.isNotEmpty) ...[
            Text(
              combinedTransliteration,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4ECCA3),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
          ],
          
          // Translation on third line (main English translation from first mapping)  
          if (mainTranslation.isNotEmpty) ...[
            Text(
              mainTranslation,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  /// Build clean tracing area without overlays
  Widget _buildCleanTracingArea(String currentSemanticWord) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: _buildTracingAreaOnly(currentSemanticWord),
    );
  }

  /// Build tracing area without bottom overlay
  Widget _buildTracingAreaOnly(String targetSemanticWord) {
    return Stack(
      children: [
        // Background with character guide
        Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1F1F1F),
                Color(0xFF2D2D2D),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  // Use 85% of available space to ensure characters fit within drawing bounds
                  width: constraints.maxWidth * 0.85,
                  height: constraints.maxHeight * 0.85,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: Text(
                      targetSemanticWord,
                      style: TextStyle(
                        // Use a base font size - FittedBox will scale appropriately
                        fontSize: targetSemanticWord.length > 2 ? 150 : 200, // Smaller for longer words
                        fontWeight: FontWeight.w300,
                        color: const Color(0xFF4ECCA3).withValues(alpha: 0.15),
                        shadows: [
                          Shadow(
                            offset: const Offset(2, 2),
                            blurRadius: 4,
                            color: const Color(0xFF4ECCA3).withValues(alpha: 0.1),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        
        // Digital ink drawing area with real-time preview
        GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: CustomPaint(
            painter: _TracingPainter(_ink, currentStrokePoints: _currentStrokePoints),
            size: Size.infinite,
          ),
        ),
        
        // Writing tips tooltip button positioned at top-left of drawing area
        if (widget.showWritingTips)
          Positioned(
            top: 16,
            left: 16,
            child: _buildWritingTipsTooltip(),
          ),
        
        // Undo button positioned at top-right of drawing area
        Positioned(
          top: 16,
          right: 16,
          child: _buildFloatingUndoButton(),
        ),
      ],
    );
  }



  /// Build semantic word info panel below canvas
  Widget _buildClusterInfoPanel() {
    final currentSemanticWord = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
        ? _currentCharacters[_currentCharacterIndex]
        : '';
    
    // Get semantic word data directly from constituent word data
    String currentRomanization = '';
    String currentTranslation = '';
    
    if (_constituentWordData.isNotEmpty && _currentCharacterIndex < _constituentWordData.length) {
      final wordData = _constituentWordData[_currentCharacterIndex];
      currentRomanization = wordData['romanized'] as String? ?? '';
      currentTranslation = wordData['translation'] as String? ?? '';
    }
    
    // Calculate progress
    final progress = _currentCharacters.isNotEmpty 
        ? '${_currentCharacterIndex + 1}/${_currentCharacters.length}'
        : '';
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Current semantic word display with three separate lines
          if (currentSemanticWord.isNotEmpty) ...[
            // Line 1: Thai word and progress (ensure proper spacing)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Left spacer to help center the Thai word
                Expanded(
                  flex: 1,
                  child: Container(),
                ),
                // Center the Thai character
                Expanded(
                  flex: 2,
                  child: Text(
                    currentSemanticWord,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // Progress indicator on the right
                Expanded(
                  flex: 1,
                  child: progress.isNotEmpty
                      ? Align(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4ECCA3).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              progress,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4ECCA3),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      : Container(),
                ),
              ],
            ),
            
            // Line 2: Transliteration 
            if (currentRomanization.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                currentRomanization,
                style: const TextStyle(
                  fontSize: 18,
                  color: Color(0xFF4ECCA3),
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            // Line 3: Translation
            if (currentTranslation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                currentTranslation,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Back button
          _buildActionButton(
            icon: Icons.arrow_back,
            color: Colors.grey[600]!,
            onPressed: widget.onBack,
            tooltip: 'Back',
          ),
          
          // Complete button
          _buildActionButton(
            icon: Icons.check,
            color: const Color(0xFF4ECCA3),
            onPressed: widget.onComplete,
            tooltip: 'Complete',
            iconColor: Colors.black,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingUndoButton() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF4ECCA3).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _ink.strokes.isNotEmpty ? _undoLastStroke : null,
          child: Icon(
            Icons.undo,
            size: 22,
            color: _ink.strokes.isNotEmpty ? Colors.black87 : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildWritingTipsTooltip() {
    return GestureDetector(
      onTap: () => _showWritingTipsDialog(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF4ECCA3).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.help_outline,
          size: 22,
          color: Colors.black87,
        ),
      ),
    );
  }

  void _showWritingTipsDialog() {
    print('Opening writing tips dialog. Current _writingTips length: ${_writingTips.length}');
    print('_writingTips preview: ${_writingTips.length > 100 ? _writingTips.substring(0, 100) + "..." : _writingTips}');
    
    // If tips are empty, try to reload them
    if (_writingTips.isEmpty) {
      print('Tips are empty, reloading...');
      _loadWritingTipsFromCache();
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 450),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF2D2D2D),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Writing Tips',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4ECCA3),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: _isLoadingTips
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF4ECCA3),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading writing tips...',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F1F1F),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_writingTips.isNotEmpty)
                                  _buildFormattedWritingTips(_writingTips)
                                else
                                  const Text(
                                    'No specific tips available for this character.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                      height: 1.5,
                                    ),
                                  ),
                                if (_hasLoadingError) ...[
                                  const SizedBox(height: 16),
                                  Center(
                                    child: ElevatedButton.icon(
                                      onPressed: _retryLoadingTips,
                                      icon: const Icon(Icons.refresh, size: 16),
                                      label: const Text('Retry'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4ECCA3),
                                        foregroundColor: Colors.black87,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16, 
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    required String tooltip,
    Color iconColor = Colors.white,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 24, color: iconColor),
        tooltip: tooltip,
      ),
    );
  }

  /// Build enhanced tips from writing guidance data
  String _buildEnhancedTipsFromGuidance(String character, Map<String, dynamic> guidance) {
    final List<String> sections = [];
    
    // Traditional names and cultural context
    final traditionalNames = guidance['traditional_names'] as List?;
    final culturalContext = guidance['cultural_context'] as List?;
    
    if (traditionalNames != null && traditionalNames.isNotEmpty) {
      sections.add('Traditional Name: ${traditionalNames.first}');
    }
    
    if (culturalContext != null && culturalContext.isNotEmpty) {
      sections.add('Cultural Context:');
      for (final context in culturalContext) {
        sections.add('$context');
      }
    }
    
    // Component breakdown with colors
    final componentBreakdown = guidance['writing_guidance']?['component_breakdown'] as List?;
    if (componentBreakdown != null && componentBreakdown.isNotEmpty) {
      sections.add('Components:');
      for (final component in componentBreakdown) {
        final char = component['character'];
        final type = component['type'];
        final traditionalName = component['traditional_name'];
        
        if (traditionalName != null) {
          sections.add('• $char ($type): $traditionalName');
        } else {
          sections.add('• $char ($type)');
        }
        
        // Add specific component tips
        final writingTips = component['writing_tips'] as List?;
        if (writingTips != null && writingTips.isNotEmpty) {
          for (final tip in writingTips) {
            sections.add('  - $tip');
          }
        }
      }
    }
    
    // Writing steps
    final writingSteps = guidance['writing_guidance']?['writing_steps'] as List?;
    if (writingSteps != null && writingSteps.isNotEmpty) {
      sections.add('Writing Order:');
      for (final step in writingSteps) {
        sections.add('$step');
      }
    }
    
    // Cultural guidelines
    final culturalGuidelines = guidance['writing_guidance']?['cultural_guidelines'] as List?;
    if (culturalGuidelines != null && culturalGuidelines.isNotEmpty) {
      sections.add('Thai Writing Guidelines:');
      for (final guideline in culturalGuidelines) {
        sections.add('• $guideline');
      }
    }
    
    // Learning level and difficulty
    final learningLevel = guidance['learning_level'];
    final complexity = guidance['complexity'];
    if (learningLevel != null || complexity != null) {
      sections.add('Level: ${learningLevel ?? complexity ?? 'Unknown'}');
    }
    
    return sections.join('\n\n');
  }

  /// Build character display with component color coding
  Widget _buildColorCodedCharacter(String character, Map<String, dynamic> guidance) {
    final componentBreakdown = guidance['writing_guidance']?['component_breakdown'] as List?;
    final componentColors = guidance['component_colors'] as Map<String, dynamic>?;
    
    if (componentBreakdown == null || componentBreakdown.isEmpty) {
      // Fallback: regular character display
      return Text(
        character,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Color(0xFF4ECCA3),
        ),
      );
    }
    
    final spans = <TextSpan>[];
    
    for (final component in componentBreakdown) {
      final char = component['character'] as String;
      final type = component['type'] as String;
      final colorHex = component['color'] as String?;
      
      Color componentColor = const Color(0xFF4ECCA3); // Default
      
      if (colorHex != null) {
        try {
          componentColor = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
        } catch (e) {
          // Use default color if parsing fails
        }
      } else if (componentColors != null) {
        // Get color from component colors mapping
        switch (type) {
          case 'consonant':
            componentColor = Color(int.parse(componentColors['consonants']?.replaceFirst('#', '0xFF') ?? '0xFF4A90E2'));
            break;
          case 'vowel':
            componentColor = Color(int.parse(componentColors['vowels']?.replaceFirst('#', '0xFF') ?? '0xFF7ED321'));
            break;
          case 'tone_mark':
            componentColor = Color(int.parse(componentColors['tone_marks']?.replaceFirst('#', '0xFF') ?? '0xFFF5A623'));
            break;
          default:
            componentColor = const Color(0xFF4ECCA3);
        }
      }
      
      spans.add(TextSpan(
        text: char,
        style: TextStyle(
          color: componentColor,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  /// Build enhanced writing tips panel with audio controls
  Widget _buildEnhancedWritingTipsPanel() {
    return GestureDetector(
      onTap: () => _showEnhancedWritingTipsDialog(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF4ECCA3).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.help_outline, size: 22, color: Colors.white),
      ),
    );
  }

  /// Show enhanced writing tips dialog with tabbed interface
  void _showEnhancedWritingTipsDialog() {
    final character = _currentCharacters.isNotEmpty 
        ? _currentCharacters[_currentCharacterIndex] 
        : '';
    
    // Get current word analysis data
    final analysisData = _wordAnalysisCache[character] ?? {};
    final tabbedContent = _buildTabbedWritingContent(character, analysisData);
    
    showDialog(
      context: context,
      builder: (context) => DefaultTabController(
        length: 3,
        initialIndex: 1, // Start with Step-by-Step tab
        child: Dialog(
          backgroundColor: const Color(0xFF2D2D2D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F1F1F),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Writing Tips: $character',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4ECCA3),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                
                // Tab Bar
                Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF1F1F1F),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFF4ECCA3), width: 1),
                    ),
                  ),
                  child: const TabBar(
                    indicatorColor: Color(0xFF4ECCA3),
                    labelColor: Color(0xFF4ECCA3),
                    unselectedLabelColor: Colors.white54,
                    labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    tabs: [
                      Tab(text: 'Guidelines'),
                      Tab(text: 'Step-by-Step'),
                      Tab(text: 'Pronunciation'),
                    ],
                  ),
                ),
                
                // Tab Content
                Flexible(
                  child: TabBarView(
                    children: [
                      _buildTabContentWidget(tabbedContent['general'] ?? []),
                      _buildTabContentWidget(tabbedContent['stepByStep'] ?? []),
                      _buildTabContentWidget(tabbedContent['pronunciation'] ?? []),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildTabContentWidget(List<String> content) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content.map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }
}

/// Custom painter for character tracing with real-time stroke preview
class _TracingPainter extends CustomPainter {
  final mlkit.Ink ink;
  final List<mlkit.StrokePoint> currentStrokePoints;

  _TracingPainter(this.ink, {this.currentStrokePoints = const []});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF4ECCA3)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0
      ..style = PaintingStyle.stroke;

    // Draw completed strokes
    for (final mlkit.Stroke stroke in ink.strokes) {
      final Path path = Path();
      bool first = true;
      
      for (final mlkit.StrokePoint point in stroke.points) {
        if (first) {
          path.moveTo(point.x, point.y);
          first = false;
        } else {
          path.lineTo(point.x, point.y);
        }
      }
      
      canvas.drawPath(path, paint);
    }

    // Draw current stroke being drawn (real-time preview)
    if (currentStrokePoints.isNotEmpty) {
      final Paint currentPaint = Paint()
        ..color = const Color(0xFF4ECCA3).withValues(alpha: 0.8)
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke;

      final Path currentPath = Path();
      bool first = true;
      
      for (final mlkit.StrokePoint point in currentStrokePoints) {
        if (first) {
          currentPath.moveTo(point.x, point.y);
          first = false;
        } else {
          currentPath.lineTo(point.x, point.y);
        }
      }
      
      canvas.drawPath(currentPath, currentPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TracingPainter oldDelegate) {
    // Always repaint if we're currently drawing
    if (currentStrokePoints.isNotEmpty || oldDelegate.currentStrokePoints.isNotEmpty) {
      return true;
    }
    // Repaint when ink changes
    return oldDelegate.ink.strokes.length != ink.strokes.length;
  }
}