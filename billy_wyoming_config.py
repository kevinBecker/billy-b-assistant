"""
Billy Bass Wyoming Integration Configuration

This module provides configuration settings for integrating Billy Bass
with Wyoming-Satellite voice processing.
"""

import os
from wyoming_satellite.settings import SatelliteSettings, MicSettings, SndSettings, WakeSettings, EventSettings, VadSettings

def create_billy_satellite_settings():
    """Create optimized Wyoming Satellite settings for Billy Bass."""
    # Create individual settings objects
    mic_settings = MicSettings()
    mic_settings.enabled = True
    mic_settings.rate = 16000
    mic_settings.width = 2
    mic_settings.channels = 1
    mic_settings.samples_per_chunk = 1024
    mic_settings.command = ["arecord", "-r", "16000", "-c", "1", "-f", "S16_LE", "-t", "raw"]
    mic_settings.reconnect_seconds = 5.0
    mic_settings.volume_multiplier = 1.0
    mic_settings.auto_gain = 0  # Disable auto gain for Billy
    mic_settings.noise_suppression = 0  # Disable noise suppression for Billy
    mic_settings.mute_during_awake_wav = True
    mic_settings.seconds_to_mute_after_awake_wav = 1.0
    
    snd_settings = SndSettings()
    snd_settings.enabled = True
    snd_settings.rate = 22050
    snd_settings.width = 2
    snd_settings.channels = 1
    snd_settings.samples_per_chunk = 1024
    snd_settings.command = ["aplay", "-r", "22050", "-c", "1", "-f", "S16_LE", "-t", "raw"]
    snd_settings.reconnect_seconds = 5.0
    snd_settings.volume_multiplier = 1.0
    snd_settings.disconnect_after_stop = False
    
    wake_settings = WakeSettings()
    wake_settings.enabled = True
    wake_settings.uri = "tcp://127.0.0.1:10400"  # Local wake word service
    wake_settings.rate = 16000
    wake_settings.width = 2
    wake_settings.channels = 1
    wake_settings.names = [
        {"name": "ok_nabu", "pipeline": None},
        {"name": "hey_jarvis", "pipeline": None},
        {"name": "alexa", "pipeline": None}
    ]
    wake_settings.refractory_seconds = 2.0
    wake_settings.reconnect_seconds = 5.0
    
    event_settings = EventSettings()
    event_settings.enabled = True
    event_settings.uri = "stdio://"  # Use our custom event handler
    event_settings.reconnect_seconds = 5.0
    
    vad_settings = VadSettings()
    vad_settings.enabled = False  # Disabled since we use wake word detection
    vad_settings.threshold = 0.5
    vad_settings.trigger_level = 0.3
    vad_settings.buffer_seconds = 0.5
    vad_settings.wake_word_timeout = 10.0
    
    # Create the main settings object
    settings = SatelliteSettings(
        mic=mic_settings,
        snd=snd_settings,
        wake=wake_settings,
        event=event_settings,
        vad=vad_settings
    )
    
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
