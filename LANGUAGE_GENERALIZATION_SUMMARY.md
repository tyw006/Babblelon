# Language Generalization Summary

This document summarizes the changes made to generalize the translation system from Thai-specific to support multiple languages.

## Overview

The translation system has been refactored to support multiple target languages instead of being hardcoded for Thai. The system now uses a `target_language` parameter and language-specific configurations to handle different languages appropriately.

## Key Changes

### 1. Backend Service Changes (`backend/services/translation_service.py`)

#### Language Configuration System
- **Added `LANGUAGE_CONFIGS`**: A dictionary containing language-specific settings for each supported language
- **Supported languages**: Thai (th), Vietnamese (vi), Chinese (zh), Japanese (ja), Korean (ko)
- **Configuration includes**: Language codes, TTS settings, tokenizer/romanizer availability, voice names
- **Added `get_language_name()`**: Function to get display names for language codes

#### Function Updates
- **`translate_text()`**: Now accepts `target_language` parameter
- **`romanize_target_text()`**: Generalized from `romanize_thai_text()`, supports multiple languages
- **`synthesize_speech()`**: Now accepts `target_language` parameter and uses language-specific TTS settings
- **`create_word_level_translation_mapping()`**: New function for word-level mappings with proper target language word order

#### Field Renaming
- `thai_text` → `target_text`
- `thai` → `target` (in word mappings)
- Function names generalized (e.g., `romanize_thai_text` → `romanize_target_text`)

### 2. API Changes (`backend/main.py`)

#### Pydantic Models
- **`TranslationRequest`**: Added `target_language` field (defaults to "th")
- **`WordMapping`**: Changed `thai` field to `target`
- **`GoogleTranslationResponse`**: Updated field names and added `target_language_name`
- **`NPCResponse`**: Updated to use generic field names

#### Endpoints
- **`/gcloud-translate-tts/`**: Now accepts `target_language` parameter
- **`/generate-npc-response/`**: Added `target_language` parameter support
- **Response includes**: Language display name for frontend

### 3. Frontend Changes (`lib/overlays/dialogue_overlay.dart`)

#### Dialog Updates
- **Function renamed**: `_showEnglishToThaiTranslationDialog` → `_showEnglishToTargetLanguageTranslationDialog`
- **Dynamic title**: Dialog title now shows actual language name (e.g., "Thai" instead of "TH")
- **Field mapping**: Updated to use `target` instead of `thai` in word mappings
- **Language support**: Ready for multiple target languages

#### Variable Renaming
- `translatedThaiTextNotifier` → `translatedTargetTextNotifier`
- `thai` → `target` in mapping displays
- Added `dialogTitleNotifier` for dynamic title updates

## Latency Analysis & Optimization

### Latency Increase Causes

The translation endpoint latency increased due to several factors:

1. **Additional API Calls**: 
   - **Before**: 1 translation call + 1 romanization + 1 TTS call = 3 API calls
   - **After**: 1 full sentence translation + N individual word translations + 1 TTS call = (2 + N) API calls
   - For a 5-word sentence: 3 calls → 7 calls (133% increase)

2. **Word-by-Word Translation**:
   - Each English word is translated individually to create mappings
   - This was necessary for word-level alignment but increased API calls significantly

3. **Enhanced Processing**:
   - Added tokenization for proper word boundaries
   - Added word alignment logic
   - Added proper target language word ordering

### Optimization Implemented

**Fixed Word Order Issue**: 
- **Problem**: Word-by-word translation maintained English word order
- **Solution**: Now translates full sentence first to get proper target language order, then creates word mappings
- **Benefit**: Correct Thai/target language grammar and word order

**Current Process**:
1. Translate entire sentence for proper word order
2. Tokenize target text for word boundaries  
3. Translate individual words for mapping alignment
4. Create word mappings using target language order
5. Generate TTS audio from properly ordered text

### Future Optimization Opportunities

1. **Caching**: Cache individual word translations to reduce repeated API calls
2. **Batch Translation**: Use Google Translate batch API for multiple words
3. **Smart Alignment**: Use fuzzy matching to align words without individual translation
4. **Async Processing**: Parallelize individual word translations

## Backward Compatibility

- **Legacy functions maintained**: `romanize_thai_text()` still available
- **Default language**: Thai ("th") remains the default for existing code
- **Field mapping**: Old field names still work in most contexts
- **API compatibility**: Existing endpoints continue to work

## Testing

- **Backend compilation**: ✅ All Python files compile successfully
- **Frontend compilation**: ✅ Flutter code compiles with minor style warnings
- **API functionality**: ✅ Translation endpoint works with new word ordering
- **Language support**: ✅ Ready for Thai, Vietnamese, Chinese, Japanese, Korean

## Migration Guide

### For Developers
1. **Update API calls**: Add `target_language` parameter to translation requests
2. **Update field names**: Use `target_text` instead of `thai_text` in responses
3. **Update models**: Use new `WordMapping` structure with `target` field
4. **Test thoroughly**: Verify word order is correct for target languages

### For Frontend
1. **Update variable names**: Replace Thai-specific variable names
2. **Update field access**: Use `target` instead of `thai` in word mappings
3. **Add language selection**: Implement UI for choosing target language
4. **Update displays**: Use `target_language_name` for user-friendly language names

## Performance Impact

- **Latency**: Increased by ~100-200ms due to additional API calls for word mapping
- **Accuracy**: Significantly improved word order for target languages
- **Functionality**: Enhanced with proper word-level mappings and language support
- **Scalability**: Ready for easy addition of new languages

## Next Steps

1. **Add language selection UI**: Allow users to choose target language
2. **Implement caching**: Reduce API calls for repeated translations
3. **Add more languages**: Extend `LANGUAGE_CONFIGS` for additional languages
4. **Optimize performance**: Implement batch translation and async processing
5. **Add language detection**: Auto-detect source language if not English

## Language Support Matrix

| Language | Code | TTS Support | Tokenization | Romanization | Status |
|----------|------|-------------|--------------|--------------|--------|
| Thai     | th   | ✅          | ✅ (PyThaiNLP) | ✅ (PyThaiNLP) | Full Support |
| Vietnamese | vi | ✅          | ❌           | ❌           | Basic Support |
| Chinese  | zh   | ✅          | ❌           | ❌           | Basic Support |
| Japanese | ja   | ✅          | ❌           | ❌           | Basic Support |
| Korean   | ko   | ✅          | ❌           | ❌           | Basic Support |

## Configuration

### Environment Variables
- API keys remain the same for all languages
- Google Cloud Translation API supports all configured languages
- Google Cloud TTS supports all configured languages

### Language Selection
- Frontend: Pass `targetLanguage` parameter to dialog function
- Backend: Include `target_language` in API requests
- Default: "th" (Thai) for backward compatibility

## Notes

- The system gracefully handles languages without romanization support
- TTS is available for all configured languages through Google Cloud
- Translation quality depends on Google Translate API capabilities
- Tokenization and romanization are currently only fully supported for Thai 