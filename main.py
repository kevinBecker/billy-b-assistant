import asyncio
import shutil
import signal
import subprocess
import sys
import threading
import time
import traceback
from pathlib import Path


# --- Ensure .env exists ---
def ensure_env_file():
    env_path = Path(".env")
    env_example_path = Path(".env.example")

    if not env_path.exists():
        if env_example_path.exists():
            shutil.copy(env_example_path, env_path)
            print("✅ .env file created from .env.example")
            print(
                "⚠️  Please review the .env file and update your API key and other settings."
            )
        else:
            print("❌ Neither .env nor .env.example found. Exiting.")
            sys.exit(1)


ensure_env_file()

# --- Now load env ---
from dotenv import load_dotenv


load_dotenv()

# --- Imports that might use environment variables ---
import core.button
from core.audio import playback_queue
from core.movements import start_motor_watchdog, stop_all_motors
from core.mqtt import start_mqtt, stop_mqtt
from core.config import (
    WYOMING_WAKE_WORD_SERVICE, 
    WYOMING_WAKE_WORD_URI, 
    WYOMING_WAKE_WORDS,
    DEBUG_MODE
)


# Global variables for process management
wake_word_process = None
wyoming_satellite_process = None


def signal_handler(sig, frame):
    print("\n👋 Exiting cleanly (signal received).")
    playback_queue.put(None)
    stop_all_motors()
    stop_mqtt()
    
    # Stop wake word service
    if wake_word_process:
        print("🛑 Stopping wake word service...")
        wake_word_process.terminate()
        try:
            wake_word_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            wake_word_process.kill()
    
    # Stop Wyoming satellite
    if wyoming_satellite_process:
        print("🛑 Stopping Wyoming satellite...")
        wyoming_satellite_process.terminate()
        try:
            wyoming_satellite_process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            wyoming_satellite_process.kill()
    
    sys.exit(0)


def start_wake_word_service():
    """Start the Wyoming wake word detection service."""
    global wake_word_process
    
    try:
        # Extract host and port from URI
        uri_parts = WYOMING_WAKE_WORD_URI.replace("tcp://", "").split(":")
        host = uri_parts[0]
        port = int(uri_parts[1])
        
        print(f"🎤 Starting wake word service: {WYOMING_WAKE_WORD_SERVICE}")
        print(f"🔗 URI: {WYOMING_WAKE_WORD_URI}")
        print(f"🗣️ Wake words: {', '.join(WYOMING_WAKE_WORDS)}")
        
        # Start the wake word service
        wake_word_process = subprocess.Popen([
            WYOMING_WAKE_WORD_SERVICE,
            "--uri", WYOMING_WAKE_WORD_URI
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        # Give it a moment to start
        time.sleep(2)
        
        if wake_word_process.poll() is None:
            print("✅ Wake word service started successfully")
            return True
        else:
            print("❌ Wake word service failed to start")
            return False
            
    except Exception as e:
        print(f"❌ Error starting wake word service: {e}")
        return False


def start_wyoming_satellite():
    """Start the Wyoming satellite service."""
    global wyoming_satellite_process
    
    try:
        print("🛰️ Starting Wyoming satellite...")
        
        # Start the Wyoming satellite
        wyoming_satellite_process = subprocess.Popen([
            sys.executable, "billy_wyoming_main.py"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        
        # Give it a moment to start
        time.sleep(3)
        
        if wyoming_satellite_process.poll() is None:
            print("✅ Wyoming satellite started successfully")
            return True
        else:
            print("❌ Wyoming satellite failed to start")
            return False
            
    except Exception as e:
        print(f"❌ Error starting Wyoming satellite: {e}")
        return False


main_event_loop = asyncio.get_event_loop()


def main():
    signal.signal(signal.SIGINT, signal_handler)
    signal.signal(signal.SIGTERM, signal_handler)

    print("🐟 Starting Billy Bass with Wyoming Integration...")
    print("=" * 50)
    
    # Start wake word service
    if not start_wake_word_service():
        print("❌ Failed to start wake word service. Exiting.")
        sys.exit(1)
    
    # Start Wyoming satellite
    if not start_wyoming_satellite():
        print("❌ Failed to start Wyoming satellite. Exiting.")
        sys.exit(1)
    
    # Start MQTT
    threading.Thread(target=start_mqtt, daemon=True).start()
    
    # Start motor watchdog
    start_motor_watchdog()
    
    # Start button handling
    core.button.start_loop()
    
    print("=" * 50)
    print("🐟 Billy Bass is ready!")
    print(f"🗣️ Say one of these wake words: {', '.join(WYOMING_WAKE_WORDS)}")
    print("🔘 Or press the button to start a voice session")
    print("=" * 50)
    
    try:
        # Keep main thread alive
        while True:
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("\n👋 Shutting down...")
        signal_handler(signal.SIGINT, None)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print("❌ Unhandled exception occurred:", e)
        traceback.print_exc()
        stop_all_motors()
        stop_mqtt()
        sys.exit(1)
