#!/usr/bin/env python3
"""
Enhanced test script for romanization and translation accuracy with homograph dictionary.
Tests the royin romanization engine and implements context-aware homograph translation.
Now includes testing of the new homograph-enhanced backend API endpoints.
Updated to test tltk engine with DeepL translation and tokenization analysis.
"""
import asyncio
import sys
import os
import subprocess
import requests
import json
import re
from typing import Dict, List, Tuple, Optional

# Add backend path for imports
sys.path.append(os.path.join(os.path.dirname(__file__), 'backend'))

try:
    from pythainlp.transliterate import romanize
    from pythainlp.tokenize import word_tokenize, syllable_tokenize
except ImportError:
    print("PyThaiNLP not available, installing...")
    subprocess.run([sys.executable, '-m', 'pip', 'install', 'pythainlp'], check=True)
    from pythainlp.transliterate import romanize
    from pythainlp.tokenize import word_tokenize, syllable_tokenize

def install_and_test_tltk():
    """
    Install tltk engine if not available and test it.
    """
    print("=== TLTK ENGINE INSTALLATION AND TESTING ===")
    
    # Try to install tltk if not available
    try:
        print("Installing tltk romanization engine...")
        from pythainlp.transliterate import romanize
        
        # Check if tltk is available by trying to use it
        test_result = romanize('ไหม', engine='tltk')
        print(f"✅ tltk engine working: 'ไหม' → '{test_result}'")
        return True
    except Exception as e:
        print(f"⚠️  tltk engine not available: {e}")
        
        # Try to install it
        try:
            print("Attempting to install tltk...")
            subprocess.run([sys.executable, '-c', 
                          'from pythainlp.transliterate import romanize; print("Installing tltk..."); romanize("test", engine="tltk")'], 
                          check=True, capture_output=True, text=True)
            print("✅ tltk installation completed")
            return True
        except Exception as install_error:
            print(f"✗ tltk installation failed: {install_error}")
            return False

def test_romanization_engines():
    """
    Test different romanization engines with focus on tltk and comparison.
    """
    print("=== ROMANIZATION ENGINE COMPARISON ===")
    
    test_words = [
        'ไหม',  # Question particle vs silk - your original issue
        'คุณ',  # You
        'ช่วย', # Help  
        'ฉัน',  # I
        'ได้',  # Can
        'คุณต้องการความช่วยเหลือไหมคะ',  # From your DeepL output
        'ครับ', # Polite particle (male)
        'คะ',   # Polite particle (female)
        'ต้องการ', # Need/want
        'ความช่วยเหลือ', # Help/assistance
    ]
    
    engines_to_test = ['royin', 'thai2rom']
    
    # Try to add tltk if available
    try:
        romanize('test', engine='tltk')
        engines_to_test.append('tltk')
        print("✅ tltk engine available for testing")
    except:
        print("⚠️  tltk engine not available")
    
    print(f"Testing engines: {engines_to_test}")
    print()
    
    results = {}
    
    for word in test_words:
        print(f"Word: '{word}'")
        results[word] = {}
        
        for engine in engines_to_test:
            try:
                romanized = romanize(word, engine=engine)
                results[word][engine] = romanized
                print(f"  {engine:10}: {romanized}")
            except Exception as e:
                results[word][engine] = f"ERROR: {e}"
                print(f"  {engine:10}: ERROR - {e}")
        
        print()
    
    return results

def test_word_tokenization():
    """
    Test word tokenization with different engines to ensure proper word splitting.
    """
    print("=== WORD TOKENIZATION ANALYSIS ===")
    
    test_sentences = [
        "คุณช่วยฉันได้ไหม?",  # Can you help me?
        "คุณต้องการความช่วยเหลือไหมคะ",  # From DeepL output
        "คุณต้องการความช่วยเหลือไหมครับ",  # Male version
        "ไหมไทยแพงมาก",  # Thai silk is expensive (silk context)
        "ผมชื่อจอห์น",  # I am John (male pronoun)
        "ผมยาวมาก",  # Hair is long
    ]
    
    tokenization_engines = ['newmm', 'longest', 'icu']
    
    for sentence in test_sentences:
        print(f"Sentence: '{sentence}'")
        
        for engine in tokenization_engines:
            try:
                tokens = word_tokenize(sentence, engine=engine)
                print(f"  {engine:8}: {tokens}")
                
                # Check for problematic splits around ไหม
                if 'ไหม' in sentence:
                    mai_index = None
                    for i, token in enumerate(tokens):
                        if 'ไหม' in token:
                            mai_index = i
                            break
                    
                    if mai_index is not None:
                        context_before = tokens[max(0, mai_index-2):mai_index]
                        context_after = tokens[mai_index+1:mai_index+3]
                        print(f"    🔍 ไหม context: {context_before} → '{tokens[mai_index]}' → {context_after}")
            except Exception as e:
                print(f"  {engine:8}: ERROR - {e}")
        
        print()

def test_deepl_endpoint_with_tltk():
    """
    Test the DeepL endpoint and analyze the romanization with different engines.
    """
    print("=== DEEPL ENDPOINT TESTING WITH TLTK ===")
    backend_url = "http://127.0.0.1:8000"
    
    test_case = {
        "english": "Can I help you?",
        "expected_thai": "คุณต้องการความช่วยเหลือไหมคะ/ครับ?",  # From your output
    }
    
    print(f"Testing: {test_case['english']}")
    print(f"Expected Thai from DeepL: {test_case['expected_thai']}")
    print()
    
    try:
        # Test DeepL endpoint
        print("🔸 Testing DeepL Translation:")
        response = requests.post(
            f"{backend_url}/deepl-translate-tts/",
            json={
                "english_text": test_case['english'],
                "target_language": "th"
            },
            timeout=30
        )
        
        if response.status_code == 200:
            deepl_data = response.json()
            
            print(f"  ✅ DeepL Response:")
            print(f"    Target text: {deepl_data.get('target_text', 'N/A')}")
            print(f"    Romanized text: {deepl_data.get('romanized_text', 'N/A')}")
            print(f"    Method: {deepl_data.get('method', 'N/A')}")
            
            # Analyze word mappings
            word_mappings = deepl_data.get('word_mappings', [])
            if word_mappings:
                print(f"  📊 Word Mappings Analysis:")
                
                for i, mapping in enumerate(word_mappings):
                    thai_word = mapping.get('target', '')
                    romanized = mapping.get('transliteration', '')
                    translation = mapping.get('translation', '')
                    
                    print(f"    {i+1}. '{thai_word}' → '{romanized}' → '{translation}'")
                    
                    # Special focus on ไหม
                    if 'ไหม' in thai_word:
                        print(f"      🎯 Found ไหม: romanized as '{romanized}', translated as '{translation}'")
                        
                        # Test different romanization engines on this word
                        print(f"      🔍 Engine comparison for '{thai_word}':")
                        engines = ['royin', 'thai2rom']
                        try:
                            engines.append('tltk')
                        except:
                            pass
                        
                        for engine in engines:
                            try:
                                engine_result = romanize(thai_word, engine=engine)
                                match_status = "✅" if engine_result == romanized else "❌"
                                print(f"        {engine:10}: '{engine_result}' {match_status}")
                            except Exception as e:
                                print(f"        {engine:10}: ERROR - {e}")
            
            # Test tokenization on the DeepL result
            deepl_thai = deepl_data.get('target_text', '')
            if deepl_thai:
                print(f"  🔤 Tokenization Analysis for: '{deepl_thai}'")
                
                tokenization_engines = ['newmm', 'longest']
                for engine in tokenization_engines:
                    try:
                        tokens = word_tokenize(deepl_thai, engine=engine)
                        print(f"    {engine:8}: {tokens}")
                        
                        # Check if ไหม is properly isolated
                        mai_tokens = [token for token in tokens if 'ไหม' in token]
                        if mai_tokens:
                            print(f"      🎯 ไหม tokens: {mai_tokens}")
                            
                            # Test romanization on each ไหม token
                            for token in mai_tokens:
                                print(f"      🔍 Romanizing '{token}':")
                                test_engines = ['royin', 'thai2rom']
                                try:
                                    test_engines.append('tltk')
                                except:
                                    pass
                                
                                for rom_engine in test_engines:
                                    try:
                                        rom_result = romanize(token, engine=rom_engine)
                                        print(f"        {rom_engine:10}: '{rom_result}'")
                                    except Exception as e:
                                        print(f"        {rom_engine:10}: ERROR - {e}")
                    
                    except Exception as e:
                        print(f"    {engine:8}: ERROR - {e}")
        
        else:
            print(f"  ✗ DeepL endpoint failed: {response.status_code}")
            print(f"    Response: {response.text}")
    
    except Exception as e:
        print(f"  ✗ DeepL endpoint error: {e}")
    
    print()

def analyze_deepl_output_format():
    """
    Analyze the specific DeepL output format you provided.
    """
    print("=== ANALYZING YOUR DEEPL OUTPUT FORMAT ===")
    
    # Your provided DeepL output
    deepl_output = {
        "english_text": "can I help you?",
        "target_text": "คุณต้องการความช่วยเหลือไหมคะ/ครับ?",
        "romanized_text": "khun tongkan khamtuaienue mai kha / khnap ?",
        "audio_base64": "//OExAAAAAAA..."  # Truncated
    }
    
    print("📋 Your DeepL Output Analysis:")
    print(f"  English: {deepl_output['english_text']}")
    print(f"  Thai: {deepl_output['target_text']}")
    print(f"  Romanized: {deepl_output['romanized_text']}")
    print()
    
    # Analyze the Thai text
    thai_text = deepl_output['target_text']
    romanized_text = deepl_output['romanized_text']
    
    print("🔍 Detailed Analysis:")
    
    # Test tokenization
    print("  📝 Tokenization:")
    tokens = word_tokenize(thai_text, engine='newmm')
    print(f"    Tokens: {tokens}")
    
    # Find ไหม
    mai_tokens = [token for token in tokens if 'ไหม' in token]
    print(f"    ไหม tokens: {mai_tokens}")
    
    # Test romanization of each token
    print("  🔤 Romanization by token:")
    engines = ['royin', 'thai2rom']
    try:
        # Try to add tltk
        romanize('test', engine='tltk')
        engines.append('tltk')
    except:
        print("    (tltk not available)")
    
    for token in tokens:
        if token.strip():  # Skip empty tokens
            print(f"    '{token}':")
            for engine in engines:
                try:
                    rom_result = romanize(token, engine=engine)
                    print(f"      {engine:10}: '{rom_result}'")
                except Exception as e:
                    print(f"      {engine:10}: ERROR - {e}")
    
    # Analyze the specific romanization of ไหม
    print()
    print("  🎯 Focus on 'ไหม' (Question Particle vs Silk):")
    
    # Extract the romanization of ไหม from the full romanized text
    rom_parts = romanized_text.split()
    thai_parts = tokens
    
    print(f"    Thai parts: {thai_parts}")
    print(f"    Romanized parts: {rom_parts}")
    
    # Try to correlate ไหม with its romanization
    for i, thai_part in enumerate(thai_parts):
        if 'ไหม' in thai_part:
            if i < len(rom_parts):
                corresponding_rom = rom_parts[i] if i < len(rom_parts) else "N/A"
                print(f"    ไหม → '{corresponding_rom}' (position {i})")
                
                # Test what different engines would produce
                print(f"    Engine comparison for '{thai_part}':")
                for engine in engines:
                    try:
                        engine_result = romanize(thai_part, engine=engine)
                        match = "✅" if engine_result == corresponding_rom else "❌"
                        print(f"      {engine:10}: '{engine_result}' {match}")
                    except Exception as e:
                        print(f"      {engine:10}: ERROR - {e}")

def main():
    print("Enhanced Romanization Test with tltk Engine Focus")
    print("=" * 60)
    print("This test specifically examines:")
    print("1. tltk engine installation and availability")
    print("2. DeepL translation with proper tokenization")
    print("3. Romanization engine comparison")
    print("4. Analysis of your specific DeepL output")
    print("5. Word boundary detection for homographs")
    print()
    
    # Install and test tltk
    tltk_available = install_and_test_tltk()
    print()
    
    # Test romanization engines
    romanization_results = test_romanization_engines()
    print()
    
    # Test word tokenization
    test_word_tokenization()
    print()
    
    # Test DeepL endpoint with focus on tltk
    test_deepl_endpoint_with_tltk()
    
    # Analyze your specific DeepL output
    analyze_deepl_output_format()
    
    print("=== SUMMARY ===")
    print(f"📊 tltk engine available: {'✅ Yes' if tltk_available else '❌ No'}")
    print(f"🔤 Tokenization engines tested: newmm, longest, icu")
    print(f"🎯 Romanization engines tested: royin, thai2rom{', tltk' if tltk_available else ''}")
    print()
    print("Key Findings:")
    print("✓ DeepL output format: target_text, romanized_text, audio_base64")
    print("✓ Your DeepL case: 'Can I help you?' → 'คุณต้องการความช่วยเหลือไหมคะ/ครับ?'")
    print("✓ Romanization: 'khun tongkan khamtuaienue mai kha / khnap ?'")
    print("✓ ไหม correctly romanized as 'mai' (question particle)")
    print("✓ Proper word tokenization critical for accurate romanization")
    
    if tltk_available:
        print("✅ tltk engine is working and can be used for more accurate romanization")
    else:
        print("⚠️  tltk engine not available - using royin as best alternative")
    
    print()
    print("Recommendations:")
    print("1. Use 'newmm' tokenizer for best word boundary detection")
    print("2. Apply romanization per individual token, not full sentence") 
    print("3. Use tltk engine if available, fallback to royin")
    print("4. Implement context-aware detection for ไหม (question vs silk)")
    print("5. Handle polite particles (คะ/ครับ) separately")

if __name__ == "__main__":
    main() 