"""
Hybrid say function that can use either OpenAI or local models.
Maintains compatibility with existing MQTT integration.
"""

import asyncio
import base64
import json
import os

from .config import USE_LOCAL_MODELS, INSTRUCTIONS, VOICE
from .audio import (
    enqueue_wav_to_playback,
    ensure_playback_worker_started,
    playback_queue,
    rotate_and_save_response_audio,
)
from .movements import move_head, stop_all_motors
from .local_session import LocalBillySession


async def say(text: str):
    """
    Say text using either OpenAI or local models based on configuration.
    Maintains compatibility with existing MQTT integration.
    """
    print(f"🗣️ say() called with text={text!r} (local models: {USE_LOCAL_MODELS})")
    
    if USE_LOCAL_MODELS:
        await _say_local(text)
    else:
        await _say_openai(text)


async def _say_local(text: str):
    """Say text using local models."""
    print("🏠 Using local models for speech synthesis")
    
    # Create a temporary local session for this say operation
    session = LocalBillySession()
    
    try:
        # Start the session
        if not await session.start():
            print("❌ Failed to start local session, falling back to error sound")
            await _play_error_sound()
            return
        
        # Prepare the text for speaking
        if text.strip().startswith("{{") and text.strip().endswith("}}"):
            # Remove prompt markers and speak literally
            stripped_text = text.strip()[2:-2].strip()
            print("💬 Detected prompt message, speaking literally")
            speak_text = stripped_text
        else:
            # Speak the text as-is
            print("💬 Speaking literal message")
            speak_text = text
        
        # Start head movement
        move_head("on")
        
        # Generate and play speech
        success = await session.say_text(speak_text)
        
        if not success:
            print("❌ Failed to generate speech, playing error sound")
            await _play_error_sound()
        
        print(f"✅ Speech completed: {speak_text}")
        
    except Exception as e:
        print(f"❌ Error in local say: {e}")
        await _play_error_sound()
    
    finally:
        # Stop head movement
        stop_all_motors()
        # Clean up session
        await session.stop()


async def _say_openai(text: str):
    """Say text using OpenAI (original implementation)."""
    print("☁️ Using OpenAI for speech synthesis")
    
    # Import OpenAI dependencies only when needed
    import websockets.legacy.client
    from .config import OPENAI_API_KEY, OPENAI_MODEL
    
    uri = f"wss://api.openai.com/v1/realtime?model={OPENAI_MODEL}"
    headers = {
        "Authorization": f"Bearer {OPENAI_API_KEY}",
        "openai-beta": "realtime=v1",
    }
    
    try:
        async with websockets.legacy.client.connect(uri, extra_headers=headers) as ws:
            # Step 1: Start session
            await ws.send(
                json.dumps({
                    "type": "session.update",
                    "session": {
                        "voice": VOICE,
                        "modalities": ["text", "audio"],
                        "output_audio_format": "pcm16",
                        "turn_detection": {"type": "semantic_vad"},
                        "instructions": INSTRUCTIONS,
                    },
                })
            )
            print("🛰️ OpenAI session started")
            
            # Step 2: Prepare message
            if text.strip().startswith("{{") and text.strip().endswith("}}"):
                stripped_text = text.strip()[2:-2].strip()
                print("💬 Detected prompt message, sending as-is")
                user_message = stripped_text
            else:
                print("💬 Detected literal message")
                user_message = (
                    "Override for this turn while maintaining your tone and accent:\n"
                    "Say the user's message **verbatim**, word for word, with no additions or reinterpretation.\n"
                    "Maintain personality, but do NOT rephrase or expand.\n\n"
                    f"Repeat this literal message sent via MQTT: {text}"
                )
            
            await ws.send(
                json.dumps({
                    "type": "conversation.item.create",
                    "item": {
                        "type": "message",
                        "role": "user",
                        "content": [{"type": "input_text", "text": user_message}],
                    },
                })
            )
            
            await ws.send(json.dumps({"type": "response.create"}))
            print("📤 Message sent to OpenAI")
            
            # Start head movement
            move_head("on")
            
            full_audio = bytearray()
            full_text = ""
            
            async for message in ws:
                parsed = json.loads(message)
                
                # Handle explicit error responses from OpenAI
                if parsed.get("type") == "error":
                    error = parsed.get("error", {})
                    code = error.get("code", "<unknown>")
                    msg = error.get("message", "<unknown>")
                    print(f"🛑 OpenAI Error ({code}): {msg}")
                    
                    stop_all_motors()
                    sound_path = (
                        "sounds/noapikey.wav"
                        if code == "invalid_api_key"
                        else "sounds/error.wav"
                    )
                    
                    if os.path.exists(sound_path):
                        print(f"🔊 Playing {os.path.basename(sound_path)}...")
                        await asyncio.to_thread(enqueue_wav_to_playback, sound_path)
                        await asyncio.to_thread(playback_queue.join)
                    else:
                        print(f"⚠️ {sound_path} not found, skipping audio.")
                    
                    return  # stop say()
                
                # Capture audio
                if parsed["type"] in ("response.audio", "response.audio.delta"):
                    b64 = parsed.get("audio") or parsed.get("delta")
                    if b64:
                        chunk = base64.b64decode(b64)
                        playback_queue.put(chunk)
                        full_audio.extend(chunk)
                
                # Capture text
                if parsed["type"] in (
                    "response.text.delta",
                    "response.audio_transcript.delta",
                ):
                    delta = parsed.get("delta")
                    if delta:
                        full_text += delta
                
                if parsed["type"] == "response.done":
                    await ws.send(json.dumps({"type": "session.end"}))
                    break
            
            print(f"✅ Audio received: {len(full_audio)} bytes")
            print(f"📝 Transcript: {full_text.strip()}")
            
    except Exception as e:
        print(f"❌ Error in OpenAI say: {e}")
        await _play_error_sound()


async def _play_error_sound():
    """Play error sound when speech synthesis fails."""
    error_sound = "sounds/error.wav"
    if os.path.exists(error_sound):
        print(f"🔊 Playing error sound: {error_sound}")
        await asyncio.to_thread(enqueue_wav_to_playback, error_sound)
        await asyncio.to_thread(playback_queue.join)
    else:
        print(f"⚠️ Error sound not found: {error_sound}")
