#!/bin/bash

# Fixed Wyoming Installation Script
# This script handles dependency conflicts and installs compatible versions

set -e

echo "🐟 Installing Wyoming with Fixed Dependencies..."

# Check if we're in the right directory
if [ ! -f "billy_wyoming_main.py" ]; then
    echo "❌ Please run this script from the billy-b-assistant-git directory"
    exit 1
fi

echo "📦 Installing dependencies with conflict resolution..."

# Method 1: Try installing with specific compatible versions
echo "  Method 1: Installing with specific versions..."
if pip install -r requirements_wyoming_fixed.txt 2>/dev/null; then
    echo "✅ Dependencies installed successfully"
    INSTALLED=true
else
    echo "⚠️  Method 1 failed, trying method 2..."
    INSTALLED=false
fi

# Method 2: Install packages individually to resolve conflicts
if [ "$INSTALLED" = false ]; then
    echo "  Method 2: Installing packages individually..."
    
    # Install core Wyoming package first
    pip install wyoming==1.5.4
    
    # Install other Wyoming packages
    pip install wyoming-satellite==1.4.1
    pip install wyoming-openwakeword==1.8.2
    
    # Install other dependencies
    pip install zeroconf==0.88.0 pyring-buffer
    
    # Install Billy's dependencies
    pip install sounddevice websockets numpy scipy gpiozero python-dotenv pydub paho-mqtt requests openai aiohttp flask adafruit-circuitpython-motorkit adafruit-circuitpython-busdevice packaging
    
    # Install optional dependencies
    pip install pysilero-vad==1.0.0 webrtc-noise-gain==1.2.3
    
    echo "✅ Dependencies installed individually"
    INSTALLED=true
fi

# Method 3: Use pip-tools to resolve conflicts
if [ "$INSTALLED" = false ]; then
    echo "  Method 3: Using pip-tools for conflict resolution..."
    
    # Install pip-tools
    pip install pip-tools
    
    # Create a requirements.in file
    cat > requirements_wyoming.in << EOF
# Core dependencies
sounddevice
websockets
numpy>=1.24.0,<2.0.0
scipy>=1.10.0,<2.0.0
gpiozero
python-dotenv
pydub
paho-mqtt
requests
openai
aiohttp
flask
adafruit-circuitpython-motorkit
adafruit-circuitpython-busdevice
packaging

# Wyoming dependencies
wyoming>=1.5.0,<1.6.0
wyoming-satellite>=1.4.0,<1.5.0
wyoming-openwakeword>=1.8.0,<1.9.0
zeroconf>=0.88.0,<0.89.0
pyring-buffer>=1,<2

# Optional dependencies
pysilero-vad==1.0.0
webrtc-noise-gain==1.2.3
EOF

    # Compile requirements
    pip-compile requirements_wyoming.in
    
    # Install compiled requirements
    pip install -r requirements_wyoming.txt
    
    echo "✅ Dependencies installed with pip-tools"
    INSTALLED=true
fi

# Test the installation
echo "🧪 Testing installation..."

# Test Wyoming imports
if python3 -c "import wyoming; print('Wyoming imported successfully')" 2>/dev/null; then
    echo "✅ Wyoming package verified"
else
    echo "❌ Wyoming package verification failed"
    echo "   Try: pip install wyoming==1.5.4"
    exit 1
fi

if python3 -c "import wyoming_satellite; print('Wyoming-Satellite imported successfully')" 2>/dev/null; then
    echo "✅ Wyoming-Satellite verified"
else
    echo "❌ Wyoming-Satellite verification failed"
    echo "   Try: pip install wyoming-satellite==1.4.1"
    exit 1
fi

if python3 -c "import wyoming_openwakeword; print('Wyoming OpenWakeWord imported successfully')" 2>/dev/null; then
    echo "✅ Wyoming OpenWakeWord verified"
else
    echo "❌ Wyoming OpenWakeWord verification failed"
    echo "   Try: pip install wyoming-openwakeword==1.8.2"
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
echo "🎉 Installation complete!"
echo ""
echo "If you still have issues, try these manual steps:"
echo "1. pip install wyoming==1.5.4"
echo "2. pip install wyoming-satellite==1.4.1"
echo "3. pip install wyoming-openwakeword==1.8.2"
echo ""
echo "Next steps:"
echo "1. Configure your audio devices in .env file"
echo "2. Run the test suite: python3 test_billy_wyoming.py"
echo "3. Start Billy: ./start_billy_wyoming.sh"
