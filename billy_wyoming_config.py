"""
Billy Bass Wyoming Integration Configuration

This module provides configuration settings for integrating Billy Bass
with Wyoming-Satellite voice processing.
"""

import os
from wyoming_satellite.settings import SatelliteSettings, MicSettings, SndSettings, WakeSettings, EventSettings, VadSettings

def create_billy_satellite_settings():
    """Create optimized Wyoming Satellite settings for Billy Bass."""
    settings = SatelliteSettings()
    
    # Microphone settings - optimized for Billy's audio setup
    settings.mic.enabled = True
    settings.mic.rate = 16000
    settings.mic.width = 2
    settings.mic.channels = 1
    settings.mic.samples_per_chunk = 1024
    settings.mic.command = ["arecord", "-r", "16000", "-c", "1", "-f", "S16_LE", "-t", "raw"]
    settings.mic.reconnect_seconds = 5.0
    settings.mic.volume_multiplier = 1.0
    settings.mic.auto_gain = 0  # Disable auto gain for Billy
    settings.mic.noise_suppression = 0  # Disable noise suppression for Billy
    settings.mic.mute_during_awake_wav = True
    settings.mic.seconds_to_mute_after_awake_wav = 1.0
    
    # Speaker settings - optimized for Billy's audio output
    settings.snd.enabled = True
    settings.snd.rate = 22050
    settings.snd.width = 2
    settings.snd.channels = 1
    settings.snd.samples_per_chunk = 1024
    settings.snd.command = ["aplay", "-r", "22050", "-c", "1", "-f", "S16_LE", "-t", "raw"]
    settings.snd.reconnect_seconds = 5.0
    settings.snd.volume_multiplier = 1.0
    settings.snd.disconnect_after_stop = False
    
    # Wake word detection settings
    settings.wake.enabled = True
    settings.wake.uri = "tcp://127.0.0.1:10400"  # Local wake word service
    settings.wake.rate = 16000
    settings.wake.width = 2
    settings.wake.channels = 1
    settings.wake.names = [
        {"name": "ok_nabu", "pipeline": None},
        {"name": "hey_jarvis", "pipeline": None},
        {"name": "alexa", "pipeline": None}
    ]
    settings.wake.refractory_seconds = 2.0
    settings.wake.reconnect_seconds = 5.0
    
    # Event handling settings
    settings.event.enabled = True
    settings.event.uri = "stdio://"  # Use our custom event handler
    settings.event.reconnect_seconds = 5.0
    
    # VAD settings - disabled since we use wake word detection
    settings.vad.enabled = False
    settings.vad.threshold = 0.5
    settings.vad.trigger_level = 0.3
    settings.vad.buffer_seconds = 0.5
    settings.vad.wake_word_timeout = 10.0
    
    # Timer settings
    settings.timer.finished_wav = None
    settings.timer.finished_wav_plays = 1
    settings.timer.finished_wav_delay = 0.0
    
    # Debug settings
    settings.debug_recording_dir = None
    
    return settings


def get_audio_device_commands():
    """Get audio device commands based on Billy's hardware configuration."""
    # Check for specific audio devices
    mic_device = os.getenv("MIC_PREFERENCE", "")
    speaker_device = os.getenv("SPEAKER_PREFERENCE", "")
    
    mic_cmd = ["arecord", "-r", "16000", "-c", "1", "-f", "S16_LE", "-t", "raw"]
    snd_cmd = ["aplay", "-r", "22050", "-c", "1", "-f", "S16_LE", "-t", "raw"]
    
    if mic_device:
        mic_cmd.extend(["-D", mic_device])
    
    if speaker_device:
        snd_cmd.extend(["-D", speaker_device])
    
    return mic_cmd, snd_cmd


def update_settings_for_hardware(settings):
    """Update settings based on detected hardware."""
    mic_cmd, snd_cmd = get_audio_device_commands()
    settings.mic.command = mic_cmd
    settings.snd.command = snd_cmd
    
    return settings
