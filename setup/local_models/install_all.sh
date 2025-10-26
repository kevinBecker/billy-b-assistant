#!/bin/bash

# Install local model services for Billy B-Assistant
# This script can install services locally or configure for remote LLM server

set -e

echo "🚀 Installing local model services for Billy B-Assistant..."

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Ask user for deployment preference
echo ""
echo "🤔 How would you like to deploy the LLM service?"
echo "1) Run LLM locally on this Raspberry Pi (requires 6-8GB RAM)"
echo "2) Use a remote LLM server (specify IP/hostname)"
echo "3) Skip LLM installation (use OpenAI or configure later)"
echo ""
read -p "Enter your choice (1-3): " LLM_CHOICE

case $LLM_CHOICE in
    1)
        echo "📦 Installing Ollama locally..."
        bash "$SCRIPT_DIR/install_ollama.sh"
        LLM_HOST="localhost"
        LLM_PORT="11434"
        ;;
    2)
        read -p "Enter the IP address or hostname of your LLM server: " LLM_HOST
        read -p "Enter the port (default 11434): " LLM_PORT
        LLM_PORT=${LLM_PORT:-11434}
        echo "🔗 Configuring for remote LLM server at $LLM_HOST:$LLM_PORT"
        ;;
    3)
        echo "⏭️ Skipping LLM installation"
        LLM_HOST="localhost"
        LLM_PORT="11434"
        ;;
    *)
        echo "❌ Invalid choice. Defaulting to local installation."
        bash "$SCRIPT_DIR/install_ollama.sh"
        LLM_HOST="localhost"
        LLM_PORT="11434"
        ;;
esac

# Check Python version for TTS compatibility
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "🐍 Detected Python version: $PYTHON_VERSION"

# Install TTS service
if [[ "$PYTHON_VERSION" > "3.12" ]]; then
    echo "⚠️ Python $PYTHON_VERSION detected. Coqui TTS doesn't support Python 3.13+ yet."
    echo "🤔 Which TTS service would you like to install?"
    echo "1) Simple TTS (espeak-ng, works with Python 3.13, basic quality) - RECOMMENDED"
    echo "2) Try Coqui TTS (may fail if Python 3.11 not available, high quality)"
    echo "3) Skip TTS installation"
    echo ""
    read -p "Enter your choice (1-3): " TTS_CHOICE
    
    case $TTS_CHOICE in
        1)
            echo "📦 Installing Simple TTS (Python 3.13+ compatible)..."
            bash "$SCRIPT_DIR/install_simple_tts_only.sh"
            TTS_SERVICE="simple-tts"
            ;;
        2)
            echo "📦 Attempting to install Coqui TTS with Python 3.11..."
            bash "$SCRIPT_DIR/install_coqui_tts.sh"
            TTS_SERVICE="coqui-tts"
            ;;
        3)
            echo "⏭️ Skipping TTS installation"
            TTS_SERVICE="none"
            ;;
        *)
            echo "❌ Invalid choice. Installing Simple TTS."
            bash "$SCRIPT_DIR/install_simple_tts_only.sh"
            TTS_SERVICE="simple-tts"
            ;;
    esac
else
    echo "📦 Installing Coqui TTS..."
    bash "$SCRIPT_DIR/install_coqui_tts.sh"
    TTS_SERVICE="coqui-tts"
fi

echo "📦 Installing Whisper STT..."
bash "$SCRIPT_DIR/install_whisper.sh"

# Create environment file template with user's choices
echo "⚙️ Creating environment file template..."
cat > "$SCRIPT_DIR/../.env.local_models" << EOF
# Local Model Configuration for Billy B-Assistant
# Copy these settings to your main .env file

# Enable local models
USE_LOCAL_MODELS=true

# Local LLM (Ollama) Configuration
LOCAL_LLM_HOST=$LLM_HOST
LOCAL_LLM_PORT=$LLM_PORT
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

echo "✅ Local model services installation completed!"
echo ""
echo "🔧 Next steps:"
echo "1. Copy the configuration from .env.local_models to your main .env file"
echo "2. Restart Billy B-Assistant to use local models"
echo ""

if [ "$LLM_CHOICE" = "1" ]; then
    echo "📊 Check local service status:"
    echo "   - sudo systemctl status ollama-billy"
    if [ "$TTS_SERVICE" = "simple-tts" ]; then
        echo "   - sudo systemctl status simple-tts"
    elif [ "$TTS_SERVICE" = "coqui-tts" ]; then
        echo "   - sudo systemctl status coqui-tts"
    fi
    echo "   - sudo systemctl status whisper-stt"
    echo ""
    echo "🧪 Test the services:"
    echo "   - curl http://localhost:11434/api/tags (Ollama)"
    if [ "$TTS_SERVICE" = "simple-tts" ]; then
        echo "   - curl http://localhost:5002/api/health (Simple TTS)"
    elif [ "$TTS_SERVICE" = "coqui-tts" ]; then
        echo "   - curl http://localhost:5002/api/health (Coqui TTS)"
    fi
    echo "   - curl http://localhost:5003/api/health (Whisper STT)"
    echo ""
    echo "📊 Monitor logs:"
    echo "   - sudo journalctl -u ollama-billy -f"
    if [ "$TTS_SERVICE" = "simple-tts" ]; then
        echo "   - sudo journalctl -u simple-tts -f"
    elif [ "$TTS_SERVICE" = "coqui-tts" ]; then
        echo "   - sudo journalctl -u coqui-tts -f"
    fi
    echo "   - sudo journalctl -u whisper-stt -f"
elif [ "$LLM_CHOICE" = "2" ]; then
    echo "🔗 Remote LLM server configuration:"
    echo "   - LLM Server: $LLM_HOST:$LLM_PORT"
    echo "   - Make sure Ollama is running on the remote server"
    echo "   - Ensure network connectivity between Pi and LLM server"
    echo ""
    echo "📊 Check local service status:"
    if [ "$TTS_SERVICE" = "simple-tts" ]; then
        echo "   - sudo systemctl status simple-tts"
    elif [ "$TTS_SERVICE" = "coqui-tts" ]; then
        echo "   - sudo systemctl status coqui-tts"
    fi
    echo "   - sudo systemctl status whisper-stt"
    echo ""
    echo "🧪 Test the services:"
    echo "   - curl http://$LLM_HOST:$LLM_PORT/api/tags (Remote Ollama)"
    if [ "$TTS_SERVICE" = "simple-tts" ]; then
        echo "   - curl http://localhost:5002/api/health (Simple TTS)"
    elif [ "$TTS_SERVICE" = "coqui-tts" ]; then
        echo "   - curl http://localhost:5002/api/health (Coqui TTS)"
    fi
    echo "   - curl http://localhost:5003/api/health (Whisper STT)"
    echo ""
    echo "📊 Monitor logs:"
    if [ "$TTS_SERVICE" = "simple-tts" ]; then
        echo "   - sudo journalctl -u simple-tts -f"
    elif [ "$TTS_SERVICE" = "coqui-tts" ]; then
        echo "   - sudo journalctl -u coqui-tts -f"
    fi
    echo "   - sudo journalctl -u whisper-stt -f"
else
    echo "⏭️ LLM installation skipped"
    echo "📊 Check local service status:"
    if [ "$TTS_SERVICE" = "simple-tts" ]; then
        echo "   - sudo systemctl status simple-tts"
    elif [ "$TTS_SERVICE" = "coqui-tts" ]; then
        echo "   - sudo systemctl status coqui-tts"
    fi
    echo "   - sudo systemctl status whisper-stt"
    echo ""
    echo "🧪 Test the services:"
    if [ "$TTS_SERVICE" = "simple-tts" ]; then
        echo "   - curl http://localhost:5002/api/health (Simple TTS)"
    elif [ "$TTS_SERVICE" = "coqui-tts" ]; then
        echo "   - curl http://localhost:5002/api/health (Coqui TTS)"
    fi
    echo "   - curl http://localhost:5003/api/health (Whisper STT)"
    echo ""
    echo "📊 Monitor logs:"
    if [ "$TTS_SERVICE" = "simple-tts" ]; then
        echo "   - sudo journalctl -u simple-tts -f"
    elif [ "$TTS_SERVICE" = "coqui-tts" ]; then
        echo "   - sudo journalctl -u coqui-tts -f"
    fi
    echo "   - sudo journalctl -u whisper-stt -f"
fi
