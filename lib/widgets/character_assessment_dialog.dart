import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../models/character_assessment_model.dart';
import '../providers/game_providers.dart';
import 'shared/app_styles.dart';
import 'package:babblelon/screens/main_screen/widgets/glassmorphic_card.dart';

/// Dialog that displays writing assessment results with prominent score and sound effects
class CharacterAssessmentDialog extends ConsumerStatefulWidget {
  /// The assessment results to display
  final TracingAssessmentResult assessmentResult;
  
  /// Character names for display
  final List<String> characterNames;
  
  /// Original vocabulary item for transliteration and translation data
  final Map<String, dynamic>? originalVocabularyItem;
  
  /// Called when user dismisses the dialog
  final VoidCallback onDismiss;
  
  /// NPC ID for item giving functionality
  final String? npcId;
  
  /// NPC name for display in button
  final String? npcName;
  
  /// Called when user wants to give item to NPC
  final VoidCallback? onGiveItem;

  const CharacterAssessmentDialog({
    super.key,
    required this.assessmentResult,
    required this.characterNames,
    this.originalVocabularyItem,
    required this.onDismiss,
    this.npcId,
    this.npcName,
    this.onGiveItem,
  });

  @override
  ConsumerState<CharacterAssessmentDialog> createState() => _CharacterAssessmentDialogState();
}

class _CharacterAssessmentDialogState extends ConsumerState<CharacterAssessmentDialog>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _scaleController;
  late AnimationController _slideController;
  late AnimationController _numberController;
  late AnimationController _progressController;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _numberAnimation;
  late Animation<double> _progressAnimation;
  int _currentPage = 0;
  
  // Audio for score animation and word playback
  late AudioPlayer _soundEffectsPlayer;
  late AudioPlayer _wordAudioPlayer;
  Timer? _soundEffectTimer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Initialize audio players
    _soundEffectsPlayer = AudioPlayer();
    _wordAudioPlayer = AudioPlayer();
    
    // Initialize multiple animation controllers for staggered animations
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _numberController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Setup animations with proper curves
    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _numberAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _numberController,
      curve: Curves.easeOutCubic,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));

    // Start staggered animations
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _slideController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _numberController.forward();
      _playCountingNumbersSound(); // Play sound effect with number animation
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      _progressController.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scaleController.dispose();
    _slideController.dispose();
    _numberController.dispose();
    _progressController.dispose();
    _soundEffectsPlayer.dispose();
    _wordAudioPlayer.dispose();
    _soundEffectTimer?.cancel();
    super.dispose();
  }
  
  /// Play counting numbers sound effect during score animation
  Future<void> _playCountingNumbersSound() async {
    try {
      final soundEffectsEnabled = ref.read(gameStateProvider).soundEffectsEnabled;
      if (soundEffectsEnabled) {
        await _soundEffectsPlayer.setAsset('assets/audio/soundeffects/soundeffect_increasingnumber.mp3');
        _soundEffectsPlayer.play();
        
        // Stop the audio after animation duration
        _soundEffectTimer = Timer(const Duration(milliseconds: 1200), () {
          _soundEffectsPlayer.stop();
        });
      }
    } catch (e) {
      print('Error playing counting numbers sound: $e');
    }
  }
  
  /// Play word audio pronunciation
  Future<void> _playWordAudio() async {
    try {
      if (widget.originalVocabularyItem != null) {
        final audioPath = widget.originalVocabularyItem!['audio_path'] as String?;
        if (audioPath != null && audioPath.isNotEmpty) {
          await _wordAudioPlayer.setAsset(audioPath);
          _wordAudioPlayer.play();
        }
      }
    } catch (e) {
      print('Error playing word audio: $e');
    }
  }
  // void _playScoreSound() async {
  //   // Sound effect implementation
  // }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 600;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(isSmallScreen ? 10.0 : 20.0),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: GlassmorphicCard(
            padding: EdgeInsets.zero,
            blur: 20,
            opacity: 0.15,
            margin: EdgeInsets.zero,
            child: Container(
              constraints: BoxConstraints(
                maxHeight: screenSize.height * 0.85,
                maxWidth: isSmallScreen ? screenSize.width * 0.95 : 500,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: _buildSinglePageContent(),
                  ),
                  _buildNavigationControls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Color(widget.assessmentResult.getGradeColor()),
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.assessmentResult.overallGrade,
                style: AppStyles.titleTextStyle.copyWith(
                  fontSize: 24,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Character Assessment Results',
                  style: AppStyles.subtitleTextStyle,
                ),
                Text(
                  '${widget.assessmentResult.getTracedCount()} of ${widget.assessmentResult.totalCount} characters traced',
                  style: AppStyles.smallTextStyle,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: widget.onDismiss,
            icon: const Icon(
              Icons.close,
              color: AppStyles.textColor,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinglePageContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // No close button - continue button provides exit mechanism
          
          // Writing Assessment Score (Most Prominent)
          _buildProminentScoreSection(),
          
          const SizedBox(height: 32),
          
          // Word Breakdown Section
          _buildWordBreakdownSection(),
          
          const SizedBox(height: 24),
          
          // Detailed Breakdown with tooltips
          _buildDetailedBreakdownSection(),
          
          const SizedBox(height: 24),
          
          // Character Accuracy
          _buildCharacterAccuracySection(),
        ],
      ),
    );
  }
  
  Widget _buildWordBreakdownSection() {
    final wordText = widget.characterNames.join('');
    
    // Get transliteration and translation from original vocabulary item
    String transliteration;
    String translation;
    
    if (widget.originalVocabularyItem != null) {
      // First try direct fields
      transliteration = widget.originalVocabularyItem!['transliteration'] as String? ?? '';
      translation = widget.originalVocabularyItem!['translation'] as String? ?? '';
      
      // Try alternative field names for NPC vocabulary
      if (transliteration.isEmpty) {
        transliteration = widget.originalVocabularyItem!['word_translit'] as String? ?? '';
      }
      if (translation.isEmpty) {
        translation = widget.originalVocabularyItem!['word_eng'] as String? ?? '';
        // Try other possible field names
        if (translation.isEmpty) {
          translation = widget.originalVocabularyItem!['english'] as String? ?? '';
        }
        if (translation.isEmpty) {
          translation = widget.originalVocabularyItem!['meaning'] as String? ?? '';
        }
      }
      
      // If still not available, try to get from wordMapping
      if (transliteration.isEmpty || translation.isEmpty) {
        final wordMapping = widget.originalVocabularyItem!['wordMapping'] as List<dynamic>? ?? [];
        if (wordMapping.isNotEmpty) {
          if (transliteration.isEmpty) {
            transliteration = wordMapping.map((m) => m['transliteration'] ?? m['word_translit'] ?? '').join(' ');
          }
          if (translation.isEmpty) {
            translation = wordMapping.map((m) => m['translation'] ?? m['word_eng'] ?? '').join(' ');
          }
        }
      }
      
      // Debug: print available fields for NPC vocabulary
      if (translation.isEmpty) {
        print('Available fields in originalVocabularyItem: ${widget.originalVocabularyItem!.keys.toList()}');
      }
    } else {
      // Fallback to assessment result or character breakdown
      transliteration = widget.assessmentResult.transliteration ?? widget.characterNames.join(' ');
      translation = widget.assessmentResult.translation ?? 'Unknown';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1), // Glassmorphic background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Word:',
            style: AppStyles.bodyTextStyle.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          // Single row with all word information
          Row(
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: wordText,
                        style: AppStyles.titleTextStyle.copyWith(
                          fontSize: 20,
                          color: const Color(0xFF6366F1), // Ethereal blue
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: ' ($transliteration) → $translation',
                        style: AppStyles.bodyTextStyle.copyWith(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _playWordAudio,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.volume_up,
                    color: Color(0xFF6366F1),
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildProminentScoreSection() {
    return Center(
      child: Column(
        children: [
          // Grade circle
          AnimatedBuilder(
            animation: _scaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: _getGradeGradient(widget.assessmentResult.overallGrade),
                    shape: BoxShape.circle,
                    boxShadow: [
                      // Outer glow
                      BoxShadow(
                        color: _getGradeColor(widget.assessmentResult.overallGrade).withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 0),
                      ),
                      // Neumorphic shadow
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                      // Inner highlight
                      BoxShadow(
                        color: Colors.white.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(-2, -2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      widget.assessmentResult.overallGrade,
                      style: AppStyles.titleTextStyle.copyWith(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          Text(
            'Writing Assessment',
            style: AppStyles.titleTextStyle.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Large animated score
          AnimatedBuilder(
            animation: _numberAnimation,
            builder: (context, child) {
              final animatedAccuracy = widget.assessmentResult.overallAccuracy * _numberAnimation.value;
              return Text(
                '${animatedAccuracy.toStringAsFixed(0)} / 100',
                style: AppStyles.titleTextStyle.copyWith(
                  fontSize: 56,
                  color: AppStyles.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
          
          const SizedBox(height: 8),
          
          Text(
            _getAccuracyLabel(widget.assessmentResult.overallAccuracy),
            style: AppStyles.bodyTextStyle.copyWith(
              fontSize: 20,
              color: _getAccuracyColor(widget.assessmentResult.overallAccuracy),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDetailedBreakdownSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1), // Glassmorphic background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Writing Analysis',
            style: AppStyles.bodyTextStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildProgressRow(
            'Overall Accuracy', 
            widget.assessmentResult.overallAccuracy,
            const Color(0xFFEF4444), // Modern red
            'Overall handwriting quality score based on character recognition accuracy and completion.',
          ),
          const SizedBox(height: 12),
          _buildProgressRow(
            'Clarity', 
            _calculateRecognitionConfidence(),
            const Color(0xFF10B981), // Modern green
            'How clearly and consistently you wrote the characters that were recognized.',
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressRow(String label, double value, Color color, String tooltip) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: AppStyles.bodyTextStyle.copyWith(fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _showTooltipModal(context, label, tooltip, color),
          child: MouseRegion(
            onEnter: (_) => _showHoverTooltip(context, tooltip),
            onExit: (_) => _hideHoverTooltip(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color.withOpacity(0.7), width: 1.5),
                color: color.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.help_outline,
                size: 12,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Container(
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.grey[800],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (value / 100) * _progressAnimation.value,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 8,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 30,
          child: AnimatedBuilder(
            animation: _numberAnimation,
            builder: (context, child) {
              final animatedValue = value * _numberAnimation.value;
              return Text(
                '${animatedValue.toStringAsFixed(0)}',
                style: AppStyles.bodyTextStyle.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildCharacterAccuracySection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1), // Glassmorphic background
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recognition Rate',
            style: AppStyles.bodyTextStyle.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6366F1), // Ethereal blue
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Individual Syllable Results
          ...widget.assessmentResult.characterResults.entries.map((entry) {
                    final index = entry.key;
                    final result = entry.value;
                    final characterName = index < widget.characterNames.length 
                        ? widget.characterNames[index] 
                        : 'Character $index';
                    
                    // Get character-level transliteration and translation
                    String characterTranslit = '';
                    String characterTranslation = '';
                    
                    // Extract transliteration and translation from vocabulary data
                    if (widget.originalVocabularyItem != null) {
                      // Try multiple possible data structures
                      final wordMapping = widget.originalVocabularyItem!['word_mapping'] as List<dynamic>? 
                          ?? widget.originalVocabularyItem!['wordMapping'] as List<dynamic>? 
                          ?? [];
                      
                      if (index < wordMapping.length) {
                        final syllableData = wordMapping[index] as Map<String, dynamic>?;
                        if (syllableData != null) {
                          characterTranslit = syllableData['transliteration'] as String? ?? '';
                          characterTranslation = syllableData['translation'] as String? ?? '';
                        }
                      }
                      
                      // Fallback: try to get from main vocabulary item if individual syllable data isn't available
                      if (characterTranslit.isEmpty && characterTranslation.isEmpty && wordMapping.length == 1) {
                        characterTranslit = widget.originalVocabularyItem!['transliteration'] as String? ?? '';
                        characterTranslation = widget.originalVocabularyItem!['translation'] as String? 
                            ?? widget.originalVocabularyItem!['english'] as String? ?? '';
                      }
                    }
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Syllable header: Thai text + transliteration + translation
                          Row(
                            children: [
                              Text(
                                characterName,
                                style: AppStyles.titleTextStyle.copyWith(
                                  fontSize: 24,
                                  color: const Color(0xFF6366F1),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (characterTranslit.isNotEmpty || characterTranslation.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${characterTranslit.isNotEmpty ? '($characterTranslit)' : ''} ${characterTranslation.isNotEmpty ? '→ $characterTranslation' : ''}',
                                    style: AppStyles.bodyTextStyle.copyWith(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Individual character runes using existing method
                          _buildColorCodedCharacters(characterName, result),
                        ],
                      ),
                    );
                  }),
                  
                  const SizedBox(height: 16),
                  
                  // Legend at the bottom
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legend:',
                          style: AppStyles.bodyTextStyle.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildColorLegend(),
                      ],
                    ),
                  ),
        ],
      ),
    );
  }
  
  String _getAccuracyLabel(double accuracy) {
    if (accuracy >= 80) return 'Excellent';
    if (accuracy >= 60) return 'Good';
    if (accuracy >= 40) return 'Fair';
    return 'Needs Improvement';
  }
  
  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 80) return Colors.green[400]!;
    if (accuracy >= 60) return Colors.blue[400]!;
    if (accuracy >= 40) return Colors.orange[400]!;
    return Colors.red[400]!;
  }
  
  
  /// Calculate recognition confidence: average confidence from ML Kit
  double _calculateRecognitionConfidence() {
    final tracedResults = widget.assessmentResult.characterResults.values
        .where((result) => result.hasStrokes && result.candidates.isNotEmpty)
        .toList();
    
    if (tracedResults.isEmpty) return 0.0;
    
    // Calculate average confidence from ML Kit candidates
    double totalConfidence = 0.0;
    int validResults = 0;
    
    for (final result in tracedResults) {
      if (result.candidates.isNotEmpty) {
        // Use the confidence score (lower is better in ML Kit, so invert)
        final confidence = (1.0 - result.confidenceScore) * 100; // Convert to 0-100 scale
        totalConfidence += confidence.clamp(0.0, 100.0);
        validResults++;
      }
    }
    
    return validResults > 0 ? (totalConfidence / validResults).clamp(0.0, 100.0) : 0.0;
  }
  
  
  /// Extract individual character from a syllable
  String _getIndividualCharacter(String syllable, int index) {
    // For Thai text, we need to extract individual characters
    // Convert string to a list of characters using runes for proper Unicode handling
    final characters = syllable.runes.map<String>((rune) => String.fromCharCode(rune)).toList();
    
    // If we have character mapping data, use that first
    if (widget.originalVocabularyItem != null) {
      final wordMapping = widget.originalVocabularyItem!['wordMapping'] as List<dynamic>? ?? [];
      if (index < wordMapping.length) {
        final charData = wordMapping[index];
        // Try to get the individual character from the mapping
        final individualChar = charData['character'] as String? ?? charData['word_target'] as String? ?? '';
        if (individualChar.isNotEmpty && individualChar.length <= 3) { // Thai characters typically 1-3 Unicode points
          return individualChar;
        }
      }
    }
    
    // Fallback: If the syllable has multiple characters, try to extract the main character
    if (characters.length > 1) {
      // Find the main consonant (usually the first character that's not a tone mark or vowel modifier)
      for (final char in characters) {
        final codeUnit = char.codeUnits.first;
        // Thai consonants range (simplified check)
        if (codeUnit >= 0x0E01 && codeUnit <= 0x0E2E) {
          return char;
        }
      }
    }
    
    // If all else fails, return the first character or the whole syllable if it's short
    return characters.isNotEmpty ? characters.first : syllable;
  }
  
  /// Build color-coded individual characters with status badges
  Widget _buildColorCodedCharacters(String syllable, dynamic result) {
    // Break down syllable into individual characters
    final List<String> characters = syllable.runes.map<String>((rune) => String.fromCharCode(rune)).toList();
    final recognizedText = result.recognizedText ?? '';
    final List<String> recognizedChars = recognizedText.runes.map<String>((rune) => String.fromCharCode(rune)).toList();
    
    // Analyze each character's status
    final List<Widget> characterBadges = [];
    int correctCount = 0;
    final totalCount = characters.length;
    
    for (int i = 0; i < characters.length; i++) {
      final expectedChar = characters[i];
      Color backgroundColor;
      Color borderColor;
      Color textColor;
      IconData? statusIcon;
      String statusLabel;
      
      // Simple position-based matching logic
      if (!result.hasStrokes) {
        // No strokes at all - all characters are missing
        backgroundColor = Colors.red[400]!.withOpacity(0.2);
        borderColor = Colors.red[400]!;
        textColor = Colors.red[300]!;
        statusIcon = Icons.remove;
        statusLabel = 'Missing';
      } else if (i >= recognizedChars.length) {
        // Character missing from recognition - not traced
        backgroundColor = Colors.red[400]!.withOpacity(0.2);
        borderColor = Colors.red[400]!;
        textColor = Colors.red[300]!;
        statusIcon = Icons.remove;
        statusLabel = 'Missing';
      } else if (recognizedChars[i] != expectedChar) {
        // Character recognized incorrectly
        backgroundColor = Colors.amber[400]!.withOpacity(0.2);
        borderColor = Colors.amber[400]!;
        textColor = Colors.amber[700]!;
        statusIcon = Icons.close;
        statusLabel = 'Incorrect';
      } else {
        // Character correct
        backgroundColor = Colors.green[400]!.withOpacity(0.2);
        borderColor = Colors.green[400]!;
        textColor = Colors.green[300]!;
        statusIcon = Icons.check;
        statusLabel = 'Correct';
        correctCount++;
      }
      
      characterBadges.add(
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: Duration(milliseconds: 300 + (i * 100)),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _showIndividualCharacterTooltip(context, expectedChar, List<String>.from(recognizedChars), i),
                  child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: borderColor, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: borderColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            expectedChar,
                            style: AppStyles.bodyTextStyle.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          // Enhanced status icon
                          if (statusIcon != null)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: borderColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  statusIcon,
                                  size: 10,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          // Show actual character for incorrect ones
                          if (statusLabel == 'Incorrect' && i < recognizedChars.length)
                            Positioned(
                              top: 1,
                              left: 1,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.amber[400]!,
                                    width: 1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.5),
                                      blurRadius: 3,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  recognizedChars[i],
                                  style: TextStyle(
                                    color: Colors.amber[300],
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black.withOpacity(0.8),
                                        blurRadius: 1,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
          },
        ),
      );
    }
    
    // Calculate simple accuracy: correct count / total count
    final accuracy = totalCount > 0 ? (correctCount / totalCount * 100) : 0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Enhanced accuracy display with integrated progress bar
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: accuracy >= 80 ? Colors.green[400]!.withOpacity(0.3) : 
                     accuracy >= 60 ? Colors.lightGreen[400]!.withOpacity(0.3) :
                     accuracy >= 40 ? Colors.amber[400]!.withOpacity(0.3) : 
                     Colors.red[400]!.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'Recognition Rate',
                        style: AppStyles.bodyTextStyle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _showTooltipModal(
                          context, 
                          'Recognition Rate', 
                          'Percentage of characters that were successfully recognized by the handwriting system. This shows how clearly you wrote each character, with each character counting equally toward your recognition rate.',
                          const Color(0xFF6366F1),
                        ),
                        child: MouseRegion(
                          onEnter: (_) => _showHoverTooltip(
                            context, 
                            'Percentage of characters that were successfully recognized by the handwriting system. This shows how clearly you wrote each character, with each character counting equally toward your recognition rate.',
                          ),
                          onExit: (_) => _hideHoverTooltip(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.7), width: 1.5),
                              color: const Color(0xFF6366F1).withOpacity(0.1),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF6366F1).withOpacity(0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.help_outline,
                              size: 10,
                              color: Color(0xFF6366F1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accuracy >= 80 ? Colors.green[400]!.withOpacity(0.2) : 
                             accuracy >= 60 ? Colors.lightGreen[400]!.withOpacity(0.2) :
                             accuracy >= 40 ? Colors.amber[400]!.withOpacity(0.2) : 
                             Colors.red[400]!.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${accuracy.round()}%',
                      style: AppStyles.bodyTextStyle.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: accuracy >= 80 ? Colors.green[400]! : 
                               accuracy >= 60 ? Colors.lightGreen[400]! :
                               accuracy >= 40 ? Colors.amber[400]! : 
                               Colors.red[400]!,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Animated progress bar
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: accuracy / 100),
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: value,
                      backgroundColor: Colors.grey[700],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        accuracy >= 80 ? Colors.green[400]! : 
                        accuracy >= 60 ? Colors.lightGreen[400]! :
                        accuracy >= 40 ? Colors.amber[400]! : 
                        Colors.red[400]!,
                      ),
                      minHeight: 10,
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              Text(
                '$correctCount of $totalCount characters recognized successfully',
                style: AppStyles.smallTextStyle.copyWith(
                  fontSize: 12,
                  color: Colors.white60,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Character breakdown section
        Text(
          'Character Breakdown',
          style: AppStyles.bodyTextStyle.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        // Character badges with horizontal scroll
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...characterBadges,
                if (characterBadges.length > 7) ...[  // Add scroll indicator for many characters
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.white.withOpacity(0.3),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  /// Build color legend to explain character status colors
  Widget _buildColorLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem('Correct', Colors.green[400]!, Icons.check),
          _buildLegendItem('Incorrect', Colors.amber[400]!, Icons.error),
          _buildLegendItem('Missing', Colors.red[400]!, Icons.close),
        ],
      ),
    );
  }
  
  /// Build a single legend item
  Widget _buildLegendItem(String label, Color color, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(
            icon,
            size: 10,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppStyles.smallTextStyle.copyWith(
            fontSize: 10,
            color: Colors.white.withOpacity(0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  /// Generate comprehensive error message showing missing and incorrect characters
  String _getErrorMessage(String syllable, dynamic result) {
    final characters = syllable.runes.map<String>((rune) => String.fromCharCode(rune)).toList();
    
    // If no strokes at all, all characters are missing
    if (!result.hasStrokes) {
      return 'Missing: ${characters.join(', ')}';
    }
    
    // If strokes exist but recognition is wrong, analyze what's incorrect
    if (result.recognizedText.isNotEmpty && result.recognizedText != syllable) {
      final recognizedChars = result.recognizedText.runes.map<String>((rune) => String.fromCharCode(rune)).toList();
      final missingChars = <String>[];
      final incorrectChars = <String>[];
      
      // Compare character by character
      for (int i = 0; i < characters.length; i++) {
        if (i >= recognizedChars.length) {
          // Character is missing from recognition
          missingChars.add(characters[i]);
        } else if (characters[i] != recognizedChars[i]) {
          // Character was recognized but incorrectly
          incorrectChars.add(characters[i]);
        }
      }
      
      // Build comprehensive error message
      final List<String> errorParts = [];
      if (missingChars.isNotEmpty) {
        errorParts.add('Missing: ${missingChars.join(', ')}');
      }
      if (incorrectChars.isNotEmpty) {
        errorParts.add('Incorrect: ${incorrectChars.join(', ')}');
      }
      
      return errorParts.isNotEmpty ? errorParts.join(' | ') : 'Incorrect: ${_getIndividualCharacter(syllable, 0)}';
    }
    
    // Fallback for other error cases
    return 'Incorrect: ${_getIndividualCharacter(syllable, 0)}';
  }
  
  /// Get all missing characters within a syllable
  String _getAllMissingCharacters(String syllable, dynamic result) {
    // For now, break down the syllable into individual characters
    // This is a simplified implementation - in a real scenario, you'd need
    // more sophisticated Thai character analysis
    final characters = syllable.runes.map<String>((rune) => String.fromCharCode(rune)).toList();
    
    // If the entire syllable wasn't traced, all characters are missing
    if (!result.hasStrokes) {
      return characters.join(', ');
    }
    
    // For partially missing characters, this would require more detailed analysis
    // For now, return the main character (this is a placeholder)
    return _getIndividualCharacter(syllable, 0);
  }
  
  /// Get all incorrect characters within a syllable
  String _getAllIncorrectCharacters(String syllable, dynamic result) {
    // Break down the syllable into individual characters
    final characters = syllable.runes.map<String>((rune) => String.fromCharCode(rune)).toList();
    
    // Simple analysis: if the recognized text doesn't match, 
    // we assume certain characters are wrong
    if (result.recognizedText.isNotEmpty && result.recognizedText != syllable) {
      // Compare character by character (simplified)
      final recognizedChars = result.recognizedText.runes.map<String>((rune) => String.fromCharCode(rune)).toList();
      final incorrectChars = <String>[];
      
      for (int i = 0; i < characters.length; i++) {
        if (i >= recognizedChars.length || characters[i] != recognizedChars[i]) {
          incorrectChars.add(characters[i]);
        }
      }
      
      return incorrectChars.isNotEmpty ? incorrectChars.join(', ') : _getIndividualCharacter(syllable, 0);
    }
    
    return _getIndividualCharacter(syllable, 0);
  }

  /// Generate comprehensive error message distinguishing between missing and incorrect characters
  String _getComprehensiveErrorMessage(String syllable, dynamic result) {
    final characters = syllable.runes.map<String>((rune) => String.fromCharCode(rune)).toList();
    
    // If no strokes at all, all characters are missing
    if (!result.hasStrokes) {
      return 'Missing: ${characters.join(', ')}';
    }
    
    // If strokes exist but recognition is wrong, analyze what's missing vs incorrect
    if (result.recognizedText.isNotEmpty && result.recognizedText != syllable) {
      final recognizedChars = result.recognizedText.runes.map<String>((rune) => String.fromCharCode(rune)).toList();
      final missingChars = <String>[];
      final incorrectChars = <String>[];
      
      // Compare character by character
      for (int i = 0; i < characters.length; i++) {
        if (i >= recognizedChars.length) {
          // Character is missing from recognition
          missingChars.add(characters[i]);
        } else if (characters[i] != recognizedChars[i]) {
          // Character was recognized but incorrectly
          incorrectChars.add(characters[i]);
        }
      }
      
      // Build comprehensive error message
      final List<String> errorParts = [];
      if (missingChars.isNotEmpty) {
        errorParts.add('Missing: ${missingChars.join(', ')}');
      }
      if (incorrectChars.isNotEmpty) {
        errorParts.add('Incorrect: ${incorrectChars.join(', ')}');
      }
      
      return errorParts.isNotEmpty ? errorParts.join(' | ') : 'Incorrect: ${characters.join(', ')}';
    }
    
    // Fallback for other error cases
    return 'Incorrect: ${characters.join(', ')}';
  }
  

  Widget _buildPage1OverallResults() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Overall Grade Circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Color(widget.assessmentResult.getGradeColor()),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                widget.assessmentResult.overallGrade,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            '${widget.assessmentResult.overallAccuracy.toStringAsFixed(1)}% Overall Accuracy',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 30),

          // Statistics Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Traced',
                  '${widget.assessmentResult.getTracedCount()}',
                  Colors.green[400]!,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Correct',
                  '${widget.assessmentResult.correctCount}',
                  Colors.blue[400]!,
                  Icons.verified,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Need Practice',
                  '${widget.assessmentResult.charactersThatNeedPractice.length}',
                  Colors.orange[400]!,
                  Icons.school,
                ),
              ),
            ],
          ),

          const SizedBox(height: 30),

          // Progress Bar
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Overall Progress',
                      style: AppStyles.bodyTextStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    AnimatedBuilder(
                      animation: _numberAnimation,
                      builder: (context, child) {
                        final animatedAccuracy = widget.assessmentResult.overallAccuracy * _numberAnimation.value;
                        return Text(
                          '${animatedAccuracy.toStringAsFixed(0)}%',
                          style: AppStyles.bodyTextStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _progressAnimation,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: (widget.assessmentResult.overallAccuracy / 100) * _progressAnimation.value,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(widget.assessmentResult.getGradeColor()),
                      ),
                      minHeight: 8,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage2CharacterBreakdown() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Character-by-Character Results',
            style: AppStyles.subtitleTextStyle.copyWith(
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 20),

          ...widget.assessmentResult.characterResults.entries.map((entry) {
            final index = entry.key;
            final result = entry.value;
            final characterName = index < widget.characterNames.length 
                ? widget.characterNames[index] 
                : 'Character $index';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Color(result.getDisplayColor()).withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  // Character Display
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Color(result.getDisplayColor()).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        characterName,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(result.getDisplayColor()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Result Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              result.accuracyLevel,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(result.getDisplayColor()),
                              ),
                            ),
                            Text(
                              '${result.accuracyPercentage.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        if (result.hasStrokes && result.recognizedText.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Recognized: ${result.recognizedText}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                        if (!result.hasStrokes) ...[
                          const SizedBox(height: 4),
                          Text(
                            'No tracing detected',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Status Icon
                  Icon(
                    result.isCorrect ? Icons.check_circle : Icons.error_outline,
                    color: Color(result.getDisplayColor()),
                    size: 24,
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildPage3Recommendations() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Improvement Recommendations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),

          if (widget.assessmentResult.charactersThatNeedPractice.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[400]!.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.orange[400]!.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.school,
                        color: Colors.orange[400],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Characters Needing Practice',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.assessmentResult.charactersThatNeedPractice
                        .map((index) {
                      final characterName = index < widget.characterNames.length 
                          ? widget.characterNames[index] 
                          : 'Character $index';
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[400]!.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          characterName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // General Tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue[400]!.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.blue[400]!.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: Colors.blue[400],
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'General Tips',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._getRecommendations().map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue[400],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          tip,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 32,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _currentPage == index 
                  ? AppStyles.accentColor 
                  : AppStyles.indicatorColor,
            ),
          );
        }),
      ),
    );
  }

  /// Show individual character tooltip on tap
  void _showIndividualCharacterTooltip(BuildContext context, String expectedChar, List<String> recognizedChars, int index) {
    final String recognizedChar = index < recognizedChars.length 
        ? recognizedChars[index] 
        : '';
    
    final String message = recognizedChar.isNotEmpty 
        ? 'Expected: $expectedChar\nRecognized: $recognizedChar'
        : 'Expected: $expectedChar\nRecognized: No character detected';
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2D2D2D),
          title: Text(
            'Character Details',
            style: TextStyle(color: Colors.white),
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNavigationControls() {
    // Check if this is an NPC vocabulary item
    final bool isNpcVocabulary = widget.originalVocabularyItem != null &&
        widget.originalVocabularyItem!['category'] != null &&
        widget.npcId != null &&
        widget.npcName != null &&
        widget.onGiveItem != null;
    
    final String? itemName = widget.originalVocabularyItem?['english'] as String?;
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: isNpcVocabulary && itemName != null
          ? Row(
              children: [
                // Give Item button
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF10B981), Color(0xFF06B6D4)], // Green to cyan
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        widget.onDismiss(); // Close dialog immediately
                        if (widget.onGiveItem != null) {
                          Future.microtask(() => widget.onGiveItem!()); // Then trigger backend processing
                        }
                      },
                      child: Text(
                        'Give $itemName to ${widget.npcName}',
                        style: AppStyles.bodyTextStyle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Continue button
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Ethereal blue to purple
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: widget.onDismiss,
                      child: Text(
                        'CONTINUE',
                        style: AppStyles.bodyTextStyle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)], // Ethereal blue to purple
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: widget.onDismiss,
                  child: Text(
                    'CONTINUE',
                    style: AppStyles.bodyTextStyle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // Tooltip functionality
  OverlayEntry? _overlayEntry;
  
  void _showTooltipModal(BuildContext context, String title, String description, Color color) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassmorphicCard(
            padding: const EdgeInsets.all(16),
            blur: 20,
            opacity: 0.15,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.info_outline,
                          color: color,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: AppStyles.bodyTextStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: AppStyles.bodyTextStyle.copyWith(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Got it'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  void _showHoverTooltip(BuildContext context, String message) {
    // For desktop hover - simplified implementation
    // In a full implementation, you'd show a small overlay
  }
  
  void _hideHoverTooltip() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  List<String> _getRecommendations() {
    final recommendations = <String>[];
    
    if (widget.assessmentResult.overallAccuracy < 50) {
      recommendations.addAll([
        'Focus on basic stroke order and direction',
        'Practice each character slowly and deliberately',
        'Use reference materials while tracing',
      ]);
    } else if (widget.assessmentResult.overallAccuracy < 75) {
      recommendations.addAll([
        'Work on consistency in stroke width and spacing',
        'Pay attention to character proportions',
        'Practice problematic characters more frequently',
      ]);
    } else {
      recommendations.addAll([
        'Great job! Focus on refining fine details',
        'Try writing faster while maintaining accuracy',
        'Practice writing in different contexts',
      ]);
    }

    if (widget.assessmentResult.getUntracedCount() > 0) {
      recommendations.add('Complete all characters for better assessment');
    }

    return recommendations;
  }
  
  /// Get modern gradient for grade circle based on grade
  LinearGradient _getGradeGradient(String grade) {
    switch (grade) {
      case 'S':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8B5CF6), Color(0xFFF59E0B)], // Purple to gold
        );
      case 'A':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF10B981), Color(0xFF06B6D4)], // Green to cyan
        );
      case 'B':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82F6), Color(0xFF10B981)], // Blue to green
        );
      case 'C':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF97316), Color(0xFFEAB308)], // Orange to yellow
        );
      case 'D':
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEF4444), Color(0xFFF97316)], // Red to orange
        );
      default:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF6B7280), Color(0xFF9CA3AF)], // Gray
        );
    }
  }
  
  /// Get primary color for grade (for glow effects)
  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'S': return const Color(0xFF8B5CF6); // Purple
      case 'A': return const Color(0xFF10B981); // Green
      case 'B': return const Color(0xFF3B82F6); // Blue
      case 'C': return const Color(0xFFF97316); // Orange
      case 'D': return const Color(0xFFEF4444); // Red
      default: return const Color(0xFF6B7280); // Gray
    }
  }
}