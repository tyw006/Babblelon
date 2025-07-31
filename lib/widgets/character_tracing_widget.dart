import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_digital_ink_recognition/google_mlkit_digital_ink_recognition.dart' as mlkit;
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import '../services/character_audio_service.dart';
import '../services/game_initialization_service.dart';
import '../services/character_recognition_service.dart';
import '../widgets/tracing_confirmation_dialog.dart';
import '../widgets/character_assessment_dialog.dart';

/// Custom StreamAudioSource for playing base64 audio data on iOS
class Base64AudioSource extends just_audio.StreamAudioSource {
  final List<int> _bytes;

  Base64AudioSource(this._bytes);

  @override
  Future<just_audio.StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return just_audio.StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}

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
  
  /// NPC ID for item giving functionality
  final String? npcId;
  
  /// NPC name for display in assessment dialog
  final String? npcName;
  
  /// Called when user wants to give item to NPC
  final VoidCallback? onGiveItem;

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
    this.npcId,
    this.npcName,
    this.onGiveItem,
  });

  @override
  State<CharacterTracingWidget> createState() => _CharacterTracingWidgetState();
}

class _CharacterTracingWidgetState extends State<CharacterTracingWidget> {
  // Character tracing state
  int _currentCharacterIndex = 0;
  List<String> _currentCharacters = [];
  final ScrollController _characterScrollController = ScrollController();
  final PageController _stepPageController = PageController();
  int _currentStepPage = 0;
  
  // Enhanced cluster data from backend
  List<String> _romanizationByCluster = [];
  List<Map<String, dynamic>> _constituentWordData = [];
  String _originalWord = '';
  
  // Pre-processing cache for word analysis
  Map<String, Map<String, dynamic>> _wordAnalysisCache = {};
  bool _isPreprocessingComplete = false;
  
  // Canvas overflow detection
  bool _isOverflowing = false;
  
  // Drawing state - Per-character isolation
  final Map<int, mlkit.Ink> _characterInks = {};
  final Map<int, List<mlkit.Stroke>> _characterStrokeHistory = {};
  final Map<int, mlkit.Stroke?> _currentStrokes = {};
  final Map<int, bool> _characterHasStrokes = {};
  final List<mlkit.StrokePoint> _currentStrokePoints = [];
  
  // Writing tips and guidance
  String _writingTips = "";
  bool _isLoadingTips = false;
  bool _hasLoadingError = false;
  Map<String, dynamic> _writingGuidance = {};
  
  // Audio services
  final AudioPlayer _audioPlayer = AudioPlayer();
  final just_audio.AudioPlayer _justAudioPlayer = just_audio.AudioPlayer();
  final CharacterAudioService _audioService = CharacterAudioService();
  
  // TTS loading state for custom words
  bool _isGeneratingTTS = false;
  bool _ttsGenerationFailed = false;
  Map<String, String> _ttsAudioCache = {};

  // Add Thai writing guide data cache
  Map<String, dynamic>? _thaiWritingGuideData;
  
  // Track last processed semantic word to prevent unnecessary page resets
  String? _lastProcessedSemanticWord;
  
  // New UI state for enhanced writing tips
  bool _tipsExpanded = false; // Will be removed - tips will be always visible
  bool _highlightingActive = true; // Controls when highlighting is shown vs neutral
  List<String> _generalWritingTips = [
    "Write from left to right across the page.",
    "The Consonant is the Anchor: Always write the main consonant of a syllable first. Then, add any vowel or tone marks that go above, below, or to the right of it.",
    "Circles First: For any character that has a circle (or 'loop'), always start by drawing the circle before drawing any attached lines or curves.",
    "Consistent Sizing: Aim to keep the main body of all consonants at a consistent height for clean, readable text.",
  ];

  @override
  void initState() {
    super.initState();
    _initializeAsync();
    _loadUIPreferences();
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
      } else {
        // Fallback: load directly from assets if not cached
        print('⚠️ Loading Thai writing guide from assets (cache not available)');
        final jsonString = await rootBundle.loadString('assets/data/thai_writing_guide.json');
        _thaiWritingGuideData = json.decode(jsonString);
        print('✅ Thai writing guide loaded from assets');
      }
      
      // Load writing principles for the banner
      _loadWritingPrinciplesFromJSON();
      
    } catch (e) {
      print('❌ Error loading Thai writing guide: $e');
      _thaiWritingGuideData = null;
    }
  }
  
  /// Load writing principles from JSON for the banner tips
  void _loadWritingPrinciplesFromJSON() {
    if (_thaiWritingGuideData != null) {
      try {
        final writingPrinciples = _thaiWritingGuideData!['writing_principles'] as Map<String, dynamic>?;
        final guidelines = writingPrinciples?['guidelines'] as List?;
        
        if (guidelines != null && guidelines.isNotEmpty) {
          setState(() {
            _generalWritingTips = guidelines.cast<String>();
          });
          print('✅ Loaded ${_generalWritingTips.length} writing principles from JSON');
        }
      } catch (e) {
        print('⚠️ Error parsing writing principles from JSON: $e');
        // Keep default fallback tips
      }
    }
  }

  // Canvas isolation helper methods
  
  /// Get or create ink object for the current character
  mlkit.Ink _getCurrentCharacterInk() {
    if (!_characterInks.containsKey(_currentCharacterIndex)) {
      _characterInks[_currentCharacterIndex] = mlkit.Ink();
      _characterStrokeHistory[_currentCharacterIndex] = [];
      _currentStrokes[_currentCharacterIndex] = null;
      _characterHasStrokes[_currentCharacterIndex] = false;
    }
    return _characterInks[_currentCharacterIndex]!;
  }
  
  /// Get current stroke for the current character
  mlkit.Stroke? _getCurrentCharacterStroke() {
    return _currentStrokes[_currentCharacterIndex];
  }
  
  /// Set current stroke for the current character
  void _setCurrentCharacterStroke(mlkit.Stroke? stroke) {
    _currentStrokes[_currentCharacterIndex] = stroke;
  }
  
  /// Get stroke history for the current character
  List<mlkit.Stroke> _getCurrentCharacterStrokeHistory() {
    if (!_characterStrokeHistory.containsKey(_currentCharacterIndex)) {
      _characterStrokeHistory[_currentCharacterIndex] = [];
    }
    return _characterStrokeHistory[_currentCharacterIndex]!;
  }
  
  /// Check if current character has strokes
  bool _currentCharacterHasStrokes() {
    return _characterHasStrokes[_currentCharacterIndex] ?? false;
  }
  
  /// Mark current character as having strokes
  void _markCurrentCharacterHasStrokes(bool hasStrokes) {
    _characterHasStrokes[_currentCharacterIndex] = hasStrokes;
  }

  /// Build visual indicators showing which characters have strokes
  Widget _buildCharacterStatusIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_currentCharacters.length, (index) {
        final hasStrokes = _characterHasStrokes[index] ?? false;
        final isCurrentCharacter = index == _currentCharacterIndex;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: isCurrentCharacter ? 12 : 8,
          height: isCurrentCharacter ? 12 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasStrokes 
                ? (isCurrentCharacter ? const Color(0xFF4ECCA3) : Colors.green[300])
                : (isCurrentCharacter ? Colors.blue[300] : Colors.grey[300]),
            border: isCurrentCharacter 
                ? Border.all(color: Colors.white, width: 2)
                : null,
          ),
        );
      }),
    );
  }

  /// Show confirmation dialog before proceeding with assessment
  Future<void> _showTracingConfirmationDialog() async {
    // Prepare character names and stroke status
    final characterNames = <int, String>{};
    final charactersWithStrokes = <int, bool>{};
    
    for (int i = 0; i < _currentCharacters.length; i++) {
      characterNames[i] = _currentCharacters[i];
      charactersWithStrokes[i] = _characterHasStrokes[i] ?? false;
    }
    
    // Show confirmation dialog
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return TracingConfirmationDialog(
          characterNames: characterNames,
          charactersWithStrokes: charactersWithStrokes,
          onConfirm: () {
            Navigator.of(context).pop();
            _proceedWithAssessment();
          },
          onCancel: () {
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  /// Proceed with ML Kit assessment and show results
  Future<void> _proceedWithAssessment() async {
    // Initialize character recognition service
    try {
      await characterRecognitionService.initialize();
    } catch (e) {
      print('Failed to initialize character recognition: $e');
      // Fallback: just call completion without assessment
      if (widget.onComplete != null) {
        widget.onComplete!();
      }
      return;
    }

    // Show loading indicator
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );

    try {
      // Perform assessment
      final assessmentResult = await characterRecognitionService.assessAllCharacters(
        _characterInks,
        _currentCharacters,
      );

      // Dismiss loading indicator and show results
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show assessment results dialog
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return CharacterAssessmentDialog(
              assessmentResult: assessmentResult,
              characterNames: _currentCharacters,
              originalVocabularyItem: widget.originalVocabularyItem,
              npcId: widget.npcId,
              npcName: widget.npcName,
              onGiveItem: () {
                // Close CharacterTracingWidget before forwarding callback
                Navigator.of(context).pop();
                if (widget.onGiveItem != null) {
                  widget.onGiveItem!(); // Forward to DialogueOverlay
                }
              },
              onDismiss: () {
                Navigator.of(context).pop();
                // Call backend processing immediately - no delay needed
                if (widget.onComplete != null) {
                  widget.onComplete!();
                }
              },
            );
          },
        );
      }
    } catch (e) {
      print('Assessment failed: $e');
      
      // Dismiss loading indicator
      if (mounted) {
        Navigator.of(context).pop();
        
        // Show error and fallback to completion
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assessment failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        
        if (widget.onComplete != null) {
          widget.onComplete!();
        }
      }
    }
  }

  @override
  void dispose() {
    _characterScrollController.dispose();
    _stepPageController.dispose();
    _audioPlayer.dispose();
    _justAudioPlayer.dispose();
    // Clear TTS audio cache
    _ttsAudioCache.clear();
    // Don't dispose the singleton _audioService as it's shared across widgets
    super.dispose();
  }
  
  /// Load UI preferences for tips display
  Future<void> _loadUIPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _tipsExpanded = prefs.getBool('character_tips_expanded') ?? false; // Will be removed
      });
    } catch (e) {
      print('Error loading UI preferences: $e');
    }
  }
  
  /// Save UI preferences
  Future<void> _saveUIPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('character_tips_expanded', _tipsExpanded);
    } catch (e) {
      print('Error saving UI preferences: $e');
    }
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

  /// Get word segments using syllable-based tokenization from backend
  Future<void> _getWordSegments() async {
    _constituentWordData = [];
    _currentCharacters = []; // This will store syllables
    
    // Process each word from the word mapping and get its syllables
    for (final mapping in widget.wordMapping) {
      final semanticWord = mapping['target'] as String? ?? mapping['thai'] as String? ?? '';
      final transliteration = mapping['transliteration'] as String? ?? '';
      final translation = mapping['translation'] as String? ?? '';
      final english = mapping['english'] as String? ?? '';
      
      if (semanticWord.isNotEmpty) {
        // Call backend to get proper syllable splitting
        try {
          final response = await http.post(
            Uri.parse('http://localhost:8000/generate-writing-guide'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'word': semanticWord,
              'target_language': 'th'
            }),
          ).timeout(const Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            
            // Extract syllables from backend response
            if (data.containsKey('traceable_canvases') && data['traceable_canvases'] is List) {
              final syllables = List<String>.from(data['traceable_canvases']);
              final syllableData = data['syllables'] as List? ?? [];
              
              _currentCharacters.addAll(syllables);
              
              // Create constituent word data for each syllable with individual romanization and translations
              for (int i = 0; i < syllables.length; i++) {
                final syllable = syllables[i];
                
                // Get individual syllable romanization from backend if available
                String syllableRomanization = transliteration; // fallback
                if (i < syllableData.length) {
                  final sylData = syllableData[i] as Map<String, dynamic>;
                  syllableRomanization = sylData['romanization'] as String? ?? transliteration;
                }
                
                // Check if syllable mappings are available from word mapping
                String syllableTranslation = translation; // fallback to full word translation
                String syllableEnglish = english; // fallback to full word english
                
                final syllableMappings = mapping['syllable_mappings'] as List<dynamic>?;
                if (syllableMappings != null) {
                  // Find the matching syllable in the mappings
                  for (final sylMapping in syllableMappings) {
                    if (sylMapping is Map<String, dynamic> && 
                        sylMapping['syllable'] == syllable) {
                      syllableTranslation = sylMapping['translation'] as String? ?? translation;
                      syllableEnglish = sylMapping['translation'] as String? ?? english;
                      // Also use the syllable-specific romanization if available
                      syllableRomanization = sylMapping['romanization'] as String? ?? syllableRomanization;
              
                      break;
                    }
                  }
                }
                
                _constituentWordData.add({
                  'word': syllable,
                  'romanized': syllableRomanization,
                  'translation': syllableTranslation,
                  'english': syllableEnglish,
                });
              }
              
              
            } else {
              // Fallback: treat as single unit
              _currentCharacters.add(semanticWord);
              _constituentWordData.add({
                'word': semanticWord,
                'romanized': transliteration,
                'translation': translation,
                'english': english,
              });
              // Backend response missing traceable_canvases data
            }
          } else {
            // Backend failed, use original word as single unit
            _currentCharacters.add(semanticWord);
            _constituentWordData.add({
              'word': semanticWord,
              'romanized': transliteration,
              'translation': translation,
              'english': english,
            });
            // Backend request failed
          }
        } catch (e) {
          // Error occurred, use original word as single unit
          _currentCharacters.add(semanticWord);
          _constituentWordData.add({
            'word': semanticWord,
            'romanized': transliteration,
            'translation': translation,
            'english': english,
          });
          print('Error getting syllables for $semanticWord: $e');
        }
      }
    }
    
    // Set original word as concatenation of all syllables
    _originalWord = _currentCharacters.join('');
    
    
  }

  /// Pre-load comprehensive analysis for all semantic words to avoid API calls during word switching
  Future<void> _preloadAllWordAnalysis() async {
    // Load detailed syllable analysis for each character/syllable
    for (final semanticWord in _currentCharacters) {
      if (semanticWord.isNotEmpty && !_wordAnalysisCache.containsKey(semanticWord)) {
        await _preloadSingleWordAnalysis(semanticWord);
      }
    }
    
    _isPreprocessingComplete = true;
    
    // Load initial writing tips (will use cached syllable analysis data)
    await _loadWritingTipsFromCache();
  }

  /// Pre-load analysis for a single word using new syllable-based endpoint
  Future<void> _preloadSingleWordAnalysis(String semanticWord) async {
    if (semanticWord.isEmpty || _wordAnalysisCache.containsKey(semanticWord)) {
      return;
    }
    
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/generate-writing-guide'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'word': semanticWord,
          'target_language': 'th'
        }),
      ).timeout(const Duration(seconds: 10)); // Increased timeout per word
      
      if (response.statusCode == 200) {
        final analysisData = json.decode(response.body);
        _wordAnalysisCache[semanticWord] = analysisData;
      } else {
        // Failed to get syllable analysis from backend
        _storeFallbackAnalysis(semanticWord);
      }
    } catch (e) {
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

  /// Tokenize vocabulary words using syllable-based analysis
  Future<void> _tokenizeVocabularyWords(List<Map<String, dynamic>> wordMapping) async {
    _currentCharacters = [];
    _romanizationByCluster = [];
    
    try {
      // Process each constituent word from the word_mapping
      for (final mapping in wordMapping) {
        final word = mapping['target'] as String? ?? '';
        if (word.isNotEmpty) {
          // Call backend to get syllable-based tokenization for this individual word
          final response = await http.post(
            Uri.parse('http://localhost:8000/generate-writing-guide'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'word': word,
              'target_language': 'th'
            }),
          ).timeout(const Duration(seconds: 10));
          
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            
            // Cache the detailed syllable analysis for this word
            _wordAnalysisCache[word] = data;
            
            // Also fetch complex vowel analysis if not already cached
            _fetchComplexVowelAnalysis(word);
            
            // Extract syllables from new response format
            if (data.containsKey('traceable_canvases') && data['traceable_canvases'] is List) {
              final syllables = List<String>.from(data['traceable_canvases']);
              _currentCharacters.addAll(syllables);
              
              // For syllable-based approach, use romanization from syllable analysis
              final transliteration = mapping['transliteration'] as String? ?? '';
              for (int i = 0; i < syllables.length; i++) {
                _romanizationByCluster.add(transliteration);
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
      
      
      
    } catch (e) {
      print('Error tokenizing vocabulary words: $e');
      // Fallback: split all words into characters
      for (final mapping in wordMapping) {
        final word = mapping['target'] as String? ?? '';
        _currentCharacters.addAll(word.split(''));
      }
    }
  }

  /// Use syllable-based analysis for semantic word boundaries
  Future<void> _tokenizeWordUsingBackendForSemanticWords(String targetWord) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/generate-writing-guide'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'word': targetWord,
          'target_language': 'th'
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Use traceable_canvases for syllable boundaries
        if (data.containsKey('traceable_canvases') && data['traceable_canvases'] is List) {
          _currentCharacters = List<String>.from(data['traceable_canvases']);
  
        } else {
          // Fallback to original word as single syllable
          _currentCharacters = [targetWord];
        }
        
        // Store syllable data if available (convert syllable data to constituent word format)
        if (data.containsKey('syllables') && data['syllables'] is List) {
          final syllables = data['syllables'] as List;
          _constituentWordData = syllables.map<Map<String, dynamic>>((syllable) {
            return {
              'word': syllable['syllable'] ?? '',
              'romanized': '', // Can be extracted from tips if needed
              'translation': '', // Not available at syllable level
              'english': '',
            };
          }).toList();
        }
        
      } else {
        // Backend semantic word tokenization failed
        _currentCharacters = [targetWord]; // Treat as single semantic word
      }
    } catch (e) {
      print('Error tokenizing word using backend for semantic words: $e');
      _currentCharacters = [targetWord]; // Treat as single semantic word
    }
  }

  /// Use syllable-based analysis for custom words
  Future<void> _tokenizeWordUsingBackend(String targetWord) async {
    try {
      // Use the new generate-writing-guide endpoint for syllable-based tokenization
      final response = await http.post(
        Uri.parse('http://localhost:8000/generate-writing-guide'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'word': targetWord,
          'target_language': 'th'
        }),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Store enhanced syllable data
        _originalWord = data['word'] ?? targetWord;
        _romanizationByCluster = []; // Will be populated from syllable data
        
        // Convert syllable data to constituent word format
        if (data.containsKey('syllables') && data['syllables'] is List) {
          final syllables = data['syllables'] as List;
          _constituentWordData = syllables.map<Map<String, dynamic>>((syllable) {
            return {
              'word': syllable['syllable'] ?? '',
              'romanized': '', // Can be extracted from tips if needed
              'translation': '', // Not available at syllable level
              'english': '',
            };
          }).toList();
        } else {
          _constituentWordData = [];
        }
        
        // Use the syllable-based tracing sequence
        if (data.containsKey('traceable_canvases') && data['traceable_canvases'] is List) {
          _currentCharacters = List<String>.from(data['traceable_canvases']);
  
        } else {
          // Last resort: split into individual characters
          _currentCharacters = targetWord.split('');
  
        }
        

      } else {
        // Backend tokenization failed
        _currentCharacters = targetWord.split('');
      }
    } on TimeoutException catch (e) {
              // Backend tokenization timed out
      _currentCharacters = targetWord.split('');
    } catch (e) {
      print('Error tokenizing word using backend: $e');
      _currentCharacters = targetWord.split('');
    }
  }

  /// Build highlighted Thai text showing current syllable being traced
  Widget _buildHighlightedThaiText() {
    if (_originalWord.isEmpty || _currentCharacters.isEmpty) {
      return const SizedBox.shrink();
    }
    
    List<TextSpan> spans = [];
    
    for (int i = 0; i < _currentCharacters.length; i++) {
      final syllableOrWord = _currentCharacters[i];
      final isCurrentSyllable = i == _currentCharacterIndex;
      final isCompleted = i < _currentCharacterIndex;
      
      Color textColor;
      FontWeight fontWeight;
      
      if (_highlightingActive) {
        // Active highlighting: show current/completed/upcoming states for syllables
        if (isCurrentSyllable) {
          textColor = const Color(0xFF4ECCA3); // Highlighted current syllable being traced
          fontWeight = FontWeight.bold;
        } else if (isCompleted) {
          textColor = Colors.white70; // Completed syllables should be grey
          fontWeight = FontWeight.w500;
        } else {
          textColor = Colors.white54; // Upcoming syllables
          fontWeight = FontWeight.w400;
        }
      } else {
        // Neutral highlighting: show all text in same neutral color when not tracing
        textColor = Colors.white70; // Neutral color for all text
        fontWeight = FontWeight.w500; // Consistent weight
      }
      
      spans.add(TextSpan(
        text: syllableOrWord,
        style: TextStyle(
          color: textColor,
          fontWeight: fontWeight,
          fontSize: 36,
        ),
      ));
      
      // Add space between syllables only if they are separate words (not syllables of same word)
      // For syllables of the same word, we don't add spaces
      if (i < _currentCharacters.length - 1) {
        // Check if next syllable starts a new word by comparing to constituent word data
        bool shouldAddSpace = _shouldAddSpaceBetweenSyllables(i);
        if (shouldAddSpace) {
          spans.add(const TextSpan(
            text: ' ',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 36,
            ),
          ));
        }
      }
    }
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(children: spans),
    );
  }

  /// Determine if we should add space between syllables (only between different words)
  bool _shouldAddSpaceBetweenSyllables(int currentIndex) {
    // If we only have one constituent word, never add spaces (all syllables belong to same word)
    if (_constituentWordData.length <= 1) {
      return false;
    }
    
    // For multiple words, we need to determine syllable boundaries
    // This is a simplified approach - in a full implementation, you'd track word boundaries
    // For now, assume syllables are grouped by word in the order they appear
    
    // Simple heuristic: if current syllable ends a word based on constituent data length
    // This would need more sophisticated logic in a production app
    return false; // For now, don't add spaces within words - will be enhanced based on actual data structure
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

    if (_currentCharacters.isEmpty || !widget.showWritingTips) return;
    
    setState(() {
      _isLoadingTips = true;
    });

    try {
      final semanticWord = _currentCharacters[_currentCharacterIndex];
      
      if (_wordAnalysisCache.containsKey(semanticWord)) {
        // Use cached analysis (comprehensive or fallback)
        final analysisData = _wordAnalysisCache[semanticWord]!;

        
        setState(() {
          _writingGuidance = analysisData;
          _writingTips = _buildComprehensiveEducationalTips(semanticWord, analysisData);
          _isLoadingTips = false;
          _hasLoadingError = false;
        });
      } else {
        // Cache miss - create enhanced fallback directly

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
              // Fallback tips request timed out
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

    
    // Check if this is fallback data (backend failed)
    if (analysisData.containsKey('fallback') && analysisData['fallback'] == true) {
      
      return _buildEnhancedFallbackTips(semanticWord);
    }
    
    // Check if we should use Thai writing guide (our preferred method)
    if (analysisData.containsKey('use_thai_guide') && analysisData['use_thai_guide'] == true) {
      
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
        final romanization = characterDetails['romanization'] ?? '';
        final mainTip = characterDetails['main_tip'] ?? '';
        final romanizationText = romanization.isNotEmpty ? ' ($romanization)' : '';
        
        sections.add('• $char$romanizationText: $mainTip');
        
        // Add standard guidance for characters
        final englishGuide = characterDetails['english_guide'];
        final position = characterDetails['position']; // For vowels
        final consonantClass = characterDetails['consonant_class']; // For consonants
        final pronunciationGuide = characterDetails['pronunciation_guide']; // For tone marks
        
        if (englishGuide != null && englishGuide != mainTip) {
          sections.add('  Sound: $englishGuide');
        }
        if (position != null) {
          sections.add('  Position: $position');
        }
        if (consonantClass != null) {
          sections.add('  Class: $consonantClass');
        }
        if (pronunciationGuide != null) {
          sections.add('  Function: $pronunciationGuide');
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
    
    // Add note about complex vowel patterns if word contains them
    if (_containsComplexVowelPatterns(semanticWord)) {
      sections.add('');
      sections.add('🔤 Complex Vowel Patterns:');
      sections.add('• This word contains complex vowel patterns');
      sections.add('• Some vowels are written in parts around consonants');
      sections.add('• Follow the reading order: consonant + complete vowel sound');
      sections.add('• Check the character pronunciation display for specific pattern details');
    }
    
    final result = sections.join('\n');

    
    // Ensure we always return something useful
    if (result.trim().isEmpty) {
      return 'Thai Writing Guidelines:\n• Write from left to right across the page\n• Start with circles and main shapes, then add lines and details\n• Keep characters the same height and evenly spaced';
    }
    
    return result;
  }

  /// Check if word contains complex vowel patterns (simple heuristic check)
  bool _containsComplexVowelPatterns(String word) {
    // Simple check for common complex vowel patterns
    final complexPatterns = [
      'เ', 'แ', 'โ', 'ใ', 'ไ', // Leading vowels
      'ำ', // Special vowel
    ];
    
    // Check for patterns that typically indicate complex vowels
    for (final pattern in complexPatterns) {
      if (word.contains(pattern)) {
        return true;
      }
    }
    
    // Check for combination patterns (vowel + consonant + vowel)
    for (int i = 0; i < word.length - 2; i++) {
      final substr = word.substring(i, i + 3);
      if (substr.contains('เ') && substr.contains('อ')) return true;
      if (substr.contains('เ') && substr.contains('ื')) return true;
      if (substr.contains('เ') && substr.contains('า')) return true;
    }
    
    return false;
  }

  /// Get standardized romanization for a character using consistent extraction logic
  String _getStandardizedRomanization(Map<String, dynamic> characterDetails, String type, {String? syllable, bool isComplexVowel = false, bool isSilent = false}) {
    String romanization = '';
    
    if (type == 'consonant') {
      // Prioritize initial sound for consonants
      final pronunciation = characterDetails['pronunciation'] as Map<String, dynamic>?;
      final sounds = characterDetails['sounds'] as Map<String, dynamic>?;
      
      romanization = pronunciation?['initial'] as String? ?? 
                    sounds?['initial'] as String? ?? 
                    pronunciation?['romanization'] as String? ?? 
                    characterDetails['romanization'] as String? ?? '';
                    
    } else if (type == 'vowel' || type == 'tone_mark' || type == 'tone') {
      // For vowels and tone marks, prioritize romanization field
      final pronunciation = characterDetails['pronunciation'] as Map<String, dynamic>?;
      final sounds = characterDetails['sounds'] as Map<String, dynamic>?;
      
      romanization = characterDetails['romanization'] as String? ?? 
                    pronunciation?['romanization'] as String? ?? 
                    sounds?['sound'] as String? ?? 
                    pronunciation?['sound'] as String? ?? '';
    }
    
    // Handle complex vowel cases
    if (isComplexVowel && isSilent && romanization.isNotEmpty) {
      romanization = '$romanization(silent)';
    }
    
    return romanization;
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
        
        
        // Extract pronunciation information
        final pronunciation = charData['pronunciation'] as Map<String, dynamic>?;
        final romanization = pronunciation?['initial'] ?? pronunciation?['romanization'] ?? '';
        final englishGuide = pronunciation?['english_guide'] ?? '';
        
        // Extract writing steps
        final writingSteps = charData['writing_steps'] as String? ?? '';
        final mainTip = writingSteps.isNotEmpty ? writingSteps : englishGuide;
        
        return {
          'character': cleanCharacter,
          'type': 'consonant',
          'name': charData['name'],  // Include the consonant name (e.g., "yo yak")
          'romanization': romanization,
          'main_tip': mainTip,
          'english_guide': englishGuide,
          'writing_steps': writingSteps,
          'consonant_class': charData['class'],
          'pronunciation': pronunciation,  // Include the full pronunciation data
        };
      }
      
      // Check vowels with all placeholder variations and complex patterns
      final vowels = _thaiWritingGuideData!['vowels'] as Map<String, dynamic>?;
      String? foundVowelKey;
      Map<String, dynamic>? vowelData;
      
      if (vowels != null) {
        // Try direct match first
        if (vowels.containsKey(cleanCharacter)) {
          foundVowelKey = cleanCharacter;
          vowelData = vowels[cleanCharacter] as Map<String, dynamic>;
        }
        // Try placeholder before vowel (◌ะ format)
        else if (vowels.containsKey('◌$cleanCharacter')) {
          foundVowelKey = '◌$cleanCharacter';
          vowelData = vowels['◌$cleanCharacter'] as Map<String, dynamic>;
        }
        // Try vowel before placeholder (เ◌ format) 
        else if (vowels.containsKey('$cleanCharacter◌')) {
          foundVowelKey = '$cleanCharacter◌';
          vowelData = vowels['$cleanCharacter◌'] as Map<String, dynamic>;
        }
        // Check complex vowel patterns (e.g., เ◌อ, เ◌ีย, etc.)
        else {
          for (final vowelKey in vowels.keys) {
            if (vowelKey.contains(cleanCharacter) && vowelKey.contains('◌')) {
              // Found character as part of a complex vowel pattern
              foundVowelKey = vowelKey;
              vowelData = vowels[vowelKey] as Map<String, dynamic>;
              break;
            }
          }
        }
      }
      
      if (vowelData != null) {
        
        
        // Extract pronunciation information
        final pronunciation = vowelData['pronunciation'] as Map<String, dynamic>?;
        final romanization = pronunciation?['romanization'] ?? '';
        final englishGuide = pronunciation?['english_guide'] ?? '';
        
        // Extract writing steps
        final writingSteps = vowelData['writing_steps'] as String? ?? '';
        final mainTip = writingSteps.isNotEmpty ? writingSteps : englishGuide;
        
        return {
          'character': cleanCharacter,
          'type': 'vowel',
          'romanization': romanization,
          'main_tip': mainTip,
          'english_guide': englishGuide,
          'writing_steps': writingSteps,
          'position': vowelData['position'],
          'pronunciation': pronunciation,  // Include the full pronunciation data
        };
      }
      
      // Check tone marks in the top-level tone_marks section
      final toneMarks = _thaiWritingGuideData!['tone_marks'] as Map<String, dynamic>?;
      if (toneMarks != null && toneMarks.containsKey(cleanCharacter)) {
        final markInfo = toneMarks[cleanCharacter] as Map<String, dynamic>;
        
        
        // Extract writing steps for tone marks
        final writingSteps = markInfo['writing_steps'] as String? ?? '';
        final name = markInfo['name'] as String? ?? '';
        final pronunciationGuide = markInfo['pronunciation_guide'] as String? ?? '';
        final mainTip = writingSteps.isNotEmpty ? writingSteps : pronunciationGuide;
        
        return {
          'character': cleanCharacter,
          'type': 'tone',
          'romanization': '', // Tone marks don't have romanization
          'main_tip': mainTip,
          'english_guide': pronunciationGuide,
          'pronunciation_guide': pronunciationGuide,
          'writing_steps': writingSteps,
          'name': name,
        };
      }
      
      // Check other marks (thanthakhat, mai yamok, etc.)
      final otherMarks = _thaiWritingGuideData!['other_marks'] as Map<String, dynamic>?;
      if (otherMarks != null && otherMarks.containsKey(cleanCharacter)) {
        final markInfo = otherMarks[cleanCharacter] as Map<String, dynamic>;
        
        // Extract information for other marks
        final writingSteps = markInfo['writing_steps'] as String? ?? '';
        final name = markInfo['name'] as String? ?? '';
        final pronunciationGuide = markInfo['pronunciation_guide'] as String? ?? '';
        final function = markInfo['function'] as String? ?? '';
        final mainTip = writingSteps.isNotEmpty ? writingSteps : pronunciationGuide;
        
        return {
          'character': cleanCharacter,
          'type': 'other_mark',
          'romanization': 'Silent', // Other marks are silent
          'main_tip': mainTip,
          'english_guide': pronunciationGuide,
          'pronunciation_guide': pronunciationGuide,
          'writing_steps': writingSteps,
          'name': name,
          'function': function,
        };
      }
      
      print('No detailed character info found for: "$cleanCharacter"');
      
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
        final charSteps = charDetails['writing_steps'] as String? ?? '';
        
        final soundDescription = charDetails['sound_description'] ?? '';
        
        if (charSteps.isNotEmpty) {
          // Show sound description and steps
          if (soundDescription.isNotEmpty) {
            steps.add('$stepNum. Draw "$char" ($romanization) - $soundDescription:');
          } else {
            steps.add('$stepNum. Draw "$char" (sounds like "$romanization"):');
          }
          // Simplify the step language for beginners
          final simplifiedStep = _simplifyStepLanguage(charSteps);
          steps.add('   • $simplifiedStep');
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
        final charSteps = charDetails['writing_steps'] as String? ?? '';
        
        if (charSteps.isNotEmpty) {
          steps.add('$stepNum. Write "$char" ($romanization):');
          steps.add('   • $charSteps');
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
  // Function removed - logic moved to _getDetailedCharacterInfo

  /// Get English translation from the word mapping (prioritize 'english' field)
  String? _getEnglishTranslationFromMapping() {
    if (widget.wordMapping.isNotEmpty) {
      final wordData = widget.wordMapping[0];
      
      // Prioritize 'english' field from NPC vocabulary
      if (wordData.containsKey('english') && 
          wordData['english'] != null && 
          wordData['english'].toString().isNotEmpty) {

        return wordData['english'].toString();
      }
      
      // Fallback to translation field
      if (wordData.containsKey('translation') && 
          wordData['translation'] != null && 
          wordData['translation'].toString().isNotEmpty) {

        return wordData['translation'].toString();
      }
    }
    return null;
  }

  /// Get character-specific tips from the Thai writing guide JSON
  String _getCharacterTipsFromJSON(String character) {
    // Strip whitespace and normalize character
    final cleanCharacter = character.trim();
    if (_thaiWritingGuideData == null) {
      return '';
    }
    
    try {
      final consonants = _thaiWritingGuideData!['consonants'] as Map<String, dynamic>?;

      if (consonants != null && consonants.containsKey(cleanCharacter)) {
        final charData = consonants[cleanCharacter] as Map<String, dynamic>;

        
        // Use writing_steps and pronunciation fields
        final writingSteps = charData['writing_steps'] as String? ?? '';
        final pronunciation = charData['pronunciation'] as Map<String, dynamic>?;
        final englishGuide = pronunciation?['english_guide'] as String? ?? '';
        
        if (writingSteps.isNotEmpty && englishGuide.isNotEmpty) {
          final result = '$englishGuide\n\nHow to write: $writingSteps';
          
          return result;
        } else if (writingSteps.isNotEmpty) {
          
          return writingSteps;
        } else if (englishGuide.isNotEmpty) {
          
          return englishGuide;
        }
        
        // Final fallback to romanization 
        final romanization = pronunciation?['initial'] as String? ?? '';
        if (romanization.isNotEmpty) {
          final result = '$romanization sound';
          
          return result;
        }
      }
      
      // Check vowels section as well (try both direct and placeholder notation)
      final vowels = _thaiWritingGuideData!['vowels'] as Map<String, dynamic>?;
      String vowelKey = cleanCharacter;
      bool foundInVowels = vowels?.containsKey(cleanCharacter) == true;
      
      // Try placeholder notation for standalone vowels (both before and after)
      if (!foundInVowels && vowels != null) {
        // Try placeholder before vowel (◌เ format)
        vowelKey = '◌$cleanCharacter';
        foundInVowels = vowels.containsKey(vowelKey);
        
        // Try vowel before placeholder (เ◌ format) 
        if (!foundInVowels) {
          vowelKey = '$cleanCharacter◌';
          foundInVowels = vowels.containsKey(vowelKey);
        }
      }
      
      
      if (foundInVowels) {
        final vowelData = vowels![vowelKey] as Map<String, dynamic>;
        
        
        // Use writing_steps and pronunciation.english_guide fields for vowels
        final writingSteps = vowelData['writing_steps'] as String? ?? '';
        final pronunciation = vowelData['pronunciation'] as Map<String, dynamic>?;
        final englishGuide = pronunciation?['english_guide'] as String? ?? '';
        
        if (writingSteps.isNotEmpty && englishGuide.isNotEmpty) {
          final result = '$englishGuide\n\nHow to write: $writingSteps';
          
          return result;
        } else if (writingSteps.isNotEmpty) {
          
          return writingSteps;
        } else if (englishGuide.isNotEmpty) {
          
          return englishGuide;
        }
        
        // Fallback to romanization and position
        final romanization = pronunciation?['romanization'] as String? ?? '';
        final position = vowelData['position'] as String? ?? '';
        if (romanization.isNotEmpty) {
          final result = '$romanization sound' + (position.isNotEmpty ? ' (placed $position consonant)' : '');
          
          return result;
        }
      } else {
        // Check if this character appears as a component in complex vowels
        final complexVowelTip = _findInComplexVowels(cleanCharacter);
        if (complexVowelTip.isNotEmpty) {

          return complexVowelTip;
        }
      }
      
      // Check tone marks section
      final toneMarks = _thaiWritingGuideData!['tone_marks'] as Map<String, dynamic>?;
      
      if (toneMarks != null && toneMarks.containsKey(cleanCharacter)) {
        final toneData = toneMarks[cleanCharacter] as Map<String, dynamic>;
        
        
        // Use writing_steps and pronunciation_guide fields for tone marks (simplified for beginners)
        final writingSteps = toneData['writing_steps'] as String? ?? '';
        final pronunciationGuide = toneData['pronunciation_guide'] as String? ?? '';
        
        if (writingSteps.isNotEmpty && pronunciationGuide.isNotEmpty) {
          // Simplify tone description for beginners
          final simplifiedTone = pronunciationGuide.replaceAll('makes ', '').replaceAll(' tone', '');
          final result = 'Makes your voice $simplifiedTone\n\nHow to write: $writingSteps';
          
          return result;
        } else if (writingSteps.isNotEmpty) {
          
          return writingSteps;
        } else if (pronunciationGuide.isNotEmpty) {
          final simplifiedTone = pronunciationGuide.replaceAll('makes ', '').replaceAll(' tone', '');
          final result = 'Makes your voice $simplifiedTone';
          
          return result;
        }
        
        // No additional fallback for tone marks
      }
      
    } catch (e) {
      print('Error getting character tips from JSON for "$character" (cleaned: "$cleanCharacter"): $e');
    }
    
    
    return '';
  }

  void _onPanStart(DragStartDetails details) {
    _setCurrentCharacterStroke(mlkit.Stroke());
    _currentStrokePoints.clear();
    
    final point = mlkit.StrokePoint(
      x: details.localPosition.dx,
      y: details.localPosition.dy,
      t: DateTime.now().millisecondsSinceEpoch,
    );
    
    _getCurrentCharacterStroke()!.points.add(point);
    _currentStrokePoints.add(point);
    
    setState(() {});
    SchedulerBinding.instance.scheduleFrame();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_getCurrentCharacterStroke() != null) {
      final point = mlkit.StrokePoint(
        x: details.localPosition.dx,
        y: details.localPosition.dy,
        t: DateTime.now().millisecondsSinceEpoch,
      );
      
      _getCurrentCharacterStroke()!.points.add(point);
      _currentStrokePoints.add(point);
      
      setState(() {});
    }
  }

  void _onPanEnd(DragEndDetails details) {
    final currentStroke = _getCurrentCharacterStroke();
    if (currentStroke != null) {
      final currentInk = _getCurrentCharacterInk();
      final currentStrokeHistory = _getCurrentCharacterStrokeHistory();
      
      if (!currentInk.strokes.contains(currentStroke)) {
        currentInk.strokes.add(currentStroke);
        currentStrokeHistory.add(currentStroke);
        _markCurrentCharacterHasStrokes(true);
      }
      
      _setCurrentCharacterStroke(null);
      _currentStrokePoints.clear();
      
      setState(() {});
    }
  }

  void _clearCanvas() {
    setState(() {
      final currentInk = _getCurrentCharacterInk();
      final currentStrokeHistory = _getCurrentCharacterStrokeHistory();
      
      currentInk.strokes.clear();
      currentStrokeHistory.clear();
      _currentStrokePoints.clear();
      _setCurrentCharacterStroke(null);
      _markCurrentCharacterHasStrokes(false);
    });
  }

  void _undoLastStroke() {
    final currentInk = _getCurrentCharacterInk();
    if (currentInk.strokes.isNotEmpty) {
      setState(() {
        currentInk.strokes.removeLast();
        final currentStrokeHistory = _getCurrentCharacterStrokeHistory();
        currentStrokeHistory.clear();
        currentStrokeHistory.addAll(currentInk.strokes);
        _markCurrentCharacterHasStrokes(currentInk.strokes.isNotEmpty);
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
        final audioPath = wordData['audio_path'] as String;

        
        // Play audio file using audioplayers
        await _audioPlayer.stop(); // Stop any currently playing audio
        
        // Check if this is base64 audio data (for custom words) or file path (for NPC words)
        if (audioPath.startsWith('assets/')) {
          // For NPC vocabulary with existing audio_path
          final cleanPath = audioPath.substring(7); // Remove 'assets/' prefix
          await _audioPlayer.play(AssetSource(cleanPath));

        } else if (audioPath.startsWith('data:') || audioPath.length > 1000) {
          // For custom words with base64 audio data
          String base64Data = audioPath;
          if (audioPath.startsWith('data:')) {
            // Extract base64 part from data URL
            base64Data = audioPath.split(',').last;
          }
          
          try {
            final audioBytes = base64Decode(base64Data);
            // Use just_audio for base64 data (iOS compatible)
            await _justAudioPlayer.stop();
            final audioSource = Base64AudioSource(audioBytes);
            await _justAudioPlayer.setAudioSource(audioSource);
            await _justAudioPlayer.play();

          } catch (e) {
            // Failed to decode base64 audio, fallback to TTS
            // Fallback to TTS
            final targetText = wordData['target'] as String? ?? '';
            if (targetText.isNotEmpty) {
              await _generateAndPlayTTS(targetText);
            }
          }
        } else {
          // Assume it's a regular file path
          await _audioPlayer.play(AssetSource(audioPath));

        }
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
    // Check cache first
    if (_ttsAudioCache.containsKey(text)) {
      final cachedAudio = _ttsAudioCache[text]!;
      final bytes = base64Decode(cachedAudio);
      await _justAudioPlayer.stop();
      final audioSource = Base64AudioSource(bytes);
      await _justAudioPlayer.setAudioSource(audioSource);
      await _justAudioPlayer.play();

      return;
    }

    setState(() {
      _isGeneratingTTS = true;
      _ttsGenerationFailed = false;
    });

    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/synthesize-speech/'),
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

          
          // Cache the audio for future use
          _ttsAudioCache[text] = audioBase64;
          
          // Decode base64 and play the audio
          final bytes = base64Decode(audioBase64);
          
          // Use just_audio for base64 data (iOS compatible)
          await _justAudioPlayer.stop();
          final audioSource = Base64AudioSource(bytes);
          await _justAudioPlayer.setAudioSource(audioSource);
          await _justAudioPlayer.play();

        }
      } else {
        // TTS generation failed
        setState(() {
          _ttsGenerationFailed = true;
        });
      }
    } catch (e) {
      // Error generating TTS
      setState(() {
        _ttsGenerationFailed = true;
      });
    } finally {
      setState(() {
        _isGeneratingTTS = false;
      });
    }
  }

  /// Handle audio playback with retry logic for failed TTS
  Future<void> _handleAudioPlayback(Map<String, dynamic> wordData, bool hasNPCAudio) async {
    if (_ttsGenerationFailed && !hasNPCAudio) {
      // Reset the failed state and retry TTS generation
      setState(() {
        _ttsGenerationFailed = false;
      });
    }
    
    // Call the original playback method
    await _playVocabularyAudio(wordData);
  }

  /// Build dynamic audio icon based on TTS loading state
  Widget _buildAudioIcon(bool hasNPCAudio) {
    if (_isGeneratingTTS) {
      // Show loading spinner for TTS generation
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECCA3)),
        ),
      );
    } else if (_ttsGenerationFailed) {
      // Show retry icon for failed TTS generation
      return const Icon(
        Icons.refresh,
        color: Colors.red,
        size: 20,
      );
    } else {
      // Show volume icon for normal state (both NPC and custom words)
      return const Icon(
        Icons.volume_up,
        color: Color(0xFF4ECCA3),
        size: 20,
      );
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
              fontSize: 36,
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
        // Check if line starts with a number (for step instructions)
        final stepMatch = RegExp(r'^(\d+)\.?\s*(.*)').firstMatch(line);
        if (stepMatch != null) {
          // Check if this is a character writing step (contains writing verbs)
          final stepText = stepMatch.group(2)!;
          final isWritingStep = _isCharacterWritingStep(stepText);
          
          if (isWritingStep) {
            // Line starts with a number and is a writing step - create inset number design
            final stepNumber = stepMatch.group(1)!;
            
            widgets.add(Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Stack(
                children: [
                  // Main text container with left padding for the number
                  Container(
                    padding: const EdgeInsets.only(left: 40, right: 16, top: 12, bottom: 12),
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF4ECCA3).withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      stepText,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        height: 1.5,
                      ),
                    ),
                  ),
                  // Inset number circle
                  Positioned(
                    left: 0,
                    top: 8,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ECCA3),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          stepNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ));
          } else {
            // Numbered line but not a writing step - display as regular text
            widgets.add(Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.white,
                  height: 1.6,
                ),
              ),
            ));
          }
        } else {
          // Regular text - no box
          widgets.add(Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white,
                height: 1.6,
              ),
            ),
          ));
        }
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
          
          // Main tracing area (clean canvas) - reduced to 35% as per design
          Expanded(
            child: _buildCleanTracingArea(currentSemanticWord),
          ),
          
          const SizedBox(height: 8),
          
          // NEW: Sound breakdown strip - fixed height
          _buildSoundBreakdownStrip(),
          
          const SizedBox(height: 8),
          
          // Minimal word info strip (no longer expanded tips panel)
          _buildMinimalWordInfo(),
          
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
          // Don't clear canvas - preserve user's work
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
    

    
    // Show audio icon for all words (NPC words with audio_path OR custom words for TTS)
    final hasNPCAudio = (widget.originalVocabularyItem?.containsKey('audio_path') == true &&
        widget.originalVocabularyItem!['audio_path'] != null &&
        widget.originalVocabularyItem!['audio_path'].toString().isNotEmpty) ||
        widget.wordMapping.any((mapping) => 
            mapping.containsKey('audio_path') && 
            mapping['audio_path'] != null && 
            mapping['audio_path'].toString().isNotEmpty);
    
    // Show audio icon for ALL words (NPC vocabulary + custom words via TTS)
    final hasAudio = hasNPCAudio || widget.wordMapping.isNotEmpty;
    
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
            Stack(
              children: [
                // Centered Thai text
                Center(
                  child: _buildHighlightedThaiText(),
                ),
                // Volume icon positioned to the right
                if (hasAudio)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: GestureDetector(
                      onTap: () => _handleAudioPlayback(wordData, hasNPCAudio),
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
                        child: _buildAudioIcon(hasNPCAudio),
                      ),
                    ),
                  ),
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
            painter: _TracingPainter(_getCurrentCharacterInk(), currentStrokePoints: _currentStrokePoints),
            size: Size.infinite,
          ),
        ),
        
        // Writing tips button overlay
        if (widget.showWritingTips)
          Positioned(
            top: 16,
            left: 16,
            child: _buildWritingTipsButton(),
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

  /// Get character name for display
  String _getCharacterName(String character) {
    final charType = _getCharacterType(character);
    
    // For other marks, get the correct name from the other mark info
    if (charType == 'other_mark') {
      final otherMarkInfo = _getOtherMarkInfo(character);
      final name = otherMarkInfo['name'] as String?;
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    
    // For tone marks, get the correct name from the tone mark info
    if (charType == 'tone') {
      final toneMarkInfo = _getToneMarkInfoFromJSON(character);
      final name = toneMarkInfo['name'] as String?;
      if (name != null && name.isNotEmpty) {
        return name;
      }
    }
    
    // For consonants, use proper Thai names from JSON
    if (charType == 'consonant') {
      final charInfo = _getDetailedCharacterInfo(character);
      if (charInfo != null) {
        final name = charInfo['name'] as String?;
        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
    }
    
    // For vowels, create proper vowel names
    if (charType == 'vowel') {
      final charInfo = _getDetailedCharacterInfo(character);
      if (charInfo != null) {
        final pronunciationData = charInfo['pronunciation'] as Map<String, dynamic>?;
        final romanization = pronunciationData?['romanization'] as String? ?? '';
        if (romanization.isNotEmpty) {
          return 'Sara $romanization'; // "Sara" means vowel in Thai
        }
      }
    }
    
    return '';
  }

  /// Get complex vowel information for the current character and word
  Future<Map<String, dynamic>?> _getComplexVowelInfo(String character, String word) async {
    try {
  
      final response = await http.post(
        Uri.parse('http://localhost:8000/analyze-complex-vowels/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'word': word,
          'target_language': 'th',
        }),
      );

      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Find if current character is part of any complex vowel
        final characterAnalysis = data['character_analysis'] as List?;
        if (characterAnalysis != null) {
          final currentCharIndex = word.indexOf(character);
          if (currentCharIndex >= 0 && currentCharIndex < characterAnalysis.length) {
            final charInfo = characterAnalysis[currentCharIndex];
            if (charInfo['complex_vowel_info'] != null) {
              return {
                'is_complex_vowel': true,
                'pattern': charInfo['complex_vowel_info']['pattern'],
                'name': charInfo['complex_vowel_info']['name'],
                'pronunciation': charInfo['complex_vowel_info']['full_pronunciation'],
                'role': charInfo['complex_vowel_info']['role'],
                'patterns': data['patterns'], // Full pattern information
              };
            }
          }
        }
      } else {
      }
    } catch (e) {
      print('Error getting complex vowel info: $e');
    }
    
    return null;
  }

  /// Build pronunciation display for step card context with character-specific logic
  Widget _buildStepCardPronunciationDisplay(String character) {
    // Get the current semantic word from the character index
    final currentSemanticWord = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
        ? _currentCharacters[_currentCharacterIndex] 
        : '';
    
    final characterType = _getCharacterType(character);
    
    // Handle each character type appropriately
    if (characterType == 'consonant') {
      return _buildConsonantDisplay(character);
    } else if (characterType == 'vowel') {
      return _buildVowelDisplay(character, currentSemanticWord);
    } else if (characterType == 'tone') {
      return _buildToneMarkDisplay(character, currentSemanticWord);
    }
    
    // Fallback for unknown character types
    return _buildGenericCharacterDisplay(character, currentSemanticWord);
  }

  /// Build consonant display - show consonant name and sound
  Widget _buildConsonantDisplay(String character) {
    // Get the current semantic word from the character index
    final currentSemanticWord = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
        ? _currentCharacters[_currentCharacterIndex] 
        : '';
    
    // Check if this specific consonant is part of a complex vowel component
    final complexVowelGuide = _getComplexVowelSoundGuide(character, currentSemanticWord);
    
    // Only show complex vowel info for consonants that are actual vowel components (like อ in เ◌ือ)
    if (complexVowelGuide.isNotEmpty && character == 'อ') {
      
      // For อ as part of เ◌ือ, show the complex vowel sound it makes
      final complexVowelData = _getComplexVowelData(currentSemanticWord);
      final complexVowelName = complexVowelData['name'] as String? ?? 'complex vowel';
      final complexVowelSound = complexVowelData['romanization'] as String? ?? complexVowelGuide;
      
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            complexVowelName,
            style: const TextStyle(
              color: Color(0xFF4ECCA3),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            "'$complexVowelSound'",
            style: const TextStyle(
              color: Color(0xFF4ECCA3),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }
    
    // Otherwise show regular consonant information
    final charInfo = _getDetailedCharacterInfo(character);
    if (charInfo == null) return const SizedBox.shrink();
    
    final name = charInfo['name'] as String? ?? '';
    final pronunciationData = charInfo['pronunciation'] as Map<String, dynamic>?;
    final initialSound = pronunciationData?['initial'] as String? ?? '';
    final finalSound = pronunciationData?['final'] as String?;
    
    // Build pronunciation display - show only relevant sound based on position
    // TODO: Determine if this consonant is initial or final in the current syllable context
    // For now, show the primary sound (initial if available, otherwise final)
    String pronunciationDisplay = '';
    if (initialSound.isNotEmpty) {
      pronunciationDisplay = "'$initialSound'";
    } else if (finalSound != null && finalSound.isNotEmpty) {
      pronunciationDisplay = "'$finalSound'";
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty)
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF4ECCA3),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (pronunciationDisplay.isNotEmpty)
          Text(
            pronunciationDisplay,
            style: const TextStyle(
              color: Color(0xFF4ECCA3),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  /// Build vowel display - show complex vowel sound if part of complex pattern
  Widget _buildVowelDisplay(String character, String word) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getComplexVowelInfo(character, word),
      builder: (context, snapshot) {
        final complexVowelInfo = snapshot.data;
        
        
        // Always show individual vowel information next to the icon
        // Complex vowel explanation will be in the Sound box via contextual tips
        
        // Otherwise show individual vowel information
        final charInfo = _getDetailedCharacterInfo(character);
        if (charInfo == null) {
          return const SizedBox.shrink();
        }
        
        final name = _getCharacterName(character);
        final romanization = charInfo['romanization'] as String? ?? '';
        
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name.isNotEmpty)
              Text(
                name,
                style: const TextStyle(
                  color: Color(0xFF4ECCA3),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (romanization.isNotEmpty)
              Text(
                "'$romanization'",
                style: const TextStyle(
                  color: Color(0xFF4ECCA3),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        );
      },
    );
  }

  /// Build tone mark display with tone calculation formula
  Widget _buildToneMarkDisplay(String character, String word) {
    
    final toneInfo = _getToneMarkInfoFromJSON(character);
    if (toneInfo.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final name = toneInfo['name'] as String? ?? '';
    final toneData = _calculateToneEffectWithFormula(character, word);
    final toneEffect = toneData['tone'] ?? '';
    
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (name.isNotEmpty)
          Text(
            name,
            style: const TextStyle(
              color: Color(0xFF4ECCA3),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (toneEffect.isNotEmpty)
          Text(
            "'$toneEffect'",
            style: const TextStyle(
              color: Color(0xFF4ECCA3),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  /// Build generic character display fallback
  Widget _buildGenericCharacterDisplay(String character, String word) {
    final pronunciation = _getPronunciationForDisplay(character, word);
    final characterName = _getCharacterName(character);
    
    if (pronunciation.isEmpty && characterName.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (characterName.isNotEmpty)
          Text(
            characterName,
            style: const TextStyle(
              color: Color(0xFF4ECCA3),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (pronunciation.isNotEmpty)
          Text(
            "'$pronunciation'",
            style: const TextStyle(
              color: Color(0xFF4ECCA3),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  /// Calculate tone effect based on consonant class and syllable type
  Map<String, String> _calculateToneEffectWithFormula(String toneMark, String word) {
    // Find the consonant this tone mark is affecting
    final consonantInWord = _findMainConsonantInWord(word);
    if (consonantInWord.isEmpty) return {'tone': '', 'formula': ''};
    
    // Get consonant class
    final consonantInfo = _getDetailedCharacterInfo(consonantInWord);
    final consonantClass = consonantInfo?['consonant_class'] as String? ?? '';
    
    // Determine syllable type (live vs dead) - simplified
    final syllableType = _determineSyllableType(word);
    
    // Get tone mark info
    final toneInfo = _getToneMarkInfoFromJSON(toneMark);
    final markName = toneInfo['name'] as String? ?? '';
    
    // Calculate resulting tone based on rules and create formula
    String resultingTone = '';
    String formula = '';
    
    if (toneMark == '่') { // Mai Ek
      if (consonantClass == 'mid' || consonantClass == 'high') {
        resultingTone = 'low tone';
        formula = '${_capitalize(consonantClass)} class + $markName + $syllableType syllable = Low tone';
      } else if (consonantClass == 'low') {
        if (syllableType == 'live') {
          resultingTone = 'falling tone';
          formula = '${_capitalize(consonantClass)} class + $markName + $syllableType syllable = Falling tone';
        } else {
          resultingTone = 'high tone';
          formula = '${_capitalize(consonantClass)} class + $markName + $syllableType syllable = High tone';
        }
      }
    } else if (toneMark == '้') { // Mai Tho
      if (consonantClass == 'mid' || consonantClass == 'high') {
        resultingTone = 'falling tone';
        formula = '${_capitalize(consonantClass)} class + $markName + $syllableType syllable = Falling tone';
      } else if (consonantClass == 'low') {
        resultingTone = 'high tone';
        formula = '${_capitalize(consonantClass)} class + $markName + $syllableType syllable = High tone';
      }
    }
    
    return {'tone': resultingTone, 'formula': formula};
  }

  /// Simple capitalize helper
  String _capitalize(String str) {
    if (str.isEmpty) return str;
    return str[0].toUpperCase() + str.substring(1);
  }

  /// Find the main consonant in a word (simplified)
  String _findMainConsonantInWord(String word) {
    for (int i = 0; i < word.length; i++) {
      final char = word[i];
      if (_getCharacterType(char) == 'consonant') {
        return char;
      }
    }
    return '';
  }

  /// Determine if syllable is live or dead
  String _determineSyllableType(String word) {
    // A dead syllable ends with a stop consonant (unvoiced: k, t, p) or short vowel
    // A live syllable ends with a vowel, sonorant consonant (m, n, ng, w, y, l, r), or no final consonant
    
    if (word.isEmpty) return 'live';
    
    // Get the last character that's not a tone mark or vowel marker
    String lastChar = '';
    for (int i = word.length - 1; i >= 0; i--) {
      final char = word[i];
      final charType = _getCharacterType(char);
      if (charType == 'consonant') {
        lastChar = char;
        break;
      }
    }
    
    if (lastChar.isEmpty) return 'live'; // No final consonant = live
    
    // Check if the final consonant is a stop consonant
    final stopConsonants = ['ก', 'ข', 'ค', 'จ', 'ช', 'ซ', 'ต', 'ท', 'ป', 'พ', 'ผ', 'ฝ', 'ศ', 'ส', 'ห'];
    
    // Dead syllable: ends with stop consonant and short vowel, or just stop consonant
    if (stopConsonants.contains(lastChar)) {
      // Check if there's a short vowel (this is simplified)
      if (word.contains('ะ') || word.length <= 2) {
        return 'dead';
      }
    }
    
    return 'live'; // Default to live
  }

  /// Build simplified complex vowel display widget (to prevent overflow)
  Widget _buildComplexVowelDisplay(Map<String, dynamic> complexVowelInfo) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Simplified name with pattern indicator
        Text(
          '${complexVowelInfo['name'] ?? 'Complex'}',
          style: const TextStyle(
            color: Color(0xFF4ECCA3),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        // Simple sound
        Text(
          '${complexVowelInfo['pronunciation'] ?? ''}',
          style: const TextStyle(
            color: Color(0xFF4ECCA3),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Build pronunciation display panel for individual characters
  Widget _buildPronunciationDisplay(String word) {
    if (word.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Get current character based on the step being traced
    String currentChar;
    if (_stepPageController.hasClients && _currentStepPage >= 0) {
      // If we're tracking steps, use the current step character
      final characters = word.split('');
      final currentStepIndex = _currentStepPage;
      if (currentStepIndex >= 0 && currentStepIndex < characters.length) {
        currentChar = characters[currentStepIndex];
      } else {
        currentChar = characters.isNotEmpty ? characters[0] : word[0];
      }
    } else {
      // Default to first character if not in step mode
      currentChar = word[0];
    }
    
    final pronunciation = _getPronunciationForDisplay(currentChar, word);
    
    if (pronunciation.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF4ECCA3).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              pronunciation,
              style: const TextStyle(
                color: Color(0xFF4ECCA3),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build always-visible character tips panel with fixed height
  Widget _buildEnhancedClusterInfoPanel() {
    final currentSemanticWord = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
        ? _currentCharacters[_currentCharacterIndex]
        : '';
    
    // Get semantic word data
    String currentRomanization = '';
    String currentTranslation = '';
    
    if (_constituentWordData.isNotEmpty && _currentCharacterIndex < _constituentWordData.length) {
      final wordData = _constituentWordData[_currentCharacterIndex];
      currentRomanization = wordData['romanized'] as String? ?? '';
      
      // Handle compound word syllables
      final rawTranslation = wordData['translation'] as String?;
      final isCompound = wordData['is_compound'] == true;
      final wordTranslation = wordData['word_translation'] as String?;
      
      if (rawTranslation == null || rawTranslation.isEmpty || rawTranslation == 'null' || rawTranslation == 'None') {
        if (isCompound && wordTranslation != null && wordTranslation.isNotEmpty) {
          // For compound words, show contextual information
          currentTranslation = '(part of $wordTranslation)';
        } else {
          // For non-compound words or missing word translation, show syllable romanization
          currentTranslation = currentRomanization.isNotEmpty ? '($currentRomanization)' : '';
        }
      } else {
        currentTranslation = rawTranslation;
      }
    }
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced padding
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
          // Current syllable display with three separate lines (centered)
          if (currentSemanticWord.isNotEmpty) ...[
            // Line 1: Thai syllable (centered, no progress indicator)
            Text(
              currentSemanticWord,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
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

  /// Build minimal word info strip (replaces large tips panel)
  Widget _buildMinimalWordInfo() {
    final currentSemanticWord = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
        ? _currentCharacters[_currentCharacterIndex]
        : '';
    
    // Get semantic word data
    String currentRomanization = '';
    String currentTranslation = '';
    
    if (_constituentWordData.isNotEmpty && _currentCharacterIndex < _constituentWordData.length) {
      final wordData = _constituentWordData[_currentCharacterIndex];
      currentRomanization = wordData['romanized'] as String? ?? '';
      currentTranslation = wordData['translation'] as String? ?? '';
    }
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 8, 16), // Reduced padding
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left navigation arrow
            Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECCA3).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: _goToPreviousCharacter,
                  icon: const Icon(Icons.chevron_left, size: 28),
                  color: const Color(0xFF4ECCA3),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ),
              
              // Center content with text only (no progress)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Row 1: Thai character (centered, no progress)
                    Text(
                      currentSemanticWord,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    
                    // Row 2: Transliteration
                    if (currentRomanization.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        currentRomanization,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4ECCA3),
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    
                    // Row 3: Translation
                    if (currentTranslation.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        currentTranslation,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              
              // Right navigation arrow
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF4ECCA3).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: _goToNextCharacter,
                  icon: const Icon(Icons.chevron_right, size: 28),
                  color: const Color(0xFF4ECCA3),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                ),
              ),
            ],
        ),
      ),
    );
  }

  /// Build sound breakdown strip showing character components with pronunciation
  Widget _buildSoundBreakdownStrip() {
    // Get current syllable only (per traceable canvas)
    final currentSyllable = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
        ? _currentCharacters[_currentCharacterIndex]
        : '';
    
    if (currentSyllable.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // If preprocessing is not complete, show a loading indicator
    if (!_isPreprocessingComplete) {
      return Container(
        width: double.infinity,
        height: 150,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          border: Border(
            top: BorderSide(
              color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
              width: 1,
            ),
            bottom: BorderSide(
              color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: const Center(
          child: Text(
            'Loading sound breakdown...',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF4ECCA3),
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 150, // Increased height to accommodate larger text
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
            width: 1,
          ),
          bottom: BorderSide(
            color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title
          const Text(
            'Sound Breakdown',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4ECCA3),
            ),
          ),
          const SizedBox(height: 8),
          
          // Character cards row - centered when content is smaller than width
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _buildCharacterSoundCards(currentSyllable),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build individual character sound cards for the breakdown strip using proper syllable analysis
  List<Widget> _buildCharacterSoundCards(String syllable) {
    final List<Widget> cards = [];
    
    // Use the same backend analysis that writing tips use
    final components = _analyzeSyllableComponents(syllable);
    
    // Use standardized spacing for consistent appearance across all traceable canvases
    const double spacing = 12.0; // Fixed spacing between cards for uniformity
    
    for (int i = 0; i < components.length; i++) {
      final component = components[i];
      
      // Build the card
      cards.add(_buildSingleSoundCard(
        character: component['character'] as String,
        romanization: component['romanization'] as String,
        typeTag: component['typeTag'] as String,
        fullTypeLabel: component['fullTypeLabel'] as String? ?? component['typeTag'] as String,
        tagColor: component['tagColor'] as Color,
        isHighlighted: false, // No highlighting needed since we only show current syllable
        isSilent: component['isSilent'] as bool? ?? false,
        isComplexVowel: component['isComplexVowel'] as bool? ?? false,
        patternName: component['patternName'] as String?,
        readingExplanation: component['readingExplanation'] as String?,
      ));
      
      if (i < components.length - 1) {
        cards.add(SizedBox(width: spacing));
      }
    }
    
    return cards;
  }

  /// Analyze syllable components using backend analysis data (same as writing tips)
  List<Map<String, dynamic>> _analyzeSyllableComponents(String syllable) {
    final List<Map<String, dynamic>> components = [];
    
    
    // Step 1: Try to get backend analysis from cache (same as writing tips)
    final backendAnalysis = _getBackendSyllableAnalysis(syllable);
    
    if (backendAnalysis != null) {
      // Use backend analysis for complex vowel detection (same as writing tips)
      components.addAll(_analyzeFromBackendData(syllable, backendAnalysis));
    } else {
      // Fallback to JSON-based analysis
      components.addAll(_analyzeFromThaiGuideJson(syllable));
    }
    
    return components;
  }
  
  /// Get backend syllable analysis from cache (same source as writing tips)
  Map<String, dynamic>? _getBackendSyllableAnalysis(String syllable) {
    // Check if we have cached analysis for this syllable
    if (_wordAnalysisCache.containsKey(syllable)) {
      final wordData = _wordAnalysisCache[syllable]!;
      
      // If this is word-level data, extract the syllable data
      if (wordData.containsKey('syllables')) {
        final syllables = wordData['syllables'] as List? ?? [];
        for (final syllableData in syllables) {
          final syllableMap = syllableData as Map<String, dynamic>;
          if (syllableMap['syllable'] == syllable) {
            return syllableMap;
          }
        }
      } else {
        // This is already syllable-level data
        return wordData;
      }
    }
    
    // Check if any cached analysis contains this syllable
    for (final analysisData in _wordAnalysisCache.values) {
      if (analysisData.containsKey('syllables')) {
        final syllables = analysisData['syllables'] as List?;
        if (syllables != null) {
          for (final syllableData in syllables) {
            final syllableMap = syllableData as Map<String, dynamic>;
            if (syllableMap['syllable'] == syllable) {
              return syllableMap;
            }
          }
        }
      }
    }
    
    return null;
  }
  
  /// Analyze syllable using backend data (same logic as writing tips)
  List<Map<String, dynamic>> _analyzeFromBackendData(String syllable, Map<String, dynamic> backendData) {
    final List<Map<String, dynamic>> components = [];
    
    // Extract character analysis from new backend structure
    final characters = backendData['characters'] as List? ?? [];
    
    // Detect consonants silenced by thanthakhat
    final silencedConsonants = _detectSilencedConsonants(syllable);
    
    // Process each character using backend analysis
    for (int i = 0; i < characters.length; i++) {
      final charData = characters[i] as Map<String, dynamic>;
      final char = charData['character'] as String? ?? '';
      
      if (char.isNotEmpty) {
        final componentData = _buildCharacterFromNewBackendAnalysis(charData);
        
        // Apply silencing if this consonant is affected by thanthakhat
        if (silencedConsonants.containsKey(i)) {
          componentData['isSilent'] = true;
          final currentRomanization = componentData['romanization'] as String? ?? '';
          if (!currentRomanization.contains('(silent)')) {
            componentData['romanization'] = '$currentRomanization(silent)';
          }
        }
        
        components.add(componentData);
      }
    }
    
    return components;
  }
  
  /// Build character data from new backend analysis structure
  Map<String, dynamic> _buildCharacterFromNewBackendAnalysis(Map<String, dynamic> charData) {
    final character = charData['character'] as String? ?? '';
    var type = charData['type'] as String? ?? 'Unknown';
    final romanization = charData['romanization'] as String? ?? '';
    final complexVowelMember = charData['complex_vowel_member'] as bool? ?? false;
    
    // Fix backend "Unknown" types by checking against JSON data
    if (type == 'Unknown' && character.isNotEmpty) {
      final actualType = _getCharacterType(character);
      if (actualType == 'other_mark') {
        type = 'Other Mark';
      } else if (actualType == 'tone') {
        type = 'Tone Mark';
      } else if (actualType == 'consonant') {
        type = 'Consonant';
      } else if (actualType == 'vowel') {
        type = 'Vowel';
      }
    }
    
    // Determine if it's silent based on romanization or type
    final isSilent = romanization.contains('(silent)') || type == 'Other Mark';
    final isComplexVowel = complexVowelMember;
    
    // Clean romanization for display
    String displayRomanization = romanization;
    if (displayRomanization.isEmpty && type == 'Tone Mark') {
      // Get tone mark name from JSON for display
      final toneInfo = _getToneMarkInfoFromJSON(character);
      displayRomanization = toneInfo['name'] as String? ?? 'Tone Mark';
    } else if (displayRomanization.isEmpty && type == 'Other Mark') {
      // For sound breakdown, just show "Silent" for other marks
      displayRomanization = 'Silent';
    }
    
    // Color coding and type tag mapping
    Color tagColor;
    String typeTag;
    
    if (isComplexVowel) {
      tagColor = const Color(0xFFE74C3C); // Red for complex vowels
      typeTag = 'CV'; // Abbreviation for complex vowel
    } else {
      switch (type) {
        case 'Consonant':
          tagColor = const Color(0xFF4ECCA3);
          typeTag = 'C';
          break;
        case 'Vowel':
          tagColor = const Color(0xFF3498DB);
          typeTag = 'V';
          break;
        case 'Tone Mark':
          tagColor = const Color(0xFFF39C12);
          typeTag = 'T';
          break;
        case 'Other Mark':
          tagColor = const Color(0xFF9B59B6);
          typeTag = 'O';
          break;
        default:
          tagColor = const Color(0xFF95A5A6);
          typeTag = 'U'; // Unknown
      }
    }
    
    return {
      'character': character,
      'romanization': displayRomanization,
      'typeTag': typeTag,
      'fullTypeLabel': type,
      'tagColor': tagColor,
      'isSilent': isSilent,
      'isComplexVowel': isComplexVowel,
      'patternName': charData['complex_vowel_pattern'] as String?,
      'readingExplanation': null, // Not provided in new backend structure
    };
  }
  
  /// Build character analysis from backend data
  Map<String, dynamic> _buildCharacterFromBackendAnalysis(
    String char, 
    Map<String, dynamic> charAnalysis, 
    List complexVowels
  ) {
    final characterDetails = _getDetailedCharacterInfo(char);
    String romanization = '';
    String typeTag = '';
    String fullTypeLabel = '';
    Color tagColor = const Color(0xFF4ECDC4);
    bool isComplexVowel = false;
    bool isSilent = false;
    String? patternName;
    String? readingExplanation;
    
    // Check if this character is part of a complex vowel (same as writing tips logic)
    final complexVowelMember = charAnalysis['complex_vowel_member'];
    
    if (complexVowelMember != null) {
      // ALL characters in complex vowel patterns are tagged as "Complex Vowel"
      isComplexVowel = true;
      typeTag = 'CV';
      fullTypeLabel = 'Complex Vowel';
      tagColor = const Color(0xFFF39C12); // Orange for complex vowels
      
      final complexVowelData = complexVowelMember as Map<String, dynamic>;
      patternName = complexVowelData['pattern'] as String?;
      final role = complexVowelData['role'] as String? ?? '';
      
      // Find the matching complex vowel pattern for additional info
      for (final vowelPattern in complexVowels) {
        final pattern = vowelPattern as Map<String, dynamic>;
        if (pattern['pattern'] == patternName) {
          readingExplanation = pattern['reading_explanation'] as String?;
          
          // Determine if this is the sound carrier or silent component
          final components = pattern['components'] as List? ?? [];
          final romanizationSound = pattern['romanization'] as String? ?? '';
          
          if (role == 'consonant') {
            // This is the consonant that carries the complex vowel sound
            final originalSound = characterDetails != null ? _getStandardizedRomanization(characterDetails, 'consonant') : char;
            romanization = '$romanizationSound($originalSound)';
            isSilent = false;
          } else {
            // This is a vowel component (เ, ื, etc.)
            final originalSound = characterDetails != null ? _getStandardizedRomanization(characterDetails, 'vowel') : char;
            romanization = '$originalSound(silent)';
            isSilent = true;
          }
          break;
        }
      }
    } else {
      // Regular character processing (same as original logic)
      final type = charAnalysis['type'] as String? ?? _getCharacterTypeFromJson(char);
      romanization = characterDetails != null ? _getStandardizedRomanization(characterDetails, type) : char;
      
      if (type == 'consonant') {
        typeTag = 'C';
        fullTypeLabel = 'Consonant';
        tagColor = const Color(0xFF4ECDC4);
      } else if (type == 'vowel') {
        typeTag = 'V'; 
        fullTypeLabel = 'Vowel';
        tagColor = const Color(0xFF9B59B6);
      } else if (type == 'tone_mark' || type == 'tone') {
        typeTag = 'T';
        fullTypeLabel = 'Tone Mark';
        tagColor = const Color(0xFF3498DB);
      }
    }
    
    return {
      'character': char,
      'romanization': romanization,
      'typeTag': typeTag,
      'fullTypeLabel': fullTypeLabel,
      'tagColor': tagColor,
      'isComplexVowel': isComplexVowel,
      'isSilent': isSilent,
      'patternName': patternName,
      'readingExplanation': readingExplanation,
    };
  }
  
  /// Fallback analysis using thai_writing_guide.json  
  List<Map<String, dynamic>> _analyzeFromThaiGuideJson(String syllable) {
    final List<Map<String, dynamic>> components = [];
    
    // Detect complex vowel patterns from JSON (fallback approach)
    final complexVowelPatterns = _detectComplexVowelPatternsFromJson(syllable);
    
    // Process each character
    for (int i = 0; i < syllable.length; i++) {
      final char = syllable[i];
      final characterDetails = _getDetailedCharacterInfo(char);
      
      if (characterDetails != null) {
        final type = characterDetails['type'] as String? ?? '';
        final complexVowelInfo = complexVowelPatterns[char];
        
        if (complexVowelInfo != null) {
          // This character is part of a complex vowel - tag as Complex Vowel
          final isCarrier = complexVowelInfo['silent'] == false;
          final complexSound = complexVowelInfo['sound'] as String? ?? '';
          final originalSound = _getStandardizedRomanization(characterDetails, type);
          
          String romanization;
          if (isCarrier) {
            romanization = '$complexSound($originalSound)';
          } else {
            romanization = '$originalSound(silent)';
          }
          
          components.add({
            'character': char,
            'romanization': romanization,
            'typeTag': 'CV',
            'fullTypeLabel': 'Complex Vowel',
            'tagColor': const Color(0xFFF39C12),
            'isComplexVowel': true,
            'isSilent': !isCarrier,
            'patternName': complexVowelInfo['pattern'],
            'readingExplanation': complexVowelInfo['explanation'],
          });
        } else {
          // Regular character
          components.add(_buildRegularCharacterAnalysis(char, characterDetails));
        }
      } else {
        // Fallback for unknown characters
        components.add(_buildFallbackCharacterAnalysis(char));
      }
    }
    
    return components;
  }
  
  /// Build regular character analysis (non-complex vowel)
  Map<String, dynamic> _buildRegularCharacterAnalysis(String char, Map<String, dynamic> characterDetails) {
    final type = characterDetails['type'] as String? ?? '';
    final romanization = _getStandardizedRomanization(characterDetails, type);
    
    String typeTag;
    String fullTypeLabel;
    Color tagColor;
    
    if (type == 'consonant') {
      typeTag = 'C';
      fullTypeLabel = 'Consonant';
      tagColor = const Color(0xFF4ECDC4);
    } else if (type == 'vowel') {
      typeTag = 'V'; 
      fullTypeLabel = 'Vowel';
      tagColor = const Color(0xFF9B59B6);
    } else if (type == 'tone_mark' || type == 'tone') {
      typeTag = 'T';
      fullTypeLabel = 'Tone Mark';
      tagColor = const Color(0xFF3498DB);
    } else {
      typeTag = '?';
      fullTypeLabel = 'Unknown';
      tagColor = const Color(0xFF95A5A6);
    }
    
    return {
      'character': char,
      'romanization': romanization,
      'typeTag': typeTag,
      'fullTypeLabel': fullTypeLabel,
      'tagColor': tagColor,
      'isComplexVowel': false,
      'isSilent': false,
      'patternName': null,
      'readingExplanation': null,
    };
  }
  
  /// Build fallback character analysis
  Map<String, dynamic> _buildFallbackCharacterAnalysis(String char) {
    final type = _getCharacterType(char);
    
    String typeTag;
    String fullTypeLabel;
    Color tagColor;
    
    switch (type) {
      case 'consonant':
        typeTag = 'C';
        fullTypeLabel = 'Consonant';
        tagColor = const Color(0xFF4ECDC4);
        break;
      case 'vowel':
        typeTag = 'V';
        fullTypeLabel = 'Vowel';
        tagColor = const Color(0xFF9B59B6);
        break;
      case 'tone_mark':
        typeTag = 'T';
        fullTypeLabel = 'Tone Mark';
        tagColor = const Color(0xFF3498DB);
        break;
      case 'other_mark':
        typeTag = 'O';
        fullTypeLabel = 'Other Mark';
        tagColor = const Color(0xFF9B59B6);
        break;
      default:
        typeTag = '?';
        fullTypeLabel = 'Unknown';
        tagColor = const Color(0xFF95A5A6);
    }
    
    return {
      'character': char,
      'romanization': char,
      'typeTag': typeTag,
      'fullTypeLabel': fullTypeLabel,
      'tagColor': tagColor,
      'isComplexVowel': false,
      'isSilent': false,
      'patternName': null,
      'readingExplanation': null,
    };
  }
  
  /// Detect complex vowel patterns from thai_writing_guide.json (fallback)
  Map<String, Map<String, dynamic>> _detectComplexVowelPatternsFromJson(String syllable) {
    final Map<String, Map<String, dynamic>> result = {};
    
    // Use the existing method as fallback
    if (_thaiWritingGuideData != null) {
      final vowels = _thaiWritingGuideData!['vowels'] as Map<String, dynamic>?;
      if (vowels != null) {
        // Check for เ◌ือ pattern specifically
        if (syllable.contains('เ') && syllable.contains('ื') && syllable.contains('อ')) {
          final pattern = vowels['เ◌ือ'] as Map<String, dynamic>?;
          if (pattern != null) {
            final pronunciation = pattern['pronunciation'] as Map<String, dynamic>?;
            final romanization = pronunciation?['romanization'] as String? ?? 'uea';
            
            // Mark all components as part of complex vowel
            result['เ'] = {
              'pattern': 'เ◌ือ',
              'sound': romanization,
              'silent': true,
              'explanation': 'Silent component of Sara Uea pattern'
            };
            result['ื'] = {
              'pattern': 'เ◌ือ', 
              'sound': romanization,
              'silent': true,
              'explanation': 'Silent component of Sara Uea pattern'
            };
            result['อ'] = {
              'pattern': 'เ◌ือ',
              'sound': romanization,
              'silent': false,
              'explanation': 'Sound carrier of Sara Uea pattern'
            };
          }
        }
      }
    }
    
    return result;
  }
  
  /// Get character type from JSON fallback
  String _getCharacterTypeFromJson(String char) {
    if (_thaiWritingGuideData != null) {
      final consonants = _thaiWritingGuideData!['consonants'] as Map<String, dynamic>?;
      final vowels = _thaiWritingGuideData!['vowels'] as Map<String, dynamic>?;
      final toneMarks = _thaiWritingGuideData!['tone_marks'] as Map<String, dynamic>?;
      final otherMarks = _thaiWritingGuideData!['other_marks'] as Map<String, dynamic>?;
      
      if (consonants?.containsKey(char) == true) return 'consonant';
      if (vowels?.values.any((v) => (v as Map<String, dynamic>)['name']?.toString().contains(char) == true) == true) return 'vowel';
      if (toneMarks?.containsKey(char) == true) return 'tone_mark';
      if (otherMarks?.containsKey(char) == true) return 'other_mark';
    }
    
    return _getCharacterType(char); // Ultimate fallback
  }


  /// Fetch detailed syllable analysis from backend
  Future<void> _fetchSyllableAnalysis(String syllable) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/generate-writing-guide'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'word': syllable,
          'target_language': 'th',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        // Cache the analysis data
        _wordAnalysisCache[syllable] = data;
        
        // Trigger a rebuild to show the updated analysis
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print('Error fetching syllable analysis: $e');
    }
  }

  /// Extract components with positions using writing tips logic
  List<Map<String, dynamic>> _extractSyllableComponentsWithPositions(String syllable, Map<String, dynamic> componentsData) {
    final List<Map<String, dynamic>> result = [];
    
    // First, detect complex vowel patterns to get metadata
    final complexVowelPattern = _detectComplexVowelPattern(syllable, componentsData);
    
    // Use the exact same logic as writing tips
    final componentsWithPosition = <Map<String, dynamic>>[];
    
    // Process components in Thai writing order (same as _extractComponentsWithPositions)
    // 1. Leading vowels (written before consonant)
    final vowels = componentsData['vowels'] as List? ?? [];
    for (final vowel in vowels) {
      if (vowel is Map<String, dynamic>) {
        final vowelMap = vowel;
        if (vowelMap['position'] == 'before') {
          componentsWithPosition.add({
            'character': vowelMap['character'] ?? '',
            'type': 'vowel',
            'position': componentsWithPosition.length,
            'details': vowelMap,
          });
        }
      }
    }
    
    // 2. Initial consonants
    final initialConsonants = componentsData['initial_consonants'] as List? ?? [];
    for (final consonant in initialConsonants) {
      if (consonant is Map<String, dynamic>) {
        final consMap = consonant;
        componentsWithPosition.add({
          'character': consMap['character'] ?? '',
          'type': 'consonant',
          'position': componentsWithPosition.length,
          'details': consMap,
        });
      } else {
        // Handle string components by splitting them
        final chars = consonant.toString().characters.toList();
        for (final char in chars) {
          componentsWithPosition.add({
            'character': char,
            'type': 'consonant',
            'position': componentsWithPosition.length,
            'details': {'character': char},
          });
        }
      }
    }
    
    // 3. Above/below vowels (written after consonant)
    for (final vowel in vowels) {
      if (vowel is Map<String, dynamic>) {
        final vowelMap = vowel;
        if (vowelMap['position'] == 'above' || vowelMap['position'] == 'below') {
          componentsWithPosition.add({
            'character': vowelMap['character'] ?? '',
            'type': 'vowel',
            'position': componentsWithPosition.length,
            'details': vowelMap,
          });
        }
      }
    }
    
    // 4. Following vowels (written after consonant)
    for (final vowel in vowels) {
      if (vowel is Map<String, dynamic>) {
        final vowelMap = vowel;
        if (vowelMap['position'] == 'after') {
          componentsWithPosition.add({
            'character': vowelMap['character'] ?? '',
            'type': 'vowel',
            'position': componentsWithPosition.length,
            'details': vowelMap,
          });
        }
      }
    }
    
    // 5. Final consonants
    final finalConsonants = componentsData['final_consonants'] as List? ?? [];
    for (final consonant in finalConsonants) {
      if (consonant is Map<String, dynamic>) {
        final consMap = consonant;
        componentsWithPosition.add({
          'character': consMap['character'] ?? '',
          'type': 'consonant',
          'position': componentsWithPosition.length,
          'details': consMap,
        });
      } else {
        // Handle string components by splitting them
        final chars = consonant.toString().characters.toList();
        for (final char in chars) {
          componentsWithPosition.add({
            'character': char,
            'type': 'consonant',
            'position': componentsWithPosition.length,
            'details': {'character': char},
          });
        }
      }
    }
    
    // 6. Tone marks (always last)
    final toneMarks = componentsData['tone_marks'] as List? ?? [];
    for (final tone in toneMarks) {
      if (tone is Map<String, dynamic>) {
        final toneMap = tone;
        componentsWithPosition.add({
          'character': toneMap['character'] ?? '',
          'type': 'tone',
          'position': componentsWithPosition.length,
          'details': toneMap,
        });
      } else {
        // Handle string tone marks
        final chars = tone.toString().characters.toList();
        for (final char in chars) {
          componentsWithPosition.add({
            'character': char,
            'type': 'tone',
            'position': componentsWithPosition.length,
            'details': {'character': char},
          });
        }
      }
    }
    
    // Now convert to sound panel format
    for (final component in componentsWithPosition) {
      final char = component['character'] as String;
      final type = component['type'] as String;
      final details = component['details'] as Map<String, dynamic>?;
      
      // Determine the category for the character analysis
      String category = '';
      if (type == 'consonant') {
        // Check if it's initial or final based on the details
        if (initialConsonants.contains(details)) {
          category = 'initial_consonants';
        } else if (finalConsonants.contains(details)) {
          category = 'final_consonants';
        } else {
          category = 'initial_consonants'; // Default
        }
      } else if (type == 'vowel') {
        final position = details?['position'] as String? ?? '';
        if (position == 'before') {
          category = 'before_vowels';
        } else if (position == 'above') {
          category = 'above_vowels';
        } else if (position == 'below') {
          category = 'below_vowels';
        } else if (position == 'after') {
          category = 'after_vowels';
        }
      } else if (type == 'tone') {
        category = 'tone_marks';
      }
      
      // Analyze the character with complex vowel context
      final analysis = _analyzeComponentCharacterWithComplexVowel(
        char,
        category,
        syllable,
        complexVowelPattern
      );
      result.add(analysis);
    }
    
    return result;
  }

  /// Check if a consonant has a tone mark above it
  bool _consonantHasToneMark(String consonant, String syllable, List toneMarks) {
    if (toneMarks.isEmpty) return false;
    
    // For Thai, tone marks are placed on the first/controlling consonant of a cluster
    // In "เครื่อง", the tone mark ่ should be on ค (the first consonant), not ร
    
    // Find the position of the consonant in the syllable
    final consonantIndex = syllable.indexOf(consonant);
    if (consonantIndex == -1) return false;
    
    // Extract all consonants in order
    final consonants = syllable.replaceAll(RegExp(r'[^ก-ฮ]'), '');
    if (consonants.isEmpty) return false;
    
    // For single consonants, the tone mark is on that consonant
    if (consonants.length == 1) {
      return consonant == consonants;
    }
    
    // For consonant clusters, tone mark is placed on the first/controlling consonant
    // This follows proper Thai linguistic rules where tone marks affect the entire cluster
    if (consonants.length > 1) {
      return consonant == consonants[0]; // First consonant gets the tone mark
    }
    
    return false;
  }

  /// Detect complex vowel patterns in the syllable using backend analysis
  Map<String, dynamic>? _detectComplexVowelPattern(String syllable, Map<String, dynamic> componentsData) {
    // First, try to get complex vowel data from backend analysis
    final fullWord = widget.wordMapping.isNotEmpty 
        ? widget.wordMapping[0]['thai'] as String? ?? ''
        : '';
    
    // Check if we have backend complex vowel analysis cached
    if (_wordAnalysisCache.containsKey(fullWord)) {
      final analysisData = _wordAnalysisCache[fullWord]!;
      
      // If this is a complex vowel analysis response, use it
      if (analysisData.containsKey('complex_vowels_detected')) {
        final complexVowels = analysisData['patterns'] as List?;
        if (complexVowels != null && complexVowels.isNotEmpty) {
          for (final pattern in complexVowels) {
            final patternData = pattern as Map<String, dynamic>;
            final components = patternData['components'] as List?;
            
            // Check if this complex vowel pattern matches our syllable
            if (components != null && _syllableContainsAllComponents(syllable, components)) {
              return {
                'character': patternData['pattern_key'] ?? 'CV',
                'romanization': patternData['romanization'] ?? 'complex',
                'typeTag': '[CV]',
                'tagColor': const Color(0xFFF39C12), // Orange for complex vowels
                'isSilent': false,
                'isComplexVowel': true,
                'components': components,
                'patternName': patternData['name'] ?? 'Complex Vowel',
                'readingExplanation': patternData['reading_explanation'] ?? 'Complex vowel pattern',
              };
            }
          }
        }
      }
    }
    
    // Fallback to manual pattern detection
    final beforeVowels = componentsData['before_vowels'] as List? ?? [];
    final aboveVowels = componentsData['above_vowels'] as List? ?? [];
    final afterVowels = componentsData['after_vowels'] as List? ?? [];
    
    // Check for เ◌ือ pattern (Sara Uea)
    if (beforeVowels.contains('เ') && aboveVowels.contains('ื') && afterVowels.contains('อ')) {
      return {
        'character': 'เ◌ือ',
        'romanization': 'uea',
        'typeTag': '[CV]',
        'tagColor': const Color(0xFFF39C12), // Orange for complex vowels
        'isSilent': false,
        'isComplexVowel': true,
        'components': ['เ', 'ื', 'อ'],
        'patternName': 'Sara Uea',
        'readingExplanation': 'เ is written first but pronounced after consonants. The full vowel เ◌ือ makes "uea" sound.',
      };
    }
    
    // Check for เ◌า pattern (Sara Ao)
    if (beforeVowels.contains('เ') && afterVowels.contains('า')) {
      return {
        'character': 'เ◌า',
        'romanization': 'ao',
        'typeTag': '[CV]',
        'tagColor': const Color(0xFFF39C12), // Orange for complex vowels
        'isSilent': false,
        'isComplexVowel': true,
        'components': ['เ', 'า'],
        'patternName': 'Sara Ao',
        'readingExplanation': 'เ is written first but pronounced after consonants. The full vowel เ◌า makes "ao" sound.',
      };
    }
    
    // Check for เ◌ะ pattern (Sara Eh)
    if (beforeVowels.contains('เ') && afterVowels.contains('ะ')) {
      return {
        'character': 'เ◌ะ',
        'romanization': 'e',
        'typeTag': '[CV]',
        'tagColor': const Color(0xFFF39C12), // Orange for complex vowels
        'isSilent': false,
        'isComplexVowel': true,
        'components': ['เ', 'ะ'],
        'patternName': 'Sara Eh',
        'readingExplanation': 'เ is written first but pronounced after consonants. The full vowel เ◌ะ makes "e" sound.',
      };
    }
    
    // Check for เ◌ีย pattern (Sara Ia)
    if (beforeVowels.contains('เ') && aboveVowels.contains('ี') && afterVowels.contains('ย')) {
      return {
        'character': 'เ◌ีย',
        'romanization': 'ia',
        'typeTag': '[CV]',
        'tagColor': const Color(0xFFF39C12), // Orange for complex vowels
        'isSilent': false,
        'isComplexVowel': true,
        'components': ['เ', 'ี', 'ย'],
        'patternName': 'Sara Ia',
        'readingExplanation': 'เ is written first but pronounced after consonants. The full vowel เ◌ีย makes "ia" sound.',
      };
    }
    
    return null;
  }
  
  /// Check if syllable contains all components of a complex vowel
  bool _syllableContainsAllComponents(String syllable, List<dynamic> components) {
    for (final component in components) {
      if (!syllable.contains(component.toString())) {
        return false;
      }
    }
    return true;
  }

  /// Fetch complex vowel analysis from backend
  Future<void> _fetchComplexVowelAnalysis(String word) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8000/analyze-complex-vowels/'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'word': word,
          'target_language': 'th',
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        // Merge complex vowel data with existing cached data
        if (_wordAnalysisCache.containsKey(word)) {
          _wordAnalysisCache[word]!.addAll(data);
        } else {
          _wordAnalysisCache[word] = data;
        }
      }
    } catch (e) {
      print('Error fetching complex vowel analysis: $e');
    }
  }

  /// Analyze individual component character with complex vowel context
  Map<String, dynamic> _analyzeComponentCharacterWithComplexVowel(
    String char, 
    String category, 
    String syllable, 
    Map<String, dynamic>? complexVowelPattern
  ) {
    final charInfo = _getDetailedCharacterInfo(char);
    
    String romanization = '';
    String typeTag = '';
    String fullTypeLabel = '';
    Color tagColor = const Color(0xFF4ECDC4);
    bool isSilent = false;
    bool isComplexVowel = false;
    
    // Check if this character is part of a complex vowel
    if (complexVowelPattern != null) {
      final components = complexVowelPattern['components'] as List?;
      if (components != null && components.contains(char)) {
        isComplexVowel = true;
        
        // Determine if this character is "silent" (not pronounced in this position)
        if (category == 'before_vowels' || category == 'above_vowels') {
          // Characters like 'เ' and 'ื' are written first but pronounced later
          isSilent = true;
          
          // Get the original sound of this character and add (silent)
          String originalSound = '';
          if (charInfo != null) {
            final sounds = charInfo['sounds'] as Map<String, dynamic>?;
            final pronunciation = charInfo['pronunciation'] as Map<String, dynamic>?;
            originalSound = sounds?['sound'] as String? ?? 
                           pronunciation?['romanization'] as String? ?? 
                           pronunciation?['sound'] as String? ?? '';
          }
          
          // If we have the original sound, show it with (silent)
          if (originalSound.isNotEmpty) {
            romanization = '$originalSound(silent)';
          } else {
            // Fallback for common characters
            switch (char) {
              case 'เ':
                romanization = 'e(silent)';
                break;
              case 'ื':
                romanization = 'ue(silent)';
                break;
              default:
                romanization = '(silent)';
            }
          }
          
          typeTag = 'CV-S';
          fullTypeLabel = 'Complex Vowel (Silent)';
          tagColor = const Color(0xFF95A5A6); // Gray for silent
        } else if (category == 'after_vowels') {
          // This is where the complex vowel sound is actually pronounced
          romanization = complexVowelPattern['romanization'] as String? ?? 'complex';
          typeTag = 'CV';
          fullTypeLabel = 'Complex Vowel';
          tagColor = const Color(0xFFF39C12); // Orange for complex vowels
        }
      }
    }
    
    // If not part of complex vowel, analyze normally
    if (!isComplexVowel) {
      switch (category) {
        case 'initial_consonants':
          typeTag = 'C';
          fullTypeLabel = 'Consonant';
          tagColor = const Color(0xFF4ECDC4); // Teal
          if (charInfo != null) {
            final sounds = charInfo['sounds'] as Map<String, dynamic>?;
            final pronunciation = charInfo['pronunciation'] as Map<String, dynamic>?;
            romanization = sounds?['initial'] as String? ?? 
                          pronunciation?['initial'] as String? ?? 
                          pronunciation?['romanization'] as String? ?? char;
          }
          break;
          
        case 'final_consonants':
          typeTag = 'C';
          fullTypeLabel = 'Consonant';
          tagColor = const Color(0xFF4ECDC4); // Teal
          if (charInfo != null) {
            final sounds = charInfo['sounds'] as Map<String, dynamic>?;
            final pronunciation = charInfo['pronunciation'] as Map<String, dynamic>?;
            romanization = sounds?['final'] as String? ?? 
                          pronunciation?['final'] as String? ?? 
                          pronunciation?['romanization'] as String? ?? char;
          }
          break;
          
        case 'before_vowels':
        case 'above_vowels':
        case 'below_vowels':
        case 'after_vowels':
          typeTag = 'V';
          fullTypeLabel = 'Vowel';
          tagColor = const Color(0xFF9B59B6); // Purple
          
          // Check if this is a silent vowel (vowel carrier)
          if (char == 'อ' && _isVowelCarrier(char, syllable)) {
            romanization = '(silent)';
            isSilent = true;
            tagColor = const Color(0xFF95A5A6); // Gray
            typeTag = 'S';
            fullTypeLabel = 'Silent Vowel';
          } else {
            // Regular vowel
            if (charInfo != null) {
              final sounds = charInfo['sounds'] as Map<String, dynamic>?;
              final pronunciation = charInfo['pronunciation'] as Map<String, dynamic>?;
              romanization = sounds?['sound'] as String? ?? 
                            pronunciation?['romanization'] as String? ?? 
                            pronunciation?['sound'] as String? ?? char;
            }
          }
          break;
          
        case 'tone_marks':
          typeTag = 'T';
          fullTypeLabel = 'Tone Mark';
          tagColor = const Color(0xFF3498DB); // Blue
          romanization = _getDetailedToneDescription(char);
          break;
          
        default:
          romanization = char;
          typeTag = '?';
          fullTypeLabel = 'Unknown';
      }
    }
    
    return {
      'character': char,
      'romanization': romanization,
      'typeTag': typeTag,
      'fullTypeLabel': fullTypeLabel,
      'tagColor': tagColor,
      'isSilent': isSilent,
      'isComplexVowel': isComplexVowel,
      'complexVowelPattern': complexVowelPattern?['patternName'] as String?,
      'readingExplanation': complexVowelPattern?['readingExplanation'] as String?,
    };
  }

  /// Legacy method for backward compatibility
  Map<String, dynamic> _analyzeComponentCharacter(String char, String category, String syllable) {
    final charInfo = _getDetailedCharacterInfo(char);
    
    String romanization = '';
    String typeTag = '';
    Color tagColor = const Color(0xFF4ECDC4);
    bool isSilent = false;
    bool isComplexVowel = false;
    
    // Determine properties based on category and character info
    switch (category) {
      case 'initial_consonants':
        typeTag = '[C]';
        tagColor = const Color(0xFF4ECDC4); // Teal
        if (charInfo != null) {
          final sounds = charInfo['sounds'] as Map<String, dynamic>?;
          final pronunciation = charInfo['pronunciation'] as Map<String, dynamic>?;
          romanization = sounds?['initial'] as String? ?? 
                        pronunciation?['initial'] as String? ?? 
                        pronunciation?['romanization'] as String? ?? char;
        }
        break;
        
      case 'final_consonants':
        typeTag = '[C]';
        tagColor = const Color(0xFF4ECDC4); // Teal
        if (charInfo != null) {
          final sounds = charInfo['sounds'] as Map<String, dynamic>?;
          final pronunciation = charInfo['pronunciation'] as Map<String, dynamic>?;
          romanization = sounds?['final'] as String? ?? 
                        pronunciation?['final'] as String? ?? 
                        pronunciation?['romanization'] as String? ?? char;
        }
        break;
        
      case 'before_vowels':
      case 'above_vowels':
      case 'below_vowels':
      case 'after_vowels':
        typeTag = '[V]';
        tagColor = const Color(0xFF9B59B6); // Purple
        
        // Check if this is a silent vowel (vowel carrier)
        if (char == 'อ' && _isVowelCarrier(char, syllable)) {
          romanization = '(silent)';
          isSilent = true;
          tagColor = const Color(0xFF95A5A6); // Gray
          typeTag = '[S]';
        } else if (_isPartOfComplexVowelPattern(char, syllable)) {
          // Part of complex vowel
          typeTag = '[CV]';
          tagColor = const Color(0xFFF39C12); // Orange
          isComplexVowel = true;
          romanization = _getComplexVowelSound(char, syllable);
        } else {
          // Regular vowel
          if (charInfo != null) {
            final sounds = charInfo['sounds'] as Map<String, dynamic>?;
            final pronunciation = charInfo['pronunciation'] as Map<String, dynamic>?;
            romanization = sounds?['sound'] as String? ?? 
                          pronunciation?['romanization'] as String? ?? 
                          pronunciation?['sound'] as String? ?? char;
          }
        }
        break;
        
      case 'tone_marks':
        typeTag = '[T]';
        tagColor = const Color(0xFF3498DB); // Blue
        romanization = _getDetailedToneDescription(char);
        break;
        
      default:
        romanization = char;
        typeTag = '[?]';
    }
    
    return {
      'character': char,
      'romanization': romanization,
      'typeTag': typeTag,
      'tagColor': tagColor,
      'isSilent': isSilent,
      'isComplexVowel': isComplexVowel,
    };
  }

  /// Check if character is a vowel carrier (silent อ)
  bool _isVowelCarrier(String char, String syllable) {
    if (char != 'อ') return false;
    
    // อ is silent when used as a vowel carrier in patterns like เอา, เอะ, etc.
    return syllable.contains('เ') || syllable.contains('แ') || syllable.contains('โ');
  }

  /// Check if character is part of a complex vowel pattern
  bool _isPartOfComplexVowelPattern(String char, String syllable) {
    // Common complex vowel patterns
    final complexPatterns = [
      'เ.*า',   // เอา, เขา, etc.
      'เ.*ะ',   // เอะ, เขะ, etc.
      'เ.*อ',   // เอีอ, เขออ, etc.
      'เ.*ีย',  // เอีย, เขีย, etc.
      '.*ัย',   // ไก่, ไข่, etc.
      '.*ัว',   // เขัว, เกัว, etc.
      'แ.*ะ',   // แกะ, แขะ, etc.
      'โ.*ะ',   // โกะ, โขะ, etc.
    ];
    
    for (final pattern in complexPatterns) {
      if (RegExp(pattern).hasMatch(syllable)) {
        return true;
      }
    }
    
    return false;
  }

  /// Get sound for complex vowel component
  String _getComplexVowelSound(String char, String syllable) {
    // Return the sound contribution of this character in the complex vowel
    final charInfo = _getDetailedCharacterInfo(char);
    if (charInfo != null) {
      final sounds = charInfo['sounds'] as Map<String, dynamic>?;
      final pronunciation = charInfo['pronunciation'] as Map<String, dynamic>?;
      return sounds?['sound'] as String? ?? 
             pronunciation?['romanization'] as String? ?? 
             pronunciation?['sound'] as String? ?? char;
    }
    return char;
  }

  /// Fallback character analysis when backend data is not available
  /// Uses the EXACT same logic as writing tips to ensure consistency
  List<Map<String, dynamic>> _fallbackCharacterAnalysis(String syllable) {
    // Use EXACT same logic as backend parse_syllable_components
    final parsedComponents = _parseSyllableComponents(syllable);
    final List<Map<String, dynamic>> components = [];
    
    // Now process each character with the parsed component information
    for (int i = 0; i < syllable.length; i++) {
      final char = syllable[i];
      final characterDetails = _getDetailedCharacterInfo(char);
      
      String romanization = '';
      String typeTag = '';
      String fullTypeLabel = '';
      Color tagColor = const Color(0xFF4ECDC4);
      bool isSilent = false;
      bool isComplexVowel = false;
      String? patternName;
      
      // Determine character role based on parsed components
      String characterRole = _getCharacterRole(char, parsedComponents);
      
      if (characterDetails != null) {
        final type = characterDetails['type'] as String? ?? '';
        
        if (type == 'consonant') {
          typeTag = 'C';
          fullTypeLabel = 'Consonant';
          tagColor = const Color(0xFF4ECDC4);
          
          final sounds = characterDetails['sounds'] as Map<String, dynamic>?;
          final pronunciation = characterDetails['pronunciation'] as Map<String, dynamic>?;
          romanization = sounds?['initial'] as String? ?? 
                        pronunciation?['initial'] as String? ?? 
                        pronunciation?['romanization'] as String? ?? char;
          
          // Check if consonant is silent in cluster
          isSilent = _isConsonantSilentInCluster(char, syllable, parsedComponents);
          if (isSilent) {
            romanization = '$romanization(silent)';
            tagColor = const Color(0xFF95A5A6);
          }
        } else if (type == 'vowel') {
          typeTag = 'V';
          fullTypeLabel = 'Vowel';
          tagColor = const Color(0xFF9B59B6);
          
          final sounds = characterDetails['sounds'] as Map<String, dynamic>?;
          final pronunciation = characterDetails['pronunciation'] as Map<String, dynamic>?;
          romanization = sounds?['sound'] as String? ?? 
                        pronunciation?['romanization'] as String? ?? 
                        pronunciation?['sound'] as String? ?? char;
          
          // Check if vowel is part of complex pattern or silent
          final complexInfo = _getVowelComplexInfo(char, syllable, characterRole);
          if (complexInfo['isComplex'] == true) {
            fullTypeLabel = 'Complex Vowel';
            tagColor = const Color(0xFFF39C12);
            isComplexVowel = true;
            patternName = complexInfo['patternName'];
          }
          
          if (complexInfo['isSilent'] == true) {
            romanization = '$romanization(silent)';
            tagColor = const Color(0xFF95A5A6);
            isSilent = true;
          }
        } else if (type == 'tone_mark' || type == 'tone') {
          typeTag = 'T';
          fullTypeLabel = 'Tone Mark';
          tagColor = const Color(0xFF3498DB);
          romanization = _getDetailedToneDescription(char);
          if (romanization.isEmpty) {
            final pronunciationGuide = characterDetails['pronunciation_guide'] as String? ?? '';
            final name = characterDetails['name'] as String? ?? '';
            romanization = pronunciationGuide.isNotEmpty ? pronunciationGuide : name;
          }
        } else if (type == 'special') {
          typeTag = 'S';
          fullTypeLabel = 'Special';
          tagColor = const Color(0xFF95A5A6);
          romanization = '(special)';
        }
      } else {
        // Basic fallback classification
        final charType = _getCharacterType(char);
        switch (charType) {
          case 'consonant':
            typeTag = 'C';
            fullTypeLabel = 'Consonant';
            tagColor = const Color(0xFF4ECDC4);
            romanization = char;
            isSilent = _isConsonantSilentInCluster(char, syllable, parsedComponents);
            if (isSilent) {
              romanization = '$romanization(silent)';
              tagColor = const Color(0xFF95A5A6);
            }
            break;
          case 'vowel':
            typeTag = 'V';
            fullTypeLabel = 'Vowel';
            tagColor = const Color(0xFF9B59B6);
            romanization = char;
            break;
          case 'tone_mark':
            typeTag = 'T';
            fullTypeLabel = 'Tone Mark';
            tagColor = const Color(0xFF3498DB);
            romanization = _getToneMarkName(char);
            if (romanization.isEmpty) {
              romanization = _getDetailedToneDescription(char);
            }
            break;
          default:
            romanization = char;
            typeTag = '?';
            fullTypeLabel = 'Unknown';
        }
      }
      
      components.add({
        'character': char,
        'romanization': romanization,
        'typeTag': typeTag,
        'fullTypeLabel': fullTypeLabel,
        'tagColor': tagColor,
        'isSilent': isSilent,
        'isComplexVowel': isComplexVowel,
        'patternName': patternName,
        'readingExplanation': null,
      });
    }
    
    return components;
  }

  /// Parse syllable components using EXACT backend logic
  Map<String, List<String>> _parseSyllableComponents(String syllable) {
    // EXACT same logic as backend parse_syllable_components
    final beforeVowels = ["เ", "แ", "โ", "ใ", "ไ"];
    final aboveVowels = ["◌ิ", "◌ี", "◌ึ", "◌ื", "◌ั", "◌ํ", "ิ", "ี", "ึ", "ื", "ั", "ํ"];
    final belowVowels = ["◌ุ", "◌ู", "◌ฺ", "ุ", "ู", "ฺ"];
    final afterVowels = ["◌ะ", "◌า", "◌ำ", "◌ๅ", "ะ", "า", "ำ", "ๅ", "อ", "ย", "ว"];
    final toneMarks = ["◌่", "◌้", "◌๊", "◌๋", "่", "้", "๊", "๋"];
    final consonants = "กขฃคฅฆงจฉชซฌญฎฏฐฑฒณดตถทธนบปผฝพฟภมยรลวศษสหฬอฮ";
    final consonantClusters = ["กร", "กล", "คร", "คล", "ปร", "ปล", "ทร", "ผล", "พร", "พล", "สร", "หร", "หล", "หม", "หน", "หย", "หว"];
    
    final components = <String, List<String>>{
      "before_vowels": [],
      "initial_consonants": [],
      "consonant_clusters": [],
      "above_vowels": [],
      "below_vowels": [],
      "after_vowels": [],
      "final_consonants": [],
      "tone_marks": []
    };
    
    int i = 0;
    while (i < syllable.length) {
      final char = syllable[i];
      
      // Check for consonant clusters first (2-character sequences)
      if (i < syllable.length - 1) {
        final cluster = syllable.substring(i, i + 2);
        if (consonantClusters.contains(cluster)) {
          components["consonant_clusters"]!.add(cluster);
          components["initial_consonants"]!.addAll(cluster.split(''));
          i += 2;
          continue;
        }
      }
      
      // Individual character analysis
      if (beforeVowels.contains(char)) {
        components["before_vowels"]!.add(char);
      } else if (aboveVowels.contains(char)) {
        components["above_vowels"]!.add(char);
      } else if (belowVowels.contains(char)) {
        components["below_vowels"]!.add(char);
      } else if (afterVowels.contains(char)) {
        components["after_vowels"]!.add(char);
      } else if (toneMarks.contains(char)) {
        components["tone_marks"]!.add(char);
      } else if (consonants.contains(char)) {
        // Determine if initial or final consonant based on position
        final remainingChars = syllable.substring(i + 1);
        
        // If there are more consonants or vowels after this, it's likely initial
        final hasVowelsAfter = remainingChars.split('').any((c) => 
          aboveVowels.contains(c) || belowVowels.contains(c) || afterVowels.contains(c));
        final hasConsonantsAfter = remainingChars.split('').any((c) => consonants.contains(c));
        
        if (hasVowelsAfter || hasConsonantsAfter) {
          components["initial_consonants"]!.add(char);
        } else {
          components["final_consonants"]!.add(char);
        }
      }
      
      i += 1;
    }
    
    return components;
  }
  
  /// Get character role based on parsed components
  String _getCharacterRole(String char, Map<String, List<String>> components) {
    for (final entry in components.entries) {
      if (entry.value.contains(char)) {
        return entry.key;
      }
    }
    return 'unknown';
  }
  
  /// Check if consonant is silent in cluster based on thai_writing_guide.json rules
  bool _isConsonantSilentInCluster(String char, String syllable, Map<String, List<String>> components) {
    final clusters = components["consonant_clusters"] ?? [];
    
    // Silent consonant rules from thai_writing_guide.json
    final silentRules = {
      'กร': 'ร',
      'กล': 'ล',
      'คร': 'ร',
      'คล': 'ล',
      'ปร': 'ร',
      'ปล': 'ล',
      'พร': 'ร',
      'สร': 'ร',
      'หร': 'ห',
      'หล': 'ห',
      'หม': 'ห',
      'หน': 'ห',
      'หย': 'ห',
      'หว': 'ห',
    };
    
    for (final cluster in clusters) {
      if (silentRules.containsKey(cluster) && silentRules[cluster] == char) {
        return true;
      }
    }
    
    return false;
  }
  
  /// Get vowel complex pattern info
  Map<String, dynamic> _getVowelComplexInfo(String char, String syllable, String characterRole) {
    // Complex vowel patterns from thai_writing_guide.json surrounding patterns
    final complexPatterns = {
      'เ_า': ['เ', 'า'],
      'เ_ะ': ['เ', 'ะ'],
      'แ_ะ': ['แ', 'ะ'],
      'โ_ะ': ['โ', 'ะ'],
      'เ_อ': ['เ', 'อ'],
      'เ_ือ': ['เ', 'ื', 'อ'],
      '_ัย': ['ั', 'ย'],
      '_ัว': ['ั', 'ว'],
    };
    
    final result = <String, dynamic>{
      'isComplex': false,
      'isSilent': false,
      'patternName': null,
    };
    
    // Check if character is part of any complex pattern
    for (final pattern in complexPatterns.entries) {
      final components = pattern.value;
      if (components.contains(char)) {
        // Check if all components of the pattern exist in syllable
        final allComponentsPresent = components.every((c) => syllable.contains(c));
        if (allComponentsPresent) {
          result['isComplex'] = true;
          result['patternName'] = pattern.key;
          
          // For surrounding patterns, some characters may be silent
          // This would need more sophisticated logic based on actual usage
          break;
        }
      }
    }
    
    return result;
  }

  /// Simple detection of complex vowel patterns based on thai_writing_guide.json
  Map<String, String> _detectComplexVowelPatternsSimple(String syllable) {
    final Map<String, String> result = {};
    
    // Complex vowel patterns from thai_writing_guide.json
    final patterns = {
      // Surrounding vowels
      'เ_า': 'sara ao',
      'เ_ะ': 'sara e',
      'แ_ะ': 'sara ae',
      'โ_ะ': 'sara o',
      'เ_อ': 'sara oe',
      'เ_อะ': 'sara oe short',
      'เ_ีย': 'sara ia',
      'เ_ือ': 'sara uea',
      '_ัย': 'sara ai',
      '_ัว': 'sara ua',
    };
    
    // Check each pattern
    for (final pattern in patterns.entries) {
      final patternKey = pattern.key;
      final patternName = pattern.value;
      
      // Simple pattern matching
      if (patternKey.contains('เ_า') && syllable.contains('เ') && syllable.contains('า')) {
        final eIndex = syllable.indexOf('เ');
        final aaIndex = syllable.indexOf('า');
        if (eIndex < aaIndex && aaIndex - eIndex > 1) {
          result['เ'] = patternName;
          result['า'] = patternName;
        }
      } else if (patternKey.contains('เ_ือ') && syllable.contains('เ') && syllable.contains('ื') && syllable.contains('อ')) {
        final eIndex = syllable.indexOf('เ');
        final ueIndex = syllable.indexOf('ื');
        final oIndex = syllable.indexOf('อ');
        if (eIndex < ueIndex && ueIndex < oIndex) {
          result['เ'] = patternName;
          result['ื'] = patternName;
          result['อ'] = patternName;
        }
      }
      // Add more patterns as needed
    }
    
    return result;
  }
  
  /// Detect silent characters based on consonant clusters
  Set<String> _detectSilentCharacters(String syllable) {
    final Set<String> silentChars = {};
    
    // Silent consonant clusters from thai_writing_guide.json
    final silentClusters = {
      'กร': ['ร'],
      'กล': ['ล'],
      'คร': ['ร'],
      'คล': ['ล'],
      'ปร': ['ร'],
      'ปล': ['ล'],
      'พร': ['ร'],
      'สร': ['ร'],
      'หร': ['ห'],
      'หล': ['ห'],
      'หม': ['ห'],
      'หน': ['ห'],
      'หย': ['ห'],
      'หว': ['ห'],
    };
    
    // Check for silent clusters
    for (final cluster in silentClusters.entries) {
      if (syllable.contains(cluster.key)) {
        for (final silentChar in cluster.value) {
          if (syllable.contains(silentChar)) {
            silentChars.add(silentChar);
          }
        }
      }
    }
    
    return silentChars;
  }

  /// Detect complex vowel patterns in syllable for sound breakdown
  Map<String, Map<String, dynamic>> _detectComplexVowelPatterns(String syllable) {
    final Map<String, Map<String, dynamic>> result = {};
    
    
    // Common Thai complex vowel patterns
    final patterns = [
      // เ_ื_อ pattern (like in เครื่อง)
      {
        'regex': RegExp(r'เ(.+)ื(.*)อ'),
        'name': 'sara uea pattern',
        'sound': 'uea', 
        'silentChars': ['เ', 'ื'],
        'soundingChars': [],
        'consonantCarriesSound': true // The consonant in between carries the full sound
      },
      // เ_า pattern
      {
        'regex': RegExp(r'เ(.*)า'),
        'name': 'sara ao pattern', 
        'sound': 'ao',
        'silentChars': ['เ'],
        'soundingChars': ['า']
      },
      // เ_ะ pattern
      {
        'regex': RegExp(r'เ(.*)ะ'),
        'name': 'sara e pattern',
        'sound': 'e',
        'silentChars': ['เ'],
        'soundingChars': ['ะ']
      },
      // แ_ะ pattern
      {
        'regex': RegExp(r'แ(.*)ะ'),
        'name': 'sara ae pattern',
        'sound': 'ae', 
        'silentChars': ['แ'],
        'soundingChars': ['ะ']
      },
      // โ_ะ pattern
      {
        'regex': RegExp(r'โ(.*)ะ'),
        'name': 'sara o pattern',
        'sound': 'o',
        'silentChars': ['โ'],
        'soundingChars': ['ะ']
      }
    ];
    
    for (final pattern in patterns) {
      final regex = pattern['regex'] as RegExp;
      final match = regex.firstMatch(syllable);
      
      if (match != null) {
        final patternName = pattern['name'] as String;
        final sound = pattern['sound'] as String;
        final silentChars = (pattern['silentChars'] as List).cast<String>();
        final soundingChars = (pattern['soundingChars'] as List).cast<String>();
        
        
        // Mark silent characters
        for (final char in silentChars) {
          if (syllable.contains(char)) {
            result[char] = {
              'pattern': patternName,
              'sound': sound,
              'silent': true,
              'explanation': 'Silent component of $patternName'
            };
          }
        }
        
        // Mark sounding characters
        for (final char in soundingChars) {
          if (syllable.contains(char)) {
            result[char] = {
              'pattern': patternName,
              'sound': sound,
              'silent': false,
              'explanation': 'Sound component of $patternName'
            };
          }
        }
        
        // For patterns where consonant carries the sound
        if (pattern['consonantCarriesSound'] == true && patternName == 'sara uea pattern') {
          // For เ_ื_อ pattern (sara uea), mark the อ as the carrier
          // The pattern already matched เ(.+)ื(.*)อ so we know อ is present
          result['อ'] = {
            'pattern': patternName,
            'sound': sound,
            'silent': false,
            'explanation': 'Consonant carrier of $patternName'
          };
        }
        
        break; // Use first matching pattern
      }
    }
    
    return result;
  }

  /// Get the original sound of a character (for silent complex vowels)
  String _getOriginalCharacterSound(String char) {
    final charInfo = _getDetailedCharacterInfo(char);
    if (charInfo != null) {
      // For vowels, get the romanization or sound
      if (charInfo['type'] == 'vowel') {
        final sounds = charInfo['sounds'] as Map<String, dynamic>?;
        final pronunciation = charInfo['pronunciation'] as Map<String, dynamic>?;
        return sounds?['sound'] as String? ?? 
               pronunciation?['romanization'] as String? ?? 
               pronunciation?['sound'] as String? ?? char;
      }
    }
    
    // Fallback mappings for common silent vowels
    switch (char) {
      case 'เ':
        return 'e';
      case 'แ':
        return 'ae';
      case 'โ':
        return 'o';
      case 'ใ':
        return 'ai';
      case 'ไ':
        return 'ai';
      default:
        return char;
    }
  }

  /// Build a single sound card for the breakdown strip
  Widget _buildSingleSoundCard({
    required String character,
    required String romanization,
    required String typeTag,
    required String fullTypeLabel,
    required Color tagColor,
    required bool isHighlighted,
    required bool isSilent,
    required bool isComplexVowel,
    String? patternName,
    String? readingExplanation,
  }) {
    // Determine background color based on character type
    Color backgroundColor = const Color(0xFF2D2D2D);
    if (!isHighlighted) {
      if (typeTag == 'CV' || isComplexVowel) {
        backgroundColor = const Color(0xFFF39C12).withValues(alpha: 0.3); // Orange for complex vowels - more visible
      } else if (typeTag == 'C' && !isSilent) {
        backgroundColor = const Color(0xFF4ECDC4).withValues(alpha: 0.15); // Teal for consonants
      } else if (typeTag == 'V') {
        backgroundColor = const Color(0xFF9B59B6).withValues(alpha: 0.15); // Purple for vowels
      } else if (typeTag == 'T') {
        backgroundColor = const Color(0xFF3498DB).withValues(alpha: 0.15); // Blue for tone marks
      } else if (isSilent || typeTag == 'S' || typeTag == 'CV-S') {
        backgroundColor = const Color(0xFF95A5A6).withValues(alpha: 0.10); // Gray for silent
      }
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 85, // Reduced width to prevent overflow
      height: 95, // Reduced height to prevent overflow
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6), // Reduced padding
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSilent
              ? const Color(0xFF95A5A6).withValues(alpha: 0.3)
              : tagColor.withValues(alpha: 0.3),
          width: 1,
        ),
        gradient: isComplexVowel && typeTag == 'CV'
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFFF39C12).withValues(alpha: 0.4),
                  const Color(0xFFF39C12).withValues(alpha: 0.2),
                ],
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Thai character - optimized size
          Text(
            character,
            style: TextStyle(
              fontSize: 28, // Increased for better readability
              fontWeight: FontWeight.w600,
              color: (isSilent && !isComplexVowel) 
                  ? const Color(0xFF95A5A6)
                  : Colors.white,
              decoration: (isSilent && !isComplexVowel) ? TextDecoration.lineThrough : null,
              decorationColor: const Color(0xFF95A5A6),
              decorationThickness: 2,
            ),
          ),
          const SizedBox(height: 2),
          
          // Romanization - optimized size
          Text(
            romanization,
            style: TextStyle(
              fontSize: 12, // Increased for better readability
              color: (isSilent && !isComplexVowel)
                  ? const Color(0xFF95A5A6)
                  : const Color(0xFF4ECCA3), // More prominent color
              fontWeight: FontWeight.w600, // Bold for better visibility
            ),
            textAlign: TextAlign.center,
            maxLines: 2, // Allow wrapping for longer descriptions
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          
          // Full type label - educational and clear, removing "(Silent)" redundancy
          Text(
            isSilent && fullTypeLabel.contains('(Silent)') 
                ? fullTypeLabel.replaceAll('(Silent)', '').trim()
                : fullTypeLabel,
            style: TextStyle(
              fontSize: 8, // Reduced to prevent overflow
              color: (isSilent && !isComplexVowel)
                  ? const Color(0xFF95A5A6)
                  : tagColor, // Use the same color as the tag
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2, // Allow wrapping for longer labels
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Check if a consonant is silent in a cluster
  bool _isSilentInCluster(String consonant, String previousChar) {
    // Common Thai consonant clusters where the second consonant is silent
    final silentClusters = {
      'กร': true, 'คร': true, 'ขร': true,
      'กล': true, 'คล': true, 'ขล': true,
      'กว': true, 'คว': true, 'ขว': true,
      'ปร': true, 'พร': true, 'ผร': true,
      'ปล': true, 'พล': true, 'ผล': true,
      'ตร': true, 'ทร': true,
    };
    
    final cluster = previousChar + consonant;
    return silentClusters.containsKey(cluster);
  }

  /// Check if a character is part of a complex vowel
  bool _isPartOfComplexVowel(String char, int index, List<String> allChars) {
    // Complex vowel patterns in Thai
    final complexVowelParts = ['ุ', 'ู', 'ิ', 'ี', 'ึ', 'ื', '็', '้', '่', '๊', '๋'];
    
    // Check if current char is a vowel that can combine with tone marks
    if (complexVowelParts.contains(char)) {
      // Check if next character is a tone mark
      if (index < allChars.length - 1) {
        final nextChar = allChars[index + 1];
        if (['่', '้', '๊', '๋'].contains(nextChar)) {
          return true;
        }
      }
    }
    
    return false;
  }

  /// Get tone description for display
  String _getToneDescription(String toneChar) {
    final toneDescriptions = {
      '่': 'low',
      '้': 'falling',
      '๊': 'high',
      '๋': 'rising',
      '์': 'silent',
    };
    
    return toneDescriptions[toneChar] ?? 'tone';
  }
  
  /// Get detailed tone description for sound breakdown
  String _getDetailedToneDescription(String toneChar) {
    final toneDescriptions = {
      '่': 'falling tone',
      '้': 'falling tone',
      '๊': 'high tone',
      '๋': 'rising tone',
      '์': 'silent',
    };
    
    return toneDescriptions[toneChar] ?? 'tone';
  }

  /// Build current character tip (focused on just one character)
  Widget _buildCurrentCharacterTip(String semanticWord) {
    if (semanticWord.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: const Text(
          'No character selected',
          style: TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    // Get the first character of the semantic word for now
    // Later we can add character navigation within words
    final char = semanticWord.characters.first;
    final charInfo = _getDetailedCharacterInfo(char);
    
    if (charInfo == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        child: Text(
          'Writing tips for: $char',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      child: _buildSingleCharacterCard(charInfo),
    );
  }
  
  /// Build a single character card (more compact than the multi-character version)
  Widget _buildSingleCharacterCard(Map<String, dynamic> charInfo) {
    final character = charInfo['character'] ?? '';
    final type = charInfo['type'] ?? 'character';
    final romanization = charInfo['romanization'] ?? '';
    final mainTip = charInfo['main_tip'] ?? '';
    final englishGuide = charInfo['english_guide'] ?? '';
    final consonantClass = charInfo['consonant_class'];
    final position = charInfo['position'];
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Character with type badge
        Column(
          children: [
            Text(
              character,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            _buildCharacterTypeBadge(type, consonantClass, position),
          ],
        ),
        
        const SizedBox(width: 12),
        
        // Tips content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Romanization
              if (romanization.isNotEmpty) ...[
                Text(
                  '($romanization)',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF4ECCA3).withValues(alpha: 0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              
              // Writing instruction
              if (mainTip.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.edit,
                      size: 12,
                      color: _getTypeColor(type),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        mainTip,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              
              // Pronunciation guide
              if (englishGuide.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.volume_up,
                      size: 12,
                      color: _getTypeColor(type),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        englishGuide,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.8),
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
  /// Build character navigation bar
  Widget _buildCharacterNavigationBar() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: const Color(0xFF4ECCA3).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Previous button (with wraparound)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF4ECCA3).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: _goToPreviousCharacter,
              icon: const Icon(Icons.chevron_left, size: 32),
              color: const Color(0xFF4ECCA3),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            ),
          ),
          
          // Next button (with wraparound)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF4ECCA3).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: IconButton(
              onPressed: _goToNextCharacter,
              icon: const Icon(Icons.chevron_right, size: 32),
              color: const Color(0xFF4ECCA3),
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Navigate to previous character (with wraparound)
  void _goToPreviousCharacter() {
    setState(() {
      _currentCharacterIndex = _currentCharacterIndex > 0 
          ? _currentCharacterIndex - 1 
          : _currentCharacters.length - 1; // Wraparound to last
    });
    // Don't clear canvas - preserve user's work
    _loadWritingTipsFromCache();
  }
  
  /// Navigate to next character (with wraparound)
  void _goToNextCharacter() {
    setState(() {
      _currentCharacterIndex = _currentCharacterIndex < _currentCharacters.length - 1 
          ? _currentCharacterIndex + 1 
          : 0; // Wraparound to first
    });
    // Don't clear canvas - preserve user's work
    _loadWritingTipsFromCache();
  }
  
  /// Show tabbed writing tips modal (General Tips + Step-by-Step)
  void _showWritingTipsModal() {
    // Reset the page index when opening the modal
    _currentStepPage = 0;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 650, maxHeight: 600),
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: DefaultTabController(
                  length: 2,
                  initialIndex: 1, // Start with Step-by-Step tab for immediate context
                  child: Column(
                    children: [
                      // Header with close button
                      Container(
                        padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Writing Tips',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4ECCA3),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.close, color: Colors.white70),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      
                      // Tab bar
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        child: TabBar(
                          indicator: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: const Color(0xFF4ECCA3).withValues(alpha: 0.2),
                          ),
                          labelColor: const Color(0xFF4ECCA3),
                          unselectedLabelColor: Colors.white54,
                          labelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                          tabs: const [
                            Tab(text: 'General Tips'),
                            Tab(text: 'Step-by-Step'),
                          ],
                        ),
                      ),
                      
                      // Tab content
                      Expanded(
                        child: TabBarView(
                          children: [
                            _buildGeneralTipsTab(),
                            _buildStepByStepTab(setModalState),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Build General Tips tab content
  Widget _buildGeneralTipsTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _generalWritingTips.map((tip) => 
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1F1F1F),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF4ECCA3).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Text(
                tip,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  height: 1.4,
                ),
              ),
            )
          ).toList(),
        ),
      ),
    );
  }

  /// Build Step-by-Step tab content for current character
  Widget _buildStepByStepTab([Function? setModalState]) {
    final currentSemanticWord = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
        ? _currentCharacters[_currentCharacterIndex]
        : '';
    
    if (currentSemanticWord.isEmpty) {
      return const Center(
        child: Text(
          'No character selected',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white54,
          ),
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Character header - condensed to single line
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Colors.white70),
                children: [
                  const TextSpan(
                    text: 'How to write: ',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  TextSpan(
                    text: currentSemanticWord,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4ECCA3),
                    ),
                  ),
                  // Add romanization and translation inline
                  if (_constituentWordData.isNotEmpty && _currentCharacterIndex < _constituentWordData.length) ...[
                    TextSpan(
                      text: ' (${_constituentWordData[_currentCharacterIndex]['romanized'] as String? ?? ''} • ${_constituentWordData[_currentCharacterIndex]['translation'] as String? ?? ''})',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white54,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Swipeable step-by-step character cards
          Expanded(
            child: _buildSwipeableStepCards(currentSemanticWord, setModalState),
          ),
        ],
      ),
    );
  }

  /// Build swipeable step-by-step character cards
  Widget _buildSwipeableStepCards(String semanticWord, [Function? setModalState]) {
    final characters = semanticWord.split('');
    
    if (characters.isEmpty) {
      return const Center(
        child: Text(
          'No characters to display',
          style: TextStyle(color: Colors.white54),
        ),
      );
    }
    
    // Reset page controller only when word actually changes
    // Check if this is a different word than before
    if (_lastProcessedSemanticWord != semanticWord) {
      _lastProcessedSemanticWord = semanticWord;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_stepPageController.hasClients) {
          _currentStepPage = 0;
          _stepPageController.animateToPage(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
    
    return Column(
      children: [
        // PageView for swipeable cards
        Expanded(
          child: PageView.builder(
            controller: _stepPageController,
            onPageChanged: (index) {
              _currentStepPage = index;
              if (setModalState != null) {
                setModalState(() {});
              } else {
                setState(() {});
              }
            },
            itemCount: characters.length,
            itemBuilder: (context, index) {
              final char = characters[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.0),
                child: _buildSingleStepCard(index + 1, char, characters.length),
              );
            },
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Page indicators (dots)
        if (characters.length > 1) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(characters.length, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index == _currentStepPage
                      ? const Color(0xFF4ECCA3)
                      : const Color(0xFF4ECCA3).withValues(alpha: 0.3),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
  
  /// Build a single step card for a character
  Widget _buildSingleStepCard(int stepNumber, String character, [int? totalSteps]) {
    final charInfo = _getDetailedCharacterInfo(character);
    final characterType = _getCharacterType(character);
    final typeColor = _getTypeColor(characterType);
    
    // Extract information from charInfo
    final writingSteps = charInfo?['writing_steps'] as String? ?? '';
    final englishGuide = charInfo?['english_guide'] as String? ?? '';
    final consonantClass = charInfo?['consonant_class'] as String?;
    final position = charInfo?['position'] as String?;
    
    // Get pronunciation system info if available
    String pronunciationInfo = '';
    if (characterType == 'consonant' && consonantClass != null) {
      pronunciationInfo = _getConsonantClassDescription(consonantClass);
    } else if (characterType == 'vowel' && position != null) {
      pronunciationInfo = _getVowelPositionDescription(position);
    } else if (characterType == 'tone') {
      pronunciationInfo = _getToneEffectDescription(character);
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: typeColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with step indicator and type badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator at top left
              if (totalSteps != null) 
                Text(
                  'Step $stepNumber of $totalSteps',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4ECCA3),
                  ),
                ),
              
              // Separate colored tag boxes at top right
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _buildSeparateTypeTags(characterType, character),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Character display with pronunciation - left-aligned for more text space
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Character square - moved to left
              Container(
                width: 80,
                height: 90,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Text(
                    character,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Pronunciation display with more space - larger fonts
              Expanded(
                child: _buildStepCardPronunciationDisplay(character),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          
          // Contextual pronunciation guide
          ...(_buildContextualPronunciationSection(character, stepNumber - 1)),
          
                  // Writing steps
                  if (writingSteps.isNotEmpty) ...[
                    const Text(
                      'How to write:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _simplifyStepLanguage(writingSteps),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Get full type label for display
  String _getFullTypeLabel(String type, [String? character]) {
    switch (type) {
      case 'consonant':
        // Check if consonant is part of complex vowel first
        if (character != null) {
          final currentSemanticWord = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
              ? _currentCharacters[_currentCharacterIndex] 
              : '';
          final complexVowelGuide = _getComplexVowelSoundGuide(character, currentSemanticWord);
          
          if (complexVowelGuide.isNotEmpty && character == 'อ') {
            // This consonant is part of a complex vowel - create multi-line label
            final complexVowelData = _getComplexVowelData(currentSemanticWord);
            final complexVowelName = complexVowelData['name'] as String? ?? 'complex vowel';
            final charInfo = _getDetailedCharacterInfo(character);
            final consonantClass = charInfo?['consonant_class'] as String? ?? '';
            
            // Create multi-line label: Consonant \n Class \n Complex Vowel
            final lines = <String>[];
            lines.add('Consonant');
            if (consonantClass.isNotEmpty) {
              lines.add('${_capitalize(consonantClass)} Class');
            }
            lines.add('Complex Vowel');
            return lines.join('\n');
          }
          
          // Regular consonant with class
          final charInfo = _getDetailedCharacterInfo(character);
          final consonantClass = charInfo?['consonant_class'] as String? ?? '';
          if (consonantClass.isNotEmpty) {
            return 'Consonant (${_capitalize(consonantClass)} class)';
          }
        }
        return 'Consonant';
      case 'vowel':
        // Check if vowel is part of complex vowel first
        if (character != null) {
          final currentSemanticWord = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
              ? _currentCharacters[_currentCharacterIndex] 
              : '';
          final complexVowelGuide = _getComplexVowelSoundGuide(character, currentSemanticWord);
          
          if (complexVowelGuide.isNotEmpty) {
            // This vowel is part of a complex vowel - create multi-line label
            final lines = <String>[];
            lines.add('Vowel');
            lines.add('Complex Vowel');
            return lines.join('\n');
          }
        }
        return 'Vowel';
      case 'tone':
        return 'Tone Mark';
      case 'punctuation':
        return 'Punctuation';
      case 'number':
        return 'Number';
      default:
        return 'Symbol'; // For any non-Thai script characters or unrecognized symbols
    }
  }
  
  /// Build separate colored tag boxes for type information
  List<Widget> _buildSeparateTypeTags(String characterType, String character) {
    final tags = <Widget>[];
    
    switch (characterType) {
      case 'consonant':
        // Add main consonant tag
        tags.add(_buildSingleTag('Consonant', const Color(0xFF2196F3))); // Blue for consonants
        
        // Add consonant class tag (second)
        final charInfo = _getDetailedCharacterInfo(character);
        final consonantClass = charInfo?['consonant_class'] as String? ?? '';
        if (consonantClass.isNotEmpty) {
          tags.add(const SizedBox(height: 4));
          tags.add(_buildSingleTag('${_capitalize(consonantClass)} Class', _getConsonantClassColor(consonantClass)));
        }
        
        // Check if consonant is part of complex vowel (last)
        final currentSemanticWord = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
            ? _currentCharacters[_currentCharacterIndex] 
            : '';
        final complexVowelGuide = _getComplexVowelSoundGuide(character, currentSemanticWord);
        
        if (complexVowelGuide.isNotEmpty && character == 'อ') {
          tags.add(const SizedBox(height: 4));
          tags.add(_buildSingleTag('Complex Vowel', const Color(0xFF9C27B0))); // Purple for complex vowels
        }
        break;
        
      case 'vowel':
        // Add main vowel tag
        tags.add(_buildSingleTag('Vowel', const Color(0xFF4CAF50))); // Green for vowels
        
        // Check if vowel is part of complex vowel
        final currentSemanticWord = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
            ? _currentCharacters[_currentCharacterIndex] 
            : '';
        final complexVowelGuide = _getComplexVowelSoundGuide(character, currentSemanticWord);
        
        if (complexVowelGuide.isNotEmpty) {
          tags.add(const SizedBox(height: 4));
          tags.add(_buildSingleTag('Complex Vowel', const Color(0xFF9C27B0))); // Purple for complex vowels
        }
        break;
        
      case 'tone':
        // Add tone mark tag
        tags.add(_buildSingleTag('Tone Mark', const Color(0xFFFFC107))); // Amber for tone marks
        break;
        
      case 'other_mark':
        // Add other mark tag (thanthakhat, mai yamok)
        tags.add(_buildSingleTag('Other Mark', const Color(0xFF795548))); // Brown for other marks
        break;
        
      default:
        tags.add(_buildSingleTag(_capitalize(characterType), const Color(0xFF607D8B))); // Gray for others
        break;
    }
    
    return tags;
  }
  
  /// Build a single colored tag
  Widget _buildSingleTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
  
  /// Get color for consonant class tags
  Color _getConsonantClassColor(String consonantClass) {
    switch (consonantClass.toLowerCase()) {
      case 'high':
        return const Color(0xFFE91E63); // Pink for high class
      case 'mid':
        return const Color(0xFF00BCD4); // Cyan for mid class  
      case 'low':
        return const Color(0xFF795548); // Brown for low class
      default:
        return const Color(0xFF607D8B); // Gray default
    }
  }
  
  /// Get consonant class description based on pronunciation system
  String _getConsonantClassDescription(String consonantClass) {
    switch (consonantClass.toLowerCase()) {
      case 'high':
        return 'High class: Affects tone - makes it higher/sharper';
      case 'mid':
        return 'Mid class: Neutral tone effect';
      case 'low':
        return 'Low class: Affects tone - makes it lower/softer';
      default:
        return '';
    }
  }
  
  /// Get vowel position description
  String _getVowelPositionDescription(String position) {
    switch (position.toLowerCase()) {
      case 'before':
        return 'Written BEFORE consonant, pronounced AFTER';
      case 'after':
        return 'Written and pronounced AFTER consonant';
      case 'above':
        return 'Written ABOVE the consonant';
      case 'below':
        return 'Written BELOW the consonant';
      case 'surrounding':
        return 'Surrounds the consonant on multiple sides';
      default:
        return '';
    }
  }
  
  /// Get tone effect description
  String _getToneEffectDescription(String toneChar) {
    // Based on pronunciation_system.tone_mark_rules from thai_writing_guide.json
    switch (toneChar) {
      case '่':
        return 'Mai Ek: Low tone (mid/high class) or Falling (low class)';
      case '้':
        return 'Mai Tho: Falling tone (mid/high) or High (low class)';
      case '๊':
        return 'Mai Tri: High tone (all classes)';
      case '๋':
        return 'Mai Chattawa: Rising tone (all classes)';
      default:
        return 'Tone mark: Changes the pitch pattern';
    }
  }


  // ============================================================================
  // CONTEXTUAL PRONUNCIATION ANALYSIS SYSTEM
  // ============================================================================

  /// Build compact horizontal character breakdown for header
  Widget _buildCompactCharacterBreakdown(String semanticWord) {
    final characters = semanticWord.split('');
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Character boxes
        ...characters.map((char) {
          final characterType = _getCharacterType(char);
          final typeColor = _getTypeColor(characterType);
          
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            child: Column(
              children: [
                // Character box
                Container(
                  width: 40,
                  height: 50,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: typeColor.withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      char,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Type label
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _getTypeLabel(characterType),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  /// Build character decomposition widget showing color-coded character types
  Widget _buildCharacterDecompositionWidget(String semanticWord) {
    final characters = semanticWord.split('');
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4ECCA3).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Character Breakdown:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4ECCA3),
            ),
          ),
          const SizedBox(height: 12),
          
          // Character boxes row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: characters.map((char) {
              final characterType = _getCharacterType(char);
              final typeColor = _getTypeColor(characterType);
              
              return Container(
                width: 60,
                height: 80,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: typeColor.withValues(alpha: 0.6),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Thai character
                    Text(
                      char,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Type label
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: typeColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getTypeLabel(characterType),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // Color legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildColorLegendItem('CON', _getTypeColor('consonant'), 'Consonant'),
              _buildColorLegendItem('VOW', _getTypeColor('vowel'), 'Vowel'),
              _buildColorLegendItem('TONE', _getTypeColor('tone'), 'Tone Mark'),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Pronunciation guide
          if (_constituentWordData.isNotEmpty && _currentCharacterIndex < _constituentWordData.length) ...[
            const Text(
              'Pronunciation Guide:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '• ${_constituentWordData[_currentCharacterIndex]['romanized'] as String? ?? ''} • ${_constituentWordData[_currentCharacterIndex]['translation'] as String? ?? ''}',
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build color legend item
  Widget _buildColorLegendItem(String label, Color color, String description) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  /// Get short type label for display
  String _getTypeLabel(String type) {
    switch (type) {
      case 'consonant':
        return 'CON';
      case 'vowel':
        return 'VOW';
      case 'tone':
        return 'TONE';
      default:
        return 'CHAR';
    }
  }

  /// Check if a numbered step is about character writing (should be boxed)
  bool _isCharacterWritingStep(String stepText) {
    final writingKeywords = [
      'write', 'draw', 'start', 'begin', 'stroke', 'line', 'curve', 'loop', 'character',
      'consonant', 'vowel', 'tone', 'mark', 'above', 'below', 'left', 'right', 'top', 'bottom',
      'horizontal', 'vertical', 'diagonal', 'circle', 'arc', 'dot', 'dash', 'connect'
    ];
    
    final lowerText = stepText.toLowerCase();
    return writingKeywords.any((keyword) => lowerText.contains(keyword));
  }

  /// Build pronunciation tips text
  String _buildPronunciationTips() {
    if (_constituentWordData.isEmpty || _currentCharacterIndex >= _constituentWordData.length) {
      return '';
    }
    
    final wordData = _constituentWordData[_currentCharacterIndex];
    final romanization = wordData['romanized'] as String? ?? '';
    final translation = wordData['translation'] as String? ?? '';
    
    final tips = <String>[];
    
    if (romanization.isNotEmpty) {
      tips.add('Pronunciation: $romanization');
    }
    
    if (translation.isNotEmpty) {
      tips.add('Meaning: $translation');
    }
    
    return tips.join(' • ');
  }

  /// Generate step-by-step instructions widget for the current semantic word
  Widget _buildStepByStepInstructionsWidget(String semanticWord) {
    final steps = _generateStepByStepGuide(semanticWord);
    
    if (steps.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F1F1F),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFF4ECCA3).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: const Text(
          'No specific writing instructions available for this character.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white70,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add informational text at the top
        if (semanticWord.isNotEmpty) ...[
          Text(
            'This word contains ${semanticWord.length} characters. Write them in order:',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
        ],
        
        // Writing steps
        ...steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1F1F1F),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFF4ECCA3).withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Inset step number inside the text box
                Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4ECCA3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                
                // Step content
                Expanded(
                  child: Text(
                    step,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        
        // Add pronunciation tips at the bottom
        if (_constituentWordData.isNotEmpty && _currentCharacterIndex < _constituentWordData.length) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.volume_up, size: 16, color: Color(0xFF4ECCA3)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _buildPronunciationTips(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Generate step-by-step guide for a semantic word
  List<String> _generateStepByStepGuide(String semanticWord) {
    final steps = <String>[];
    
    if (semanticWord.isEmpty) return steps;
    
    // For single characters, get detailed instructions
    if (semanticWord.length == 1) {
      final char = semanticWord;
      final charInfo = _getDetailedCharacterInfo(char);
      
      if (charInfo != null) {
        final writingSteps = charInfo['writing_steps'] as String? ?? '';
        final englishGuide = charInfo['english_guide'] as String? ?? '';
        final romanization = charInfo['romanization'] as String? ?? '';
        
        // Add pronunciation context
        if (englishGuide.isNotEmpty) {
          steps.add('Sound: $englishGuide');
        } else if (romanization.isNotEmpty) {
          steps.add('Pronunciation: "$romanization"');
        }
        
        // Add detailed writing steps
        if (writingSteps.isNotEmpty) {
          // Split writing steps into individual instructions
          final stepInstructions = _parseWritingSteps(writingSteps);
          steps.addAll(stepInstructions);
        } else if (englishGuide.isNotEmpty) {
          steps.add('General guidance: $englishGuide');
        }
        
        // Add character type info if helpful
        final type = charInfo['type'] as String? ?? '';
        final consonantClass = charInfo['consonant_class'] as String?;
        
        if (type == 'consonant' && consonantClass != null) {
          final friendlyClass = _getBeginnerFriendlyClass(consonantClass);
          if (friendlyClass.isNotEmpty) {
            steps.add('Character type: $friendlyClass');
          }
        } else if (type == 'vowel') {
          final position = charInfo['position'] as String?;
          if (position != null) {
            final friendlyPosition = _getBeginnerFriendlyPosition(position);
            if (friendlyPosition.isNotEmpty) {
              steps.add('Vowel placement: $friendlyPosition');
            }
          }
        }
      }
    } else {
      // For multi-character words, provide character-by-character breakdown
      steps.add('This word contains ${semanticWord.length} characters. Write them in order:');
      
      for (int i = 0; i < semanticWord.length; i++) {
        final char = semanticWord[i];
        final charInfo = _getDetailedCharacterInfo(char);
        
        if (charInfo != null) {
          final romanization = charInfo['romanization'] as String? ?? '';
          final writingSteps = charInfo['writing_steps'] as String? ?? '';
          
          String instruction = 'Character ${i + 1}: "$char"';
          if (romanization.isNotEmpty) {
            instruction += ' (sounds like "$romanization")';
          }
          
          if (writingSteps.isNotEmpty) {
            instruction += ' - ${_simplifyStepLanguage(writingSteps)}';
          }
          
          steps.add(instruction);
        } else {
          steps.add('Character ${i + 1}: "$char" - practice this character shape');
        }
      }
    }
    
    // Add general completion tip
    if (steps.isNotEmpty) {
      steps.add('Practice writing slowly and deliberately until the shape becomes natural.');
    }
    
    return steps;
  }

  /// Parse writing steps into individual instructions
  List<String> _parseWritingSteps(String writingSteps) {
    final steps = <String>[];
    
    // Split by common delimiters
    final sentences = writingSteps.split(RegExp(r'[.!]\s+'))
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim())
        .toList();
    
    for (String sentence in sentences) {
      if (sentence.isNotEmpty) {
        // Clean up and simplify language
        String cleanSentence = _simplifyStepLanguage(sentence);
        
        // Ensure sentence ends with period
        if (!cleanSentence.endsWith('.') && !cleanSentence.endsWith('!') && !cleanSentence.endsWith('?')) {
          cleanSentence += '.';
        }
        
        steps.add(cleanSentence);
      }
    }
    
    return steps.isNotEmpty ? steps : [_simplifyStepLanguage(writingSteps)];
  }

  /// Get beginner-friendly description for consonant class
  String _getBeginnerFriendlyClass(String consonantClass) {
    switch (consonantClass.toLowerCase()) {
      case 'high':
        return 'Sharp sound character (affects tone)';
      case 'mid':
        return 'Clear sound character (neutral tone)';
      case 'low':
        return 'Soft sound character (affects tone)';
      default:
        return '';
    }
  }

  /// Get beginner-friendly description for vowel position
  String _getBeginnerFriendlyPosition(String position) {
    switch (position.toLowerCase()) {
      case 'before':
        return 'Write this vowel BEFORE the consonant';
      case 'after':
        return 'Write this vowel AFTER the consonant';
      case 'above':
        return 'Write this vowel ABOVE the consonant';
      case 'below':
        return 'Write this vowel BELOW the consonant';
      case 'surrounding':
        return 'This vowel wraps AROUND the consonant';
      default:
        return '';
    }
  }

  /// Build syllable info panel below canvas showing current syllable being traced
  Widget _buildClusterInfoPanel() {
    final currentSyllable = _currentCharacters.isNotEmpty && _currentCharacterIndex < _currentCharacters.length
        ? _currentCharacters[_currentCharacterIndex]
        : '';
    
    // Get syllable data directly from constituent word data (now contains syllables when using syllable_mapping)
    String currentRomanization = '';
    String currentTranslation = '';
    
    if (_constituentWordData.isNotEmpty && _currentCharacterIndex < _constituentWordData.length) {
      final syllableData = _constituentWordData[_currentCharacterIndex];
      currentRomanization = syllableData['romanized'] as String? ?? '';
      
      // Handle compound word syllables
      final rawTranslation = syllableData['translation'] as String?;
      final isCompound = syllableData['is_compound'] == true;
      final wordTranslation = syllableData['word_translation'] as String?;
      
      if (rawTranslation == null || rawTranslation.isEmpty || rawTranslation == 'null' || rawTranslation == 'None') {
        if (isCompound && wordTranslation != null && wordTranslation.isNotEmpty) {
          // For compound words, show contextual information
          currentTranslation = '(part of $wordTranslation)';
        } else {
          // For non-compound words or missing word translation, show syllable romanization
          currentTranslation = currentRomanization.isNotEmpty ? '($currentRomanization)' : '';
        }
      } else {
        currentTranslation = rawTranslation;
      }
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
          // Current syllable display with three separate lines (centered)
          if (currentSyllable.isNotEmpty) ...[
            // Line 1: Thai syllable (centered)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  currentSyllable,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (progress.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  Container(
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
                ],
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
            onPressed: _showTracingConfirmationDialog,
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
          onTap: _getCurrentCharacterInk().strokes.isNotEmpty ? _undoLastStroke : null,
          child: Icon(
            Icons.undo,
            size: 22,
            color: _getCurrentCharacterInk().strokes.isNotEmpty ? Colors.black87 : Colors.black54,
          ),
        ),
      ),
    );
  }

  Widget _buildWritingTipsButton() {
    return GestureDetector(
      onTap: _showWritingTipsModal,
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

  /// Build character tips content with classification
  Widget _buildCharacterTipsContent(String semanticWord) {
    if (_isLoadingTips) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF4ECCA3),
            strokeWidth: 2,
          ),
        ),
      );
    }
    
    // Parse characters from the semantic word
    final characterInfoList = _parseCharacterInfo(semanticWord);
    
    if (characterInfoList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: const Text(
          'No writing tips available for this word.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: characterInfoList.map((charInfo) => 
          _buildCompactCharacterCard(charInfo)
        ).toList(),
      ),
    );
  }
  
  /// Parse character information from semantic word
  List<Map<String, dynamic>> _parseCharacterInfo(String semanticWord) {
    final List<Map<String, dynamic>> characterInfoList = [];
    
    for (int i = 0; i < semanticWord.length; i++) {
      final char = semanticWord[i];
      final detailedInfo = _getDetailedCharacterInfo(char);
      
      if (detailedInfo != null) {
        characterInfoList.add(detailedInfo);
      } else {
        // Create basic info if detailed info not available
        characterInfoList.add({
          'character': char,
          'type': _getCharacterType(char),
          'main_tip': _getCharacterTipsFromJSON(char),
        });
      }
    }
    
    return characterInfoList;
  }
  
  /// Get complex vowel sound guide for character if it's part of a complex vowel
  String _getComplexVowelSoundGuide(String character, String word) {
    if (_thaiWritingGuideData == null) return '';
    
    try {
      final vowels = _thaiWritingGuideData!['vowels'] as Map<String, dynamic>?;
      if (vowels == null) return '';
      
      // Check all complex vowel patterns to see if this character is part of one
      for (final entry in vowels.entries) {
        final vowelKey = entry.key;
        final vowelData = entry.value as Map<String, dynamic>;
        
        // Only check complex vowels (those with ◌)
        if (vowelKey.contains('◌')) {
          // Extract the actual vowel components (not the placeholder)
          final vowelComponents = vowelKey.replaceAll('◌', '').split('');
          
          // Check if this character is one of the vowel components
          if (vowelComponents.contains(character)) {
            // Additional validation: ensure the word has the pattern
            bool hasPattern = false;
            
            if (vowelKey == 'เ◌ือ') {
              // For เ◌ือ: character must be เ, ื, or อ (not the consonant in placeholder position)
              if ((character == 'เ' || character == 'ื' || character == 'อ') &&
                  word.contains('เ') && word.contains('ื') && word.contains('อ')) {
                hasPattern = true;
              }
            } else if (vowelKey == 'เ◌า') {
              // For เ◌า: character must be เ or า
              if ((character == 'เ' || character == 'า') &&
                  word.contains('เ') && word.contains('า')) {
                hasPattern = true;
              }
            } else if (vowelKey == 'เ◌ะ') {
              // For เ◌ะ: character must be เ or ะ
              if ((character == 'เ' || character == 'ะ') &&
                  word.contains('เ') && word.contains('ะ')) {
                hasPattern = true;
              }
            } else if (vowelKey == 'แ◌ะ') {
              // For แ◌ะ: character must be แ or ะ
              if ((character == 'แ' || character == 'ะ') &&
                  word.contains('แ') && word.contains('ะ')) {
                hasPattern = true;
              }
            } else if (vowelKey == 'โ◌ะ') {
              // For โ◌ะ: character must be โ or ะ
              if ((character == 'โ' || character == 'ะ') &&
                  word.contains('โ') && word.contains('ะ')) {
                hasPattern = true;
              }
            } else if (vowelKey == 'เ◌อ') {
              // For เ◌อ: character must be เ or อ
              if ((character == 'เ' || character == 'อ') &&
                  word.contains('เ') && word.contains('อ')) {
                hasPattern = true;
              }
            }
            // Add more pattern checks as needed
            
            if (hasPattern) {
              final pronunciation = vowelData['pronunciation'] as Map<String, dynamic>?;
              final englishGuide = pronunciation?['english_guide'] as String?;
              
              if (englishGuide != null && englishGuide.isNotEmpty) {
                print('Found complex vowel pattern $vowelKey in word $word for character $character');
                return englishGuide;
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error in _getComplexVowelSoundGuide: $e');
    }
    
    return '';
  }

  /// Get character type (consonant, vowel, tone mark, other mark)
  String _getCharacterType(String character) {
    if (_thaiWritingGuideData == null) return 'character';
    
    // Check other marks section FIRST (thanthakhat, mai yamok)
    final otherMarks = _thaiWritingGuideData!['other_marks'] as Map<String, dynamic>?;
    if (otherMarks?.containsKey(character) == true) {
      return 'other_mark';
    }
    
    // Check general tone marks section
    final toneMarks = _thaiWritingGuideData!['tone_marks'] as Map<String, dynamic>?;
    if (toneMarks?.containsKey(character) == true) {
      return 'tone';
    }
    
    // Check tone marks in pronunciation system rules
    final pronunciationSystem = _thaiWritingGuideData!['pronunciation_system'] as Map<String, dynamic>?;
    final toneMarkRules = pronunciationSystem?['tone_mark_rules'] as Map<String, dynamic>?;
    if (toneMarkRules != null) {
      for (final markData in toneMarkRules.values) {
        final markInfo = markData as Map<String, dynamic>;
        if (markInfo['character'] == character) {
          return 'tone';
        }
      }
    }
    
    // Check consonants
    final consonants = _thaiWritingGuideData!['consonants'] as Map<String, dynamic>?;
    if (consonants?.containsKey(character) == true) {
      return 'consonant';
    }
    
    // Check vowels - handle all placeholder patterns
    final vowels = _thaiWritingGuideData!['vowels'] as Map<String, dynamic>?;
    if (vowels != null) {
      // Direct match
      if (vowels.containsKey(character)) {
        return 'vowel';
      }
      // Placeholder after character (เ◌ pattern)
      if (vowels.containsKey('$character◌')) {
        return 'vowel';
      }
      // Placeholder before character (◌ะ pattern)
      if (vowels.containsKey('◌$character')) {
        return 'vowel';
      }
      // Check if character is part of any complex vowel pattern
      for (final vowelKey in vowels.keys) {
        if (vowelKey.contains(character) && vowelKey.contains('◌')) {
          return 'vowel';
        }
      }
    }
    
    return 'character';
  }
  
  /// Build compact character card with classification
  Widget _buildCompactCharacterCard(Map<String, dynamic> charInfo) {
    final character = charInfo['character'] ?? '';
    final type = charInfo['type'] ?? 'character';
    final romanization = charInfo['romanization'] ?? '';
    final mainTip = charInfo['main_tip'] ?? '';
    final englishGuide = charInfo['english_guide'] ?? '';
    final consonantClass = charInfo['consonant_class'];
    final position = charInfo['position'];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF2D2D2D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getTypeColor(type).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Character header with type badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    character,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  if (romanization.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '($romanization)',
                      style: TextStyle(
                        fontSize: 16,
                        color: const Color(0xFF4ECCA3).withValues(alpha: 0.8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
              _buildCharacterTypeBadge(type, consonantClass, position),
            ],
          ),
          
          const SizedBox(height: 6),
          
          // Writing instruction
          if (mainTip.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.edit,
                  size: 14,
                  color: _getTypeColor(type),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    mainTip,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          
          // Pronunciation guide
          if (englishGuide.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.volume_up,
                  size: 14,
                  color: _getTypeColor(type),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    englishGuide,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  /// Build character type badge with beginner-friendly descriptions
  Widget _buildCharacterTypeBadge(String type, String? consonantClass, String? position) {
    String label = type.toUpperCase();
    String? subLabel;
    
    if (type == 'consonant' && consonantClass != null) {
      // Replace technical class names with beginner-friendly descriptions
      switch (consonantClass.toLowerCase()) {
        case 'high':
          subLabel = 'SHARP SOUND';
          break;
        case 'mid':
          subLabel = 'CLEAR SOUND';
          break;
        case 'low':
          subLabel = 'SOFT SOUND';
          break;
        default:
          subLabel = consonantClass.toUpperCase();
      }
    } else if (type == 'vowel' && position != null) {
      // Make vowel positions more descriptive
      switch (position.toLowerCase()) {
        case 'before':
          subLabel = 'WRITE FIRST';
          break;
        case 'after':
          subLabel = 'WRITE LAST';
          break;
        case 'above':
          subLabel = 'WRITE ABOVE';
          break;
        case 'below':
          subLabel = 'WRITE BELOW';
          break;
        default:
          subLabel = position.toUpperCase();
      }
    } else if (type == 'tone') {
      subLabel = 'CHANGES TONE';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _getTypeColor(type).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getTypeColor(type).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _getTypeColor(type),
            ),
          ),
          if (subLabel != null) ...[
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 8,
                color: _getTypeColor(type).withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Get color for character type
  Color _getTypeColor(String type) {
    switch (type) {
      case 'consonant':
        return const Color(0xFF4FC3F7); // Blue
      case 'vowel':
        return const Color(0xFF81C784); // Green
      case 'tone':
        return const Color(0xFFFFD54F); // Yellow
      default:
        return const Color(0xFF4ECCA3); // Default teal
    }
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
            constraints: const BoxConstraints(maxWidth: 650, maxHeight: 600),
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
                      Tab(text: 'Writing Order'),
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
  
  // ============================================================================
  // CONTEXTUAL PRONUNCIATION ANALYSIS SYSTEM
  // ============================================================================

  /// Detect consonant clusters using pronunciation_system rules
  Map<String, dynamic> _detectCluster(String character, String syllable, int positionInSyllable) {
    if (_thaiWritingGuideData == null || positionInSyllable >= syllable.length - 1) {
      return {'hasCluster': false};
    }

    final pronunciationSystem = _thaiWritingGuideData!['pronunciation_system'] as Map<String, dynamic>?;
    final consonantRules = pronunciationSystem?['consonant_position_rules'] as Map<String, dynamic>?;
    final commonClusters = consonantRules?['cluster']?['common_clusters'] as Map<String, dynamic>?;

    if (commonClusters == null) {
      return {'hasCluster': false};
    }

    // Check if this character starts a cluster
    for (final clusterPattern in commonClusters.keys) {
      if (positionInSyllable + clusterPattern.length <= syllable.length &&
          syllable.substring(positionInSyllable, positionInSyllable + clusterPattern.length) == clusterPattern) {
        
        final clusterInfo = commonClusters[clusterPattern] as String;
        return {
          'hasCluster': true,
          'clusterPattern': clusterPattern,
          'clusterInfo': clusterInfo,
          'isFirstInCluster': character == clusterPattern[0],
          'isSecondInCluster': clusterPattern.length > 1 && character == clusterPattern[1],
        };
      }
    }

    // Check if this character is part of a cluster that started earlier
    for (final clusterPattern in commonClusters.keys) {
      for (int i = 1; i < clusterPattern.length && i <= positionInSyllable; i++) {
        if (positionInSyllable - i + clusterPattern.length <= syllable.length &&
            syllable.substring(positionInSyllable - i, positionInSyllable - i + clusterPattern.length) == clusterPattern &&
            character == clusterPattern[i]) {
          
          final clusterInfo = commonClusters[clusterPattern] as String;
          return {
            'hasCluster': true,
            'clusterPattern': clusterPattern,
            'clusterInfo': clusterInfo,
            'isFirstInCluster': false,
            'isSecondInCluster': i == 1,
            'position': i,
          };
        }
      }
    }

    return {'hasCluster': false};
  }

  /// Generate contextual pronunciation tip with emoji formatting
  String _getContextualPronunciationTip(String character, String syllable, int positionInSyllable) {
    print('=== _getContextualPronunciationTip called for: "$character" ===');
    final charInfo = _getDetailedCharacterInfo(character);
    print('charInfo for "$character": $charInfo');
    if (charInfo == null) {
      print('No charInfo found for "$character" - returning empty');
      return '';
    }

    final characterType = _getCharacterType(character);
    final tips = <String>[];

    // Detect cluster context
    final clusterInfo = _detectCluster(character, syllable, positionInSyllable);

    switch (characterType) {
      case 'consonant':
        tips.add(_getConsonantContextualTip(character, charInfo, clusterInfo, syllable, positionInSyllable));
        break;
      case 'vowel':
        tips.add(_getVowelContextualTip(character, charInfo, syllable, positionInSyllable));
        break;
      case 'tone':
        tips.add(_getToneContextualTip(character, charInfo, syllable));
        break;
      case 'other_mark':
        tips.add(_getOtherMarkContextualTip(character, charInfo, syllable));
        break;
    }

    return tips.where((tip) => tip.isNotEmpty).join('\n');
  }

  /// Generate consonant-specific contextual tips
  String _getConsonantContextualTip(String character, Map<String, dynamic> charInfo, Map<String, dynamic> clusterInfo, String syllable, int positionInSyllable) {
    print('=== _getConsonantContextualTip for: "$character" ===');
    final tips = <String>[];
    
    // Check if this consonant is part of a complex vowel using synchronous JSON lookup
    final complexVowelGuide = _getComplexVowelSoundGuide(character, syllable);
    if (complexVowelGuide.isNotEmpty && character == 'อ') {
      // This consonant is part of a complex vowel - explain the transformation
      final originalSound = charInfo['romanization'] as String? ?? '';
      final originalName = charInfo['name'] as String? ?? '';
      final complexVowelData = _getComplexVowelData(syllable);
      final complexVowelName = complexVowelData['name'] as String? ?? 'complex vowel';
      final complexVowelSound = complexVowelData['romanization'] as String? ?? complexVowelGuide;
      
      final explanation = 'Sound: Originally "$originalSound" ($originalName), but as part of $complexVowelName complex vowel, it combines to make "$complexVowelSound" sound.';
      tips.add(explanation);
      print('Added complex vowel transformation explanation for consonant: "$character"');
    } else {
      // Regular consonant sound information
      final englishGuide = charInfo['english_guide'] as String? ?? '';
      print('englishGuide from charInfo: "$englishGuide"');
      
      if (englishGuide.isNotEmpty) {
        tips.add('Sound: $englishGuide');
        print('Added consonant sound tip: "Sound: $englishGuide"');
      } else {
        // Fallback to romanization if no english_guide
        final romanization = charInfo['romanization'] as String? ?? '';
        if (romanization.isNotEmpty) {
          final soundRef = _getEnglishSoundReference(character);
          tips.add('Sound: $soundRef');
          print('Added sound tip from romanization: "Sound: $soundRef"');
        } else {
          tips.add('Sound: Consonant sound (guide not available)');
          print('No sound information found for consonant "$character"');
        }
      }
      
      // Add consonant role explanation
      final pronunciation = charInfo['pronunciation'] as Map<String, dynamic>? ?? {};
      final initialSound = pronunciation['initial'] as String? ?? '';
      final finalSound = pronunciation['final'] as String?;
      
      // Determine syllable type for current word
      final syllableType = _determineSyllableType(syllable);
      final syllableExplanation = syllableType == 'live' 
          ? 'This is a live syllable (ends with long vowel or sonorant consonant - sound flows).'
          : 'This is a dead syllable (ends with short vowel or stop consonant - sound cuts off).';
      
      if (initialSound.isNotEmpty && finalSound != null && finalSound.isNotEmpty && finalSound != initialSound) {
        // Can be both initial and final
        tips.add('Role: This consonant can start syllables (initial "$initialSound" - affects tone) or end them (final "$finalSound" - affects syllable flow). $syllableExplanation');
      } else if (initialSound.isNotEmpty && (finalSound == null || finalSound.isEmpty)) {
        // Initial only
        tips.add('Role: Initial consonant ("$initialSound") - starts syllables and carries the consonant class that affects tone. $syllableExplanation');
      } else if (finalSound != null && finalSound.isNotEmpty) {
        // Final only (rare)
        tips.add('Role: Final consonant ("$finalSound") - ends syllables and affects whether the syllable is live or dead. $syllableExplanation');
      }
    }

    return tips.join('\n');
  }

  /// Get vowel pronunciation order information from JSON
  String _getVowelPronunciationOrder(String character, Map<String, dynamic> complexVowelData) {
    if (_thaiWritingGuideData == null) return '';
    
    final pronunciationSystem = _thaiWritingGuideData!['pronunciation_system'] as Map<String, dynamic>?;
    final vowelPositionRules = pronunciationSystem?['vowel_position_rules'] as Map<String, dynamic>?;
    
    if (vowelPositionRules == null) return '';
    
    // First try to get position from complex vowel data
    String position = '';
    if (complexVowelData.isNotEmpty) {
      position = complexVowelData['position'] as String? ?? '';
    }
    
    // If no complex vowel position, get individual vowel position
    if (position.isEmpty) {
      final individualVowelInfo = _getIndividualVowelInfo(character);
      position = individualVowelInfo['position'] as String? ?? '';
    }
    
    // If still no position, try to determine from character itself
    if (position.isEmpty) {
      position = _determineVowelPosition(character, vowelPositionRules);
    }
    
    // Get the pronunciation tip for this position
    if (position.isNotEmpty && vowelPositionRules.containsKey(position)) {
      final positionRule = vowelPositionRules[position] as Map<String, dynamic>?;
      final pronunciationTip = positionRule?['pronunciation_tip'] as String? ?? '';
      
      if (pronunciationTip.isNotEmpty) {
        return pronunciationTip;
      }
    }
    
    return '';
  }

  /// Determine vowel position based on character and position rules
  String _determineVowelPosition(String character, Map<String, dynamic> vowelPositionRules) {
    for (final entry in vowelPositionRules.entries) {
      final position = entry.key;
      final ruleData = entry.value as Map<String, dynamic>;
      final characters = ruleData['characters'] as List?;
      
      if (characters != null && characters.contains(character)) {
        return position;
      }
    }
    return '';
  }

  /// Get complex vowel information from JSON
  Map<String, dynamic> _getComplexVowelData(String word) {
    if (_thaiWritingGuideData == null) return {};
    
    final vowels = _thaiWritingGuideData!['vowels'] as Map<String, dynamic>?;
    if (vowels == null) return {};
    
    // Look for complex vowel patterns that match this word
    for (final entry in vowels.entries) {
      final vowelKey = entry.key;
      final vowelData = entry.value as Map<String, dynamic>;
      
      // Check if this is a complex vowel pattern (contains ◌)
      if (vowelKey.contains('◌') && _wordMatchesComplexVowelPattern(word, vowelKey)) {
        final pronunciation = vowelData['pronunciation'] as Map<String, dynamic>?;
        return {
          'name': vowelData['name'] ?? '',
          'romanization': pronunciation?['romanization'] ?? '',
          'english_guide': pronunciation?['english_guide'] ?? '',
          'pattern': vowelKey,
        };
      }
    }
    
    return {};
  }

  /// Check if word contains the complex vowel pattern
  bool _wordMatchesComplexVowelPattern(String word, String pattern) {
    // Simple pattern matching for common complex vowels
    if (pattern == 'เ◌ือ') {
      return word.contains('เ') && word.contains('ื') && word.contains('อ');
    } else if (pattern == 'เ◌า') {
      return word.contains('เ') && word.contains('า');
    } else if (pattern == 'เ◌ะ') {
      return word.contains('เ') && word.contains('ะ');
    }
    // Add other patterns as needed
    return false;
  }

  /// Get individual vowel information from JSON before complex vowel transformation
  Map<String, dynamic> _getIndividualVowelInfo(String character) {
    if (_thaiWritingGuideData == null) return {};
    
    final vowels = _thaiWritingGuideData!['vowels'] as Map<String, dynamic>?;
    if (vowels == null) return {};
    
    // List of possible patterns to check for this character
    final patternsToCheck = [
      '◌$character',  // Most vowels like ◌ื, ◌ิ, ◌า
      '$character◌',  // Vowels before consonant like เ◌, แ◌, โ◌
      character,      // Direct match
    ];
    
    for (final pattern in patternsToCheck) {
      if (vowels.containsKey(pattern)) {
        final vowelData = vowels[pattern] as Map<String, dynamic>;
        final pronunciation = vowelData['pronunciation'] as Map<String, dynamic>?;
        return {
          'romanization': pronunciation?['romanization'] ?? '',
          'english_guide': pronunciation?['english_guide'] ?? '',
          'name': vowelData['name'] ?? '',
          'position': vowelData['position'] ?? '',
        };
      }
    }
    
    return {};
  }

  /// Generate vowel-specific contextual tips
  String _getVowelContextualTip(String character, Map<String, dynamic> charInfo, String syllable, int positionInSyllable) {
    print('=== _getVowelContextualTip for: "$character" ===');
    final tips = <String>[];
    
    // Check if this vowel is part of a complex vowel using synchronous JSON lookup
    final complexVowelGuide = _getComplexVowelSoundGuide(character, syllable);
    if (complexVowelGuide.isNotEmpty) {
      // Get the individual vowel's original sound and complex vowel information
      final individualVowelInfo = _getIndividualVowelInfo(character);
      final originalSound = individualVowelInfo['romanization'] as String? ?? '';
      final originalName = individualVowelInfo['name'] as String? ?? '';
      
      // Get complex vowel details
      final complexVowelData = _getComplexVowelData(syllable);
      final complexVowelName = complexVowelData['name'] as String? ?? 'complex vowel';
      final complexVowelSound = complexVowelData['romanization'] as String? ?? complexVowelGuide;
      
      if (originalSound.isNotEmpty && originalName.isNotEmpty) {
        // Get pronunciation order information
        final pronunciationOrder = _getVowelPronunciationOrder(character, complexVowelData);
        
        // Explain the complex vowel transformation with names and pronunciation order
        var explanation = 'Sound: Part of $complexVowelName complex vowel (\'$complexVowelSound\'). Originally \'$originalSound\' ($originalName), but combines to make \'$complexVowelSound\' sound.';
        
        if (pronunciationOrder.isNotEmpty) {
          explanation += ' $pronunciationOrder';
        }
        
        tips.add(explanation);
        print('Added complex vowel transformation explanation for vowel: "$character"');
      } else {
        // Fallback to simpler explanation with pronunciation order
        final pronunciationOrder = _getVowelPronunciationOrder(character, complexVowelData);
        var explanation = 'Sound: Part of $complexVowelName complex vowel making \'$complexVowelSound\' sound';
        
        if (pronunciationOrder.isNotEmpty) {
          explanation += '. $pronunciationOrder';
        }
        
        tips.add(explanation);
        print('Added complex vowel sound tip for vowel: "Sound: $complexVowelGuide"');
      }
    } else {
      // Regular vowel sound information with pronunciation order
      final englishGuide = charInfo['english_guide'] as String? ?? '';
      final pronunciationOrder = _getVowelPronunciationOrder(character, {});
      
      print('vowel englishGuide from charInfo: "$englishGuide"');
      if (englishGuide.isNotEmpty) {
        var soundTip = 'Sound: $englishGuide';
        if (pronunciationOrder.isNotEmpty) {
          soundTip += '. $pronunciationOrder';
        }
        tips.add(soundTip);
        print('Added vowel sound tip: "$soundTip"');
      } else {
        // Fallback to romanization if no english_guide
        final romanization = charInfo['romanization'] as String? ?? '';
        if (romanization.isNotEmpty) {
          var soundTip = 'Sound: /$romanization/ vowel sound';
          if (pronunciationOrder.isNotEmpty) {
            soundTip += '. $pronunciationOrder';
          }
          tips.add(soundTip);
          print('Added vowel sound from romanization: "/$romanization/"');
        } else {
          var soundTip = 'Sound: Vowel sound (guide not available)';
          if (pronunciationOrder.isNotEmpty) {
            soundTip += '. $pronunciationOrder';
          }
          tips.add(soundTip);
          print('No sound information found for vowel "$character"');
        }
      }
    }

    // Removed Role and Tip boxes as requested - all information is now shown next to the character icon

    return tips.join('\n');
  }

  /// Generate tone mark contextual tips with writing instructions
  String _getToneContextualTip(String character, Map<String, dynamic> charInfo, String syllable) {
    final tips = <String>[];

    // Get tone mark information from JSON
    final toneMarkInfo = _getToneMarkInfoFromJSON(character);
    
    // Calculate and show the actual tone effect with formula
    final toneFormulaData = _calculateToneEffectWithFormula(character, syllable);
    final formula = toneFormulaData['formula'] ?? '';
    
    
    // Get consonant information for enhanced explanation
    final consonantInWord = _findMainConsonantInWord(syllable);
    final consonantInfo = _getDetailedCharacterInfo(consonantInWord);
    final consonantClass = consonantInfo?['consonant_class'] as String? ?? '';
    final consonantName = consonantInfo?['name'] as String? ?? '';
    final syllableTypeDetailed = _determineSyllableType(syllable);
    
    if (formula.isNotEmpty && consonantInWord.isNotEmpty) {
      // Enhanced explanation with detailed syllable type explanation and specific consonant
      final syllableExplanation = syllableTypeDetailed == 'live' 
          ? 'Live syllables end with long vowels or sonorant consonants (ง, น, ม, ย, ว) - the sound flows or continues.'
          : 'Dead syllables end with short vowels or stop consonants (ก, ด, บ - k, t, p sounds) - the sound cuts off abruptly.';
      
      final enhancedExplanation = 'Sound: ${_capitalize(consonantClass)} class consonant ($consonantInWord - $consonantName) + ${toneMarkInfo['name']} + $syllableTypeDetailed syllable = ${_extractToneFromFormula(formula)}. $syllableExplanation';
      tips.add(enhancedExplanation);
    } else {
      // Enhanced fallback with manual calculation
      final toneMarkName = toneMarkInfo['name'] as String? ?? 'tone mark';
      
      if (consonantInWord.isNotEmpty && consonantClass.isNotEmpty && toneMarkName.isNotEmpty) {
        
        final syllableTypeManual = _determineSyllableType(syllable);
        String resultingTone = '';
        if (character == '่') { // Mai Ek
          if (consonantClass == 'mid' || consonantClass == 'high') {
            resultingTone = 'low tone';
          } else if (consonantClass == 'low') {
            resultingTone = syllableTypeManual == 'live' ? 'falling tone' : 'high tone';
          }
        } else if (character == '้') { // Mai Tho
          if (consonantClass == 'mid' || consonantClass == 'high') {
            resultingTone = 'falling tone';
          } else if (consonantClass == 'low') {
            resultingTone = 'high tone';
          }
        }
        
        if (resultingTone.isNotEmpty) {
          final syllableExplanation = syllableTypeManual == 'live' 
              ? 'Live syllables end with long vowels or sonorant consonants (ง, น, ม, ย, ว) - the sound flows or continues.'
              : 'Dead syllables end with short vowels or stop consonants (ก, ด, บ - k, t, p sounds) - the sound cuts off abruptly.';
          
          final enhancedExplanation = 'Sound: ${_capitalize(consonantClass)} class consonant ($consonantInWord - $consonantName) + $toneMarkName + $syllableTypeManual syllable = $resultingTone. $syllableExplanation';
          tips.add(enhancedExplanation);
        } else {
          tips.add('Sound: $toneMarkName effect depends on consonant class and syllable type');
        }
      } else {
        tips.add('Sound: $toneMarkName effect depends on consonant class and syllable type');
      }
    }
    
    // Writing instructions are handled in the main step card area as white text
    // (not in contextual tips to match consonant card formatting)

    return tips.join('\n');
  }

  /// Extract tone result from formula string
  String _extractToneFromFormula(String formula) {
    // Extract the tone result from a formula like "Low class + Mai Ek + live syllable = Falling tone"
    final parts = formula.split('=');
    if (parts.length >= 2) {
      return parts[1].trim().toLowerCase();
    }
    return 'tone';
  }

  /// Get English-friendly explanation of tone effects
  String _getToneEnglishEffect(String toneType) {
    switch (toneType) {
      case 'falling_tone':
        return 'Like saying "Oh!" with surprise (high→low)';
      case 'rising_tone':
        return 'Like asking "Really?" (low→high)';
      case 'high_tone':
        return 'Like saying "YES!" with excitement (high, sharp)';
      case 'low_tone':
        return 'Like saying "hmm" thoughtfully (low, flat)';
      case 'mid_tone':
        return 'Like normal speaking voice (neutral, flat)';
      default:
        return 'Changes the pitch pattern of the syllable';
    }
  }

  /// Generate other mark contextual tips (thanthakhat, mai yamok, etc.)
  String _getOtherMarkContextualTip(String character, Map<String, dynamic> charInfo, String syllable) {
    final tips = <String>[];

    // Get other mark information from JSON
    final otherMarkInfo = _getOtherMarkInfo(character);
    final name = otherMarkInfo['name'] as String? ?? '';
    final function = otherMarkInfo['function'] as String? ?? '';
    
    if (name.isNotEmpty && function.isNotEmpty) {
      // Consolidated sound explanation with specific effects
      if (character == '์') { // Thanthakhat
        final silencedConsonants = _detectSilencedConsonants(syllable);
        if (silencedConsonants.isNotEmpty) {
          final consonantList = silencedConsonants.values.join(', ');
          tips.add('Sound: $name ($function). Silent mark that silences the consonant(s) it appears above: $consonantList');
        } else {
          tips.add('Sound: $name ($function). Silent mark that silences the consonant it is placed above');
        }
      } else if (character == 'ๆ') { // Mai Yamok
        tips.add('Sound: $name ($function). Silent mark that signals repetition of the preceding word or phrase');
      } else {
        tips.add('Sound: $name ($function). This mark is silent and not pronounced');
      }
    } else {
      // Fallback if JSON data not found
      tips.add('Sound: Silent mark - not pronounced');
    }

    return tips.join('\n');
  }

  /// Get pronunciation information for display next to character
  String _getPronunciationForDisplay(String character, [String? contextWord]) {
    final charType = _getCharacterType(character);
    final charInfo = _getDetailedCharacterInfo(character);
    
    switch (charType) {
      case 'consonant':
        final pronunciationData = charInfo?['pronunciation'] as Map<String, dynamic>?;
        final initial = pronunciationData?['initial'] as String? ?? '';
        // Just show the basic sound without slashes
        return initial;
        
      case 'vowel':
        final romanization = charInfo?['pronunciation']?['romanization'] as String? ?? '';
        // Just show the vowel sound without slashes
        return romanization;
        
      case 'tone':
        // For tone marks, show just the tone result
        if (contextWord != null && contextWord.isNotEmpty) {
          final toneAnalysis = _calculateComprehensiveTone(contextWord);
          final tone = toneAnalysis['tone'] as String? ?? '';
          final toneName = tone.replaceAll('_tone', '').replaceAll('_', ' ');
          return toneName;
        } else {
          return '';
        }
        
      case 'other_mark':
        // Other marks (thanthakhat, mai yamok) are silent
        return 'Silent';
        
      default:
        return '';
    }
  }



  /// Get English sound reference for a character
  String _getEnglishSoundReference(String character) {
    final charInfo = _getDetailedCharacterInfo(character);
    final pronunciation = charInfo?['pronunciation'] as Map<String, dynamic>?;
    final initial = pronunciation?['initial'] as String? ?? '';
    
    // Map Thai sounds to English examples
    final soundMap = {
      'g': '/g/ like "go"',
      'k': '/k/ like "key"',
      'kh': '/kh/ like "k" + puff of air',
      'ng': '/ng/ like "sing"',
      'j': '/j/ like "jet"',
      'ch': '/ch/ like "chair"',
      's': '/s/ like "see"',
      'd': '/d/ like "do"',
      't': '/t/ like "stop"',
      'th': '/th/ like "t" + puff of air',
      'n': '/n/ like "no"',
      'b': '/b/ like "boy"',
      'p': '/p/ like "spin"',
      'ph': '/ph/ like "p" + puff of air',
      'f': '/f/ like "four"',
      'm': '/m/ like "me"',
      'y': '/y/ like "yes"',
      'r': '/r/ like Spanish rr',
      'l': '/l/ like "love"',
      'w': '/w/ like "we"',
      'h': '/h/ like "hello"',
      'o': '/o/ vowel carrier',
    };

    return soundMap[initial] ?? initial;
  }

  /// Get tone instruction for English speakers (enhanced version)
  String _getToneInstructionForEnglishSpeakers(String toneEffect) {
    final instructions = {
      'low_tone': 'Lower pitch, like saying "mmm-hmm" when agreeing',
      'mid_tone': 'Natural speaking pitch - no special melody needed',
      'high_tone': 'Higher pitch, like asking "really?" with surprise',
      'rising_tone': 'Start low, end high - like asking a question',
      'falling_tone': 'Start high, drop down - like saying "no" definitively',
    };

    return instructions[toneEffect] ?? 'Follow the pitch pattern for this tone';
  }

  // ============================================================================
  // COMPREHENSIVE THAI TONE ANALYSIS SYSTEM
  // ============================================================================

  /// Analyze syllable structure for comprehensive tone calculation
  Map<String, dynamic> _analyzeSyllableStructure(String syllable) {
    final analysis = {
      'mainConsonant': null,
      'consonantClass': null,
      'finalConsonant': null,
      'finalConsonantType': null, // 'sonorant', 'obstruent', or null
      'vowels': <String>[],
      'vowelLength': null, // 'short' or 'long'
      'toneMarks': <String>[],
      'isLive': false,
      'isDead': false,
    };

    final chars = syllable.split('');
    
    // Find main consonant (usually first consonant)
    for (int i = 0; i < chars.length; i++) {
      if (_getCharacterType(chars[i]) == 'consonant') {
        analysis['mainConsonant'] = chars[i];
        final consonantInfo = _getDetailedCharacterInfo(chars[i]);
        analysis['consonantClass'] = consonantInfo?['consonant_class'] ?? consonantInfo?['class'];
        break;
      }
    }

    // Find final consonant (last consonant)
    for (int i = chars.length - 1; i >= 0; i--) {
      if (_getCharacterType(chars[i]) == 'consonant') {
        analysis['finalConsonant'] = chars[i];
        analysis['finalConsonantType'] = _getConsonantType(chars[i]);
        break;
      }
    }

    // Collect vowels and tone marks
    for (final char in chars) {
      final type = _getCharacterType(char);
      if (type == 'vowel') {
        (analysis['vowels'] as List<String>).add(char);
      } else if (type == 'tone') {
        (analysis['toneMarks'] as List<String>).add(char);
      }
    }

    // Determine vowel length
    analysis['vowelLength'] = _determineVowelLength(analysis['vowels'] as List<String>);

    // Determine if syllable is live or dead
    if (analysis['finalConsonant'] == null) {
      // Ends with vowel - live syllable
      analysis['isLive'] = true;
    } else if (analysis['finalConsonantType'] == 'sonorant') {
      // Ends with sonorant consonant - live syllable
      analysis['isLive'] = true;
    } else {
      // Ends with obstruent consonant - dead syllable
      analysis['isDead'] = true;
    }

    return analysis;
  }

  /// Determine if a consonant is sonorant or obstruent
  String _getConsonantType(String consonant) {
    // Sonorant consonants (voiced, allow airflow)
    const sonorants = ['ม', 'น', 'ง', 'ญ', 'ณ', 'ย', 'ร', 'ล', 'ว'];
    
    // Obstruent consonants (stops, blocks airflow)
    const obstruents = ['ป', 'ต', 'ก', 'บ', 'ด', 'พ', 'ท', 'ค', 'ภ', 'ธ', 'ข', 'ผ', 'ถ', 'ฉ', 'ช', 'จ', 'ซ', 'ส', 'ศ', 'ษ', 'ห', 'ฮ', 'ฟ', 'ฝ'];
    
    if (sonorants.contains(consonant)) {
      return 'sonorant';
    } else if (obstruents.contains(consonant)) {
      return 'obstruent';
    }
    return 'unknown';
  }

  /// Determine vowel length from vowel characters
  String _determineVowelLength(List<String> vowels) {
    if (vowels.isEmpty) return 'short';
    
    // Long vowels (short vowels determined by absence of long markers)
    const longVowels = ['า', 'ี', 'ื', 'ู', 'เ◌', 'แ◌', 'โ◌', 'ไ◌', 'ใ◌', 'เ◌า', 'เ◌อ', 'เ◌ีย', 'เ◌ือ', 'ัว', 'ัย'];
    
    // Check against vowel patterns from JSON
    for (final vowel in vowels) {
      final vowelInfo = _getDetailedCharacterInfo(vowel);
      final vowelKey = vowelInfo?['character'] ?? vowel;
      
      if (longVowels.any((pattern) => pattern.contains(vowel) || vowelKey.contains(pattern.replaceAll('◌', '')))) {
        return 'long';
      }
    }
    
    return 'short';
  }

  /// Calculate tone for a syllable using comprehensive Thai rules from JSON
  Map<String, dynamic> _calculateComprehensiveTone(String syllable) {
    final analysis = _analyzeSyllableStructure(syllable);
    
    final consonantClass = analysis['consonantClass'] as String? ?? '';
    final isLive = analysis['isLive'] as bool? ?? false;
    final isDead = analysis['isDead'] as bool? ?? false;
    final toneMarks = analysis['toneMarks'] as List<String>? ?? [];
    
    String resultTone;
    String explanation;
    
    if (toneMarks.isNotEmpty) {
      // Has tone mark - use tone mark rules from JSON
      final toneMark = toneMarks.first;
      resultTone = _getToneMarkEffectFromJSON(toneMark, consonantClass);
      final toneMarkName = _getToneMarkName(toneMark);
      explanation = '$toneMarkName ($toneMark) + $consonantClass class consonant = $resultTone';
    } else {
      // No tone mark - use default tone rules from JSON
      resultTone = _getDefaultToneFromJSON(consonantClass, isLive, isDead);
      final syllableType = isLive ? 'live' : 'dead';
      explanation = '$consonantClass class + $syllableType syllable = $resultTone';
    }
    
    return {
      'tone': resultTone,
      'explanation': explanation,
      'analysis': analysis,
      'toneDescription': _getToneDescriptionFromJSON(resultTone),
      'pronunciationTip': _getToneInstructionForEnglishSpeakers(resultTone),
    };
  }

  /// Get tone mark effect using JSON data
  String _getToneMarkEffectFromJSON(String toneMark, String consonantClass) {
    if (_thaiWritingGuideData == null) return '';
    
    final pronunciationSystem = _thaiWritingGuideData!['pronunciation_system'] as Map<String, dynamic>?;
    final toneMarkRules = pronunciationSystem?['tone_mark_rules'] as Map<String, dynamic>?;
    
    if (toneMarkRules == null) return '';

    for (final markData in toneMarkRules.values) {
      final markInfo = markData as Map<String, dynamic>;
      if (markInfo['character'] == toneMark) {
        final effectByClass = markInfo['effect_by_consonant_class'] as Map<String, dynamic>?;
        return effectByClass?[consonantClass] as String? ?? '';
      }
    }
    return '';
  }

  /// Get tone mark information from JSON
  Map<String, dynamic> _getToneMarkInfoFromJSON(String toneMark) {
    if (_thaiWritingGuideData == null) return {};
    
    // Look in the tone_marks section for name and other info
    final toneMarks = _thaiWritingGuideData!['tone_marks'] as Map<String, dynamic>?;
    if (toneMarks != null && toneMarks.containsKey(toneMark)) {
      return toneMarks[toneMark] as Map<String, dynamic>;
    }
    
    // Fallback to pronunciation_system.tone_mark_rules for effect info
    final pronunciationSystem = _thaiWritingGuideData!['pronunciation_system'] as Map<String, dynamic>?;
    final toneMarkRules = pronunciationSystem?['tone_mark_rules'] as Map<String, dynamic>?;
    
    if (toneMarkRules == null) return {};

    for (final markData in toneMarkRules.values) {
      final markInfo = markData as Map<String, dynamic>;
      if (markInfo['character'] == toneMark) {
        return markInfo;
      }
    }
    return {};
  }

  /// Get other mark information from JSON (thanthakhat, mai yamok)
  Map<String, dynamic> _getOtherMarkInfo(String otherMark) {
    if (_thaiWritingGuideData == null) return {};
    
    final otherMarks = _thaiWritingGuideData!['other_marks'] as Map<String, dynamic>?;
    if (otherMarks != null && otherMarks.containsKey(otherMark)) {
      return otherMarks[otherMark] as Map<String, dynamic>;
    }
    
    return {};
  }

  /// Detect consonants silenced by thanthakhat marks
  Map<int, String> _detectSilencedConsonants(String syllable) {
    final Map<int, String> silencedConsonants = {};
    final characters = syllable.split('');
    
    for (int i = 0; i < characters.length; i++) {
      final char = characters[i];
      
      // Check if this is a thanthakhat
      if (char == '์') {
        // Find the consonant it silences (usually the preceding consonant)
        for (int j = i - 1; j >= 0; j--) {
          final prevChar = characters[j];
          if (_getCharacterType(prevChar) == 'consonant') {
            silencedConsonants[j] = prevChar;
            break;
          }
        }
      }
    }
    
    return silencedConsonants;
  }

  /// Generate silencing explanation for pronunciation guide
  String _generateSilencingExplanation(String consonant, String syllable) {
    final otherMarkInfo = _getOtherMarkInfo('์');
    final function = otherMarkInfo['function'] as String? ?? 'Silencing Mark';
    final effect = otherMarkInfo['pronunciation_guide'] as String? ?? 'This mark silences the consonant';
    
    return 'The consonant "$consonant" is silenced by thanthakhat (์). $effect';
  }

  /// Detect repetition marks (Mai Yamok) and generate explanations
  Map<int, String> _detectRepetitionMarks(String syllable) {
    final Map<int, String> repetitionMarks = {};
    final characters = syllable.split('');
    
    for (int i = 0; i < characters.length; i++) {
      final char = characters[i];
      
      // Check if this is a Mai Yamok
      if (char == 'ๆ') {
        // Find the word or phrase to be repeated (usually everything before this mark)
        final precedingText = characters.take(i).join('');
        repetitionMarks[i] = precedingText;
      }
    }
    
    return repetitionMarks;
  }

  /// Generate repetition explanation for pronunciation guide
  String _generateRepetitionExplanation(String repeatedText) {
    final otherMarkInfo = _getOtherMarkInfo('ๆ');
    final function = otherMarkInfo['function'] as String? ?? 'Repetition Mark';
    final effect = otherMarkInfo['pronunciation_guide'] as String? ?? 'This mark signals repetition';
    
    return 'Mai Yamok (ๆ) indicates that "$repeatedText" should be repeated. $effect';
  }

  /// Get tone mark name from JSON
  String _getToneMarkName(String toneMark) {
    if (_thaiWritingGuideData == null) return '';
    
    // First check tone_marks section for name
    final toneMarks = _thaiWritingGuideData!['tone_marks'] as Map<String, dynamic>?;
    if (toneMarks != null && toneMarks.containsKey(toneMark)) {
      final markData = toneMarks[toneMark] as Map<String, dynamic>;
      final name = markData['name'] as String? ?? '';
      if (name.isNotEmpty) return name;
    }
    
    // Fallback to pronunciation_system.tone_mark_rules
    final pronunciationSystem = _thaiWritingGuideData!['pronunciation_system'] as Map<String, dynamic>?;
    final toneMarkRules = pronunciationSystem?['tone_mark_rules'] as Map<String, dynamic>?;
    
    if (toneMarkRules == null) return '';

    for (final markData in toneMarkRules.values) {
      final markInfo = markData as Map<String, dynamic>;
      if (markInfo['character'] == toneMark) {
        return markInfo['name'] as String? ?? '';
      }
    }
    return '';
  }

  /// Get default tone using JSON data
  String _getDefaultToneFromJSON(String consonantClass, bool isLive, bool isDead) {
    if (_thaiWritingGuideData == null) return 'mid_tone';
    
    final pronunciationSystem = _thaiWritingGuideData!['pronunciation_system'] as Map<String, dynamic>?;
    final toneMarkRules = pronunciationSystem?['tone_mark_rules'] as Map<String, dynamic>?;
    final defaultTones = toneMarkRules?['default_tones'] as Map<String, dynamic>?;
    
    if (defaultTones == null) return 'mid_tone';
    
    final effectByClass = defaultTones['effect_by_consonant_class'] as Map<String, dynamic>?;
    final classRules = effectByClass?[consonantClass] as Map<String, dynamic>?;
    
    if (classRules == null) return 'mid_tone';
    
    if (isLive) {
      return classRules['live_syllable'] as String? ?? 'mid_tone';
    } else {
      return classRules['dead_syllable'] as String? ?? 'low_tone';
    }
  }

  /// Get tone description from JSON data
  String _getToneDescriptionFromJSON(String toneType) {
    if (_thaiWritingGuideData == null) return _getToneDescription(toneType);
    
    final pronunciationSystem = _thaiWritingGuideData!['pronunciation_system'] as Map<String, dynamic>?;
    final toneDescriptions = pronunciationSystem?['tone_descriptions'] as Map<String, dynamic>?;
    
    if (toneDescriptions == null) return _getToneDescription(toneType);
    
    final toneInfo = toneDescriptions[toneType] as Map<String, dynamic>?;
    if (toneInfo == null) return _getToneDescription(toneType);
    
    final description = toneInfo['description'] as String? ?? '';
    final thaiName = toneInfo['thai_name'] as String? ?? '';
    final pitch = toneInfo['relative_pitch'] as String? ?? '';
    
    return '$description (Thai: $thaiName, Pitch: $pitch)';
  }

  /// Calculate complete syllable pronunciation for English speakers
  String _calculateCompleteSyllablePronunciation(String syllable) {
    final chars = syllable.split('');
    
    String pronunciation = '';
    
    // Process characters in phonetic order (not visual order)
    for (int i = 0; i < chars.length; i++) {
      final char = chars[i];
      final charType = _getCharacterType(char);
      
      if (charType == 'consonant') {
        final charInfo = _getDetailedCharacterInfo(char);
        final pronunciationData = charInfo?['pronunciation'] as Map<String, dynamic>?;
        
        if (i == 0) {
          // Initial consonant
          pronunciation += pronunciationData?['initial'] as String? ?? '';
        } else if (i == chars.length - 1) {
          // Final consonant
          final finalSound = pronunciationData?['final'] as String?;
          if (finalSound != null) {
            pronunciation += finalSound;
          }
        }
      } else if (charType == 'vowel') {
        final charInfo = _getDetailedCharacterInfo(char);
        final romanization = charInfo?['pronunciation']?['romanization'] as String? ?? '';
        if (romanization.isNotEmpty) {
          pronunciation += romanization;
        }
      }
    }
    
    // Add tone indication if present
    final toneAnalysis = _calculateComprehensiveTone(syllable);
    final tone = toneAnalysis['tone'] as String?;
    if (tone != null && tone != 'mid_tone') {
      final toneSymbol = _getToneSymbol(tone);
      if (toneSymbol.isNotEmpty) {
        pronunciation = '$toneSymbol$pronunciation';
      }
    }
    
    return pronunciation.isEmpty ? syllable : pronunciation;
  }

  /// Get tone symbol for pronunciation display
  String _getToneSymbol(String toneType) {
    switch (toneType) {
      case 'low_tone':
        return 'ˋ'; // Low tone mark
      case 'falling_tone':
        return 'ˆ'; // Falling tone mark
      case 'high_tone':
        return 'ˊ'; // High tone mark
      case 'rising_tone':
        return 'ˇ'; // Rising tone mark
      default:
        return '';
    }
  }

  /// Get character's contribution to syllable pronunciation
  String _getCharacterContribution(String character, String syllable, int positionInSyllable) {
    final charType = _getCharacterType(character);
    final charInfo = _getDetailedCharacterInfo(character);
    
    switch (charType) {
      case 'consonant':
        final pronunciationData = charInfo?['pronunciation'] as Map<String, dynamic>?;
        if (positionInSyllable == 0) {
          // Initial position
          final initial = pronunciationData?['initial'] as String? ?? '';
          return initial.isNotEmpty ? '/$initial/ (initial)' : '';
        } else if (positionInSyllable == syllable.length - 1) {
          // Final position
          final finalSound = pronunciationData?['final'] as String?;
          return finalSound != null ? '/$finalSound/ (final)' : '(cannot end syllables)';
        } else {
          // Middle position
          final initial = pronunciationData?['initial'] as String? ?? '';
          return initial.isNotEmpty ? '/$initial/ (middle)' : '';
        }
        
      case 'vowel':
        final romanization = charInfo?['pronunciation']?['romanization'] as String? ?? '';
        final length = _isLongVowel(character) ? 'long' : 'short';
        return romanization.isNotEmpty ? '/$romanization/ ($length)' : '';
        
      case 'tone':
        final toneAnalysis = _calculateComprehensiveTone(syllable);
        final tone = toneAnalysis['tone'] as String?;
        return _getToneDisplayName(tone ?? '');
        
      default:
        return '';
    }
  }

  /// Check if vowel is long
  bool _isLongVowel(String vowel) {
    const longVowels = ['า', 'ี', 'ื', 'ู', 'เ', 'แ', 'โ', 'ไ', 'ใ'];
    return longVowels.contains(vowel);
  }

  /// Get user-friendly tone display name
  String _getToneDisplayName(String toneType) {
    switch (toneType) {
      case 'mid_tone':
        return 'Creates mid tone';
      case 'low_tone':
        return 'Creates low tone';
      case 'falling_tone':
        return 'Creates falling tone';
      case 'high_tone':
        return 'Creates high tone';
      case 'rising_tone':
        return 'Creates rising tone';
      default:
        return 'Modifies tone';
    }
  }

  /// Get English equivalent explanation for complete syllable
  String _getEnglishEquivalent(String syllable) {
    final pronunciation = _calculateCompleteSyllablePronunciation(syllable);
    
    // Map common Thai syllables to English comparisons
    final equivalents = {
      'gaa': 'Like "gah" but longer',
      'ka': 'Like "ka" in "car"',
      'ge': 'Like "gay" but shorter',
      'ko': 'Like "go"',
      'ki': 'Like "key" but shorter',
      'kuu': 'Like "coo"',
      'baa': 'Like "bah"',
      'dii': 'Like "dee"',
      'maa': 'Like "ma" but longer',
      'naa': 'Like "nah"',
      'raa': 'Like "rah"',
      'laa': 'Like "lah"',
    };
    
    final lowerPronunciation = pronunciation.toLowerCase().replaceAll(RegExp(r'[ˋˆˊˇ]'), '');
    return equivalents[lowerPronunciation] ?? 'Unique Thai sound';
  }

  /// Explain how character combines with others in syllable
  String _explainCombination(String character, String syllable) {
    final charType = _getCharacterType(character);
    final position = syllable.indexOf(character);
    
    switch (charType) {
      case 'consonant':
        if (position == 0) {
          return 'This consonant starts the syllable sound';
        } else {
          return 'This consonant ends the syllable with a different sound';
        }
        
      case 'vowel':
        final charInfo = _getDetailedCharacterInfo(character);
        final vowelPosition = charInfo?['position'] as String?;
        
        switch (vowelPosition) {
          case 'before':
            return 'Thai trick! Written first but pronounced AFTER the consonant';
          case 'after':
            return 'Combines with consonant in the order written';
          case 'above':
          case 'below':
            return 'Attached to consonant and pronounced right after it';
          case 'surrounding':
            return 'Complex vowel that wraps around the consonant';
          default:
            return 'Combines with the consonant to make the syllable sound';
        }
        
      case 'tone':
        return 'Changes the pitch pattern of the entire syllable';
        
      default:
        return 'Part of the complete syllable sound';
    }
  }
  
  /// Build contextual pronunciation section UI for step cards
  List<Widget> _buildContextualPronunciationSection(String character, int characterIndex) {
    // Determine syllable and position
    // For complex vowel detection, we need the full word context
    String syllable = _originalWord.isNotEmpty ? _originalWord : character;
    int positionInSyllable = characterIndex;
    
    
    final contextualTip = _getContextualPronunciationTip(character, syllable, positionInSyllable);
    
    if (contextualTip.isEmpty) {
      return [];
    }
    
    // Split the contextual tip into lines for better formatting
    final tipLines = contextualTip.split('\n').where((line) => line.trim().isNotEmpty).toList();
    
    final widgets = <Widget>[];
    
    for (final line in tipLines) {
      widgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _getContextualTipColor(line).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _getContextualTipColor(line).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Text(
            line,
            style: TextStyle(
              fontSize: 12,
              color: _getContextualTipColor(line),
              height: 1.3,
              fontWeight: line.startsWith('Sound:') || line.startsWith('Effect:') || line.startsWith('Writing:') || line.startsWith('Role:') ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      );
    }
    
    return widgets;
  }
  
  /// Get color based on tip type (text prefix)
  Color _getContextualTipColor(String tipLine) {
    if (tipLine.startsWith('Sound:')) {
      return const Color(0xFF4ECCA3); // Sound - primary green
    } else if (tipLine.startsWith('Effect:')) {
      return const Color(0xFFE91E63); // Effect - pink (for tone calculations)
    } else if (tipLine.startsWith('Writing:')) {
      return const Color(0xFFFFC107); // Writing - amber (legacy)
    } else if (tipLine.startsWith('Role:')) {
      return const Color(0xFF2196F3); // Role - blue
    } else {
      return const Color(0xFF4ECCA3); // Default
    }
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