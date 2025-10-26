#!/bin/bash

# Install Whisper.cpp for local speech-to-text
# This script sets up Whisper STT on the Raspberry Pi

set -e

echo "🚀 Installing Whisper.cpp for local speech-to-text..."

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "⚠️ This script is designed for Raspberry Pi. Proceeding anyway..."
fi

# Install system dependencies
echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y build-essential cmake ffmpeg python3-pip python3-venv

# Create virtual environment
echo "🐍 Creating Python virtual environment..."
python3 -m venv /opt/whisper-stt
source /opt/whisper-stt/bin/activate

# Install Python dependencies
echo "📥 Installing Python dependencies..."
pip install --upgrade pip
pip install flask numpy soundfile

# Clone and build whisper.cpp
echo "📥 Cloning whisper.cpp..."
cd /tmp
git clone https://github.com/ggerganov/whisper.cpp.git
cd whisper.cpp

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

# Create systemd service
echo "⚙️ Creating systemd service..."
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
Environment="PYTHONPATH=/opt/whisper-stt/lib/python3.11/site-packages"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable whisper-stt.service

echo "✅ Whisper STT installation complete!"
echo "🔧 Configure Billy to use local STT by setting USE_LOCAL_MODELS=true in your .env file"
echo "📊 Check status with: sudo systemctl status whisper-stt"
echo "🧪 Test with: curl http://localhost:5003/api/health"
