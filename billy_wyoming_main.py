#!/usr/bin/env python3
"""
Billy Bass Wyoming Integration Main Script

This script integrates Billy Bass with Wyoming-Satellite for voice processing
while maintaining Billy's unique motion capabilities.
"""

import asyncio
import logging
import signal
import sys
import threading
import time
from pathlib import Path

# Ensure .env exists
def ensure_env_file():
    env_path = Path(".env")
    env_example_path = Path(".env.example")

    if not env_path.exists():
        if env_example_path.exists():
            import shutil
            shutil.copy(env_example_path, env_path)
            print("✅ .env file created from .env.example")
            print("⚠️  Please review the .env file and update your API key and other settings.")
        else:
            print("❌ Neither .env nor .env.example found. Exiting.")
            sys.exit(1)

ensure_env_file()

# Load environment
from dotenv import load_dotenv
load_dotenv()

# Import Billy components
import core.button
from core.movements import start_motor_watchdog, stop_all_motors
from core.mqtt import start_mqtt, stop_mqtt
from core.config import DEBUG_MODE, CHUNK_MS

# Import Wyoming components
from wyoming_satellite.satellite import WakeStreamingSatellite
from wyoming_satellite.settings import SatelliteSettings
from wyoming_satellite.event_handler import SatelliteEventHandler
from wyoming.info import Info
from wyoming.server import AsyncServer

# Import our custom configuration
from billy_wyoming_config import create_billy_satellite_settings, update_settings_for_hardware

_LOGGER = logging.getLogger()


class BillyWyomingSatellite(WakeStreamingSatellite):
    """Custom Wyoming Satellite with Billy Bass integration."""
    
    def __init__(self, settings: SatelliteSettings):
        super().__init__(settings)
        self.billy_event_handler = None
        
    async def trigger_detection(self, detection):
        """Override to add Billy-specific wake word handling."""
        await super().trigger_detection(detection)
        _LOGGER.info("Billy detected wake word: %s", detection.name)
        # Billy raises his head when woken up
        from core.movements import move_head
        move_head("on")
        
    async def trigger_tts_start(self):
        """Override to add Billy-specific TTS handling."""
        await super().trigger_tts_start()
        _LOGGER.info("Billy started speaking")
        # Billy raises his head when speaking
        from core.movements import move_head
        move_head("on")
        
    async def trigger_tts_stop(self):
        """Override to add Billy-specific TTS handling."""
        await super().trigger_tts_stop()
        _LOGGER.info("Billy finished speaking")
        # Billy lowers his head when done speaking
        from core.movements import move_head, interlude
        move_head("off")
        # Random interlude behavior
        import random
        if random.random() < 0.3:  # 30% chance
            interlude()
            
    async def event_from_mic(self, event, audio_bytes=None):
        """Override to add Billy-specific audio processing."""
        await super().event_from_mic(event, audio_bytes)
        
        # Add mouth flapping during TTS
        if hasattr(self, 'is_streaming') and self.is_streaming:
            from wyoming.audio import AudioChunk
            if AudioChunk.is_type(event.type):
                chunk = AudioChunk.from_event(event)
                import numpy as np
                audio_data = np.frombuffer(chunk.audio, dtype=np.int16)
                from core.movements import flap_from_pcm_chunk
                flap_from_pcm_chunk(audio_data, chunk_ms=CHUNK_MS)


def signal_handler(sig, frame):
    """Handle shutdown signals."""
    print("\n👋 Exiting cleanly (signal received).")
    stop_all_motors()
    stop_mqtt()
    sys.exit(0)


def create_satellite_settings():
    """Create Wyoming Satellite settings for Billy."""
    settings = create_billy_satellite_settings()
    settings = update_settings_for_hardware(settings)
    return settings


async def run_wyoming_satellite():
    """Run the Wyoming Satellite with Billy integration."""
    settings = create_satellite_settings()
    satellite = BillyWyomingSatellite(settings)
    
    # Create Wyoming info
    wyoming_info = Info(
        wyoming=Info.Wyoming(version="1.0.0"),
        satellite=Info.Satellite(
            name="Billy Bass Assistant",
            description="Big Mouth Billy Bass with Wyoming voice processing",
            attribution="Thom Koopman",
            installed=True
        )
    )
    
    # Create event handler
    event_handler = SatelliteEventHandler(
        wyoming_info=wyoming_info,
        satellite=satellite,
        cli_args=None
    )
    
    # Start server
    server = AsyncServer.from_uri("tcp://0.0.0.0:10700")
    
    try:
        await server.run(lambda *args, **kwargs: event_handler)
    except Exception as e:
        _LOGGER.exception("Error running Wyoming Satellite: %s", e)
    finally:
        stop_all_motors()


def main():
    """Main entry point."""
    # Setup signal handlers
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)
    
    # Setup logging
    logging.basicConfig(
        level=logging.DEBUG if DEBUG_MODE else logging.INFO,
        format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    
    # Start MQTT
    threading.Thread(target=start_mqtt, daemon=True).start()
    
    # Start motor watchdog
    start_motor_watchdog()
    
    # Start button handling
    core.button.start_loop()
    
    # Start Wyoming Satellite in a separate thread
    def run_satellite():
        try:
            asyncio.run(run_wyoming_satellite())
        except Exception as e:
            _LOGGER.exception("Error in satellite thread: %s", e)
    
    satellite_thread = threading.Thread(target=run_satellite, daemon=True)
    satellite_thread.start()
    
    print("🐟 Billy Bass Wyoming Integration Ready!")
    print("🎤 Press button to start voice session")
    print("🕐 Waiting for button press...")
    
    try:
        # Keep main thread alive
        while True:
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("\n👋 Shutting down...")
        stop_all_motors()
        stop_mqtt()
        sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"❌ Unhandled exception occurred: {e}")
        import traceback
        traceback.print_exc()
        stop_all_motors()
        stop_mqtt()
        sys.exit(1)
