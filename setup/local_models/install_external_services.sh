#!/bin/bash

# External TTS and STT Services Setup
# This script sets up external services for TTS and STT instead of installing everything locally

set -e

echo "🎤 Setting up External TTS and STT Services"
echo "=========================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "❌ This script should not be run as root"
    exit 1
fi

# Create services directory
mkdir -p ~/.config/systemd/user

# Create external TTS service (using espeak-ng)
cat > ~/.config/systemd/user/external-tts.service << 'EOF'
[Unit]
Description=External TTS Service (espeak-ng)
After=network.target

[Service]
Type=simple
User=%i
WorkingDirectory=/home/%i
ExecStart=/usr/bin/python3 -m http.server 5001
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Create external STT service (using whisper.cpp)
cat > ~/.config/systemd/user/external-stt.service << 'EOF'
[Unit]
Description=External STT Service (whisper.cpp)
After=network.target

[Service]
Type=simple
User=%i
WorkingDirectory=/home/%i
ExecStart=/usr/bin/python3 -m http.server 5002
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Create TTS server script
cat > ~/tts_server.py << 'EOF'
#!/usr/bin/env python3
"""
External TTS Server using espeak-ng
This provides a simple HTTP API for text-to-speech
"""

import subprocess
import tempfile
import os
from flask import Flask, request, send_file
import threading
import time

app = Flask(__name__)

# Global lock for TTS operations
tts_lock = threading.Lock()

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return {"status": "healthy", "service": "external-tts"}

@app.route('/tts', methods=['POST'])
def tts():
    """Convert text to speech using espeak-ng"""
    try:
        data = request.get_json()
        if not data or 'text' not in data:
            return {"error": "Missing 'text' field"}, 400
        
        text = data['text']
        voice = data.get('voice', 'en-us')
        
        # Create temporary file for audio output
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
            temp_path = temp_file.name
        
        try:
            # Use espeak-ng to generate speech
            cmd = [
                'espeak-ng',
                '-v', voice,
                '-s', '150',  # Speed
                '-p', '50',   # Pitch
                '-w', temp_path,
                text
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                return {"error": f"espeak-ng failed: {result.stderr}"}, 500
            
            # Return the audio file
            return send_file(temp_path, mimetype='audio/wav', as_attachment=True, download_name='speech.wav')
            
        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.unlink(temp_path)
                
    except subprocess.TimeoutExpired:
        return {"error": "TTS generation timed out"}, 500
    except Exception as e:
        return {"error": str(e)}, 500

@app.route('/voices', methods=['GET'])
def voices():
    """Get available voices"""
    try:
        result = subprocess.run(['espeak-ng', '--voices'], capture_output=True, text=True)
        if result.returncode != 0:
            return {"error": "Failed to get voices"}, 500
        
        voices = []
        for line in result.stdout.strip().split('\n')[1:]:  # Skip header
            if line.strip():
                parts = line.split()
                if len(parts) >= 4:
                    voices.append({
                        'name': parts[1],
                        'language': parts[2],
                        'gender': parts[3] if len(parts) > 3 else 'unknown'
                    })
        
        return {"voices": voices}
    except Exception as e:
        return {"error": str(e)}, 500

if __name__ == '__main__':
    print("🎤 Starting External TTS Server...")
    print("📡 Server will be available at: http://localhost:5001")
    print("🔧 Using espeak-ng for text-to-speech")
    app.run(host='0.0.0.0', port=5001, debug=False)
EOF

# Create STT server script
cat > ~/stt_server.py << 'EOF'
#!/usr/bin/env python3
"""
External STT Server using whisper.cpp
This provides a simple HTTP API for speech-to-text
"""

import subprocess
import tempfile
import os
from flask import Flask, request, jsonify
import threading
import time

app = Flask(__name__)

# Global lock for STT operations
stt_lock = threading.Lock()

@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return {"status": "healthy", "service": "external-stt"}

@app.route('/stt', methods=['POST'])
def stt():
    """Convert speech to text using whisper.cpp"""
    try:
        if 'audio' not in request.files:
            return {"error": "No audio file provided"}, 400
        
        audio_file = request.files['audio']
        model = request.form.get('model', 'base')
        
        # Create temporary file for audio input
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
            audio_file.save(temp_file.name)
            temp_path = temp_file.name
        
        try:
            # Use whisper.cpp to transcribe audio
            # Note: This assumes whisper.cpp is installed and available
            cmd = [
                'whisper',
                '--model', model,
                '--output_format', 'txt',
                '--output_dir', '/tmp',
                temp_path
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            
            if result.returncode != 0:
                return {"error": f"whisper failed: {result.stderr}"}, 500
            
            # Read the transcription result
            output_file = temp_path.replace('.wav', '.txt')
            if os.path.exists(output_file):
                with open(output_file, 'r') as f:
                    transcription = f.read().strip()
                os.unlink(output_file)
            else:
                transcription = result.stdout.strip()
            
            return {"text": transcription}
            
        finally:
            # Clean up temporary file
            if os.path.exists(temp_path):
                os.unlink(temp_path)
                
    except subprocess.TimeoutExpired:
        return {"error": "STT processing timed out"}, 500
    except Exception as e:
        return {"error": str(e)}, 500

@app.route('/models', methods=['GET'])
def models():
    """Get available models"""
    return {
        "models": [
            {"name": "tiny", "description": "Fastest, least accurate"},
            {"name": "base", "description": "Good balance of speed and accuracy"},
            {"name": "small", "description": "Better accuracy, slower"},
            {"name": "medium", "description": "Good accuracy, slower"},
            {"name": "large", "description": "Best accuracy, slowest"}
        ]
    }

if __name__ == '__main__':
    print("🎤 Starting External STT Server...")
    print("📡 Server will be available at: http://localhost:5002")
    print("🔧 Using whisper.cpp for speech-to-text")
    app.run(host='0.0.0.0', port=5002, debug=False)
EOF

# Make scripts executable
chmod +x ~/tts_server.py
chmod +x ~/stt_server.py

# Install required packages
echo "📦 Installing required packages..."
pip3 install flask

# Enable and start services
echo "🚀 Enabling and starting services..."
systemctl --user daemon-reload
systemctl --user enable external-tts.service
systemctl --user enable external-stt.service
systemctl --user start external-tts.service
systemctl --user start external-stt.service

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 5

# Check service status
echo "📊 Service Status:"
systemctl --user status external-tts.service --no-pager -l
systemctl --user status external-stt.service --no-pager -l

echo ""
echo "✅ External TTS and STT services installed successfully!"
echo ""
echo "📡 Services:"
echo "  • TTS Server: http://localhost:5001"
echo "  • STT Server: http://localhost:5002"
echo ""
echo "🔧 TTS Features:"
echo "  • Uses espeak-ng for text-to-speech"
echo "  • Multiple voice options"
echo "  • HTTP API for integration"
echo ""
echo "🔧 STT Features:"
echo "  • Uses whisper.cpp for speech-to-text"
echo "  • Multiple model options"
echo "  • HTTP API for integration"
echo ""
echo "📋 Next Steps:"
echo "  1. Install espeak-ng: sudo apt install espeak-ng"
echo "  2. Install whisper.cpp: https://github.com/ggerganov/whisper.cpp"
echo "  3. Test the services:"
echo "     curl -X POST http://localhost:5001/tts -H 'Content-Type: application/json' -d '{\"text\":\"Hello world\"}'"
echo "     curl -X POST http://localhost:5002/stt -F 'audio=@audio.wav'"
echo ""
echo "🎯 These services can be used by Billy B-Assistant for local TTS and STT!"
