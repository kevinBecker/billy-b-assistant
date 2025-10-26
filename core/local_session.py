"""
Local model session handler for Billy B-Assistant.
Replaces OpenAI Realtime API with local model services.
"""

import asyncio
import base64
import json
import time
from typing import Any, Dict, List, Optional

from .config import (
    INSTRUCTIONS,
    PERSONALITY,
    TOOLS,
    USE_LOCAL_MODELS,
    LOCAL_LLM_MODEL,
    LOCAL_TTS_VOICE,
    LOCAL_STT_MODEL,
    DEBUG_MODE,
    TEXT_ONLY_MODE,
)
from .local_llm import LocalLLMClient, check_llm_health
from .local_tts import LocalTTSClient, check_tts_health
from .local_stt import LocalSTTClient, check_stt_health
from .ha import send_conversation_prompt
from .movements import move_tail_async, stop_all_motors
from .mqtt import mqtt_publish
from .personality import update_persona_ini
from . import audio


class LocalBillySession:
    """Session handler for local model integration."""
    
    def __init__(self, interrupt_event=None):
        self.interrupt_event = interrupt_event
        self.llm_client: Optional[LocalLLMClient] = None
        self.tts_client: Optional[LocalTTSClient] = None
        self.stt_client: Optional[LocalSTTClient] = None
        
        # Session state
        self.session_active = asyncio.Event()
        self.audio_buffer: List[bytes] = []
        self.committed = False
        self.first_text = True
        self.full_response_text = ""
        self.last_activity = [time.time()]
        self.user_spoke_after_assistant = False
        self.allow_mic_input = True
        
        # Conversation history
        self.conversation_history: List[Dict[str, Any]] = []
        
        # Health status
        self.llm_healthy = False
        self.tts_healthy = False
        self.stt_healthy = False
    
    async def start(self):
        """Initialize the local model session."""
        print("\n⏱️ Local model session starting...")
        
        # Check service health
        self.llm_healthy = await check_llm_health()
        self.tts_healthy = await check_tts_health()
        self.stt_healthy = await check_stt_health()
        
        if not self.llm_healthy:
            print("❌ Local LLM service is not available")
            return False
        
        if not self.tts_healthy and not TEXT_ONLY_MODE:
            print("⚠️ Local TTS service is not available, falling back to text-only mode")
        
        if not self.stt_healthy:
            print("⚠️ Local STT service is not available")
        
        # Initialize clients
        self.llm_client = LocalLLMClient()
        if self.tts_healthy:
            self.tts_client = LocalTTSClient()
        if self.stt_healthy:
            self.stt_client = LocalSTTClient()
        
        # Initialize conversation with system message
        self.conversation_history = [
            {
                "role": "system",
                "content": INSTRUCTIONS
            }
        ]
        
        self.session_active.set()
        print("✅ Local model session started successfully")
        return True
    
    async def stop(self):
        """Stop the local model session."""
        print("\n🛑 Stopping local model session...")
        
        self.session_active.clear()
        
        # Close clients
        if self.llm_client:
            await self.llm_client.__aexit__(None, None, None)
        if self.tts_client:
            await self.tts_client.__aexit__(None, None, None)
        if self.stt_client:
            await self.stt_client.__aexit__(None, None, None)
        
        print("✅ Local model session stopped")
    
    async def process_audio_input(self, audio_data: bytes) -> Optional[str]:
        """Process audio input and return transcribed text."""
        if not self.stt_healthy or not self.stt_client:
            return None
        
        try:
            result = await self.stt_client.transcribe_audio(audio_data)
            if result.get("type") == "transcription":
                return result.get("text", "")
            else:
                print(f"❌ STT error: {result.get('error', {}).get('message', 'Unknown error')}")
                return None
        except Exception as e:
            print(f"❌ STT processing error: {e}")
            return None
    
    async def generate_response(self, user_input: str) -> AsyncGenerator[Dict[str, Any], None]:
        """Generate response to user input using local models."""
        if not self.llm_healthy or not self.llm_client:
            yield {
                "type": "error",
                "error": {
                    "code": "service_unavailable",
                    "message": "Local LLM service is not available"
                }
            }
            return
        
        # Add user message to conversation history
        self.conversation_history.append({
            "role": "user",
            "content": user_input
        })
        
        try:
            # Generate response using local LLM
            async for response_chunk in self.llm_client.generate_response(
                messages=self.conversation_history,
                tools=TOOLS,
                stream=True
            ):
                if response_chunk.get("type") == "error":
                    yield response_chunk
                    return
                
                # Handle text response
                if response_chunk.get("type") == "response.text.delta":
                    delta = response_chunk.get("delta", "")
                    self.full_response_text += delta
                    yield response_chunk
                
                # Handle tool calls
                elif response_chunk.get("type") == "response.tool_call":
                    tool_call = response_chunk.get("tool_call", {})
                    tool_result = await self._handle_tool_call(tool_call)
                    
                    # Add tool result to conversation
                    self.conversation_history.append({
                        "role": "tool",
                        "content": tool_result,
                        "tool_call_id": tool_call.get("id", "")
                    })
                    
                    yield {
                        "type": "response.tool_call",
                        "tool_call": tool_call
                    }
                
                # Handle completion
                elif response_chunk.get("type") == "response.done":
                    # Add assistant response to conversation history
                    if self.full_response_text:
                        self.conversation_history.append({
                            "role": "assistant",
                            "content": self.full_response_text
                        })
                    
                    # Generate speech if TTS is available
                    if self.tts_healthy and self.tts_client and self.full_response_text:
                        async for audio_chunk in self.tts_client.synthesize_speech(
                            text=self.full_response_text,
                            voice=LOCAL_TTS_VOICE
                        ):
                            if audio_chunk.get("type") == "response.audio.delta":
                                yield audio_chunk
                            elif audio_chunk.get("type") == "error":
                                print(f"⚠️ TTS error: {audio_chunk.get('error', {}).get('message', 'Unknown error')}")
                    
                    yield {"type": "response.done"}
                    break
                    
        except Exception as e:
            yield {
                "type": "error",
                "error": {
                    "code": "generation_error",
                    "message": f"Error generating response: {str(e)}"
                }
            }
    
    async def _handle_tool_call(self, tool_call: Dict[str, Any]) -> str:
        """Handle function tool calls."""
        tool_name = tool_call.get("name", "")
        tool_args = json.loads(tool_call.get("arguments", "{}"))
        
        try:
            if tool_name == "update_personality":
                # Update personality traits
                traits = {k: v for k, v in tool_args.items() if k in vars(PERSONALITY)}
                if traits:
                    update_persona_ini(traits)
                    return f"Updated personality traits: {list(traits.keys())}"
                return "No valid personality traits to update"
            
            elif tool_name == "play_song":
                # Play a song
                song_name = tool_args.get("song", "")
                if song_name:
                    await audio.play_song(song_name)
                    return f"Playing song: {song_name}"
                return "No song specified"
            
            elif tool_name == "smart_home_command":
                # Send command to Home Assistant
                prompt = tool_args.get("prompt", "")
                if prompt:
                    ha_response = await send_conversation_prompt(prompt)
                    if ha_response:
                        return f"Home Assistant response: {ha_response}"
                    return "No response from Home Assistant"
                return "No command specified"
            
            else:
                return f"Unknown tool: {tool_name}"
                
        except Exception as e:
            return f"Error executing tool {tool_name}: {str(e)}"
    
    async def say_text(self, text: str) -> bool:
        """Say text using local TTS."""
        if not self.tts_healthy or not self.tts_client:
            print("⚠️ TTS service not available")
            return False
        
        try:
            full_audio = bytearray()
            async for audio_chunk in self.tts_client.synthesize_speech(
                text=text,
                voice=LOCAL_TTS_VOICE
            ):
                if audio_chunk.get("type") == "response.audio.delta":
                    delta = audio_chunk.get("delta", "")
                    if delta:
                        chunk = base64.b64decode(delta)
                        audio.playback_queue.put(chunk)
                        full_audio.extend(chunk)
                elif audio_chunk.get("type") == "error":
                    print(f"❌ TTS error: {audio_chunk.get('error', {}).get('message', 'Unknown error')}")
                    return False
            
            print(f"✅ Audio generated: {len(full_audio)} bytes")
            return True
            
        except Exception as e:
            print(f"❌ TTS error: {e}")
            return False
    
    def get_health_status(self) -> Dict[str, bool]:
        """Get health status of all local services."""
        return {
            "llm": self.llm_healthy,
            "tts": self.tts_healthy,
            "stt": self.stt_healthy
        }
