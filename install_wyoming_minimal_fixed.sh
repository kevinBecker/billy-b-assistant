#!/bin/bash

# Fixed Minimal Wyoming Installation Script
# This script handles verification failures more gracefully

set -e

echo "🐟 Installing Wyoming with Minimal Dependencies (Fixed)..."

# Check if we're in the right directory
if [ ! -f "billy_wyoming_main.py" ]; then
    echo "❌ Please run this script from the billy-b-assistant-git directory"
    exit 1
fi

echo "📦 Installing dependencies..."

# Install Billy's core dependencies first
echo "  Installing Billy's core dependencies..."
pip install sounddevice websockets numpy scipy gpiozero python-dotenv pydub paho-mqtt requests openai aiohttp flask adafruit-circuitpython-motorkit adafruit-circuitpython-busdevice packaging

# Install only the essential Wyoming packages
echo "  Installing essential Wyoming packages..."

# Try to install Wyoming core package
echo "  Installing Wyoming core package..."
if pip install wyoming 2>/dev/null; then
    echo "✅ Wyoming core package installed"
else
    echo "⚠️  Wyoming core package failed, trying specific version..."
    if pip install wyoming==1.5.4 2>/dev/null; then
        echo "✅ Wyoming core package installed (version 1.5.4)"
    else
        echo "⚠️  Wyoming core package failed, but continuing..."
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
        echo "⚠️  Wyoming-Satellite failed, but continuing..."
    fi
fi

# Install supporting packages
echo "  Installing supporting packages..."
pip install zeroconf pyring-buffer

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

# Test the installation with detailed debugging
echo "🧪 Testing installation with detailed debugging..."

# Run the debug script
echo "  Running detailed package check..."
python3 debug_wyoming.py

# Test core Wyoming functionality with better error handling
echo "  Testing Wyoming package..."
if python3 -c "import wyoming; print('Wyoming imported successfully')" 2>/dev/null; then
    echo "✅ Wyoming package verified"
    WYOMING_OK=true
else
    echo "⚠️  Wyoming package verification failed"
    echo "   This might be due to version conflicts or missing dependencies"
    WYOMING_OK=false
fi

# Test Wyoming-Satellite
echo "  Testing Wyoming-Satellite package..."
if python3 -c "import wyoming_satellite; print('Wyoming-Satellite imported successfully')" 2>/dev/null; then
    echo "✅ Wyoming-Satellite verified"
    SATELLITE_OK=true
else
    echo "⚠️  Wyoming-Satellite verification failed"
    SATELLITE_OK=false
fi

# Test Billy's imports
echo "  Testing Billy Wyoming integration..."
if python3 -c "from billy_wyoming_config import create_billy_satellite_settings; print('Billy Wyoming config imported successfully')" 2>/dev/null; then
    echo "✅ Billy Wyoming integration verified"
    BILLY_OK=true
else
    echo "⚠️  Billy Wyoming integration verification failed"
    BILLY_OK=false
fi

echo ""
echo "🎉 Installation complete!"
echo ""

# Provide status summary
echo "📊 Installation Status:"
echo "   Wyoming: $([ "$WYOMING_OK" = true ] && echo "✅ OK" || echo "⚠️  Issues")"
echo "   Wyoming-Satellite: $([ "$SATELLITE_OK" = true ] && echo "✅ OK" || echo "⚠️  Issues")"
echo "   Billy Integration: $([ "$BILLY_OK" = true ] && echo "✅ OK" || echo "⚠️  Issues")"

if [ "$WYOMING_OK" = true ] && [ "$SATELLITE_OK" = true ] && [ "$BILLY_OK" = true ]; then
    echo ""
    echo "🎉 All components working! You can now:"
    echo "1. Run the test suite: python3 test_billy_wyoming.py"
    echo "2. Start Billy: ./start_billy_wyoming.sh"
else
    echo ""
    echo "⚠️  Some components have issues, but the core functionality may still work."
    echo ""
    echo "Troubleshooting steps:"
    echo "1. Check the detailed output above for specific errors"
    echo "2. Try running: python3 debug_wyoming.py"
    echo "3. If Wyoming packages failed, try: pip install wyoming==1.5.4"
    echo "4. If Billy integration failed, check that all files are present"
    echo ""
    echo "You can still try to run Billy: ./start_billy_wyoming.sh"
fi
