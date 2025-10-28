#!/bin/bash

# Billy Bass Wyoming Integration Installation Script
# This script installs everything needed for Billy Bass with Wyoming voice processing

set -e

echo "🐟 Billy Bass Wyoming Integration Installer"
echo "=========================================="

# Check if we're in the right directory
if [ ! -f "billy_wyoming_main.py" ]; then
    echo "❌ Please run this script from the billy-b-assistant-git directory"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "🐍 Python version: $PYTHON_VERSION"

if [ "$(echo "$PYTHON_VERSION < 3.9" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
    echo "❌ Python 3.9+ required. Found: $PYTHON_VERSION"
    exit 1
fi

# Check if we're in a virtual environment
if [ -n "$VIRTUAL_ENV" ]; then
    echo "✅ Virtual environment detected: $VIRTUAL_ENV"
else
    echo "⚠️  No virtual environment detected. It's recommended to use one:"
    echo "   python3 -m venv billy_env"
    echo "   source billy_env/bin/activate"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 1
    fi
fi

echo ""
echo "📦 Installing dependencies..."

# Update pip and install build tools
echo "  Updating pip and build tools..."
pip install --upgrade pip setuptools wheel

# Install Billy's core dependencies
echo "  Installing Billy's core dependencies..."
pip install sounddevice websockets numpy scipy gpiozero python-dotenv pydub paho-mqtt requests openai aiohttp flask adafruit-circuitpython-motorkit adafruit-circuitpython-busdevice packaging

# Install Wyoming core package
echo "  Installing Wyoming core package..."
if pip install wyoming 2>/dev/null; then
    echo "✅ Wyoming core package installed"
else
    echo "⚠️  Wyoming core package failed, trying specific version..."
    if pip install wyoming==1.5.4 2>/dev/null; then
        echo "✅ Wyoming core package installed (version 1.5.4)"
    else
        echo "❌ Wyoming core package installation failed"
        echo "   This may be due to Python version compatibility issues"
        echo "   Try using Python 3.11 or 3.12 instead of $PYTHON_VERSION"
        exit 1
    fi
fi

# Install Wyoming-Satellite
echo "  Installing Wyoming-Satellite..."
if pip install wyoming-satellite 2>/dev/null; then
    echo "✅ Wyoming-Satellite installed"
else
    echo "⚠️  Wyoming-Satellite failed, trying specific version..."
    if pip install wyoming-satellite==1.4.1 2>/dev/null; then
        echo "✅ Wyoming-Satellite installed (version 1.4.1)"
    else
        echo "❌ Wyoming-Satellite installation failed"
        exit 1
    fi
fi

# Install supporting packages
echo "  Installing supporting packages..."
pip install zeroconf pyring-buffer

# Install optional wake word package
echo "  Installing wake word detection (optional)..."
if pip install wyoming-openwakeword 2>/dev/null; then
    echo "✅ Wyoming OpenWakeWord installed"
else
    echo "⚠️  Wyoming OpenWakeWord failed, but continuing..."
    echo "   You can install it later with: pip install wyoming-openwakeword"
fi

# Install optional audio processing packages
echo "  Installing audio processing packages (optional)..."
if pip install pysilero-vad webrtc-noise-gain 2>/dev/null; then
    echo "✅ Audio processing packages installed"
else
    echo "⚠️  Audio processing packages failed, but continuing..."
fi

# Test the installation
echo ""
echo "🧪 Testing installation..."

# Test Wyoming imports
if python3 -c "import wyoming; print('Wyoming imported successfully')" 2>/dev/null; then
    echo "✅ Wyoming package verified"
else
    echo "❌ Wyoming package verification failed"
    exit 1
fi

if python3 -c "import wyoming_satellite; print('Wyoming-Satellite imported successfully')" 2>/dev/null; then
    echo "✅ Wyoming-Satellite verified"
else
    echo "❌ Wyoming-Satellite verification failed"
    exit 1
fi

# Test Billy's imports
if python3 -c "from billy_wyoming_config import create_billy_satellite_settings; print('Billy Wyoming config imported successfully')" 2>/dev/null; then
    echo "✅ Billy Wyoming integration verified"
else
    echo "❌ Billy Wyoming integration verification failed"
    exit 1
fi

# Test Billy's core functionality
if python3 -c "from core.movements import move_head; print('Billy movements OK')" 2>/dev/null; then
    echo "✅ Billy movements verified"
else
    echo "❌ Billy movements verification failed"
    exit 1
fi

echo ""
echo "🎉 Installation complete!"
echo ""
echo "📋 Next steps:"
echo "1. Configure your audio devices in .env file:"
echo "   echo 'MIC_PREFERENCE=plughw:1,0' >> .env"
echo "   echo 'SPEAKER_PREFERENCE=plughw:1,0' >> .env"
echo ""
echo "2. Test the installation:"
echo "   python3 test_billy_wyoming.py"
echo ""
echo "3. Start Billy with Wyoming integration:"
echo "   ./start_billy_wyoming.sh"
echo ""
echo "4. For Home Assistant integration:"
echo "   - Add Wyoming integration in Home Assistant"
echo "   - Enter Billy's IP address and port 10700"
echo ""
echo "🐟 Billy Bass is ready to go!"
