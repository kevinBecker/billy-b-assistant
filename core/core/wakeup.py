import asyncio
import base64
import json
import os
import re
import wave

import websockets.legacy.client

from .config import CUSTOM_INSTRUCTIONS, OPENAI_API_KEY, OPENAI_MODEL, VOICE


WAKEUP_DIR = os.path.abspath(
    os.path.join(os.path.dirname(__file__), "../sounds/wake-up/custom")
)
os.makedirs(WAKEUP_DIR, exist_ok=True)


def slugify(text: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "_", text).strip("_").lower()


def get_wakeup_path(phrase: str) -> str:
    return os.path.join(WAKEUP_DIR, f"{slugify(phrase)}.wav")


def generate_wake_clip_async(prompt, index):
    path = os.path.join(WAKEUP_DIR, f"{index}.wav")

    async def _generate():
        uri = f"wss://api.openai.com/v1/realtime?model={OPENAI_MODEL}"
        headers = {
            "Authorization": f"Bearer {OPENAI_API_KEY}",
            "openai-beta": "realtime=v1",
        }

        print(f"🔊 Connecting to OpenAI realtime for: {prompt} → {index}", flush=True)

        try:
            async with websockets.legacy.client.connect(
                uri, extra_headers=headers
            ) as ws:
                print("🛰️ Connected to OpenAI realtime", flush=True)

                await ws.send(
                    json.dumps({
                        "type": "session.update",
                        "session": {
                            "voice": VOICE,
                            "modalities": ["text", "audio"],
                            "output_audio_format": "pcm16",
                            "turn_detection": {"type": "semantic_vad"},
                            "instructions": (
                                "Always respond by speaking the exact user text out loud. Do not change or rephrase anything!\n\n"
                                + CUSTOM_INSTRUCTIONS
                            ),
                        },
                    })
                )
                print("🗣️ Sent session update", flush=True)

                await ws.send(
                    json.dumps({
                        "type": "conversation.item.create",
                        "item": {
                            "type": "message",
                            "role": "user",
                            "content": [
                                {
                                    "type": "input_text",
                                    "text": "Repeat this literal message:" + prompt,
                                }
                            ],
                        },
                    })
                )
                print("📤 Sent prompt", flush=True)

                await ws.send(
                    json.dumps({
                        "type": "response.create",
                        "response": {"modalities": ["audio", "text"]},
                    })
                )
                print("⏳ Waiting for response...", flush=True)

                audio_data = bytearray()

                async for message in ws:
                    parsed = json.loads(message)
                    print(f"📩 {parsed['type']}", flush=True)

                    if parsed["type"] == "error":
                        print(
                            f"❌ OpenAI API error: {json.dumps(parsed, indent=2)}",
                            flush=True,
                        )

                    if parsed["type"] in ("response.audio", "response.audio.delta"):
                        b64 = parsed.get("audio") or parsed.get("delta")
                        if b64:
                            audio_data.extend(base64.b64decode(b64))

                    if parsed["type"] == "response.done":
                        break

                print(f"📦 Audio data size: {len(audio_data)} bytes", flush=True)

                if not audio_data:
                    raise RuntimeError("No audio data received from OpenAI.")

                with wave.open(path, "wb") as wf:
                    print(f"💾 Writing WAV to: {path}", flush=True)
                    wf.setnchannels(1)
                    wf.setsampwidth(2)
                    wf.setframerate(24000)
                    wf.writeframes(audio_data)

                print(f"✅ Saved wakeup clip: {path}", flush=True)
                return path

        except Exception as e:
            print(f"❌ ERROR during TTS generation: {e}", flush=True)
            raise

    return asyncio.run(_generate())
