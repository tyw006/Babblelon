"""
Homograph Detection Service for Context-Aware Thai Translation
Implements methods from "Handling Homographs in Neural Machine Translation" research
"""

import re
import logging
from typing import Dict, List, Optional, Tuple
from pythainlp.tokenize import word_tokenize
from pythainlp.transliterate import romanize

# Import our expanded homograph dictionary
import sys
import os
sys.path.append(os.path.join(os.path.dirname(__file__), '..'))
from data.thai_homographs import (
    THAI_HOMOGRAPHS, 
    CONTEXT_WEIGHTS, 
    SPECIAL_PATTERNS,
    get_homograph_confidence_score
)

logger = logging.getLogger(__name__)

class HomographDetectionService:
    """
    Service for detecting and resolving Thai homographs based on context.
    Implements context-aware word embeddings approach from NMT research.
    """
    
    def __init__(self):
        self.homograph_dict = THAI_HOMOGRAPHS
        self.context_weights = CONTEXT_WEIGHTS
        self.special_patterns = SPECIAL_PATTERNS
        logger.info(f"Initialized HomographDetectionService with {len(self.homograph_dict)} homograph types")
    
    def detect_homograph_context(self, word: str, sentence: str, word_list: List[str]) -> Optional[str]:
        """
        Detect the correct meaning of a homograph based on context.
        Uses weighted scoring algorithm inspired by word sense disambiguation research.
        
        Args:
            word: The potential homograph word
            sentence: Full sentence context
            word_list: List of words in the sentence
            
        Returns:
            Context key (e.g., 'question_particle', 'silk') or None if not a homograph
        """
        if word not in self.homograph_dict:
            return None
        
        logger.debug(f"Analyzing homograph: {word} in context: {sentence[:50]}...")
        
        # Convert to lowercase for comparison
        sentence_lower = sentence.lower()
        word_list_lower = [w.lower() for w in word_list]
        
        # Special pattern detection (question particles, etc.)
        special_context = self._detect_special_patterns(word, sentence, sentence_lower)
        if special_context:
            logger.debug(f"Special pattern detected for {word}: {special_context}")
            return special_context
        
        # Standard context analysis
        best_match = None
        max_score = 0.0
        context_scores = {}
        
        for context_key, context_data in self.homograph_dict[word].items():
            score = self._calculate_context_score(
                context_data, 
                sentence_lower, 
                word_list_lower,
                word
            )
            context_scores[context_key] = score
            
            if score > max_score:
                max_score = score
                best_match = context_key
        
        logger.debug(f"Context scores for {word}: {context_scores}")
        
        # Require minimum confidence threshold
        if max_score < 0.3:  # Threshold based on research findings
            # Return first context as fallback
            return list(self.homograph_dict[word].keys())[0]
        
        return best_match
    
    def _detect_special_patterns(self, word: str, sentence: str, sentence_lower: str) -> Optional[str]:
        """
        Detect special linguistic patterns based on Thai NMT research.
        Handles question particles and compound word boundaries.
        """
        # Question particle detection (major issue identified in research)
        if word == 'ไหม':
            question_patterns = self.special_patterns['question_sentences']
            
            # Check for question endings
            for ending in question_patterns['endings']:
                if sentence.endswith(ending):
                    return 'question_particle'
            
            # Check for question indicators
            for indicator in question_patterns['indicators']:
                if indicator in sentence_lower:
                    return 'question_particle'
            
            # Check if sentence ends with question mark
            if sentence.strip().endswith('?'):
                return 'question_particle'
        
        # Compound word detection (word segmentation challenge from research)
        if word in ['ตา', 'กลม']:
            compound_check = self._check_compound_words(word, sentence_lower)
            if compound_check:
                return compound_check
        
        return None
    
    def _check_compound_words(self, word: str, sentence_lower: str) -> Optional[str]:
        """
        Handle compound word detection issues identified in Thai NMT research.
        Example: ตากลม could be ตา-กลม (round eyes) or ตาก-ลม (drying by wind)
        """
        if word == 'ตา':
            # Check for ตากลม pattern
            if 'ตากลม' in sentence_lower:
                # Look for eye-related context vs. drying context
                eye_indicators = ['หน้า', 'สวย', 'ใหญ่', 'เล็ก']
                drying_indicators = ['แดด', 'ลม', 'ผ้า', 'ข้าว']
                
                eye_count = sum(1 for ind in eye_indicators if ind in sentence_lower)
                dry_count = sum(1 for ind in drying_indicators if ind in sentence_lower)
                
                if eye_count > dry_count:
                    return 'eye'
                elif dry_count > 0:
                    return 'drying'
        
        return None
    
    def _calculate_context_score(self, context_data: Dict, sentence_lower: str, 
                                word_list_lower: List[str], word: str) -> float:
        """
        Calculate weighted context score using indicators and patterns.
        Implements scoring algorithm based on context-aware word embeddings research.
        """
        indicators_found = []
        score = 0.0
        
        # Check for context indicators in sentence and word list
        for indicator in context_data['context_indicators']:
            indicator_lower = indicator.lower()
            
            if indicator_lower in sentence_lower:
                indicators_found.append(indicator)
                score += self.context_weights['exact_match']
            elif indicator_lower in word_list_lower:
                indicators_found.append(indicator)
                score += self.context_weights['exact_match']
            else:
                # Check for partial matches
                for word_in_list in word_list_lower:
                    if indicator_lower in word_in_list or word_in_list in indicator_lower:
                        indicators_found.append(indicator)
                        score += self.context_weights['partial_match']
                        break
        
        # Normalize score and apply confidence boost
        if indicators_found:
            confidence_boost = context_data.get('confidence_boost', 1.0)
            confidence_score = get_homograph_confidence_score(word, 
                                                            list(context_data.keys())[0] if context_data else '', 
                                                            indicators_found)
            score = (score / len(context_data['context_indicators'])) * confidence_boost * confidence_score
        
        return min(score, 1.0)  # Cap at 1.0
    
    def get_enhanced_translation(self, word: str, context: str, romanization_engine: str = "royin") -> Dict[str, str]:
        """
        Get context-aware romanization and translation for a word.
        Uses royin engine (switched from thai2rom) based on test results.
        """
        if word not in self.homograph_dict or context not in self.homograph_dict[word]:
            # Fallback to standard romanization
            return {
                'romanization': romanize(word, engine=romanization_engine),
                'translation': word,
                'description': 'regular word',
                'confidence': 0.0,
                'is_homograph': False
            }
        
        context_data = self.homograph_dict[word][context]
        return {
            'romanization': context_data['romanization'],
            'translation': context_data['translation'],
            'description': context_data['description'],
            'confidence': 1.0,
            'is_homograph': True,
            'context_detected': context,
            'example_sentences': context_data.get('example_sentences', [])
        }
    
    def analyze_sentence_homographs(self, thai_sentence: str, romanization_engine: str = "royin") -> Dict:
        """
        Comprehensive homograph analysis for an entire Thai sentence.
        Returns detailed analysis with context detection and enhanced translations.
        """
        # Tokenize sentence
        words = word_tokenize(thai_sentence, engine='newmm')
        words = [w.strip() for w in words if w.strip()]
        
        analysis_results = []
        total_homographs = 0
        
        for word in words:
            # Detect context for potential homographs
            detected_context = self.detect_homograph_context(word, thai_sentence, words)
            
            # Get enhanced translation
            if detected_context:
                translation_data = self.get_enhanced_translation(word, detected_context, romanization_engine)
                total_homographs += 1
            else:
                translation_data = {
                    'romanization': romanize(word, engine=romanization_engine),
                    'translation': word,
                    'description': 'regular word',
                    'confidence': 1.0,
                    'is_homograph': False
                }
            
            analysis_results.append({
                'word': word,
                'detected_context': detected_context,
                **translation_data
            })
        
        return {
            'thai_sentence': thai_sentence,
            'analysis': analysis_results,
            'total_words': len(words),
            'total_homographs': total_homographs,
            'homograph_percentage': (total_homographs / len(words) * 100) if words else 0,
            'romanization_engine': romanization_engine
        }
    
    def get_word_mappings_enhanced(self, english_text: str, thai_text: str, 
                                  google_word_mappings: List[Dict]) -> List[Dict]:
        """
        Enhance Google Translate word mappings with homograph-aware translations.
        Integrates with existing translation pipeline while adding context awareness.
        """
        enhanced_mappings = []
        
        # Analyze Thai sentence for homographs
        homograph_analysis = self.analyze_sentence_homographs(thai_text)
        
        # Create mapping between Google results and enhanced analysis
        for google_mapping in google_word_mappings:
            thai_word = google_mapping.get('thai', '')
            
            # Find corresponding analysis
            enhanced_data = None
            for analysis in homograph_analysis['analysis']:
                if analysis['word'] == thai_word:
                    enhanced_data = analysis
                    break
            
            # Create enhanced mapping
            enhanced_mapping = {
                **google_mapping,  # Keep original Google data
                'enhanced_romanization': enhanced_data.get('romanization', google_mapping.get('romanized', '')) if enhanced_data else google_mapping.get('romanized', ''),
                'enhanced_translation': enhanced_data.get('translation', google_mapping.get('english', '')) if enhanced_data else google_mapping.get('english', ''),
                'is_homograph': enhanced_data.get('is_homograph', False) if enhanced_data else False,
                'detected_context': enhanced_data.get('detected_context') if enhanced_data else None,
                'description': enhanced_data.get('description', '') if enhanced_data else '',
                'confidence': enhanced_data.get('confidence', 0.0) if enhanced_data else 0.0
            }
            
            enhanced_mappings.append(enhanced_mapping)
        
        return enhanced_mappings
    
    def get_homograph_statistics(self) -> Dict:
        """
        Get statistics about the homograph dictionary for monitoring and debugging.
        """
        total_words = len(self.homograph_dict)
        total_contexts = sum(len(contexts) for contexts in self.homograph_dict.values())
        
        context_distribution = {}
        for word, contexts in self.homograph_dict.items():
            count = len(contexts)
            if count not in context_distribution:
                context_distribution[count] = 0
            context_distribution[count] += 1
        
        return {
            'total_homograph_words': total_words,
            'total_contexts': total_contexts,
            'average_contexts_per_word': total_contexts / total_words if total_words > 0 else 0,
            'context_distribution': context_distribution,
            'supported_words': list(self.homograph_dict.keys())
        }

# Global instance for use in translation service
homograph_service = HomographDetectionService() 