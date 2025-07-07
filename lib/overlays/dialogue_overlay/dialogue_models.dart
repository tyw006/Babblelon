import 'package:flutter/material.dart';

// --- Sanitization Helper ---
String sanitizeString(String text) {
  // Re-encoding and decoding with allowMalformed: true replaces invalid sequences
  // with the Unicode replacement character (U+FFFD), preventing rendering errors.
  return text; // Simplified for now
}

// --- Recording State Enum ---
enum RecordingState {
  idle,
  recording,
  reviewing,
}

// --- POSMapping Model ---
@immutable
class POSMapping {
  final String wordTarget;
  final String wordTranslit;
  final String wordEng;
  final String pos;

  const POSMapping({
    required this.wordTarget,
    required this.wordTranslit,
    required this.wordEng,
    required this.pos,
  });

  factory POSMapping.fromJson(Map<String, dynamic> json) {
    return POSMapping(
      wordTarget: sanitizeString(json['word_target'] as String? ?? ''),
      wordTranslit: sanitizeString(json['word_translit'] as String? ?? ''),
      wordEng: sanitizeString(json['word_eng'] as String? ?? ''),
      pos: sanitizeString(json['pos'] as String? ?? ''),
    );
  }
}

// --- POS Color Mapping ---
final Map<String, Color> posColorMapping = {
  'ADJ': Colors.orange.shade700, // Adjective
  'ADP': Colors.purple.shade700, // Adposition (e.g., prepositions, postpositions)
  'ADV': Colors.green.shade700, // Adverb
  'AUX': Colors.blue.shade700, // Auxiliary verb
  'CCONJ': Colors.cyan.shade700, // Coordinating conjunction
  'DET': Colors.lime.shade700, // Determiner
  'INTJ': Colors.pink.shade700, // Interjection
  'NOUN': Colors.red.shade700, // Noun
  'NUM': Colors.indigo.shade700, // Numeral
  'PART': Colors.brown.shade700, // Particle
  'PRON': Colors.amber.shade700, // Pronoun
  'PROPN': Colors.deepOrange.shade700, // Proper noun
  'PUNCT': Colors.grey.shade600, // Punctuation
  'SCONJ': Colors.lightBlue.shade700, // Subordinating conjunction
  'SYM': Colors.teal.shade700, // Symbol
  'VERB': Colors.lightGreen.shade700, // Verb
  'OTHER': Colors.black54, // Other
};

// --- Initial NPC Greeting Model ---
@immutable
class InitialNPCGreeting {
  final String responseTarget;
  final String responseAudioPath;
  final String responseEnglish;
  final String responseTranslit;
  final List<POSMapping> responseMapping;

  const InitialNPCGreeting({
    required this.responseTarget,
    required this.responseAudioPath,
    required this.responseEnglish,
    required this.responseTranslit,
    required this.responseMapping,
  });

  factory InitialNPCGreeting.fromJson(Map<String, dynamic> json) {
    final responseMapping = (json['response_mapping'] as List<dynamic>?)
        ?.map((item) => POSMapping.fromJson(item as Map<String, dynamic>))
        .toList() ?? [];

    return InitialNPCGreeting(
      responseTarget: sanitizeString(json['response_target'] as String? ?? ''),
      responseAudioPath: json['response_audio_path'] as String? ?? '',
      responseEnglish: sanitizeString(json['response_english'] as String? ?? ''),
      responseTranslit: sanitizeString(json['response_translit'] as String? ?? ''),
      responseMapping: responseMapping,
    );
  }
}