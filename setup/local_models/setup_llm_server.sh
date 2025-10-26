#!/bin/bash

# Setup script for running Ollama LLM server on a separate machine
# This script can be run on a more powerful server to host the LLM service

set -e

echo "🚀 Setting up Ollama LLM server for Billy B-Assistant..."

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "⚠️ This script should not be run as root. Please run as a regular user."
    exit 1
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

# Ask user which model to install
echo ""
echo "🤔 Which LLM model would you like to install?"
echo "1) Llama 3.1 8B (recommended, ~4.7GB)"
echo "2) Phi-3.5 Mini (faster, ~2.3GB)"
echo "3) Llama 3.1 70B (best quality, ~40GB)"
echo "4) Custom model (specify name)"
echo ""
read -p "Enter your choice (1-4): " MODEL_CHOICE

case $MODEL_CHOICE in
    1)
        MODEL_NAME="llama3.1:8b"
        echo "📥 Downloading Llama 3.1 8B..."
        ;;
    2)
        MODEL_NAME="phi3.5:mini"
        echo "📥 Downloading Phi-3.5 Mini..."
        ;;
    3)
        MODEL_NAME="llama3.1:70b"
        echo "📥 Downloading Llama 3.1 70B (this may take a while)..."
        ;;
    4)
        read -p "Enter the model name (e.g., llama3.1:8b): " MODEL_NAME
        echo "📥 Downloading $MODEL_NAME..."
        ;;
    *)
        echo "❌ Invalid choice. Defaulting to Llama 3.1 8B."
        MODEL_NAME="llama3.1:8b"
        echo "📥 Downloading Llama 3.1 8B..."
        ;;
esac

# Pull the selected model
ollama pull "$MODEL_NAME"

# Configure Ollama to accept external connections
echo "⚙️ Configuring Ollama for external access..."
sudo tee /etc/systemd/system/ollama-billy-server.service > /dev/null <<EOF
[Unit]
Description=Ollama LLM Server for Billy B-Assistant
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

# Stop the default service and start the new one
sudo systemctl stop ollama
sudo systemctl daemon-reload
sudo systemctl enable ollama-billy-server.service
sudo systemctl start ollama-billy-server.service

# Get the server's IP address
SERVER_IP=$(hostname -I | awk '{print $1}')

echo "✅ Ollama LLM server setup complete!"
echo ""
echo "🔧 Server Configuration:"
echo "   - Server IP: $SERVER_IP"
echo "   - Port: 11434"
echo "   - Model: $MODEL_NAME"
echo ""
echo "🔗 To use this server with Billy B-Assistant:"
echo "   1. Run the install script on your Raspberry Pi"
echo "   2. Choose option 2 (remote LLM server)"
echo "   3. Enter this IP address: $SERVER_IP"
echo "   4. Use port: 11434"
echo ""
echo "🧪 Test the server:"
echo "   - curl http://$SERVER_IP:11434/api/tags"
echo "   - curl http://localhost:11434/api/tags"
echo ""
echo "📊 Monitor the service:"
echo "   - sudo systemctl status ollama-billy-server"
echo "   - sudo journalctl -u ollama-billy-server -f"
echo ""
echo "🔒 Security Note:"
echo "   - This server is now accessible from any device on your network"
echo "   - Consider setting up a firewall if needed"
echo "   - The server will automatically start on boot"
