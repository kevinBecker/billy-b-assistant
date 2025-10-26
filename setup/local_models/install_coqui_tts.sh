#!/bin/bash

# Install Coqui TTS for local text-to-speech
# This script sets up Coqui TTS on the Raspberry Pi

set -e

echo "🚀 Installing Coqui TTS for local text-to-speech..."

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "⚠️ This script is designed for Raspberry Pi. Proceeding anyway..."
fi

# Install system dependencies
echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y python3-pip python3-venv espeak-ng

# Create virtual environment
echo "🐍 Creating Python virtual environment..."
python3 -m venv /opt/coqui-tts
source /opt/coqui-tts/bin/activate

# Install Coqui TTS
echo "📥 Installing Coqui TTS..."
pip install --upgrade pip
pip install TTS

# Download XTTS-v2 model (multilingual, high quality)
echo "📥 Downloading XTTS-v2 model..."
python3 -c "
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

# Create systemd service
echo "⚙️ Creating systemd service..."
sudo tee /etc/systemd/system/coqui-tts.service > /dev/null <<EOF
[Unit]
Description=Coqui TTS Server for Billy B-Assistant
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/coqui-tts
ExecStart=/opt/coqui-tts/bin/python tts_server.py
Restart=always
RestartSec=3
Environment="PYTHONPATH=/opt/coqui-tts/lib/python3.11/site-packages"

[Install]
WantedBy=multi-user.target
EOF

# Install additional Python dependencies
echo "📦 Installing additional dependencies..."
sudo /opt/coqui-tts/bin/pip install flask soundfile numpy

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable coqui-tts.service

echo "✅ Coqui TTS installation complete!"
echo "🔧 Configure Billy to use local TTS by setting USE_LOCAL_MODELS=true in your .env file"
echo "📊 Check status with: sudo systemctl status coqui-tts"
echo "🧪 Test with: curl http://localhost:5002/api/health"
