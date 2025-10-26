#!/bin/bash



# asdf
# Install Coqui TTS for local text-to-speech
# This script sets up Coqui TTS on the Raspberry Pi

set -e

echo "🚀 Installing Coqui TTS for local text-to-speech..."

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "⚠️ This script is designed for Raspberry Pi. Proceeding anyway..."
fi

# Check Python version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "🐍 Detected Python version: $PYTHON_VERSION"

if [[ "$PYTHON_VERSION" > "3.12" ]]; then
    echo "⚠️ Python $PYTHON_VERSION detected. Coqui TTS doesn't support Python 3.13+ yet."
    echo "🔧 Attempting to install Python 3.11 for TTS compatibility..."
    
    # Try to install Python 3.11
    sudo apt update
    
    # Check if python3.11 is available
    if apt-cache show python3.11 > /dev/null 2>&1; then
        echo "✅ Python 3.11 found in repositories"
        sudo apt install -y python3.11 python3.11-venv python3.11-dev python3-pip espeak-ng
    else
        echo "❌ Python 3.11 not available in repositories"
        echo "🔧 Attempting to add deadsnakes PPA for Python 3.11..."
        
        # Try to add deadsnakes PPA for older Python versions
        if apt-cache show software-properties-common > /dev/null 2>&1; then
            echo "✅ software-properties-common available"
            sudo apt install -y software-properties-common
            sudo add-apt-repository -y ppa:deadsnakes/ppa
            sudo apt update
        else
            echo "❌ software-properties-common not available"
            echo "🔄 Cannot add PPA repositories on this system"
            echo "🔄 Falling back to Simple TTS instead..."
            echo "📦 Installing Simple TTS (espeak-ng based)..."
            
            # Install system dependencies for Simple TTS
            sudo apt install -y espeak-ng sox python3-pip python3-venv
            
            # Create virtual environment
            echo "🐍 Creating Python virtual environment..."
            python3 -m venv /opt/simple-tts
            source /opt/simple-tts/bin/activate
            
            # Install Python dependencies
            echo "📥 Installing Python dependencies..."
            pip install --upgrade pip
            pip install flask numpy
            
            # Create Simple TTS service script
            echo "⚙️ Creating Simple TTS service script..."
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
            echo "   For better quality, consider using a remote TTS service."
            exit 0
        fi
        
        # Try again
        if apt-cache show python3.11 > /dev/null 2>&1; then
            echo "✅ Python 3.11 now available"
            sudo apt install -y python3.11 python3.11-venv python3.11-dev python3-pip espeak-ng
        else
            echo "❌ Python 3.11 still not available"
            echo "🔄 Falling back to Simple TTS instead..."
            echo "📦 Installing Simple TTS (espeak-ng based)..."
            
            # Install system dependencies for Simple TTS
            sudo apt install -y espeak-ng sox python3-pip python3-venv
            
            # Create virtual environment
            echo "🐍 Creating Python virtual environment..."
            python3 -m venv /opt/simple-tts
            source /opt/simple-tts/bin/activate
            
            # Install Python dependencies
            echo "📥 Installing Python dependencies..."
            pip install --upgrade pip
            pip install flask numpy
            
            # Create Simple TTS service script
            echo "⚙️ Creating Simple TTS service script..."
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
            echo "   For better quality, consider using a remote TTS service."
            exit 0
        fi
    fi
    
    # Create virtual environment with Python 3.11
    echo "🐍 Creating Python 3.11 virtual environment..."
    python3.11 -m venv /opt/coqui-tts
    source /opt/coqui-tts/bin/activate
    
    # Install Coqui TTS
    echo "📥 Installing Coqui TTS with Python 3.11..."
    pip install --upgrade pip
    pip install TTS
else
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
fi

# Download XTTS-v2 model (multilingual, high quality)
echo "📥 Downloading XTTS-v2 model..."
if [[ "$PYTHON_VERSION" > "3.12" ]]; then
    /opt/coqui-tts/bin/python -c "
import TTS
from TTS.api import TTS

# Initialize TTS
tts = TTS('tts_models/multilingual/multi-dataset/xtts_v2')

# Download model files
print('Model downloaded successfully')
"
else
    python3 -c "
import TTS
from TTS.api import TTS

# Initialize TTS
tts = TTS('tts_models/multilingual/multi-dataset/xtts_v2')

# Download model files
print('Model downloaded successfully')
"
fi

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
if [[ "$PYTHON_VERSION" > "3.12" ]]; then
    PYTHON_PATH="/opt/coqui-tts/lib/python3.11/site-packages"
    PYTHON_EXEC="/opt/coqui-tts/bin/python"
else
    PYTHON_PATH="/opt/coqui-tts/lib/python3.${PYTHON_VERSION##*.}/site-packages"
    PYTHON_EXEC="/opt/coqui-tts/bin/python"
fi

sudo tee /etc/systemd/system/coqui-tts.service > /dev/null <<EOF
[Unit]
Description=Coqui TTS Server for Billy B-Assistant
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/coqui-tts
ExecStart=$PYTHON_EXEC tts_server.py
Restart=always
RestartSec=3
Environment="PYTHONPATH=$PYTHON_PATH"

[Install]
WantedBy=multi-user.target
EOF

# Install additional Python dependencies
echo "📦 Installing additional dependencies..."
sudo $PYTHON_EXEC -m pip install flask soundfile numpy

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable coqui-tts.service

echo "✅ Coqui TTS installation complete!"
echo "🔧 Configure Billy to use local TTS by setting USE_LOCAL_MODELS=true in your .env file"
echo "📊 Check status with: sudo systemctl status coqui-tts"
echo "🧪 Test with: curl http://localhost:5002/api/health"
