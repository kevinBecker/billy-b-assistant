#!/bin/bash
# Billy B-Assistant Setup Script
# This script automates the Python environment setup as described in README.md
# It installs all required system dependencies and Python packages

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get current user and directory
CURRENT_USER=$(whoami)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Billy B-Assistant Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Setting up for user: ${CURRENT_USER}"
echo "Project directory: ${PROJECT_ROOT}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
   echo -e "${RED}Error: This script should not be run as root.${NC}"
   echo "Please run as a regular user. The script will use sudo for system package installation."
   exit 1
fi

# Step 1: Check Python 3
echo -e "${YELLOW}[1/7] Checking Python 3 installation...${NC}"
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed.${NC}"
    echo "Please install Python 3 first:"
    echo "  sudo apt update && sudo apt install -y python3"
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✓${NC} Found: ${PYTHON_VERSION}"
echo ""

# Step 2: Install system packages
echo -e "${YELLOW}[2/7] Installing required system packages...${NC}"
echo "This may require sudo privileges."

# Update package lists
sudo apt update

# Install all required system packages
# - python3-pip: Python package installer
# - libportaudio2: Audio I/O library for sounddevice
# - ffmpeg: Audio/video processing
# - swig: Required to build lgpio Python bindings
# - liblgpio-dev: Development headers for lgpio (required for building lgpio package)
# - python3-dev: Python development headers (may be needed for other packages)
# - avahi-daemon: mDNS service for .local hostname resolution
sudo apt install -y \
    python3-pip \
    libportaudio2 \
    ffmpeg \
    swig \
    liblgpio-dev \
    python3-dev \
    avahi-daemon

echo -e "${GREEN}✓${NC} System packages installed"
echo ""

# Configure hostname and Avahi (for .local resolution)
echo -e "${YELLOW}Configuring hostname...${NC}"
CURRENT_HOSTNAME=$(hostname)
DESIRED_HOSTNAME="billybass"

if [ "$CURRENT_HOSTNAME" != "$DESIRED_HOSTNAME" ]; then
    echo "Current hostname: ${CURRENT_HOSTNAME}"
    echo "Setting hostname to: ${DESIRED_HOSTNAME}"
    sudo hostnamectl set-hostname "$DESIRED_HOSTNAME"
    echo -e "${GREEN}✓${NC} Hostname set to ${DESIRED_HOSTNAME}"
else
    echo -e "${GREEN}✓${NC} Hostname already set to ${DESIRED_HOSTNAME}"
fi

# Ensure Avahi is running for .local resolution
echo "Ensuring Avahi daemon is running for .local hostname resolution..."
sudo systemctl enable avahi-daemon.service 2>/dev/null || true
sudo systemctl start avahi-daemon.service 2>/dev/null || true

if systemctl is-active --quiet avahi-daemon.service; then
    echo -e "${GREEN}✓${NC} Avahi daemon is running (billybass.local should be accessible)"
else
    echo -e "${YELLOW}⚠${NC}  Avahi daemon is not running. .local hostname may not work."
    echo "  You can start it manually with: sudo systemctl start avahi-daemon"
fi
echo ""

# Step 3: Create virtual environment
echo -e "${YELLOW}[3/7] Setting up Python virtual environment...${NC}"
VENV_PATH="${PROJECT_ROOT}/venv"

if [ -d "$VENV_PATH" ]; then
    echo "Virtual environment already exists at: ${VENV_PATH}"
    read -p "Do you want to recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Removing existing virtual environment..."
        rm -rf "$VENV_PATH"
        python3 -m venv "$VENV_PATH"
        echo -e "${GREEN}✓${NC} Virtual environment recreated"
    else
        echo -e "${GREEN}✓${NC} Using existing virtual environment"
    fi
else
    python3 -m venv "$VENV_PATH"
    echo -e "${GREEN}✓${NC} Virtual environment created at: ${VENV_PATH}"
fi
echo ""

# Step 4: Verify virtual environment
echo -e "${YELLOW}[4/7] Verifying virtual environment...${NC}"
if [ ! -f "${VENV_PATH}/bin/python" ]; then
    echo -e "${RED}Error: Virtual environment Python not found${NC}"
    exit 1
fi

# Check which Python is being used
VENV_PYTHON=$(cd "$PROJECT_ROOT" && "$VENV_PATH/bin/python" --version)
echo -e "${GREEN}✓${NC} Virtual environment Python: ${VENV_PYTHON}"
echo ""

# Step 5: Install Python dependencies
echo -e "${YELLOW}[5/7] Installing Python dependencies...${NC}"
REQUIREMENTS_FILE="${PROJECT_ROOT}/requirements.txt"

if [ ! -f "$REQUIREMENTS_FILE" ]; then
    echo -e "${RED}Error: requirements.txt not found at: ${REQUIREMENTS_FILE}${NC}"
    exit 1
fi

# Upgrade pip first
echo "Upgrading pip..."
cd "$PROJECT_ROOT"
"${VENV_PATH}/bin/pip" install --upgrade pip

# Install requirements
echo "Installing packages from requirements.txt..."
"${VENV_PATH}/bin/pip" install -r "$REQUIREMENTS_FILE"

echo -e "${GREEN}✓${NC} Python dependencies installed"
echo ""

# Verify lgpio installation (since it was a known issue)
echo -e "${YELLOW}Verifying critical dependencies...${NC}"
if "${VENV_PATH}/bin/python" -c "import lgpio" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} lgpio imported successfully"
else
    echo -e "${YELLOW}⚠${NC}  Warning: lgpio import test failed"
    echo "   This may cause issues with gpiozero. Try running the script again."
fi

if "${VENV_PATH}/bin/python" -c "import gpiozero" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} gpiozero imported successfully"
else
    echo -e "${RED}✗${NC} Error: gpiozero import failed"
    exit 1
fi
echo ""

# Step 6: Configure audio devices
echo -e "${YELLOW}[6/7] Configuring audio devices...${NC}"
echo "This step will help you configure microphone and speaker devices."
echo ""

# Install alsa-utils if not already installed
if ! command -v aplay &> /dev/null || ! command -v arecord &> /dev/null; then
    echo "Installing alsa-utils..."
    sudo apt install -y alsa-utils
fi

# List output devices
echo "Available output (speaker) devices:"
aplay -l 2>/dev/null || echo "No output devices found"
echo ""

# List input devices
echo "Available input (microphone) devices:"
arecord -l 2>/dev/null || echo "No input devices found"
echo ""

# Ask if user wants to configure audio
read -p "Do you want to configure audio devices now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Enter the speaker card number (from 'aplay -l' output):"
    read -p "Speaker card: " SPEAKER_CARD
    echo "Enter the speaker subdevice number (usually 0):"
    read -p "Speaker subdevice (default: 0): " SPEAKER_SUB
    SPEAKER_SUB=${SPEAKER_SUB:-0}
    
    echo "Enter the microphone card number (from 'arecord -l' output):"
    read -p "Microphone card: " MIC_CARD
    echo "Enter the microphone subdevice number (usually 0):"
    read -p "Microphone subdevice (default: 0): " MIC_SUB
    MIC_SUB=${MIC_SUB:-0}
    
    # Configure /usr/share/alsa/alsa.conf
    echo "Configuring default ALSA device..."
    # Update or add defaults.ctl.card
    if grep -q "^defaults.ctl.card" /usr/share/alsa/alsa.conf 2>/dev/null; then
        sudo sed -i "s/^defaults.ctl.card .*/defaults.ctl.card ${SPEAKER_CARD}/" /usr/share/alsa/alsa.conf
    else
        echo "defaults.ctl.card ${SPEAKER_CARD}" | sudo tee -a /usr/share/alsa/alsa.conf > /dev/null
    fi
    
    # Update or add defaults.pcm.card
    if grep -q "^defaults.pcm.card" /usr/share/alsa/alsa.conf 2>/dev/null; then
        sudo sed -i "s/^defaults.pcm.card .*/defaults.pcm.card ${SPEAKER_CARD}/" /usr/share/alsa/alsa.conf
    else
        echo "defaults.pcm.card ${SPEAKER_CARD}" | sudo tee -a /usr/share/alsa/alsa.conf > /dev/null
    fi
    
    # Create /etc/asound.conf
    echo "Creating /etc/asound.conf..."
    sudo tee /etc/asound.conf > /dev/null <<EOF
pcm.!default {
    type asym
    capture.pcm "mic"
    playback.pcm "speaker"
}

pcm.mic {
    type plug
    slave {
        pcm "plughw:${MIC_CARD},${MIC_SUB}"
    }
}

pcm.speaker {
    type plug
    slave {
        pcm "plughw:${SPEAKER_CARD},${SPEAKER_SUB}"
    }
}
EOF
    
    echo -e "${GREEN}✓${NC} Audio configuration saved"
    echo "You can test the configuration after reboot with:"
    echo "  aplay -D default /usr/share/sounds/alsa/Front_Center.wav"
    echo "  arecord -vvv -f dat /dev/null"
else
    echo -e "${YELLOW}⚠${NC}  Skipping audio configuration"
    echo "You can configure audio devices manually later (see README.md section D)"
fi
echo ""

# Step 7: Set up systemd services
echo -e "${YELLOW}[7/7] Setting up systemd services...${NC}"
echo ""

SERVICE_DIR="${PROJECT_ROOT}/setup/system"
SYSTEMD_DIR="/etc/systemd/system"

# Check if service files exist
if [ ! -f "${SERVICE_DIR}/billy.service" ]; then
    echo -e "${RED}Error: billy.service not found at: ${SERVICE_DIR}/billy.service${NC}"
    exit 1
fi

if [ ! -f "${SERVICE_DIR}/billy-webconfig.service" ]; then
    echo -e "${RED}Error: billy-webconfig.service not found at: ${SERVICE_DIR}/billy-webconfig.service${NC}"
    exit 1
fi

# Ask if user wants to set up services
read -p "Do you want to set up systemd services? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Create temporary service files with correct paths and user
    TMP_BILLY_SERVICE=$(mktemp)
    TMP_WEB_SERVICE=$(mktemp)
    
    # Update billy.service
    sed "s|User=pi|User=${CURRENT_USER}|g; s|/home/pi/billy-b-assistant|${PROJECT_ROOT}|g" \
        "${SERVICE_DIR}/billy.service" > "$TMP_BILLY_SERVICE"
    
    # Update billy-webconfig.service
    sed "s|User=pi|User=${CURRENT_USER}|g; s|/home/pi/billy-b-assistant|${PROJECT_ROOT}|g" \
        "${SERVICE_DIR}/billy-webconfig.service" > "$TMP_WEB_SERVICE"
    
    # Copy to systemd directory
    echo "Installing billy.service..."
    sudo cp "$TMP_BILLY_SERVICE" "${SYSTEMD_DIR}/billy.service"
    
    echo "Installing billy-webconfig.service..."
    sudo cp "$TMP_WEB_SERVICE" "${SYSTEMD_DIR}/billy-webconfig.service"
    
    # Clean up temp files
    rm "$TMP_BILLY_SERVICE" "$TMP_WEB_SERVICE"
    
    # Fix permissions: Ensure project directory is owned by service user
    echo "Setting proper file permissions..."
    echo "This ensures the service user can read/write configuration files."
    
    # Change ownership of entire project directory
    sudo chown -R "${CURRENT_USER}:${CURRENT_USER}" "$PROJECT_ROOT"
    
    # Ensure directories are writable (needed for creating files)
    find "$PROJECT_ROOT" -type d -exec chmod 755 {} \;
    
    # Ensure specific files that services need to write are accessible
    # Create .env if it doesn't exist (with proper permissions)
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        touch "${PROJECT_ROOT}/.env"
    fi
    chmod 644 "${PROJECT_ROOT}/.env"
    
    # Ensure persona.ini is writable
    if [ -f "${PROJECT_ROOT}/persona.ini" ]; then
        chmod 644 "${PROJECT_ROOT}/persona.ini"
    fi
    
    # Ensure versions.ini directory is writable (webconfig creates this file)
    touch "${PROJECT_ROOT}/versions.ini" 2>/dev/null || true
    chmod 644 "${PROJECT_ROOT}/versions.ini" 2>/dev/null || true
    
    # Ensure sounds directories exist and are writable (for wake-up custom sounds)
    if [ -d "${PROJECT_ROOT}/sounds" ]; then
        sudo chown -R "${CURRENT_USER}:${CURRENT_USER}" "${PROJECT_ROOT}/sounds"
        find "${PROJECT_ROOT}/sounds" -type d -exec chmod 755 {} \;
        find "${PROJECT_ROOT}/sounds" -type f -exec chmod 644 {} \;
    fi
    
    # Ensure venv is accessible
    if [ -d "${VENV_PATH}" ]; then
        sudo chown -R "${CURRENT_USER}:${CURRENT_USER}" "${VENV_PATH}"
        chmod -R u+rwX "${VENV_PATH}"
    fi
    
    echo -e "${GREEN}✓${NC} Permissions set"
    echo ""
    
    # Optional: Configure passwordless sudo for systemctl commands
    # The webconfig service needs to run systemctl commands
    read -p "Configure passwordless sudo for systemctl commands (required for webconfig)? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SUDOERS_FILE="/etc/sudoers.d/billy-assistant"
        echo "Configuring passwordless sudo for systemctl, journalctl, shutdown, hostnamectl, and avahi-daemon..."
        
        # Create sudoers file with specific commands
        sudo tee "$SUDOERS_FILE" > /dev/null <<EOF
# Billy B-Assistant: Allow ${CURRENT_USER} to run system management commands without password
${CURRENT_USER} ALL=(ALL) NOPASSWD: /usr/bin/systemctl start billy.service
${CURRENT_USER} ALL=(ALL) NOPASSWD: /usr/bin/systemctl stop billy.service
${CURRENT_USER} ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart billy.service
${CURRENT_USER} ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart billy-webconfig.service
${CURRENT_USER} ALL=(ALL) NOPASSWD: /usr/bin/journalctl -u billy.service *
${CURRENT_USER} ALL=(ALL) NOPASSWD: /usr/bin/journalctl -u billy-webconfig.service *
${CURRENT_USER} ALL=(ALL) NOPASSWD: /usr/sbin/shutdown
${CURRENT_USER} ALL=(ALL) NOPASSWD: /usr/bin/hostnamectl
${CURRENT_USER} ALL=(ALL) NOPASSWD: /usr/bin/systemctl restart avahi-daemon
EOF
        
        # Ensure proper permissions on sudoers file
        sudo chmod 0440 "$SUDOERS_FILE"
        
        # Validate sudoers file syntax
        if sudo visudo -c -f "$SUDOERS_FILE" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Sudoers configuration added and validated"
        else
            echo -e "${RED}✗${NC} Error: Sudoers file validation failed"
            echo "Removing invalid sudoers file..."
            sudo rm -f "$SUDOERS_FILE"
            echo "You can configure sudo access manually if needed."
        fi
    else
        echo -e "${YELLOW}⚠${NC}  Skipping sudo configuration"
        echo "The webconfig service may need passwordless sudo access to run systemctl commands."
        echo "You can configure this manually later if needed."
    fi
    echo ""
    
    # Reload systemd
    echo "Reloading systemd daemon..."
    sudo systemctl daemon-reload
    
    # Ask if user wants to enable services
    read -p "Do you want to enable billy.service to start on boot? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo systemctl enable billy.service
        echo -e "${GREEN}✓${NC} billy.service enabled"
    fi
    
    read -p "Do you want to enable billy-webconfig.service to start on boot? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Set capabilities for binding to port 80 (following README.md)
        # The service uses the venv Python, which may be a symlink
        # Resolve the actual binary path and set capabilities on it
        VENV_PYTHON="${PROJECT_ROOT}/venv/bin/python"
        if [ -f "$VENV_PYTHON" ] || [ -L "$VENV_PYTHON" ]; then
            echo "Setting network binding capabilities for port 80..."
            # Resolve symlink to actual binary
            ACTUAL_PYTHON=$(readlink -f "$VENV_PYTHON")
            sudo setcap 'cap_net_bind_service=+ep' "$ACTUAL_PYTHON"
            echo -e "${GREEN}✓${NC} Capabilities set on ${ACTUAL_PYTHON}"
        else
            echo -e "${YELLOW}⚠${NC}  Venv Python not found"
        fi
        
        sudo systemctl enable billy-webconfig.service
        echo -e "${GREEN}✓${NC} billy-webconfig.service enabled"
    fi
    
    # Ask if user wants to start services now
    read -p "Do you want to start the services now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if sudo systemctl is-enabled billy.service &>/dev/null; then
            sudo systemctl start billy.service
            echo -e "${GREEN}✓${NC} billy.service started"
        fi
        if sudo systemctl is-enabled billy-webconfig.service &>/dev/null; then
            sudo systemctl start billy-webconfig.service
            echo -e "${GREEN}✓${NC} billy-webconfig.service started"
        fi
    fi
    
    echo -e "${GREEN}✓${NC} Systemd services configured"
    echo ""
    echo "Service management commands:"
    echo "  sudo systemctl status billy.service"
    echo "  sudo systemctl status billy-webconfig.service"
    echo "  journalctl -u billy.service -f"
    echo "  journalctl -u billy-webconfig.service -f"
    echo ""
    echo "Access the web UI at: http://billybass.local"
else
    echo -e "${YELLOW}⚠${NC}  Skipping systemd service setup"
    echo "You can set up services manually later (see README.md section H)"
fi
echo ""

# Success message
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Create a .env file with your configuration (see README.md)"
echo "     Example: OPENAI_API_KEY=sk-proj-..."
echo ""
echo "  2. If you configured audio devices, reboot to apply changes:"
echo "     sudo reboot"
echo ""
echo "  3. After reboot (if needed), test audio configuration:"
echo "     aplay -D default /usr/share/sounds/alsa/Front_Center.wav"
echo "     arecord -vvv -f dat /dev/null"
echo ""
echo "  4. If services were enabled, Billy should start automatically on boot."
echo "     Otherwise, activate the virtual environment and run manually:"
echo "     source ${VENV_PATH}/bin/activate"
echo "     python main.py"
echo ""



