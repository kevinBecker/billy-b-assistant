# Billy B-Assistant Deployment Options

## Quick Reference

### 🏠 **Local Deployment (All on Raspberry Pi)**
```bash
# Install everything locally
cd setup/local_models
sudo bash install_all.sh
# Choose option 1: Local LLM
```

**Best for**: Raspberry Pi 5 (8GB RAM)
**Benefits**: Complete privacy, no network dependency
**Requirements**: 6-8GB RAM, 16GB storage

### 🔗 **Remote LLM Deployment**
```bash
# Step 1: Setup LLM server (on powerful machine)
bash setup/local_models/setup_llm_server.sh

# Step 2: Setup Billy (on Raspberry Pi)
cd setup/local_models
sudo bash install_all.sh
# Choose option 2: Remote LLM server
# Enter your LLM server IP
```

**Best for**: Raspberry Pi 4 or limited RAM
**Benefits**: Better LLM performance, lower Pi requirements
**Requirements**: Network connection, separate LLM server

### ⚙️ **Configuration Management**
```bash
# Switch between deployment options anytime
cd setup/local_models
bash configure_llm.sh
```

**Options**:
1. Local LLM
2. Remote LLM server
3. OpenAI (cloud)
4. Show current config
5. Test current config

## Hardware Recommendations

| Pi Model | RAM | Recommended Setup | LLM Performance |
|----------|-----|-------------------|-----------------|
| **Pi 5** | 8GB | All Local | ⭐⭐⭐⭐ Excellent |
| **Pi 5** | 4GB | Remote LLM | ⭐⭐⭐⭐ Excellent |
| **Pi 4** | 8GB | Remote LLM | ⭐⭐⭐⭐ Excellent |
| **Pi 4** | 4GB | Remote LLM | ⭐⭐⭐⭐ Excellent |

## Model Performance Comparison

### Local LLM Models (on Pi 5 8GB)
| Model | Size | RAM | Speed | Quality |
|-------|------|-----|-------|---------|
| **Phi-3.5 Mini** | 2.3GB | 4GB | ⚡⚡⚡ | ⭐⭐⭐ |
| **Llama 3.1 8B** | 4.7GB | 6GB | ⚡⚡ | ⭐⭐⭐⭐ |

### Remote LLM Models (on powerful server)
| Model | Size | RAM | Speed | Quality |
|-------|------|-----|-------|---------|
| **Llama 3.1 8B** | 4.7GB | 6GB | ⚡⚡⚡ | ⭐⭐⭐⭐ |
| **Llama 3.1 70B** | 40GB | 64GB | ⚡⚡ | ⭐⭐⭐⭐⭐ |

## Network Requirements

### Local Deployment
- ✅ No network required after setup
- ✅ Complete offline operation
- ✅ Maximum privacy

### Remote LLM Deployment
- 🔗 Stable network connection required
- 🔗 Low latency preferred (<50ms)
- 🔗 Bandwidth: ~1-5 Mbps during conversation

## Security Considerations

### Local Deployment
- 🛡️ All data stays on device
- 🛡️ No external network access needed
- 🛡️ Maximum privacy

### Remote LLM Deployment
- 🔒 Data travels over local network
- 🔒 Consider VPN for remote access
- 🔒 Firewall configuration recommended

## Troubleshooting

### Local LLM Issues
```bash
# Check service status
sudo systemctl status ollama-billy

# Check memory usage
free -h

# Restart service
sudo systemctl restart ollama-billy
```

### Remote LLM Issues
```bash
# Test connection
curl http://YOUR_LLM_SERVER:11434/api/tags

# Check network connectivity
ping YOUR_LLM_SERVER

# Test from Billy
bash setup/local_models/configure_llm.sh
# Choose option 5: Test current configuration
```

## Migration Between Options

### From Local to Remote
1. Set up LLM server: `bash setup_llm_server.sh`
2. Configure Billy: `bash configure_llm.sh`
3. Choose option 2 (Remote LLM)
4. Enter server IP and port

### From Remote to Local
1. Install Ollama locally: `bash install_ollama.sh`
2. Configure Billy: `bash configure_llm.sh`
3. Choose option 1 (Local LLM)

### From Local/Remote to OpenAI
1. Configure Billy: `bash configure_llm.sh`
2. Choose option 3 (OpenAI)
3. Enter your API key

## Performance Optimization

### For Local Deployment
- Use smaller models (Phi-3.5 Mini) for faster responses
- Close unnecessary services
- Monitor temperature: `vcgencmd measure_temp`
- Consider cooling solutions for sustained use

### For Remote Deployment
- Use wired network connection
- Place LLM server close to Billy (low latency)
- Use faster models on powerful server
- Monitor network latency

## Cost Comparison

| Option | Setup Cost | Ongoing Cost | Performance |
|--------|------------|--------------|-------------|
| **Local (Pi 5 8GB)** | $75-100 | $0 | Good |
| **Remote LLM Server** | $200-500 | $0 | Excellent |
| **OpenAI** | $0 | $10-50/month | Excellent |

## Quick Commands

```bash
# Install everything locally
sudo bash setup/local_models/install_all.sh

# Setup remote LLM server
bash setup/local_models/setup_llm_server.sh

# Configure deployment
bash setup/local_models/configure_llm.sh

# Test configuration
bash setup/local_models/configure_llm.sh
# Choose option 5

# Check service status
sudo systemctl status ollama-billy coqui-tts whisper-stt

# View logs
sudo journalctl -u ollama-billy -f
```
