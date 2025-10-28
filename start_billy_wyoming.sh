#!/bin/bash

# Billy Bass Wyoming Integration Startup Script
# This script starts the Wyoming wake word service and Billy's integrated system

set -e

echo "🐟 Starting Billy Bass Wyoming Integration..."

# Check if we're in the right directory
if [ ! -f "billy_wyoming_main.py" ]; then
    echo "❌ Please run this script from the billy-b-assistant-git directory"
    exit 1
fi

# Check if Wyoming Satellite is available
if [ ! -d "wyoming-satellite" ]; then
    echo "❌ Wyoming Satellite directory not found. Please ensure it's in the current directory."
    exit 1
fi

# Check if wake word service is available
if ! command -v wyoming-openwakeword &> /dev/null; then
    echo "⚠️  Wyoming OpenWakeWord not found. Installing..."
    cd wyoming-satellite
    if [ -f "script/setup" ]; then
        ./script/setup
    else
        echo "❌ Wyoming setup script not found"
        exit 1
    fi
    cd ..
fi

# Start wake word service in background
echo "🎤 Starting wake word detection service..."
cd wyoming-satellite
if [ -f "script/run" ]; then
    ./script/run \
        --uri 'tcp://0.0.0.0:10400' \
        --preload-model 'ok_nabu' \
        --debug &
    WAKE_PID=$!
    echo "✅ Wake word service started (PID: $WAKE_PID)"
else
    echo "❌ Wyoming run script not found"
    exit 1
fi
cd ..

# Wait a moment for wake word service to start
sleep 3

# Start Billy's integrated system
echo "🐟 Starting Billy Bass Wyoming Integration..."
python3 billy_wyoming_main.py &
BILLY_PID=$!
echo "✅ Billy Bass started (PID: $BILLY_PID)"

# Function to cleanup on exit
cleanup() {
    echo "🛑 Shutting down..."
    kill $BILLY_PID 2>/dev/null || true
    kill $WAKE_PID 2>/dev/null || true
    wait $BILLY_PID 2>/dev/null || true
    wait $WAKE_PID 2>/dev/null || true
    echo "👋 Shutdown complete"
}

# Set up signal handlers
trap cleanup EXIT INT TERM

echo "🎉 Billy Bass Wyoming Integration is running!"
echo "Press Ctrl+C to stop"

# Wait for processes
wait $BILLY_PID
