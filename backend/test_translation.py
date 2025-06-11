#!/usr/bin/env python3
"""
Simple test script for the enhanced translation service.
"""

import asyncio
import json
from services.translation_service import create_word_level_translation_mapping

async def test_translation():
    """Test the word-level translation mapping function."""
    test_phrases = [
        "Hello world",
        "How are you today?",
        "I would like some water please",
        "Where is the bathroom?",
        "Thank you very much"
    ]
    
    # Test different languages
    test_languages = ["th", "vi", "zh", "ja", "ko"]
    
    print("Testing word-level translation mapping...")
    print("=" * 50)
    
    for target_language in test_languages:
        print(f"\n🌍 Testing language: {target_language.upper()}")
        print("=" * 30)
        
        for phrase in test_phrases:
            print(f"\nTesting: '{phrase}' -> {target_language}")
            print("-" * 30)
            
            try:
                result = await create_word_level_translation_mapping(phrase, target_language=target_language)
                
                print(f"✅ Success!")
                print(f"   Target text (spaced): {result['target_text_spaced']}")
                print(f"   Romanized text: {result['romanized_text']}")
                print(f"   Audio available: {'Yes' if result['audio_base64'] else 'No'}")
                print(f"   Word mappings count: {len(result['word_mappings'])}")
                
                # Show first few word mappings
                for i, mapping in enumerate(result['word_mappings'][:3]):
                    print(f"   Mapping {i+1}: '{mapping['english']}' -> '{mapping['target']}' -> '{mapping['romanized']}'")
                
                if len(result['word_mappings']) > 3:
                    print(f"   ... and {len(result['word_mappings']) - 3} more mappings")
                    
            except Exception as e:
                print(f"❌ Error: {e}")
        
        print("\n" + "=" * 50)

if __name__ == "__main__":
    asyncio.run(test_translation()) 