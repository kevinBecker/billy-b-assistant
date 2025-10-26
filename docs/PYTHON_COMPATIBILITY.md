# Python Version Compatibility Guide

## Overview

Billy B-Assistant supports multiple Python versions, but some local model services have specific requirements. This guide explains the compatibility and provides solutions for different Python versions.

## Python Version Support

| Component | Python 3.9 | Python 3.10 | Python 3.11 | Python 3.12 | Python 3.13+ |
|-----------|-------------|--------------|--------------|--------------|---------------|
| **Billy Core** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Ollama LLM** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Coqui TTS** | ✅ | ✅ | ✅ | ✅ | ❌ |
| **Simple TTS** | ✅ | ✅ | ✅ | ✅ | ✅ |
| **Whisper STT** | ✅ | ✅ | ✅ | ✅ | ✅ |

## Python 3.13+ Compatibility Issues

### Problem
Coqui TTS doesn't support Python 3.13+ yet. You'll see errors like:
```
ERROR: Could not find a version that satisfies the requirement TTS (from versions: none)
ERROR: No matching distribution found for TTS
```

### Solutions

#### Option 1: Use Simple TTS (Recommended)
The installation script automatically detects Python 3.13+ and offers Simple TTS as an alternative:

```bash
cd setup/local_models
sudo bash install_all.sh
# Choose option 1: Simple TTS (espeak-ng)
```

**Benefits:**
- ✅ Works with Python 3.13+
- ✅ Lightweight and fast
- ✅ No additional Python version needed
- ✅ Good for basic speech synthesis

**Limitations:**
- ⚠️ Basic voice quality (robotic sound)
- ⚠️ Limited voice options
- ⚠️ No neural voice synthesis

#### Option 2: Use Coqui TTS with Python 3.11
The installation script can install Python 3.11 specifically for Coqui TTS:

```bash
cd setup/local_models
sudo bash install_all.sh
# Choose option 2: Coqui TTS (requires Python 3.11)
```

**Benefits:**
- ✅ High-quality neural voice synthesis
- ✅ Multiple voice options
- ✅ Natural-sounding speech
- ✅ XTTS-v2 model support

**Limitations:**
- ⚠️ Requires additional Python 3.11 installation
- ⚠️ Larger disk space usage
- ⚠️ More complex setup

#### Option 3: Use Remote TTS Service
Run Coqui TTS on a separate server with Python 3.11:

```bash
# On a separate server with Python 3.11
bash setup/local_models/install_coqui_tts.sh

# On your Raspberry Pi
cd setup/local_models
sudo bash install_all.sh
# Choose option 3: Skip TTS installation
# Then configure remote TTS in .env
```

## Installation Process

### Automatic Detection
The installation script automatically detects your Python version and offers appropriate options:

```bash
cd setup/local_models
sudo bash install_all.sh
```

**For Python 3.13+:**
```
🐍 Detected Python version: 3.13
⚠️ Python 3.13 detected. Coqui TTS doesn't support Python 3.13+ yet.
🤔 Which TTS service would you like to install?
1) Simple TTS (espeak-ng, works with Python 3.13, basic quality)
2) Coqui TTS (requires Python 3.11, high quality)
3) Skip TTS installation
```

**For Python 3.12 and below:**
```
🐍 Detected Python version: 3.12
📦 Installing Coqui TTS...
```

### Manual Installation
You can also install TTS services individually:

```bash
# Simple TTS (works with any Python version)
sudo bash setup/local_models/install_simple_tts.sh

# Coqui TTS (handles Python version compatibility)
sudo bash setup/local_models/install_coqui_tts.sh
```

## Configuration

### Environment Variables
The TTS service is configured in your `.env` file:

```bash
# For Simple TTS
LOCAL_TTS_HOST=localhost
LOCAL_TTS_PORT=5002
LOCAL_TTS_VOICE=default

# For Coqui TTS
LOCAL_TTS_HOST=localhost
LOCAL_TTS_PORT=5002
LOCAL_TTS_VOICE=default
```

### Service Management
Different TTS services use different systemd services:

```bash
# Simple TTS
sudo systemctl status simple-tts
sudo systemctl restart simple-tts

# Coqui TTS
sudo systemctl status coqui-tts
sudo systemctl restart coqui-tts
```

## Performance Comparison

| TTS Service | Quality | Speed | Memory | Python Support |
|-------------|---------|-------|--------|----------------|
| **Simple TTS** | ⭐⭐ | ⚡⚡⚡ | 50MB | All versions |
| **Coqui TTS** | ⭐⭐⭐⭐⭐ | ⚡⚡ | 2GB | 3.9-3.12 |

## Troubleshooting

### Python 3.13+ Issues
If you encounter Python compatibility issues:

1. **Check your Python version:**
   ```bash
   python3 --version
   ```

2. **Use Simple TTS:**
   ```bash
   sudo bash setup/local_models/install_simple_tts.sh
   ```

3. **Or install Python 3.11 for Coqui TTS:**
   ```bash
   sudo apt install python3.11 python3.11-venv
   sudo bash setup/local_models/install_coqui_tts.sh
   ```

### Service Issues
If TTS services fail to start:

1. **Check service status:**
   ```bash
   sudo systemctl status simple-tts
   sudo systemctl status coqui-tts
   ```

2. **Check logs:**
   ```bash
   sudo journalctl -u simple-tts -f
   sudo journalctl -u coqui-tts -f
   ```

3. **Test manually:**
   ```bash
   curl http://localhost:5002/api/health
   ```

### Switching Between TTS Services
You can switch between TTS services:

1. **Stop current service:**
   ```bash
   sudo systemctl stop coqui-tts
   sudo systemctl stop simple-tts
   ```

2. **Install new service:**
   ```bash
   sudo bash setup/local_models/install_simple_tts.sh
   # or
   sudo bash setup/local_models/install_coqui_tts.sh
   ```

3. **Update configuration:**
   ```bash
   # No changes needed - both use port 5002
   ```

## Recommendations

### For Python 3.13+ Users
- **Start with Simple TTS** for immediate functionality
- **Consider Coqui TTS with Python 3.11** for better quality
- **Use remote TTS service** for best of both worlds

### For Python 3.12 and Below
- **Use Coqui TTS** for best quality
- **Simple TTS** as a lightweight alternative

### For Production Use
- **Simple TTS** for reliability and compatibility
- **Coqui TTS** for quality and naturalness
- **Remote services** for scalability

## Future Compatibility

### Expected Updates
- **Coqui TTS**: Python 3.13+ support expected in future releases
- **Billy Core**: Will continue supporting all Python versions
- **Simple TTS**: Will remain compatible with all versions

### Migration Path
When Coqui TTS adds Python 3.13+ support:

1. **Update Coqui TTS:**
   ```bash
   sudo bash setup/local_models/install_coqui_tts.sh
   ```

2. **Switch services:**
   ```bash
   sudo systemctl stop simple-tts
   sudo systemctl start coqui-tts
   ```

3. **No configuration changes needed** (both use port 5002)

## Quick Reference

### Check Python Version
```bash
python3 --version
```

### Install Simple TTS
```bash
sudo bash setup/local_models/install_simple_tts.sh
```

### Install Coqui TTS
```bash
sudo bash setup/local_models/install_coqui_tts.sh
```

### Test TTS Service
```bash
curl http://localhost:5002/api/health
```

### Switch TTS Services
```bash
# Stop current
sudo systemctl stop simple-tts
sudo systemctl stop coqui-tts

# Start desired
sudo systemctl start simple-tts
sudo systemctl start coqui-tts
```
