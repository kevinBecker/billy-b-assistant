#!/bin/bash

# Simple Wyoming-Satellite Installation Script
# This script installs Wyoming-Satellite without development mode

set -e

echo "🐟 Installing Wyoming-Satellite (Simple Method)..."

# Check if we're in the right directory
if [ ! -f "billy_wyoming_main.py" ]; then
    echo "❌ Please run this script from the billy-b-assistant-git directory"
    exit 1
fi

echo "📦 Installing dependencies..."

# Install Billy's requirements
pip install -r requirements_wyoming.txt

# Install Wyoming-Satellite from PyPI instead of local directory
echo "  Installing Wyoming-Satellite from PyPI..."
pip install wyoming-satellite

# Install Wyoming OpenWakeWord
echo "  Installing Wyoming OpenWakeWord..."
pip install wyoming-openwakeword

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
echo "Note: This installs Wyoming-Satellite from PyPI instead of the local directory."
echo "If you need the local version, use install_wyoming.sh instead."
echo ""
echo "Next steps:"
echo "1. Configure your audio devices in .env file"
echo "2. Run the test suite: python3 test_billy_wyoming.py"
echo "3. Start Billy: ./start_billy_wyoming.sh"
