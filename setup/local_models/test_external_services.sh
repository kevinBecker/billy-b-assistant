#!/bin/bash

# Test External Services
# This script tests the external TTS and STT services

set -e

echo "🧪 Testing External TTS and STT Services"
echo "========================================"

# Test TTS service
echo "🎤 Testing TTS service..."
if curl -s -X POST http://localhost:5001/tts \
    -H 'Content-Type: application/json' \
    -d '{"text":"Hello, this is a test of the TTS service."}' \
    --output /tmp/test_tts.wav; then
    echo "✅ TTS service is working"
    echo "📁 Audio file saved to: /tmp/test_tts.wav"
    
    # Play the audio if sox is available
    if command -v play &> /dev/null; then
        echo "🔊 Playing test audio..."
        play /tmp/test_tts.wav
    else
        echo "💡 Install sox to play audio: sudo apt install sox"
    fi
else
    echo "❌ TTS service is not responding"
fi

echo ""

# Test STT service
echo "🎤 Testing STT service..."
if curl -s -X GET http://localhost:5002/health; then
    echo "✅ STT service is responding"
    echo "💡 To test STT, send an audio file:"
    echo "   curl -X POST http://localhost:5002/stt -F 'audio=@audio.wav'"
else
    echo "❌ STT service is not responding"
fi

echo ""

# Test health endpoints
echo "🏥 Testing health endpoints..."
echo "TTS Health:"
curl -s http://localhost:5001/health | python3 -m json.tool || echo "❌ TTS health check failed"

echo ""
echo "STT Health:"
curl -s http://localhost:5002/health | python3 -m json.tool || echo "❌ STT health check failed"

echo ""
echo "🧪 External services test complete!"
