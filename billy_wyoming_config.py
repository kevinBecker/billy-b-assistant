"""
Billy Bass Wyoming Integration Configuration

This module provides configuration settings for integrating Billy Bass
with Wyoming-Satellite voice processing.
"""

import os
from wyoming_satellite.settings import SatelliteSettings, MicSettings, SndSettings, WakeSettings, EventSettings, VadSettings

def create_billy_satellite_settings():
    """Create optimized Wyoming Satellite settings for Billy Bass."""
    # Create individual settings objects with all parameters
    mic_settings = MicSettings(
        enabled=True,
        rate=16000,
        width=2,
        channels=1,
        samples_per_chunk=1024,
        command=["arecord", "-r", "16000", "-c", "1", "-f", "S16_LE", "-t", "raw"],
        reconnect_seconds=5.0,
        volume_multiplier=1.0,
        auto_gain=0,  # Disable auto gain for Billy
        noise_suppression=0,  # Disable noise suppression for Billy
        mute_during_awake_wav=True,
        seconds_to_mute_after_awake_wav=1.0
    )
    
    snd_settings = SndSettings(
        enabled=True,
        rate=22050,
        width=2,
        channels=1,
        samples_per_chunk=1024,
        command=["aplay", "-r", "22050", "-c", "1", "-f", "S16_LE", "-t", "raw"],
        reconnect_seconds=5.0,
        volume_multiplier=1.0,
        disconnect_after_stop=False
    )
    
    wake_settings = WakeSettings(
        enabled=True,
        uri="tcp://127.0.0.1:10400",  # Local wake word service
        rate=16000,
        width=2,
        channels=1,
        names=[
            {"name": "ok_nabu", "pipeline": None},
            {"name": "hey_jarvis", "pipeline": None},
            {"name": "alexa", "pipeline": None}
        ],
        refractory_seconds=2.0,
        reconnect_seconds=5.0
    )
    
    event_settings = EventSettings(
        enabled=True,
        uri="stdio://",  # Use our custom event handler
        reconnect_seconds=5.0
    )
    
    vad_settings = VadSettings(
        enabled=False,  # Disabled since we use wake word detection
        threshold=0.5,
        trigger_level=0.3,
        buffer_seconds=0.5,
        wake_word_timeout=10.0
    )
    
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
