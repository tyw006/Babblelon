"""
Input validation and sanitization service for BabbleOn backend.
Handles file uploads, text input sanitization, and request validation.
"""

import os
import re
import mimetypes
from typing import List, Optional, Dict, Any
from fastapi import UploadFile, HTTPException
import logging
from pathlib import Path

# Python-magic is optional - we have built-in header detection as fallback
MAGIC_AVAILABLE = False  # Disabled to avoid unnecessary warnings

logger = logging.getLogger(__name__)

class ValidationService:
    """Service for validating and sanitizing inputs"""
    
    # File upload limits
    MAX_FILE_SIZE = 10 * 1024 * 1024  # 10MB for audio files
    ALLOWED_AUDIO_TYPES = {
        'audio/wav', 'audio/wave', 'audio/x-wav',
        'audio/mpeg', 'audio/mp3',
        'audio/mp4', 'audio/m4a',
        'audio/webm', 'audio/ogg'
    }
    ALLOWED_AUDIO_EXTENSIONS = {'.wav', '.mp3', '.m4a', '.webm', '.ogg'}
    
    # Text validation patterns
    MAX_TEXT_LENGTH = 10000
    ALLOWED_TEXT_PATTERN = re.compile(r'^[\w\s\-_.!?,:;\'\"()[\]{}+=*&^%$#@~`|\\/<>\n\r\t\u0E00-\u0E7F]*$')
    
    def __init__(self):
        """Initialize validation service"""
        # Use the global magic availability flag
        self.magic_available = MAGIC_AVAILABLE
    
    def validate_audio_file(self, file: UploadFile) -> Dict[str, Any]:
        """
        Validate uploaded audio file
        
        Args:
            file: FastAPI UploadFile object
            
        Returns:
            Dict with validation results and file info
            
        Raises:
            HTTPException: If file validation fails
        """
        # Check file size
        if hasattr(file, 'size') and file.size > self.MAX_FILE_SIZE:
            raise HTTPException(
                status_code=413,
                detail=f"File too large. Maximum size is {self.MAX_FILE_SIZE // (1024*1024)}MB"
            )
        
        # Check filename
        if not file.filename:
            raise HTTPException(
                status_code=400,
                detail="Filename is required"
            )
        
        # Validate file extension
        file_path = Path(file.filename)
        file_extension = file_path.suffix.lower()
        
        if file_extension not in self.ALLOWED_AUDIO_EXTENSIONS:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid file extension. Allowed: {', '.join(self.ALLOWED_AUDIO_EXTENSIONS)}"
            )
        
        # Check content type header
        if file.content_type and file.content_type not in self.ALLOWED_AUDIO_TYPES:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid file type. Allowed: {', '.join(self.ALLOWED_AUDIO_TYPES)}"
            )
        
        return {
            'filename': file.filename,
            'content_type': file.content_type,
            'extension': file_extension,
            'size': getattr(file, 'size', None)
        }
    
    def validate_audio_content(self, file_content: bytes) -> Dict[str, Any]:
        """
        Validate audio file content by reading file headers
        
        Args:
            file_content: Audio file bytes
            
        Returns:
            Dict with content validation results
            
        Raises:
            HTTPException: If content validation fails
        """
        # Check file size
        if len(file_content) > self.MAX_FILE_SIZE:
            raise HTTPException(
                status_code=413,
                detail=f"File content too large. Maximum size is {self.MAX_FILE_SIZE // (1024*1024)}MB"
            )
        
        # Check for empty file
        if len(file_content) < 100:  # Minimum size for audio file
            raise HTTPException(
                status_code=400,
                detail="File appears to be empty or corrupted"
            )
        
        # Basic audio file header validation
        detected_type = None
        
        if self.magic_available:
            try:
                detected_type = magic.from_buffer(file_content, mime=True)
            except:
                pass
        
        # Fallback to simple header checks
        if not detected_type:
            detected_type = self._detect_audio_type_by_header(file_content)
        
        if detected_type and detected_type not in self.ALLOWED_AUDIO_TYPES:
            raise HTTPException(
                status_code=400,
                detail=f"File content does not appear to be a valid audio file"
            )
        
        return {
            'size': len(file_content),
            'detected_type': detected_type,
            'valid': True
        }
    
    def _detect_audio_type_by_header(self, content: bytes) -> Optional[str]:
        """
        Detect audio file type by reading file headers
        
        Args:
            content: File content bytes
            
        Returns:
            MIME type string or None
        """
        if len(content) < 4:
            return None
        
        # Check for common audio file signatures
        if content.startswith(b'RIFF') and b'WAVE' in content[:12]:
            return 'audio/wav'
        elif content.startswith(b'ID3') or content.startswith(b'\xff\xfb'):
            return 'audio/mpeg'
        elif content.startswith(b'OggS'):
            return 'audio/ogg'
        elif content.startswith(b'\x1aE\xdf\xa3'):
            return 'audio/webm'
        
        return None
    
    def sanitize_text(self, text: str, max_length: Optional[int] = None) -> str:
        """
        Sanitize text input
        
        Args:
            text: Input text to sanitize
            max_length: Maximum allowed length (defaults to MAX_TEXT_LENGTH)
            
        Returns:
            Sanitized text
            
        Raises:
            HTTPException: If text validation fails
        """
        if not text:
            return ""
        
        max_len = max_length or self.MAX_TEXT_LENGTH
        
        # Check length
        if len(text) > max_len:
            raise HTTPException(
                status_code=400,
                detail=f"Text too long. Maximum length is {max_len} characters"
            )
        
        # Basic pattern matching (allow Thai characters, English, common punctuation)
        if not self.ALLOWED_TEXT_PATTERN.match(text):
            raise HTTPException(
                status_code=400,
                detail="Text contains invalid characters"
            )
        
        # Remove any potential HTML/script tags
        text = re.sub(r'<[^>]*>', '', text)
        
        # Normalize whitespace
        text = ' '.join(text.split())
        
        return text
    
    def validate_language_code(self, lang_code: str) -> str:
        """
        Validate language code
        
        Args:
            lang_code: Language code to validate
            
        Returns:
            Validated language code
            
        Raises:
            HTTPException: If language code is invalid
        """
        # Allowed language codes for BabbleOn
        allowed_languages = {'th', 'en', 'th-TH', 'en-US', 'en-GB'}
        
        if lang_code not in allowed_languages:
            raise HTTPException(
                status_code=400,
                detail=f"Unsupported language code. Allowed: {', '.join(allowed_languages)}"
            )
        
        return lang_code
    
    def validate_complexity_level(self, complexity: int) -> int:
        """
        Validate complexity level
        
        Args:
            complexity: Complexity level to validate
            
        Returns:
            Validated complexity level
            
        Raises:
            HTTPException: If complexity level is invalid
        """
        if not isinstance(complexity, int) or complexity < 1 or complexity > 5:
            raise HTTPException(
                status_code=400,
                detail="Complexity level must be an integer between 1 and 5"
            )
        
        return complexity
    
    def validate_npc_id(self, npc_id: str) -> str:
        """
        Validate NPC ID
        
        Args:
            npc_id: NPC identifier to validate
            
        Returns:
            Validated NPC ID
            
        Raises:
            HTTPException: If NPC ID is invalid
        """
        # Allowed NPC IDs
        allowed_npcs = {'amara', 'somchai'}
        
        if npc_id not in allowed_npcs:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid NPC ID. Allowed: {', '.join(allowed_npcs)}"
            )
        
        return npc_id

# Global validation service instance
validation_service = ValidationService()

# Convenience functions for FastAPI dependencies
def validate_audio_upload(file: UploadFile = None) -> UploadFile:
    """FastAPI dependency for validating audio uploads"""
    if not file:
        raise HTTPException(status_code=400, detail="Audio file is required")
    
    validation_service.validate_audio_file(file)
    return file

def validate_text_input(text: str, max_length: Optional[int] = None) -> str:
    """Helper function for validating text input"""
    return validation_service.sanitize_text(text, max_length)