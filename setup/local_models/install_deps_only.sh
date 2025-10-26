#!/bin/bash

# Install only the Python dependencies for TTS and STT
# This script assumes you have Python 3.11 installed manually

set -e

echo "🚀 Installing Python dependencies for TTS and STT..."

# Find Python 3.11 installation
echo "🔍 Looking for Python 3.11 installation..."

# Common locations for manually compiled Python
PYTHON311_PATHS=(
    "/usr/local/bin/python3.11"
    "/opt/python3.11/bin/python3.11"
    "/home/pi/python3.11/bin/python3.11"
    "/usr/bin/python3.11"
    "python3.11"  # If it's in PATH
)

PYTHON311=""
for path in "${PYTHON311_PATHS[@]}"; do
    if command -v "$path" > /dev/null 2>&1; then
        PYTHON311="$path"
        echo "✅ Found Python 3.11 at: $PYTHON311"
        break
    fi
done

if [ -z "$PYTHON311" ]; then
    echo "❌ Python 3.11 not found in common locations"
    echo "🔍 Please specify the path to your Python 3.11 installation:"
    read -p "Enter full path to python3.11: " PYTHON311
    
    if [ ! -f "$PYTHON311" ]; then
        echo "❌ Python 3.11 not found at: $PYTHON311"
        exit 1
    fi
fi

# Verify Python 3.11 version
PYTHON_VERSION=$($PYTHON311 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "🐍 Using Python version: $PYTHON_VERSION"

if [[ "$PYTHON_VERSION" != "3.11" ]]; then
    echo "❌ Expected Python 3.11, but found $PYTHON_VERSION"
    exit 1
fi

# Install system dependencies
echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y build-essential cmake ffmpeg espeak-ng sox

# Create virtual environments
echo "🐍 Creating virtual environments..."

# TTS virtual environment
echo "📦 Creating TTS virtual environment..."
$PYTHON311 -m venv /opt/coqui-tts
source /opt/coqui-tts/bin/activate

echo "📥 Installing TTS dependencies..."
pip install --upgrade pip
pip install TTS flask soundfile numpy

# Download TTS model
echo "📥 Downloading XTTS-v2 model..."
python -c "
import TTS
from TTS.api import TTS

# Initialize TTS
tts = TTS('tts_models/multilingual/multi-dataset/xtts_v2')

# Download model files
print('TTS model downloaded successfully')
"

# STT virtual environment (can use system Python)
echo "📦 Creating STT virtual environment..."
python3 -m venv /opt/whisper-stt
source /opt/whisper-stt/bin/activate

echo "📥 Installing STT dependencies..."
pip install --upgrade pip
pip install flask numpy soundfile

# Clone and build whisper.cpp
echo "📥 Setting up Whisper STT..."
cd /tmp
if [ -d "whisper.cpp" ]; then
    echo "🔄 Updating existing whisper.cpp..."
    cd whisper.cpp
    git pull
else
    echo "📥 Cloning whisper.cpp..."
    git clone https://github.com/ggerganov/whisper.cpp.git
    cd whisper.cpp
fi

# Build whisper.cpp
echo "🔨 Building whisper.cpp..."
make

# Download base model
echo "📥 Downloading Whisper base model..."
./models/download-ggml-model.sh base

echo "✅ Dependencies installation complete!"
echo ""
echo "🔧 Virtual environments created:"
echo "   - /opt/coqui-tts (Python 3.11 for TTS)"
echo "   - /opt/whisper-stt (System Python for STT)"
echo ""
echo "📦 TTS dependencies installed:"
echo "   - TTS (Coqui TTS)"
echo "   - flask, soundfile, numpy"
echo "   - XTTS-v2 model downloaded"
echo ""
echo "📦 STT dependencies installed:"
echo "   - flask, numpy, soundfile"
echo "   - whisper.cpp built"
echo "   - Whisper base model downloaded"
echo ""
echo "🚀 Next steps:"
echo "   1. Run the full installation script:"
echo "      sudo bash setup/local_models/install_with_custom_python311.sh"
echo "   2. Or manually create the service scripts and systemd services"
echo ""
echo "🧪 Test the installations:"
echo "   # Test TTS"
echo "   source /opt/coqui-tts/bin/activate"
echo "   python -c \"from TTS.api import TTS; print('TTS working!')\""
echo ""
echo "   # Test STT"
echo "   source /opt/whisper-stt/bin/activate"
echo "   python -c \"import flask, numpy, soundfile; print('STT dependencies working!')\""
