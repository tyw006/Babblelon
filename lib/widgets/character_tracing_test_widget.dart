import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'character_tracing_widget.dart';

class CharacterTracingTestWidget extends StatefulWidget {
  final String npcName; // 'somchai' or 'amara'
  
  const CharacterTracingTestWidget({
    super.key,
    this.npcName = 'somchai', // Default to Somchai
  });

  @override
  State<CharacterTracingTestWidget> createState() => _CharacterTracingTestWidgetState();
}

class _CharacterTracingTestWidgetState extends State<CharacterTracingTestWidget> {
  List<Map<String, dynamic>> _testWordMapping = [];
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadNPCVocabulary();
  }

  Future<void> _loadNPCVocabulary() async {
    try {
      // Load NPC vocabulary JSON
      final jsonString = await rootBundle.loadString(
        'assets/data/npc_vocabulary_${widget.npcName}.json'
      );
      final data = json.decode(jsonString);
      
      // Find condiment set entry with word_mapping
      final vocabularyList = data['vocabulary'] as List;
      final condimentSetEntry = vocabularyList.firstWhere(
        (item) => item['english'] == 'Condiment Set' && item['word_mapping'] != null,
        orElse: () => null,
      );
      
      if (condimentSetEntry != null) {
        setState(() {
          _testWordMapping = [{
            "thai": condimentSetEntry['thai'],
            "transliteration": condimentSetEntry['transliteration'],
            "translation": condimentSetEntry['translation'] ?? condimentSetEntry['english'],
            "audio_path": condimentSetEntry['audio_path'],
            "word_mapping": condimentSetEntry['word_mapping'],
          }];
          _isLoading = false;
        });
      } else {
        // Fallback to first entry with word_mapping
        final firstWithMapping = vocabularyList.firstWhere(
          (item) => item['word_mapping'] != null,
          orElse: () => null,
        );
        
        if (firstWithMapping != null) {
          setState(() {
            _testWordMapping = [{
              "thai": firstWithMapping['thai'],
              "transliteration": firstWithMapping['transliteration'],
              "translation": firstWithMapping['translation'] ?? firstWithMapping['english'],
              "audio_path": firstWithMapping['audio_path'],
              "word_mapping": firstWithMapping['word_mapping'],
            }];
            _isLoading = false;
          });
        } else {
          setState(() {
            _errorMessage = 'No vocabulary with word_mapping found';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading vocabulary: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Dialog(
        backgroundColor: Colors.transparent,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Dialog(
        backgroundColor: const Color(0xFF2D2D2D),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: CharacterTracingWidget(
        wordMapping: _testWordMapping.isNotEmpty && _testWordMapping[0]['word_mapping'] != null 
            ? List<Map<String, dynamic>>.from(_testWordMapping[0]['word_mapping'])
            : _testWordMapping,
        originalVocabularyItem: _testWordMapping.isNotEmpty ? _testWordMapping[0] : null,
        onBack: () => Navigator.of(context).pop(),
        onComplete: () {
          // Show completion message
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Character tracing test completed!'),
              backgroundColor: Color(0xFF4ECCA3),
            ),
          );
        },
        showBackButton: true,
        showWritingTips: true,
      ),
    );
  }
}