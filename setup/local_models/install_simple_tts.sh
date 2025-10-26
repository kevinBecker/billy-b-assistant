#!/bin/bash

# Install a simple TTS service using espeak-ng and sox
# This is a lightweight alternative to Coqui TTS that works with Python 3.13

set -e

echo "🚀 Installing Simple TTS service for Billy B-Assistant..."

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "⚠️ This script is designed for Raspberry Pi. Proceeding anyway..."
fi

# Install system dependencies
echo "📦 Installing system dependencies..."
sudo apt update
sudo apt install -y espeak-ng sox python3-pip python3-venv

# Create virtual environment
echo "🐍 Creating Python virtual environment..."
python3 -m venv /opt/simple-tts
source /opt/simple-tts/bin/activate

# Install Python dependencies
echo "📥 Installing Python dependencies..."
pip install --upgrade pip
pip install flask numpy

# Create TTS service script
echo "⚙️ Creating TTS service script..."
sudo tee /opt/simple-tts/tts_server.py > /dev/null <<'EOF'
#!/usr/bin/env python3
"""
Simple TTS HTTP server for Billy B-Assistant using espeak-ng
"""

import asyncio
import base64
import json
import logging
import subprocess
import tempfile
import os
from typing import Dict, Any
from flask import Flask, request, jsonify, Response
import numpy as np

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)

@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint."""
    return jsonify({"status": "healthy", "engine": "espeak-ng"})

@app.route('/api/voices', methods=['GET'])
def get_voices():
    """Get available voices."""
    return jsonify({"voices": ["default", "male", "female"]})

@app.route('/api/synthesize', methods=['POST'])
def synthesize():
    """Synthesize speech from text using espeak-ng."""
    try:
        data = request.get_json()
        text = data.get('text', '')
        voice = data.get('voice', 'default')
        output_format = data.get('output_format', 'pcm16')
        stream = data.get('stream', False)
        
        if not text:
            return jsonify({"error": "No text provided"}), 400
        
        # Create temporary file for audio
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
            temp_path = temp_file.name
        
        try:
            # Configure espeak-ng based on voice
            espeak_cmd = ['espeak-ng']
            
            if voice == 'male':
                espeak_cmd.extend(['-v', 'en+m3'])  # Male voice
            elif voice == 'female':
                espeak_cmd.extend(['-v', 'en+f3'])  # Female voice
            else:
                espeak_cmd.extend(['-v', 'en'])     # Default voice
            
            # Add text and output options
            espeak_cmd.extend([
                '-s', '150',  # Speed (words per minute)
                '-w', temp_path,  # Output file
                text
            ])
            
            # Run espeak-ng
            result = subprocess.run(espeak_cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                logger.error(f"espeak-ng error: {result.stderr}")
                return jsonify({"error": f"TTS synthesis failed: {result.stderr}"}), 500
            
            # Read the generated WAV file
            with open(temp_path, 'rb') as f:
                wav_data = f.read()
            
            # Convert to PCM16 if requested
            if output_format == 'pcm16':
                # Use sox to convert WAV to PCM16
                pcm_path = temp_path + '.pcm'
                sox_cmd = [
                    'sox', temp_path, '-t', 'raw', '-r', '16000', '-c', '1', '-b', '16', pcm_path
                ]
                
                sox_result = subprocess.run(sox_cmd, capture_output=True, text=True, timeout=10)
                
                if sox_result.returncode == 0:
                    with open(pcm_path, 'rb') as f:
                        audio_data = f.read()
                    os.unlink(pcm_path)
                else:
                    # Fallback: return WAV data
                    audio_data = wav_data
            else:
                audio_data = wav_data
            
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
                
        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.unlink(temp_path)
            
    except subprocess.TimeoutExpired:
        return jsonify({"error": "TTS synthesis timeout"}), 500
    except Exception as e:
        logger.error(f"Synthesis error: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting Simple TTS server on port 5002")
    app.run(host='0.0.0.0', port=5002, debug=False)
EOF

# Make script executable
sudo chmod +x /opt/simple-tts/tts_server.py

# Create systemd service
echo "⚙️ Creating systemd service..."
sudo tee /etc/systemd/system/simple-tts.service > /dev/null <<EOF
[Unit]
Description=Simple TTS Server for Billy B-Assistant
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/simple-tts
ExecStart=/opt/simple-tts/bin/python tts_server.py
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable simple-tts.service

echo "✅ Simple TTS installation complete!"
echo "🔧 This TTS service uses espeak-ng and works with Python 3.13+"
echo "📊 Check status with: sudo systemctl status simple-tts"
echo "🧪 Test with: curl http://localhost:5002/api/health"
echo ""
echo "⚠️ Note: This is a simpler TTS solution with basic voice quality."
echo "   For better quality, consider using Coqui TTS with Python 3.11."
