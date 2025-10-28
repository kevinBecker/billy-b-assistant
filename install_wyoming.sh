#!/bin/bash

# Wyoming-Satellite Installation Script for Billy Bass
# This script properly installs Wyoming-Satellite and its dependencies

set -e

echo "🐟 Installing Wyoming-Satellite for Billy Bass..."

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

# Check if pyproject.toml exists
if [ ! -f "wyoming-satellite/pyproject.toml" ]; then
    echo "❌ pyproject.toml not found in wyoming-satellite directory!"
    exit 1
fi

echo "📦 Installing Python dependencies..."

# Install Billy's requirements first
echo "  Installing Billy's requirements..."
pip install -r requirements_wyoming.txt

# Install Wyoming-Satellite
echo "  Installing Wyoming-Satellite..."
cd wyoming-satellite

# Check if we can install in development mode
if pip install -e . 2>/dev/null; then
    echo "✅ Wyoming-Satellite installed in development mode"
else
    echo "⚠️  Development mode failed, trying regular install..."
    pip install .
fi

cd ..

# Install Wyoming OpenWakeWord if available
echo "🎤 Setting up wake word detection..."

if [ -f "wyoming-satellite/script/setup" ]; then
    echo "  Running Wyoming setup script..."
    cd wyoming-satellite
    chmod +x script/setup
    ./script/setup
    cd ..
    echo "✅ Wyoming setup completed"
else
    echo "⚠️  Wyoming setup script not found, you may need to install wake word models manually"
fi

# Test the installation
echo "🧪 Testing installation..."
if python3 -c "import wyoming_satellite; print('Wyoming-Satellite imported successfully')" 2>/dev/null; then
    echo "✅ Wyoming-Satellite installation verified"
else
    echo "❌ Wyoming-Satellite installation failed"
    exit 1
fi

# Test Billy's imports
if python3 -c "from billy_wyoming_config import create_billy_satellite_settings; print('Billy Wyoming config imported successfully')" 2>/dev/null; then
    echo "✅ Billy Wyoming integration verified"
else
    echo "❌ Billy Wyoming integration failed"
    exit 1
fi

echo ""
echo "🎉 Installation complete!"
echo ""
echo "Next steps:"
echo "1. Configure your audio devices in .env file"
echo "2. Run the test suite: python3 test_billy_wyoming.py"
echo "3. Start Billy: ./start_billy_wyoming.sh"
echo ""
echo "For Home Assistant integration:"
echo "- Add Wyoming integration in Home Assistant"
echo "- Enter Billy's IP address and port 10700"
