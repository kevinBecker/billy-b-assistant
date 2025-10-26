#!/bin/bash

# Configuration script for LLM deployment options
# Allows easy switching between local and remote LLM configurations

set -e

echo "🔧 Billy B-Assistant LLM Configuration Tool"
echo ""

# Check if .env file exists
ENV_FILE="../.env"
if [ ! -f "$ENV_FILE" ]; then
    echo "❌ .env file not found. Please run this script from the setup/local_models directory."
    exit 1
fi

# Function to update .env file
update_env() {
    local key=$1
    local value=$2
    
    if grep -q "^$key=" "$ENV_FILE"; then
        # Update existing value
        sed -i "s/^$key=.*/$key=$value/" "$ENV_FILE"
    else
        # Add new value
        echo "$key=$value" >> "$ENV_FILE"
    fi
}

# Function to get current value from .env
get_env() {
    local key=$1
    grep "^$key=" "$ENV_FILE" 2>/dev/null | cut -d'=' -f2- || echo ""
}

echo "🤔 How would you like to configure the LLM service?"
echo "1) Use local LLM (Ollama on this Raspberry Pi)"
echo "2) Use remote LLM server"
echo "3) Use OpenAI (cloud service)"
echo "4) Show current configuration"
echo "5) Test current configuration"
echo ""
read -p "Enter your choice (1-5): " CONFIG_CHOICE

case $CONFIG_CHOICE in
    1)
        echo "🏠 Configuring for local LLM..."
        
        # Check if Ollama is installed
        if ! command -v ollama &> /dev/null; then
            echo "❌ Ollama is not installed. Please run install_ollama.sh first."
            exit 1
        fi
        
        # Check if Ollama service is running
        if ! systemctl is-active --quiet ollama-billy; then
            echo "⚠️ Ollama service is not running. Starting it..."
            sudo systemctl start ollama-billy
        fi
        
        update_env "USE_LOCAL_MODELS" "true"
        update_env "LOCAL_LLM_HOST" "localhost"
        update_env "LOCAL_LLM_PORT" "11434"
        
        echo "✅ Configured for local LLM"
        echo "🔧 Settings:"
        echo "   - Host: localhost"
        echo "   - Port: 11434"
        ;;
        
    2)
        echo "🔗 Configuring for remote LLM server..."
        
        read -p "Enter the IP address or hostname of your LLM server: " REMOTE_HOST
        read -p "Enter the port (default 11434): " REMOTE_PORT
        REMOTE_PORT=${REMOTE_PORT:-11434}
        
        # Test connection
        echo "🧪 Testing connection to $REMOTE_HOST:$REMOTE_PORT..."
        if curl -s --connect-timeout 5 "http://$REMOTE_HOST:$REMOTE_PORT/api/tags" > /dev/null; then
            echo "✅ Connection successful!"
        else
            echo "⚠️ Could not connect to $REMOTE_HOST:$REMOTE_PORT"
            echo "   Make sure the LLM server is running and accessible"
            read -p "Continue anyway? (y/N): " CONTINUE
            if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
        
        update_env "USE_LOCAL_MODELS" "true"
        update_env "LOCAL_LLM_HOST" "$REMOTE_HOST"
        update_env "LOCAL_LLM_PORT" "$REMOTE_PORT"
        
        echo "✅ Configured for remote LLM server"
        echo "🔧 Settings:"
        echo "   - Host: $REMOTE_HOST"
        echo "   - Port: $REMOTE_PORT"
        ;;
        
    3)
        echo "☁️ Configuring for OpenAI..."
        
        read -p "Enter your OpenAI API key: " OPENAI_KEY
        if [ -z "$OPENAI_KEY" ]; then
            echo "❌ OpenAI API key is required"
            exit 1
        fi
        
        update_env "USE_LOCAL_MODELS" "false"
        update_env "OPENAI_API_KEY" "$OPENAI_KEY"
        
        echo "✅ Configured for OpenAI"
        echo "🔧 Settings:"
        echo "   - Service: OpenAI"
        echo "   - API Key: ${OPENAI_KEY:0:8}..."
        ;;
        
    4)
        echo "📋 Current Configuration:"
        echo ""
        
        USE_LOCAL=$(get_env "USE_LOCAL_MODELS")
        LLM_HOST=$(get_env "LOCAL_LLM_HOST")
        LLM_PORT=$(get_env "LOCAL_LLM_PORT")
        OPENAI_KEY=$(get_env "OPENAI_API_KEY")
        
        if [ "$USE_LOCAL" = "true" ]; then
            echo "🏠 Mode: Local Models"
            echo "   - LLM Host: $LLM_HOST"
            echo "   - LLM Port: $LLM_PORT"
        else
            echo "☁️ Mode: OpenAI"
            if [ -n "$OPENAI_KEY" ]; then
                echo "   - API Key: ${OPENAI_KEY:0:8}..."
            else
                echo "   - API Key: Not set"
            fi
        fi
        
        TTS_HOST=$(get_env "LOCAL_TTS_HOST")
        TTS_PORT=$(get_env "LOCAL_TTS_PORT")
        STT_HOST=$(get_env "LOCAL_STT_HOST")
        STT_PORT=$(get_env "LOCAL_STT_PORT")
        
        echo "   - TTS Host: $TTS_HOST:$TTS_PORT"
        echo "   - STT Host: $STT_HOST:$STT_PORT"
        ;;
        
    5)
        echo "🧪 Testing current configuration..."
        
        USE_LOCAL=$(get_env "USE_LOCAL_MODELS")
        LLM_HOST=$(get_env "LOCAL_LLM_HOST")
        LLM_PORT=$(get_env "LOCAL_LLM_PORT")
        
        if [ "$USE_LOCAL" = "true" ]; then
            echo "Testing local LLM at $LLM_HOST:$LLM_PORT..."
            if curl -s --connect-timeout 5 "http://$LLM_HOST:$LLM_PORT/api/tags" > /dev/null; then
                echo "✅ LLM service is responding"
            else
                echo "❌ LLM service is not responding"
            fi
        else
            echo "Testing OpenAI configuration..."
            OPENAI_KEY=$(get_env "OPENAI_API_KEY")
            if [ -n "$OPENAI_KEY" ]; then
                echo "✅ OpenAI API key is configured"
            else
                echo "❌ OpenAI API key is not set"
            fi
        fi
        
        # Test TTS
        TTS_HOST=$(get_env "LOCAL_TTS_HOST")
        TTS_PORT=$(get_env "LOCAL_TTS_PORT")
        echo "Testing TTS at $TTS_HOST:$TTS_PORT..."
        if curl -s --connect-timeout 5 "http://$TTS_HOST:$TTS_PORT/api/health" > /dev/null; then
            echo "✅ TTS service is responding"
        else
            echo "❌ TTS service is not responding"
        fi
        
        # Test STT
        STT_HOST=$(get_env "LOCAL_STT_HOST")
        STT_PORT=$(get_env "LOCAL_STT_PORT")
        echo "Testing STT at $STT_HOST:$STT_PORT..."
        if curl -s --connect-timeout 5 "http://$STT_HOST:$STT_PORT/api/health" > /dev/null; then
            echo "✅ STT service is responding"
        else
            echo "❌ STT service is not responding"
        fi
        ;;
        
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "🔄 To apply changes, restart Billy B-Assistant:"
echo "   sudo systemctl restart billy"
