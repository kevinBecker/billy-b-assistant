#!/bin/bash

# Install Ollama for local LLM inference
# This script sets up Ollama on the Raspberry Pi

set -e

echo "🚀 Installing Ollama for local LLM inference..."

# Check if running on Raspberry Pi
if ! grep -q "Raspberry Pi" /proc/cpuinfo; then
    echo "⚠️ This script is designed for Raspberry Pi. Proceeding anyway..."
fi

# Install Ollama
echo "📦 Installing Ollama..."
curl -fsSL https://ollama.ai/install.sh | sh

# Start Ollama service
echo "🔄 Starting Ollama service..."
sudo systemctl enable ollama
sudo systemctl start ollama

# Wait for service to start
echo "⏳ Waiting for Ollama service to start..."
sleep 10

# Pull recommended model
echo "📥 Downloading recommended model (llama3.1:8b)..."
ollama pull llama3.1:8b

# Create systemd service for auto-start
echo "⚙️ Creating systemd service..."
sudo tee /etc/systemd/system/ollama-billy.service > /dev/null <<EOF
[Unit]
Description=Ollama for Billy B-Assistant
After=network.target

[Service]
Type=simple
User=ollama
Group=ollama
ExecStart=/usr/local/bin/ollama serve
Restart=always
RestartSec=3
Environment="OLLAMA_HOST=0.0.0.0:11434"

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
sudo systemctl daemon-reload
sudo systemctl enable ollama-billy.service

echo "✅ Ollama installation complete!"
echo "🔧 Configure Billy to use local models by setting USE_LOCAL_MODELS=true in your .env file"
echo "📊 Check status with: sudo systemctl status ollama-billy"
echo "🧪 Test with: ollama list"
