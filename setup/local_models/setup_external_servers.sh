#!/bin/bash

# External Server Setup
# This script helps set up TTS and STT services on external servers

set -e

echo "🌐 Setting up External TTS and STT Servers"
echo "=========================================="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "❌ This script should not be run as root"
    exit 1
fi

# Create external server configuration
cat > ~/external_servers_config.py << 'EOF'
#!/usr/bin/env python3
"""
External Server Configuration
This file contains the configuration for external TTS and STT servers
"""

# External TTS Server Configuration
EXTERNAL_TTS_SERVERS = {
    "local": {
        "host": "localhost",
        "port": 5001,
        "type": "espeak-ng",
        "description": "Local espeak-ng server"
    },
    "coqui": {
        "host": "localhost",
        "port": 5003,
        "type": "coqui-tts",
        "description": "Local Coqui TTS server"
    },
    "remote": {
        "host": "192.168.1.100",  # Change this to your server IP
        "port": 5001,
        "type": "espeak-ng",
        "description": "Remote espeak-ng server"
    }
}

# External STT Server Configuration
EXTERNAL_STT_SERVERS = {
    "local": {
        "host": "localhost",
        "port": 5002,
        "type": "whisper",
        "description": "Local Whisper server"
    },
    "remote": {
        "host": "192.168.1.100",  # Change this to your server IP
        "port": 5002,
        "type": "whisper",
        "description": "Remote Whisper server"
    }
}

# Default server selection
DEFAULT_TTS_SERVER = "local"
DEFAULT_STT_SERVER = "local"

def get_tts_server(server_name=None):
    """Get TTS server configuration"""
    if server_name is None:
        server_name = DEFAULT_TTS_SERVER
    
    return EXTERNAL_TTS_SERVERS.get(server_name, EXTERNAL_TTS_SERVERS[DEFAULT_TTS_SERVER])

def get_stt_server(server_name=None):
    """Get STT server configuration"""
    if server_name is None:
        server_name = DEFAULT_STT_SERVER
    
    return EXTERNAL_STT_SERVERS.get(server_name, EXTERNAL_STT_SERVERS[DEFAULT_STT_SERVER])

def list_tts_servers():
    """List available TTS servers"""
    return list(EXTERNAL_TTS_SERVERS.keys())

def list_stt_servers():
    """List available STT servers"""
    return list(EXTERNAL_STT_SERVERS.keys())
EOF

# Create external TTS client
cat > ~/external_tts_client.py << 'EOF'
#!/usr/bin/env python3
"""
External TTS Client
This client can connect to various external TTS servers
"""

import requests
import tempfile
import os
from external_servers_config import get_tts_server

class ExternalTTSClient:
    def __init__(self, server_name=None):
        self.server_config = get_tts_server(server_name)
        self.base_url = f"http://{self.server_config['host']}:{self.server_config['port']}"
    
    def health_check(self):
        """Check if the TTS server is healthy"""
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def synthesize(self, text, voice=None):
        """Synthesize text to speech"""
        try:
            data = {"text": text}
            if voice:
                data["voice"] = voice
            
            response = requests.post(
                f"{self.base_url}/tts",
                json=data,
                timeout=30
            )
            
            if response.status_code == 200:
                # Save audio to temporary file
                with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
                    temp_file.write(response.content)
                    return temp_file.name
            else:
                raise Exception(f"TTS request failed: {response.text}")
                
        except Exception as e:
            raise Exception(f"TTS synthesis failed: {str(e)}")
    
    def get_voices(self):
        """Get available voices"""
        try:
            response = requests.get(f"{self.base_url}/voices", timeout=5)
            if response.status_code == 200:
                return response.json().get("voices", [])
            else:
                return []
        except:
            return []

# Example usage
if __name__ == "__main__":
    client = ExternalTTSClient()
    
    if client.health_check():
        print("✅ TTS server is healthy")
        
        # Test synthesis
        try:
            audio_file = client.synthesize("Hello, this is a test of the external TTS server.")
            print(f"✅ Audio generated: {audio_file}")
        except Exception as e:
            print(f"❌ TTS synthesis failed: {e}")
    else:
        print("❌ TTS server is not responding")
EOF

# Create external STT client
cat > ~/external_stt_client.py << 'EOF'
#!/usr/bin/env python3
"""
External STT Client
This client can connect to various external STT servers
"""

import requests
from external_servers_config import get_stt_server

class ExternalSTTClient:
    def __init__(self, server_name=None):
        self.server_config = get_stt_server(server_name)
        self.base_url = f"http://{self.server_config['host']}:{self.server_config['port']}"
    
    def health_check(self):
        """Check if the STT server is healthy"""
        try:
            response = requests.get(f"{self.base_url}/health", timeout=5)
            return response.status_code == 200
        except:
            return False
    
    def transcribe(self, audio_file_path, model=None):
        """Transcribe audio file to text"""
        try:
            with open(audio_file_path, 'rb') as audio_file:
                files = {'audio': audio_file}
                data = {}
                if model:
                    data['model'] = model
                
                response = requests.post(
                    f"{self.base_url}/stt",
                    files=files,
                    data=data,
                    timeout=60
                )
                
                if response.status_code == 200:
                    return response.json().get("text", "")
                else:
                    raise Exception(f"STT request failed: {response.text}")
                    
        except Exception as e:
            raise Exception(f"STT transcription failed: {str(e)}")
    
    def get_models(self):
        """Get available models"""
        try:
            response = requests.get(f"{self.base_url}/models", timeout=5)
            if response.status_code == 200:
                return response.json().get("models", [])
            else:
                return []
        except:
            return []

# Example usage
if __name__ == "__main__":
    client = ExternalSTTClient()
    
    if client.health_check():
        print("✅ STT server is healthy")
        
        # Test transcription (you would need an audio file)
        # try:
        #     text = client.transcribe("test_audio.wav")
        #     print(f"✅ Transcription: {text}")
        # except Exception as e:
        #     print(f"❌ STT transcription failed: {e}")
    else:
        print("❌ STT server is not responding")
EOF

# Create setup script for remote servers
cat > ~/setup_remote_server.sh << 'EOF'
#!/bin/bash

# Setup script for remote TTS/STT servers
# Run this on your remote server to set up TTS and STT services

set -e

echo "🌐 Setting up Remote TTS and STT Server"
echo "======================================="

# Install dependencies
echo "📦 Installing dependencies..."
sudo apt update
sudo apt install -y espeak-ng sox python3-pip

# Install Python dependencies
pip3 install flask requests

# Create TTS server
cat > ~/remote_tts_server.py << 'TTS_EOF'
#!/usr/bin/env python3
"""
Remote TTS Server using espeak-ng
"""

import subprocess
import tempfile
import os
from flask import Flask, request, send_file

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return {"status": "healthy", "service": "remote-tts"}

@app.route('/tts', methods=['POST'])
def tts():
    try:
        data = request.get_json()
        if not data or 'text' not in data:
            return {"error": "Missing 'text' field"}, 400
        
        text = data['text']
        voice = data.get('voice', 'en-us')
        
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
            temp_path = temp_file.name
        
        try:
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
    print("🎤 Starting Remote TTS Server...")
    print("📡 Server: http://0.0.0.0:5001")
    app.run(host='0.0.0.0', port=5001, debug=False)
TTS_EOF

# Create STT server
cat > ~/remote_stt_server.py << 'STT_EOF'
#!/usr/bin/env python3
"""
Remote STT Server using whisper.cpp
"""

import subprocess
import tempfile
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/health', methods=['GET'])
def health():
    return {"status": "healthy", "service": "remote-stt"}

@app.route('/stt', methods=['POST'])
def stt():
    try:
        if 'audio' not in request.files:
            return {"error": "No audio file provided"}, 400
        
        audio_file = request.files['audio']
        model = request.form.get('model', 'base')
        
        with tempfile.NamedTemporaryFile(suffix='.wav', delete=False) as temp_file:
            audio_file.save(temp_file.name)
            temp_path = temp_file.name
        
        try:
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
    print("🎤 Starting Remote STT Server...")
    print("📡 Server: http://0.0.0.0:5002")
    app.run(host='0.0.0.0', port=5002, debug=False)
STT_EOF

# Make scripts executable
chmod +x ~/remote_tts_server.py
chmod +x ~/remote_stt_server.py

# Create systemd services
mkdir -p ~/.config/systemd/user

cat > ~/.config/systemd/user/remote-tts.service << 'EOF'
[Unit]
Description=Remote TTS Service
After=network.target

[Service]
Type=simple
User=%i
WorkingDirectory=/home/%i
ExecStart=/usr/bin/python3 /home/%i/remote_tts_server.py
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

cat > ~/.config/systemd/user/remote-stt.service << 'EOF'
[Unit]
Description=Remote STT Service
After=network.target

[Service]
Type=simple
User=%i
WorkingDirectory=/home/%i
ExecStart=/usr/bin/python3 /home/%i/remote_stt_server.py
Restart=always
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Enable and start services
echo "🚀 Enabling and starting services..."
systemctl --user daemon-reload
systemctl --user enable remote-tts.service
systemctl --user enable remote-stt.service
systemctl --user start remote-tts.service
systemctl --user start remote-stt.service

echo "✅ Remote TTS and STT server setup complete!"
echo ""
echo "📡 Services:"
echo "  • TTS Server: http://0.0.0.0:5001"
echo "  • STT Server: http://0.0.0.0:5002"
echo ""
echo "🔧 Next Steps:"
echo "  1. Install whisper.cpp on this server"
echo "  2. Update the IP address in external_servers_config.py on your Pi"
echo "  3. Test the services from your Pi"
EOF

# Make scripts executable
chmod +x ~/external_servers_config.py
chmod +x ~/external_tts_client.py
chmod +x ~/external_stt_client.py
chmod +x ~/setup_remote_server.sh

echo "✅ External server setup complete!"
echo ""
echo "📁 Files created:"
echo "  • ~/external_servers_config.py - Server configuration"
echo "  • ~/external_tts_client.py - TTS client"
echo "  • ~/external_stt_client.py - STT client"
echo "  • ~/setup_remote_server.sh - Remote server setup script"
echo ""
echo "🌐 To set up a remote server:"
echo "  1. Copy ~/setup_remote_server.sh to your remote server"
echo "  2. Run it on the remote server"
echo "  3. Update the IP addresses in ~/external_servers_config.py"
echo ""
echo "🎯 These clients can be used by Billy B-Assistant for external TTS and STT!"
