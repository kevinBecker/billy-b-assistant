"""
Local Text-to-Speech service client using Coqui TTS.
Replaces OpenAI voice synthesis with local TTS inference.
"""

import asyncio
import base64
import json
import aiohttp
from typing import Dict, Any, AsyncGenerator, Optional
from .config import LOCAL_TTS_HOST, LOCAL_TTS_PORT, LOCAL_TTS_VOICE


class LocalTTSClient:
    """Client for interacting with local Coqui TTS service."""
    
    def __init__(self):
        self.base_url = f"http://{LOCAL_TTS_HOST}:{LOCAL_TTS_PORT}"
        self.voice = LOCAL_TTS_VOICE
        self.session: Optional[aiohttp.ClientSession] = None
    
    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self
    
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()
    
    async def synthesize_speech(
        self, 
        text: str, 
        voice: Optional[str] = None,
        output_format: str = "pcm16"
    ) -> AsyncGenerator[Dict[str, Any], None]:
        """
        Synthesize speech from text using local TTS service.
        
        Args:
            text: Text to synthesize
            voice: Voice to use (optional, uses default if not provided)
            output_format: Audio output format (pcm16, wav, etc.)
            
        Yields:
            Dict containing audio data chunks
        """
        if not self.session:
            raise RuntimeError("Client not initialized. Use async context manager.")
        
        voice_to_use = voice or self.voice
        
        payload = {
            "text": text,
            "voice": voice_to_use,
            "output_format": output_format,
            "stream": True,
            "chunk_size": 1024  # Adjust based on TTS service capabilities
        }
        
        try:
            async with self.session.post(
                f"{self.base_url}/api/synthesize",
                json=payload,
                headers={"Content-Type": "application/json"}
            ) as response:
                if response.status != 200:
                    error_text = await response.text()
                    yield {
                        "type": "error",
                        "error": {
                            "code": "tts_error",
                            "message": f"TTS service error: {response.status} - {error_text}"
                        }
                    }
                    return
                
                # Stream audio chunks
                async for chunk in response.content.iter_chunked(1024):
                    if chunk:
                        # Encode audio chunk as base64 (matching OpenAI format)
                        b64_audio = base64.b64encode(chunk).decode('utf-8')
                        yield {
                            "type": "response.audio.delta",
                            "delta": b64_audio
                        }
                
                yield {"type": "response.done"}
                
        except aiohttp.ClientError as e:
            yield {
                "type": "error",
                "error": {
                    "code": "connection_error",
                    "message": f"Failed to connect to local TTS: {str(e)}"
                }
            }
        except Exception as e:
            yield {
                "type": "error",
                "error": {
                    "code": "unknown_error",
                    "message": f"Unexpected TTS error: {str(e)}"
                }
            }
    
    async def get_available_voices(self) -> list[str]:
        """Get list of available voices from TTS service."""
        try:
            if not self.session:
                async with aiohttp.ClientSession() as session:
                    async with session.get(f"{self.base_url}/api/voices") as response:
                        if response.status == 200:
                            data = await response.json()
                            return data.get("voices", [])
                        return []
            else:
                async with self.session.get(f"{self.base_url}/api/voices") as response:
                    if response.status == 200:
                        data = await response.json()
                        return data.get("voices", [])
                    return []
        except Exception:
            return []
    
    async def check_health(self) -> bool:
        """Check if the local TTS service is available."""
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
_tts_client: Optional[LocalTTSClient] = None


async def get_tts_client() -> LocalTTSClient:
    """Get or create the global TTS client."""
    global _tts_client
    if _tts_client is None:
        _tts_client = LocalTTSClient()
    return _tts_client


async def check_tts_health() -> bool:
    """Check if local TTS service is healthy."""
    async with LocalTTSClient() as client:
        return await client.check_health()
