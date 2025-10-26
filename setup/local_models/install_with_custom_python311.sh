#!/bin/bash

# Install TTS and STT services using manually compiled Python 3.11
# This script assumes you have Python 3.11 installed manually

set -e

echo "🚀 Installing TTS and STT services with custom Python 3.11..."

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "⚠️ This script is designed for Raspberry Pi. Proceeding anyway..."
fi

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
sudo apt install -y build-essential cmake ffmpeg espeak-ng sox python3-pip python3-venv

# Install TTS service
echo "📦 Installing Coqui TTS service..."

# Create virtual environment with custom Python 3.11
echo "🐍 Creating Python 3.11 virtual environment for TTS..."
$PYTHON311 -m venv /opt/coqui-tts
source /opt/coqui-tts/bin/activate

# Install Coqui TTS
echo "📥 Installing Coqui TTS..."
pip install --upgrade pip
pip install TTS

# Download XTTS-v2 model
echo "📥 Downloading XTTS-v2 model..."
python -c "
import TTS
from TTS.api import TTS

# Initialize TTS
tts = TTS('tts_models/multilingual/multi-dataset/xtts_v2')

# Download model files
print('Model downloaded successfully')
"

# Create TTS service script
echo "⚙️ Creating TTS service script..."
sudo tee /opt/coqui-tts/tts_server.py > /dev/null <<'EOF'
#!/usr/bin/env python3
"""
Coqui TTS HTTP server for Billy B-Assistant
"""

import asyncio
import base64
import json
import logging
from typing import Dict, Any
from flask import Flask, request, jsonify, Response
from TTS.api import TTS
import io
import soundfile as sf
import numpy as np

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Global TTS instance
tts_instance = None

def init_tts():
    """Initialize TTS model."""
    global tts_instance
    try:
        tts_instance = TTS('tts_models/multilingual/multi-dataset/xtts_v2')
        logger.info("TTS model loaded successfully")
        return True
    except Exception as e:
        logger.error(f"Failed to load TTS model: {e}")
        return False

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({"status": "healthy", "model_loaded": tts_instance is not None})

@app.route('/api/voices', methods=['GET'])
def get_voices():
    """Get available voices."""
    return jsonify({"voices": ["default"]})

@app.route('/api/synthesize', methods=['POST'])
def synthesize():
    """Synthesize speech from text."""
    try:
        data = request.get_json()
        text = data.get('text', '')
        voice = data.get('voice', 'default')
        output_format = data.get('output_format', 'pcm16')
        stream = data.get('stream', False)
        
        if not text:
            return jsonify({"error": "No text provided"}), 400
        
        if not tts_instance:
            return jsonify({"error": "TTS model not loaded"}), 500
        
        # Generate speech
        wav = tts_instance.tts(text=text)
        
        # Convert to PCM16 if requested
        if output_format == 'pcm16':
            # Convert float32 to int16
            wav_int16 = (wav * 32767).astype(np.int16)
            audio_data = wav_int16.tobytes()
        else:
            # Return as WAV
            buffer = io.BytesIO()
            sf.write(buffer, wav, 22050, format='WAV')
            audio_data = buffer.getvalue()
        
        if stream:
            def generate():
                chunk_size = 1024
                for i in range(0, len(audio_data), chunk_size):
                    chunk = audio_data[i:i+chunk_size]
                    yield chunk
                    if i % (chunk_size * 10) == 0:  # Small delay every 10 chunks
                        yield b''
            
            return Response(generate(), mimetype='application/octet-stream')
        else:
            # Return base64 encoded audio
            b64_audio = base64.b64encode(audio_data).decode('utf-8')
            return jsonify({"audio": b64_audio})
            
    except Exception as e:
        logger.error(f"Synthesis error: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    if init_tts():
        logger.info("Starting TTS server on port 5002")
        app.run(host='0.0.0.0', port=5002, debug=False)
    else:
        logger.error("Failed to initialize TTS, exiting")
        exit(1)
EOF

# Make script executable
sudo chmod +x /opt/coqui-tts/tts_server.py

# Install additional Python dependencies
echo "📦 Installing additional TTS dependencies..."
pip install flask soundfile numpy

# Create TTS systemd service
echo "⚙️ Creating TTS systemd service..."
sudo tee /etc/systemd/system/coqui-tts.service > /dev/null <<EOF
[Unit]
Description=Coqui TTS Server for Billy B-Assistant (Custom Python 3.11)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/coqui-tts
ExecStart=/opt/coqui-tts/bin/python tts_server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Install STT service
echo "📦 Installing Whisper STT service..."

# Create virtual environment for STT (can use system Python)
echo "🐍 Creating virtual environment for STT..."
python3 -m venv /opt/whisper-stt
source /opt/whisper-stt/bin/activate

# Install Python dependencies
echo "📥 Installing STT Python dependencies..."
pip install --upgrade pip
pip install flask numpy soundfile

# Clone and build whisper.cpp
echo "📥 Cloning and building whisper.cpp..."
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

# Create STT service script
echo "⚙️ Creating STT service script..."
sudo tee /opt/whisper-stt/stt_server.py > /dev/null <<'EOF'
#!/usr/bin/env python3
"""
Whisper STT HTTP server for Billy B-Assistant
"""

import asyncio
import base64
import json
import logging
import subprocess
import tempfile
import os
from typing import Dict, Any
from flask import Flask, request, jsonify
import numpy as np
import soundfile as sf

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

# Whisper.cpp paths
WHISPER_CPP_PATH = "/tmp/whisper.cpp"
WHISPER_MODEL = "/tmp/whisper.cpp/models/ggml-base.bin"
WHISPER_MAIN = "/tmp/whisper.cpp/main"

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    model_exists = os.path.exists(WHISPER_MODEL)
    main_exists = os.path.exists(WHISPER_MAIN)
    return jsonify({
        "status": "healthy" if model_exists and main_exists else "unhealthy",
        "model_loaded": model_exists,
        "main_exists": main_exists
    })

@app.route('/api/transcribe', methods=['POST'])
def transcribe():
    """Transcribe audio to text."""
    try:
        data = request.get_json()
        audio_b64 = data.get('audio', '')
        language = data.get('language', 'en')
        model = data.get('model', 'base')
        audio_format = data.get('format', 'pcm16')
        
        if not audio_b64:
            return jsonify({"error": "No audio data provided"}), 400
        
        # Decode audio data
        audio_data = base64.b64decode(audio_b64)
        
        # Create temporary file for audio
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
            temp_path = temp_file.name
            
            if audio_format == 'pcm16':
                # Convert PCM16 to WAV
                # Assume 16kHz sample rate for PCM16
                audio_array = np.frombuffer(audio_data, dtype=np.int16)
                sf.write(temp_path, audio_array, 16000)
            else:
                # Assume it's already WAV
                temp_file.write(audio_data)
                temp_file.flush()
        
        try:
            # Run whisper.cpp
            cmd = [
                WHISPER_MAIN,
                "-m", WHISPER_MODEL,
                "-f", temp_path,
                "-l", language,
                "--no-timestamps",
                "--print-colors", "false"
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                logger.error(f"Whisper error: {result.stderr}")
                return jsonify({"error": f"Transcription failed: {result.stderr}"}), 500
            
            # Extract text from output
            output_lines = result.stdout.strip().split('\n')
            text = ""
            for line in output_lines:
                if line.strip() and not line.startswith('['):
                    text += line.strip() + " "
            
            text = text.strip()
            
            return jsonify({
                "text": text,
                "confidence": 0.9,  # Whisper.cpp doesn't provide confidence scores
                "language": language
            })
            
        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.unlink(temp_path)
            
    except subprocess.TimeoutExpired:
        return jsonify({"error": "Transcription timeout"}), 500
    except Exception as e:
        logger.error(f"Transcription error: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting Whisper STT server on port 5003")
    app.run(host='0.0.0.0', port=5003, debug=False)
EOF

# Make script executable
sudo chmod +x /opt/whisper-stt/stt_server.py

# Create STT systemd service
echo "⚙️ Creating STT systemd service..."
sudo tee /etc/systemd/system/whisper-stt.service > /dev/null <<EOF
[Unit]
Description=Whisper STT Server for Billy B-Assistant
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/whisper-stt
ExecStart=/opt/whisper-stt/bin/python stt_server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable services
sudo systemctl daemon-reload
sudo systemctl enable coqui-tts.service
sudo systemctl enable whisper-stt.service

echo "✅ TTS and STT installation complete!"
echo ""
echo "🔧 Services installed:"
echo "   - Coqui TTS (using custom Python 3.11)"
echo "   - Whisper STT (using system Python)"
echo ""
echo "📊 Check service status:"
echo "   - sudo systemctl status coqui-tts"
echo "   - sudo systemctl status whisper-stt"
echo ""
echo "🧪 Test the services:"
echo "   - curl http://localhost:5002/api/health (Coqui TTS)"
echo "   - curl http://localhost:5003/api/health (Whisper STT)"
echo ""
echo "📊 Monitor logs:"
echo "   - sudo journalctl -u coqui-tts -f"
echo "   - sudo journalctl -u whisper-stt -f"
echo ""
echo "🚀 To start the services:"
echo "   sudo systemctl start coqui-tts"
echo "   sudo systemctl start whisper-stt"
