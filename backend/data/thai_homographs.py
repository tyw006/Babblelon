"""
Thai Homograph Dictionary for Context-Aware Translation and Romanization
Provides context detection and correct romanization for Thai homographs
"""

# Comprehensive Thai homograph dictionary with context indicators
THAI_HOMOGRAPHS = {
    'ไหม': {
        'question_particle': {
            'romanization': 'mai',
            'translation': 'question particle',
            'context_indicators': ['?', 'หรือ', 'ใช่', 'ได้', 'ค่ะ', 'ครับ', 'คะ', 'คับ'],
            'description': 'Question particle used at the end of yes/no questions',
            'confidence_boost': 1.5,
            'example_sentences': [
                'คุณสบายดีไหม',
                'อร่อยไหม',
                'ได้ไหม'
            ]
        },
        'silk': {
            'romanization': 'mai',
            'translation': 'silk',
            'context_indicators': ['ผ้า', 'เส้น', 'ใย', 'ทอ', 'ผืน', 'สาย'],
            'description': 'Silk material or fabric',
            'confidence_boost': 1.0,
            'example_sentences': [
                'ผ้าไหมไทย',
                'เส้นไหม'
            ]
        }
    },
    'ตา': {
        'eye': {
            'romanization': 'ta',
            'translation': 'eye',
            'context_indicators': ['หน้า', 'ใบหน้า', 'มอง', 'ดู', 'เห็น', 'สายตา', 'กลม', 'สวย'],
            'description': 'Human eye or eyes',
            'confidence_boost': 1.2,
            'example_sentences': [
                'ตาสวย',
                'ตากลม'
            ]
        },
        'grandfather': {
            'romanization': 'ta',
            'translation': 'grandfather (maternal)',
            'context_indicators': ['ยาย', 'ปู่', 'ย่า', 'พ่อ', 'แม่', 'ลูก', 'หลาน'],
            'description': 'Maternal grandfather',
            'confidence_boost': 1.1,
            'example_sentences': [
                'ตากับยาย',
                'บ้านตา'
            ]
        },
        'drying': {
            'romanization': 'tak',
            'translation': 'to dry in the sun',
            'context_indicators': ['แดด', 'ลม', 'ผ้า', 'ข้าว', 'ปลา', 'ตาก'],
            'description': 'To dry something in the sun or air',
            'confidence_boost': 1.0,
            'example_sentences': [
                'ตากผ้า',
                'ตากแดด'
            ]
        }
    },
    'ยาย': {
        'grandmother': {
            'romanization': 'yai',
            'translation': 'grandmother (maternal)',
            'context_indicators': ['ตา', 'ปู่', 'ย่า', 'พ่อ', 'แม่', 'ลูก', 'หลาน'],
            'description': 'Maternal grandmother',
            'confidence_boost': 1.2,
            'example_sentences': [
                'ยายกับตา',
                'บ้านยาย'
            ]
        },
        'old_woman': {
            'romanization': 'yai',
            'translation': 'old woman',
            'context_indicators': ['แก่', 'ชรา', 'คน', 'หญิง'],
            'description': 'An elderly woman (can be informal/rude)',
            'confidence_boost': 0.8,
            'example_sentences': [
                'ยายแก่',
                'ยายคนนั้น'
            ]
        }
    },
    'หนาว': {
        'cold_weather': {
            'romanization': 'nao',
            'translation': 'cold (weather)',
            'context_indicators': ['อากาศ', 'ฤดู', 'หิมะ', 'ลม', 'เย็น'],
            'description': 'Cold weather or temperature',
            'confidence_boost': 1.1,
            'example_sentences': [
                'อากาศหนาว',
                'ฤดูหนาว'
            ]
        },
        'feeling_cold': {
            'romanization': 'nao',
            'translation': 'feeling cold',
            'context_indicators': ['รู้สึก', 'ตัว', 'สั่น', 'ผ้าห่ม'],
            'description': 'The feeling of being cold',
            'confidence_boost': 1.0,
            'example_sentences': [
                'รู้สึกหนาว',
                'หนาวมาก'
            ]
        }
    }
}

# Context scoring weights for homograph detection
CONTEXT_WEIGHTS = {
    'exact_match': 1.0,       # Full word match in context
    'partial_match': 0.5,     # Partial word match
    'position_weight': 0.3,   # Position-based scoring
    'frequency_weight': 0.2   # Frequency-based scoring
}

# Special patterns for linguistic detection
SPECIAL_PATTERNS = {
    'question_sentences': {
        'endings': ['ไหม', 'หรือ', 'ไหน', 'มั้ย', 'เหรอ', 'หรือเปล่า'],
        'indicators': ['?', 'ช่วย', 'ขอ', 'ได้']
    },
    'polite_markers': {
        'male': ['ครับ', 'คับ'],
        'female': ['ค่ะ', 'คะ']
    },
    'compound_words': {
        'patterns': ['ตากลม', 'ตาแดง', 'ยายนาง']
    }
}

def get_homograph_confidence_score(word: str, context: str, indicators_found: list) -> float:
    """
    Calculate confidence score for homograph context detection
    
    Args:
        word: The homograph word
        context: Detected context key
        indicators_found: List of context indicators found
    
    Returns:
        Confidence score between 0.0 and 1.0
    """
    if not indicators_found:
        return 0.3  # Low confidence if no indicators
    
    # Base confidence from number of indicators
    base_score = min(len(indicators_found) * 0.25, 1.0)
    
    # Boost for question particles at sentence end
    if word == 'ไหม' and context == 'question_particle':
        return min(base_score * 1.5, 1.0)
    
    return base_score