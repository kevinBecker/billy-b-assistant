#!/bin/bash

# Install all local model services for Billy B-Assistant
# This script sets up Ollama, Coqui TTS, and Whisper STT

set -e

echo "🚀 Installing all local model services for Billy B-Assistant..."

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Install Ollama
echo "📦 Installing Ollama..."
bash "$SCRIPT_DIR/install_ollama.sh"

# Install Coqui TTS
echo "📦 Installing Coqui TTS..."
bash "$SCRIPT_DIR/install_coqui_tts.sh"

# Install Whisper STT
echo "📦 Installing Whisper STT..."
bash "$SCRIPT_DIR/install_whisper.sh"

# Create environment file template
echo "⚙️ Creating environment file template..."
cat > "$SCRIPT_DIR/../.env.local_models" << 'EOF'
# Local Model Configuration for Billy B-Assistant
# Copy these settings to your main .env file

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

# Optional: Disable OpenAI (set to empty to disable)
# OPENAI_API_KEY=
EOF

echo "✅ All local model services installed successfully!"
echo ""
echo "🔧 Next steps:"
echo "1. Copy the configuration from .env.local_models to your main .env file"
echo "2. Restart Billy B-Assistant to use local models"
echo "3. Check service status with:"
echo "   - sudo systemctl status ollama-billy"
echo "   - sudo systemctl status coqui-tts"
echo "   - sudo systemctl status whisper-stt"
echo ""
echo "🧪 Test the services:"
echo "   - curl http://localhost:11434/api/tags (Ollama)"
echo "   - curl http://localhost:5002/api/health (Coqui TTS)"
echo "   - curl http://localhost:5003/api/health (Whisper STT)"
echo ""
echo "📊 Monitor logs:"
echo "   - sudo journalctl -u ollama-billy -f"
echo "   - sudo journalctl -u coqui-tts -f"
echo "   - sudo journalctl -u whisper-stt -f"
