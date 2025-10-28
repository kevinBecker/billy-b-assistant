#!/bin/bash

# Minimal Wyoming Installation Script
# This script installs only the essential packages to avoid conflicts

set -e

echo "🐟 Installing Wyoming with Minimal Dependencies..."

# Check if we're in the right directory
if [ ! -f "billy_wyoming_main.py" ]; then
    echo "❌ Please run this script from the billy-b-assistant-git directory"
    exit 1
fi

echo "📦 Installing minimal dependencies..."

# Install Billy's core dependencies first
echo "  Installing Billy's core dependencies..."
pip install sounddevice websockets numpy scipy gpiozero python-dotenv pydub paho-mqtt requests openai aiohttp flask adafruit-circuitpython-motorkit adafruit-circuitpython-busdevice packaging

# Install only the essential Wyoming packages
echo "  Installing essential Wyoming packages..."

# Try to install Wyoming core package
if pip install wyoming 2>/dev/null; then
    echo "✅ Wyoming core package installed"
else
    echo "⚠️  Wyoming core package failed, trying specific version..."
    pip install wyoming==1.5.4
fi

# Install Wyoming-Satellite
if pip install wyoming-satellite 2>/dev/null; then
    echo "✅ Wyoming-Satellite installed"
else
    echo "⚠️  Wyoming-Satellite failed, trying specific version..."
    pip install wyoming-satellite==1.4.1
fi

# Install supporting packages
pip install zeroconf pyring-buffer

# Try to install wake word package (optional)
if pip install wyoming-openwakeword 2>/dev/null; then
    echo "✅ Wyoming OpenWakeWord installed"
else
    echo "⚠️  Wyoming OpenWakeWord failed, but continuing..."
    echo "   You can install it later with: pip install wyoming-openwakeword"
fi

# Install optional audio processing packages
if pip install pysilero-vad webrtc-noise-gain 2>/dev/null; then
    echo "✅ Audio processing packages installed"
else
    echo "⚠️  Audio processing packages failed, but continuing..."
fi

# Test the installation
echo "🧪 Testing installation..."

# Test core Wyoming functionality
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

echo ""
echo "🎉 Minimal installation complete!"
echo ""
echo "Note: Some optional packages may not be installed due to conflicts."
echo "The core functionality should work. You can install additional packages later:"
echo "- pip install wyoming-openwakeword  # For wake word detection"
echo "- pip install pysilero-vad          # For voice activity detection"
echo "- pip install webrtc-noise-gain     # For audio enhancement"
echo ""
echo "Next steps:"
echo "1. Configure your audio devices in .env file"
echo "2. Run the test suite: python3 test_billy_wyoming.py"
echo "3. Start Billy: ./start_billy_wyoming.sh"
