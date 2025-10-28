#!/usr/bin/env python3
"""
Billy Bass Wyoming Satellite Event Handler

This module integrates Billy Bass's motion system with Wyoming-Satellite's audio processing.
It handles Wyoming events and triggers appropriate Billy movements.
"""

import argparse
import asyncio
import logging
import time
from functools import partial

import numpy as np
from wyoming.audio import AudioChunk
from wyoming.event import Event
from wyoming.server import AsyncEventHandler, AsyncServer

# Import Billy's motion system
from core.movements import (
    flap_from_pcm_chunk,
    interlude,
    move_head,
    move_tail_async,
    stop_all_motors,
)
from core.config import CHUNK_MS

_LOGGER = logging.getLogger()


class BillyWyomingEventHandler(AsyncEventHandler):
    """Event handler that integrates Billy Bass motion with Wyoming-Satellite."""

    def __init__(
        self,
        cli_args: argparse.Namespace,
        *args,
        **kwargs,
    ) -> None:
        super().__init__(*args, **kwargs)
        self.cli_args = cli_args
        self.client_id = str(time.monotonic_ns())
        self.is_speaking = False
        self.is_listening = False
        
        # Audio processing state
        self.audio_buffer = []
        self.last_audio_time = 0
        
        _LOGGER.debug("Billy Wyoming Event Handler initialized: %s", self.client_id)

    async def handle_event(self, event: Event) -> bool:
        """Handle Wyoming events and trigger Billy movements."""
        try:
            # Handle different event types
            if AudioChunk.is_type(event.type):
                await self._handle_audio_chunk(event)
            elif event.type == "wyoming.wake.detection":
                await self._handle_wake_detection()
            elif event.type == "wyoming.asr.transcript":
                await self._handle_transcript(event)
            elif event.type == "wyoming.tts.synthesize":
                await self._handle_tts_start()
            elif event.type == "wyoming.snd.played":
                await self._handle_tts_stop()
            elif event.type == "wyoming.error":
                await self._handle_error(event)
            elif event.type == "wyoming.satellite.streaming_started":
                await self._handle_streaming_started()
            elif event.type == "wyoming.satellite.streaming_stopped":
                await self._handle_streaming_stopped()
                
        except Exception as e:
            _LOGGER.exception("Error handling event: %s", e)
            
        return True

    async def _handle_audio_chunk(self, event: Event) -> None:
        """Handle audio chunks for mouth movement synchronization."""
        try:
            chunk = AudioChunk.from_event(event)
            
            # Convert audio to numpy array for processing
            audio_data = np.frombuffer(chunk.audio, dtype=np.int16)
            
            # Trigger mouth flapping based on audio
            if self.is_speaking:
                flap_from_pcm_chunk(audio_data, chunk_ms=CHUNK_MS)
            
            # Store audio for potential processing
            self.audio_buffer.extend(audio_data)
            self.last_audio_time = time.time()
            
            # Keep buffer size manageable
            if len(self.audio_buffer) > 16000:  # ~1 second at 16kHz
                self.audio_buffer = self.audio_buffer[-8000:]  # Keep last 0.5 seconds
                
        except Exception as e:
            _LOGGER.exception("Error processing audio chunk: %s", e)

    async def _handle_wake_detection(self) -> None:
        """Handle wake word detection - Billy wakes up!"""
        _LOGGER.info("Wake word detected - Billy is waking up!")
        self.is_listening = True
        move_head("on")  # Billy raises his head when woken up

    async def _handle_transcript(self, event: Event) -> None:
        """Handle speech-to-text transcript."""
        _LOGGER.info("Transcript received: %s", event)
        # Billy can do a little tail wag when he understands
        move_tail_async(duration=0.3)

    async def _handle_tts_start(self) -> None:
        """Handle text-to-speech start - Billy starts speaking."""
        _LOGGER.info("TTS started - Billy is speaking!")
        self.is_speaking = True
        move_head("on")  # Billy raises his head when speaking

    async def _handle_tts_stop(self) -> None:
        """Handle text-to-speech stop - Billy stops speaking."""
        _LOGGER.info("TTS stopped - Billy finished speaking")
        self.is_speaking = False
        move_head("off")  # Billy lowers his head when done speaking
        
        # Random interlude behavior
        if np.random.random() < 0.3:  # 30% chance
            interlude()

    async def _handle_error(self, event: Event) -> None:
        """Handle errors."""
        _LOGGER.warning("Error occurred: %s", event)
        # Billy can show he's confused with a tail movement
        move_tail_async(duration=0.5)

    async def _handle_streaming_started(self) -> None:
        """Handle when audio streaming starts."""
        _LOGGER.info("Audio streaming started")
        self.is_listening = True

    async def _handle_streaming_stopped(self) -> None:
        """Handle when audio streaming stops."""
        _LOGGER.info("Audio streaming stopped")
        self.is_listening = False

    async def disconnect(self) -> None:
        """Clean up when client disconnects."""
        _LOGGER.info("Client disconnected: %s", self.client_id)
        self.is_speaking = False
        self.is_listening = False
        move_head("off")
        stop_all_motors()


async def main() -> None:
    """Main entry point."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--uri", default="stdio://", help="unix:// or tcp://")
    parser.add_argument("--debug", action="store_true", help="Log DEBUG messages")
    args = parser.parse_args()

    logging.basicConfig(level=logging.DEBUG if args.debug else logging.INFO)
    _LOGGER.debug(args)

    _LOGGER.info("Billy Bass Wyoming Event Handler Ready")

    # Start server
    server = AsyncServer.from_uri(args.uri)

    try:
        await server.run(partial(BillyWyomingEventHandler, args))
    except KeyboardInterrupt:
        pass
    finally:
        # Cleanup
        stop_all_motors()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
