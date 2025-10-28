#!/bin/bash

# Local Wyoming Installation Script
# This script uses the local Wyoming-Satellite directory to avoid PyPI conflicts

set -e

echo "🐟 Installing Wyoming using Local Directory..."

# Check if we're in the right directory
if [ ! -f "billy_wyoming_main.py" ]; then
    echo "❌ Please run this script from the billy-b-assistant-git directory"
    exit 1
fi

# Check if Wyoming-Satellite directory exists
if [ ! -d "wyoming-satellite" ]; then
    echo "❌ Wyoming-Satellite directory not found!"
    echo "   Please ensure the wyoming-satellite directory is in the current directory"
    exit 1
fi

echo "📦 Installing dependencies..."

# Install Billy's core dependencies first
echo "  Installing Billy's core dependencies..."
pip install sounddevice websockets numpy scipy gpiozero python-dotenv pydub paho-mqtt requests openai aiohttp flask adafruit-circuitpython-motorkit adafruit-circuitpython-busdevice packaging

# Install Wyoming core package
echo "  Installing Wyoming core package..."
pip install wyoming

# Install supporting packages
pip install zeroconf pyring-buffer

# Install Wyoming-Satellite from local directory
echo "  Installing Wyoming-Satellite from local directory..."
cd wyoming-satellite

# Try different installation methods
if pip install -e . 2>/dev/null; then
    echo "✅ Wyoming-Satellite installed in development mode"
elif pip install . 2>/dev/null; then
    echo "✅ Wyoming-Satellite installed normally"
else
    echo "❌ Failed to install Wyoming-Satellite from local directory"
    echo "   Trying to install dependencies manually..."
    
    # Install the Python package manually
    pip install -e . --no-deps
    pip install wyoming zeroconf pyring-buffer
fi

cd ..

# Try to install wake word package (optional)
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
echo "🎉 Local installation complete!"
echo ""
echo "This installation uses the local Wyoming-Satellite directory to avoid"
echo "PyPI dependency conflicts. The core functionality should work."
echo ""
echo "Next steps:"
echo "1. Configure your audio devices in .env file"
echo "2. Run the test suite: python3 test_billy_wyoming.py"
echo "3. Start Billy: ./start_billy_wyoming.sh"
