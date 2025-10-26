# Local Models Migration Guide

This guide explains how to migrate Billy B-Assistant from OpenAI to fully open-source local models while maintaining all existing functionality including MQTT and Home Assistant integration.

## Overview

The local models implementation provides:
- **Local LLM**: Ollama with Llama 3.1 8B model
- **Local TTS**: Coqui TTS with XTTS-v2 model
- **Local STT**: Whisper.cpp with base model
- **Hybrid Support**: Seamless switching between OpenAI and local models
- **Full Compatibility**: All existing features (MQTT, Home Assistant, tools) continue to work

## Architecture Changes

### Before (OpenAI)
```
Billy B-Assistant → OpenAI Realtime API → Cloud Services
```

### After (Local Models)
```
Billy B-Assistant → Local Services (Ollama + Coqui TTS + Whisper)
```

## Prerequisites

- Raspberry Pi 4 or 5 (recommended: 8GB RAM)
- At least 16GB free storage space
- Stable internet connection for initial model downloads

## Installation

### Option 1: Automated Installation (Recommended)

```bash
# Navigate to the setup directory
cd setup/local_models

# Run the automated installer
sudo bash install_all.sh
```

This will install all three services:
- Ollama (LLM)
- Coqui TTS (Text-to-Speech)
- Whisper STT (Speech-to-Text)

### Option 2: Manual Installation

Install each service individually:

```bash
# Install Ollama
sudo bash setup/local_models/install_ollama.sh

# Install Coqui TTS
sudo bash setup/local_models/install_coqui_tts.sh

# Install Whisper STT
sudo bash setup/local_models/install_whisper.sh
```

## Configuration

### 1. Update Environment Variables

Add these settings to your `.env` file:

```bash
# Enable local models
USE_LOCAL_MODELS=true

# Local LLM (Ollama) Configuration
LOCAL_LLM_HOST=localhost
LOCAL_LLM_PORT=11434
LOCAL_LLM_MODEL=llama3.1:8b

# Local TTS (Coqui TTS) Configuration
LOCAL_TTS_HOST=localhost
LOCAL_TTS_PORT=5002
LOCAL_TTS_VOICE=default

# Local STT (Whisper) Configuration
LOCAL_STT_HOST=localhost
LOCAL_STT_PORT=5003
LOCAL_STT_MODEL=base
```

### 2. Optional: Disable OpenAI

To completely remove OpenAI dependency, comment out or remove:
```bash
# OPENAI_API_KEY=your_key_here
```

## Service Management

### Check Service Status
```bash
# Check all services
sudo systemctl status ollama-billy
sudo systemctl status coqui-tts
sudo systemctl status whisper-stt

# Check if services are running
sudo systemctl is-active ollama-billy
sudo systemctl is-active coqui-tts
sudo systemctl is-active whisper-stt
```

### Start/Stop Services
```bash
# Start services
sudo systemctl start ollama-billy
sudo systemctl start coqui-tts
sudo systemctl start whisper-stt

# Stop services
sudo systemctl stop ollama-billy
sudo systemctl stop coqui-tts
sudo systemctl stop whisper-stt

# Restart services
sudo systemctl restart ollama-billy
sudo systemctl restart coqui-tts
sudo systemctl restart whisper-stt
```

### View Logs
```bash
# View logs for each service
sudo journalctl -u ollama-billy -f
sudo journalctl -u coqui-tts -f
sudo journalctl -u whisper-stt -f
```

## Testing

### Test Individual Services

```bash
# Test Ollama
curl http://localhost:11434/api/tags

# Test Coqui TTS
curl http://localhost:5002/api/health

# Test Whisper STT
curl http://localhost:5003/api/health
```

### Test Billy B-Assistant

1. Start Billy B-Assistant with local models enabled
2. Press the button to start a conversation
3. Verify that:
   - Speech is transcribed correctly
   - Responses are generated locally
   - Audio is synthesized locally
   - MQTT integration still works
   - Home Assistant commands still work

## Performance Considerations

### Hardware Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| RAM | 4GB | 8GB |
| Storage | 8GB free | 16GB free |
| CPU | Raspberry Pi 4 | Raspberry Pi 5 |

### Model Performance

- **LLM (Llama 3.1 8B)**: ~2-5 seconds response time on Pi 5
- **TTS (XTTS-v2)**: ~1-3 seconds synthesis time
- **STT (Whisper base)**: ~1-2 seconds transcription time

### Optimization Tips

1. **Use faster models for better performance**:
   ```bash
   # For faster LLM responses (lower quality)
   ollama pull phi3.5:mini
   # Update LOCAL_LLM_MODEL=phi3.5:mini in .env
   ```

2. **Adjust audio quality for faster processing**:
   ```bash
   # In .env file
   CHUNK_MS=100  # Increase for faster processing
   ```

3. **Monitor system resources**:
   ```bash
   # Check memory usage
   free -h
   
   # Check CPU usage
   top
   ```

## Troubleshooting

### Common Issues

#### 1. Services Won't Start
```bash
# Check service status
sudo systemctl status ollama-billy

# Check logs
sudo journalctl -u ollama-billy --no-pager

# Restart service
sudo systemctl restart ollama-billy
```

#### 2. Out of Memory Errors
```bash
# Check available memory
free -h

# If low on memory, try a smaller model
ollama pull phi3.5:mini
```

#### 3. Slow Performance
- Ensure you're using a Raspberry Pi 5
- Close unnecessary services
- Consider using smaller models
- Check CPU temperature: `vcgencmd measure_temp`

#### 4. Audio Issues
```bash
# Test audio devices
aplay -l
arecord -l

# Check audio permissions
sudo usermod -a -G audio $USER
```

### Fallback to OpenAI

If local models aren't working, you can quickly fall back to OpenAI:

1. Set `USE_LOCAL_MODELS=false` in your `.env` file
2. Ensure `OPENAI_API_KEY` is set
3. Restart Billy B-Assistant

## MQTT Integration

Local models maintain full MQTT compatibility:

- **State Publishing**: `billy/state` topic continues to work
- **Remote Commands**: `billy/command` and `billy/say` topics work
- **Home Assistant Discovery**: All MQTT discovery messages are sent
- **Device Control**: Shutdown and other commands work normally

## Home Assistant Integration

Home Assistant integration remains unchanged:

- **Conversation API**: Smart home commands work through local LLM
- **MQTT Sensors**: State sensors continue to update
- **MQTT Buttons**: Control buttons work normally
- **Device Discovery**: Automatic device discovery continues

## Advanced Configuration

### Custom Models

You can use different models by updating the configuration:

```bash
# Different LLM models
LOCAL_LLM_MODEL=phi3.5:mini      # Faster, smaller
LOCAL_LLM_MODEL=llama3.1:70b     # Slower, higher quality

# Different TTS voices (if available)
LOCAL_TTS_VOICE=custom_voice

# Different STT models
LOCAL_STT_MODEL=tiny             # Faster, lower accuracy
LOCAL_STT_MODEL=large            # Slower, higher accuracy
```

### Network Configuration

For remote access to local models:

```bash
# Allow external access to Ollama
LOCAL_LLM_HOST=0.0.0.0

# Use different ports if needed
LOCAL_LLM_PORT=11434
LOCAL_TTS_PORT=5002
LOCAL_STT_PORT=5003
```

## Security Considerations

- Local models run entirely on your device
- No data is sent to external services
- All conversations remain private
- Network access is only needed for initial model downloads

## Support

If you encounter issues:

1. Check the logs for each service
2. Verify all services are running
3. Test individual components
4. Check system resources (memory, storage)
5. Review the troubleshooting section above

## Migration Checklist

- [ ] Install local model services
- [ ] Update `.env` configuration
- [ ] Test individual services
- [ ] Test Billy B-Assistant with local models
- [ ] Verify MQTT integration
- [ ] Verify Home Assistant integration
- [ ] Test all Billy features (songs, personality, etc.)
- [ ] Monitor performance and adjust if needed
- [ ] Document any custom configurations

## Benefits of Local Models

- **Privacy**: All conversations stay on your device
- **Reliability**: No dependency on external services
- **Cost**: No API usage fees
- **Customization**: Full control over models and configuration
- **Offline**: Works without internet connection (after initial setup)
