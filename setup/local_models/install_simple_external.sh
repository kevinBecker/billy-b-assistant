#!/bin/bash

# Simple External Services Setup
# This script sets up the simplest possible external TTS and STT services

set -e

echo "🎤 Setting up Simple External TTS and STT Services"
echo "================================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "❌ This script should not be run as root"
    exit 1
fi

# Install basic dependencies
echo "📦 Installing basic dependencies..."
sudo apt update
sudo apt install -y espeak-ng sox

# Install Python dependencies
echo "📦 Installing Python dependencies..."
pip3 install flask requests

# Create simple TTS server
cat > ~/simple_tts_server.py << 'EOF'
#!/usr/bin/env python3
"""
Simple TTS Server using espeak-ng
"""

import subprocess
import tempfile
import os
from flask import Flask, request, send_file

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return {"status": "healthy", "service": "simple-tts"}

@app.route('/tts', methods=['POST'])
def tts():
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
                '-s', '150',
                '-p', '50',
                '-w', temp_path,
                text
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            
            if result.returncode != 0:
                return {"error": f"espeak-ng failed: {result.stderr}"}, 500
            
            return send_file(temp_path, mimetype='audio/wav', as_attachment=True, download_name='speech.wav')
            
        finally:
            if os.path.exists(temp_path):
                os.unlink(temp_path)
                
    except Exception as e:
        return {"error": str(e)}, 500

if __name__ == '__main__':
    print("🎤 Starting Simple TTS Server...")
    print("📡 Server: http://localhost:5001")
    app.run(host='0.0.0.0', port=5001, debug=False)
EOF

# Create simple STT server
cat > ~/simple_stt_server.py << 'EOF'
#!/usr/bin/env python3
"""
Simple STT Server using whisper.cpp
"""

import subprocess
import tempfile
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return {"status": "healthy", "service": "simple-stt"}

@app.route('/stt', methods=['POST'])
def stt():
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
            if os.path.exists(temp_path):
                os.unlink(temp_path)
                
    except Exception as e:
        return {"error": str(e)}, 500

if __name__ == '__main__':
    print("🎤 Starting Simple STT Server...")
    print("📡 Server: http://localhost:5002")
    app.run(host='0.0.0.0', port=5002, debug=False)
EOF

# Make scripts executable
chmod +x ~/simple_tts_server.py
chmod +x ~/simple_stt_server.py

# Create systemd services
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/simple-tts.service << 'EOF'
[Unit]
Description=Simple TTS Service
After=network.target

[Service]
Type=simple
User=%i
WorkingDirectory=/home/%i
ExecStart=/usr/bin/python3 /home/%i/simple_tts_server.py
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

cat > ~/.config/systemd/user/simple-stt.service << 'EOF'
[Unit]
Description=Simple STT Service
After=network.target

[Service]
Type=simple
User=%i
WorkingDirectory=/home/%i
ExecStart=/usr/bin/python3 /home/%i/simple_stt_server.py
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Enable and start services
echo "🚀 Enabling and starting services..."
systemctl --user daemon-reload
systemctl --user enable simple-tts.service
systemctl --user enable simple-stt.service
systemctl --user start simple-tts.service
systemctl --user start simple-stt.service

# Wait for services to start
echo "⏳ Waiting for services to start..."
sleep 5

# Check service status
echo "📊 Service Status:"
systemctl --user status simple-tts.service --no-pager -l
systemctl --user status simple-stt.service --no-pager -l

echo ""
echo "✅ Simple External TTS and STT services installed successfully!"
echo ""
echo "📡 Services:"
echo "  • TTS Server: http://localhost:5001"
echo "  • STT Server: http://localhost:5002"
echo ""
echo "🔧 TTS Features:"
echo "  • Uses espeak-ng for text-to-speech"
echo "  • Simple HTTP API"
echo ""
echo "🔧 STT Features:"
echo "  • Uses whisper.cpp for speech-to-text"
echo "  • Simple HTTP API"
echo ""
echo "📋 Next Steps:"
echo "  1. Install whisper.cpp: https://github.com/ggerganov/whisper.cpp"
echo "  2. Test the services:"
echo "     curl -X POST http://localhost:5001/tts -H 'Content-Type: application/json' -d '{\"text\":\"Hello world\"}'"
echo "     curl -X POST http://localhost:5002/stt -F 'audio=@audio.wav'"
echo ""
echo "🎯 These services can be used by Billy B-Assistant for local TTS and STT!"
