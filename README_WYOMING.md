# Billy Bass Wyoming Integration

This integration combines Billy Bass's unique motion capabilities with Wyoming-Satellite's advanced voice processing, providing a more robust and feature-rich voice assistant experience.

## Overview

The Wyoming integration replaces Billy's original audio processing with Wyoming-Satellite's sophisticated voice handling while preserving all of Billy's characteristic movements and personality.

### Key Features

- **Advanced Wake Word Detection**: Uses Wyoming's local wake word detection
- **Voice Activity Detection**: Smart audio streaming only when speech is detected
- **Audio Enhancement**: Optional noise suppression and auto gain control
- **Motion Synchronization**: Billy's mouth, head, and tail movements synchronized with audio
- **Event-Driven Architecture**: Comprehensive event handling for voice interactions
- **Home Assistant Integration**: Full compatibility with Home Assistant's Wyoming protocol

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Microphone    │───▶│ Wyoming-Satellite│───▶│   Speaker       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │ Billy Motion     │
                       │ Controller       │
                       └──────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │ Motors (Mouth,   │
                       │ Head, Tail)      │
                       └──────────────────┘
```

## Installation

### Prerequisites

1. **Raspberry Pi** with Billy Bass hardware
2. **Python 3.9+** (tested on 3.11+)
3. **Audio devices** configured (microphone and speaker)

### Step 1: Install Dependencies

```bash
# Install Billy's dependencies plus Wyoming requirements
pip install -r requirements_wyoming.txt

# Install Wyoming-Satellite
cd wyoming-satellite
pip install -e .
cd ..
```

### Step 2: Install Wake Word Service

```bash
# Install Wyoming OpenWakeWord
cd wyoming-satellite
./script/setup
cd ..
```

### Step 3: Configure Audio Devices

```bash
# List available audio devices
arecord -L
aplay -L

# Update .env file with your preferred devices
echo "MIC_PREFERENCE=plughw:1,0" >> .env
echo "SPEAKER_PREFERENCE=plughw:1,0" >> .env
```

## Usage

### Quick Start

```bash
# Start Billy with Wyoming integration
./start_billy_wyoming.sh
```

### Manual Start

```bash
# Terminal 1: Start wake word service
cd wyoming-satellite
./script/run \
  --uri 'tcp://0.0.0.0:10400' \
  --preload-model 'ok_nabu' \
  --debug

# Terminal 2: Start Billy
python3 billy_wyoming_main.py
```

### Home Assistant Integration

1. **Add Wyoming Integration** in Home Assistant
2. **Enter Billy's IP address** and port `10700`
3. **Configure wake words** in Home Assistant settings
4. **Billy will appear** as a voice assistant device

## Configuration

### Environment Variables

Add these to your `.env` file:

```bash
# Audio Configuration
MIC_PREFERENCE=plughw:1,0          # Preferred microphone device
SPEAKER_PREFERENCE=plughw:1,0       # Preferred speaker device

# Wyoming Configuration
WYOMING_WAKE_URI=tcp://127.0.0.1:10400  # Wake word service URI
WYOMING_SATELLITE_URI=tcp://0.0.0.0:10700  # Satellite URI

# Billy Motion Configuration
MOUTH_ARTICULATION=5                # Mouth movement sensitivity (1-10)
BILLY_MODEL=modern                  # Billy hardware model
BILLY_PINS=new                      # Pin configuration
```

### Wake Word Models

Available wake words:
- `ok_nabu` (default)
- `hey_jarvis`
- `alexa`
- `hey_mycroft`
- `hey_rhasspy`

### Motion Behavior

Billy's movements are triggered by:

- **Wake Word Detection**: Head raises up
- **Speaking (TTS)**: Head stays up, mouth flaps with audio
- **Listening**: Head up, mouth flaps with speech
- **Finished Speaking**: Head lowers, random interlude behavior
- **Errors**: Confused tail movement

## File Structure

```
billy-b-assistant-git/
├── billy_wyoming_main.py          # Main integration script
├── billy_wyoming_event_handler.py # Custom event handler
├── billy_wyoming_config.py        # Configuration settings
├── start_billy_wyoming.sh         # Startup script
├── requirements_wyoming.txt       # Combined dependencies
├── wyoming-satellite/             # Wyoming-Satellite code
└── core/                          # Billy's original motion system
    ├── movements.py               # Motor control
    ├── button.py                  # GPIO button handling
    ├── mqtt.py                    # MQTT integration
    └── config.py                  # Configuration
```

## Troubleshooting

### Audio Issues

```bash
# Test microphone
arecord -f S16_LE -r 16000 -c 1 -t raw | aplay -f S16_LE -r 16000 -c 1 -t raw

# Check audio devices
arecord -L | grep -E "(card|device)"
aplay -L | grep -E "(card|device)"
```

### Wake Word Issues

```bash
# Test wake word service
cd wyoming-satellite
./script/run --uri 'tcp://0.0.0.0:10400' --preload-model 'ok_nabu' --debug
```

### Motion Issues

```bash
# Test motor control
python3 -c "from core.movements import move_head, move_tail_async; move_head('on'); move_tail_async()"
```

## Advanced Configuration

### Custom Wake Words

1. **Download custom model** to `wyoming-satellite/models/`
2. **Update configuration** in `billy_wyoming_config.py`
3. **Restart services**

### Audio Processing

Enable advanced audio processing:

```python
# In billy_wyoming_config.py
settings.mic.auto_gain = 5          # Auto gain control (0-31)
settings.mic.noise_suppression = 2  # Noise suppression (0-4)
```

### Event Customization

Modify `billy_wyoming_event_handler.py` to customize Billy's behavior for different events.

## Performance

### Resource Usage

- **CPU**: ~15-20% on Raspberry Pi 4
- **RAM**: ~200-300MB
- **Audio Latency**: ~100-200ms

### Optimization

- **Disable VAD** if using wake word detection
- **Adjust audio buffer sizes** for your hardware
- **Use hardware-accelerated audio** when available

## Migration from Original Billy

The Wyoming integration is designed to be a drop-in replacement:

1. **Backup your configuration** (`.env`, `persona.ini`)
2. **Install Wyoming dependencies**
3. **Run the integration** instead of `main.py`
4. **All existing features** (MQTT, button, personality) are preserved

## Support

- **Issues**: Check the troubleshooting section above
- **Logs**: Enable debug mode with `DEBUG_MODE=true` in `.env`
- **Community**: Join the Billy Bass community for help

## License

This integration maintains the same license as the original Billy Bass Assistant project.
