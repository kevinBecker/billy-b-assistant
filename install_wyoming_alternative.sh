#!/bin/bash

# Alternative Wyoming-Satellite Installation Script
# This script handles various installation scenarios

set -e

echo "🐟 Installing Wyoming-Satellite (Alternative Method)..."

# Check if we're in the right directory
if [ ! -f "billy_wyoming_main.py" ]; then
    echo "❌ Please run this script from the billy-b-assistant-git directory"
    exit 1
fi

# Get absolute path to current directory
CURRENT_DIR=$(pwd)
WYOMING_DIR="$CURRENT_DIR/wyoming-satellite"

echo "📁 Current directory: $CURRENT_DIR"
echo "📁 Wyoming directory: $WYOMING_DIR"

# Check if Wyoming-Satellite directory exists
if [ ! -d "$WYOMING_DIR" ]; then
    echo "❌ Wyoming-Satellite directory not found at $WYOMING_DIR"
    exit 1
fi

# Check if pyproject.toml exists
if [ ! -f "$WYOMING_DIR/pyproject.toml" ]; then
    echo "❌ pyproject.toml not found in $WYOMING_DIR"
    exit 1
fi

echo "📦 Installing Python dependencies..."

# Install Billy's requirements first
echo "  Installing Billy's requirements..."
pip install -r requirements_wyoming.txt

# Try different installation methods
echo "🎯 Attempting Wyoming-Satellite installation..."

# Method 1: Try pip install with absolute path
echo "  Method 1: Installing from absolute path..."
if pip install "$WYOMING_DIR" 2>/dev/null; then
    echo "✅ Wyoming-Satellite installed from absolute path"
    INSTALLED=true
else
    echo "⚠️  Method 1 failed, trying method 2..."
    INSTALLED=false
fi

# Method 2: Try pip install -e with absolute path
if [ "$INSTALLED" = false ]; then
    echo "  Method 2: Installing in development mode from absolute path..."
    if pip install -e "$WYOMING_DIR" 2>/dev/null; then
        echo "✅ Wyoming-Satellite installed in development mode from absolute path"
        INSTALLED=true
    else
        echo "⚠️  Method 2 failed, trying method 3..."
    fi
fi

# Method 3: Try from PyPI
if [ "$INSTALLED" = false ]; then
    echo "  Method 3: Installing from PyPI..."
    if pip install wyoming-satellite 2>/dev/null; then
        echo "✅ Wyoming-Satellite installed from PyPI"
        INSTALLED=true
    else
        echo "⚠️  Method 3 failed, trying method 4..."
    fi
fi

# Method 4: Manual installation
if [ "$INSTALLED" = false ]; then
    echo "  Method 4: Manual installation..."
    cd "$WYOMING_DIR"
    if python3 setup.py install 2>/dev/null; then
        echo "✅ Wyoming-Satellite installed manually"
        INSTALLED=true
    else
        echo "❌ All installation methods failed"
        echo ""
        echo "Troubleshooting:"
        echo "1. Check if you have the latest pip: pip install --upgrade pip"
        echo "2. Check if you have setuptools: pip install setuptools"
        echo "3. Try installing from PyPI: pip install wyoming-satellite"
        echo "4. Check the Wyoming-Satellite directory structure"
        exit 1
    fi
    cd "$CURRENT_DIR"
fi

# Install Wyoming OpenWakeWord
echo "🎤 Installing Wyoming OpenWakeWord..."
if pip install wyoming-openwakeword 2>/dev/null; then
    echo "✅ Wyoming OpenWakeWord installed"
else
    echo "⚠️  Wyoming OpenWakeWord installation failed, but continuing..."
fi

# Test the installation
echo "🧪 Testing installation..."
if python3 -c "import wyoming_satellite; print('Wyoming-Satellite imported successfully')" 2>/dev/null; then
    echo "✅ Wyoming-Satellite installation verified"
else
    echo "❌ Wyoming-Satellite installation verification failed"
    echo "   Try running: python3 -c 'import wyoming_satellite'"
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
echo "Next steps:"
echo "1. Configure your audio devices in .env file"
echo "2. Run the test suite: python3 test_billy_wyoming.py"
echo "3. Start Billy: ./start_billy_wyoming.sh"
