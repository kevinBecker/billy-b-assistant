"""
Local Speech-to-Text service client using Whisper.cpp.
Replaces OpenAI audio transcription with local STT inference.
"""

import asyncio
import base64
import json
import aiohttp
from typing import Dict, Any, Optional
from .config import LOCAL_STT_HOST, LOCAL_STT_PORT


class LocalSTTClient:
    """Client for interacting with local Whisper STT service."""
    
    def __init__(self):
        self.base_url = f"http://{LOCAL_STT_HOST}:{LOCAL_STT_PORT}"
        self.session: Optional[aiohttp.ClientSession] = None
    
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
    
    async def transcribe_audio(
        self, 
        audio_data: bytes,
        language: str = "en",
        model: str = "base"
    ) -> Dict[str, Any]:
        """
        Transcribe audio data to text using local STT service.
        
        Args:
            audio_data: Raw audio data (PCM16 format)
            language: Language code for transcription
            model: Whisper model to use
            
        Returns:
            Dict containing transcription result
        """
        if not self.session:
            raise RuntimeError("Client not initialized. Use async context manager.")
        
        # Encode audio as base64
        b64_audio = base64.b64encode(audio_data).decode('utf-8')
        
        payload = {
            "audio": b64_audio,
            "language": language,
            "model": model,
            "format": "pcm16"
        }
        
        try:
            async with self.session.post(
                f"{self.base_url}/api/transcribe",
                json=payload,
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    return {
                        "type": "error",
                        "error": {
                            "code": "stt_error",
                            "message": f"STT service error: {response.status} - {error_text}"
                        }
                    }
                
                data = await response.json()
                return {
                    "type": "transcription",
                    "text": data.get("text", ""),
                    "confidence": data.get("confidence", 0.0),
                    "language": data.get("language", language)
                }
                
        except aiohttp.ClientError as e:
            return {
                "type": "error",
                "error": {
                    "code": "connection_error",
                    "message": f"Failed to connect to local STT: {str(e)}"
                }
            }
        except Exception as e:
            return {
                "type": "error",
                "error": {
                    "code": "unknown_error",
                    "message": f"Unexpected STT error: {str(e)}"
                }
            }
    
    async def check_health(self) -> bool:
        """Check if the local STT service is available."""
        try:
            if not self.session:
                async with aiohttp.ClientSession() as session:
                    async with session.get(f"{self.base_url}/api/health") as response:
                        return response.status == 200
            else:
                async with self.session.get(f"{self.base_url}/api/health") as response:
                    return response.status == 200
        except Exception:
            return False


# Global client instance
_stt_client: Optional[LocalSTTClient] = None


async def get_stt_client() -> LocalSTTClient:
    """Get or create the global STT client."""
    global _stt_client
    if _stt_client is None:
        _stt_client = LocalSTTClient()
    return _stt_client


async def check_stt_health() -> bool:
    """Check if local STT service is healthy."""
    async with LocalSTTClient() as client:
        return await client.check_health()
