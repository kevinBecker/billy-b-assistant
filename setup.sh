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
echo -e "${YELLOW}[1/5] Checking Python 3 installation...${NC}"
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
echo -e "${YELLOW}[2/5] Installing required system packages...${NC}"
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
sudo apt install -y \
    python3-pip \
    libportaudio2 \
    ffmpeg \
    swig \
    liblgpio-dev \
    python3-dev

echo -e "${GREEN}✓${NC} System packages installed"
echo ""

# Step 3: Create virtual environment
echo -e "${YELLOW}[3/5] Setting up Python virtual environment...${NC}"
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
echo -e "${YELLOW}[4/5] Verifying virtual environment...${NC}"
if [ ! -f "${VENV_PATH}/bin/python" ]; then
    echo -e "${RED}Error: Virtual environment Python not found${NC}"
    exit 1
fi

# Check which Python is being used
VENV_PYTHON=$(cd "$PROJECT_ROOT" && "$VENV_PATH/bin/python" --version)
echo -e "${GREEN}✓${NC} Virtual environment Python: ${VENV_PYTHON}"
echo ""

# Step 5: Install Python dependencies
echo -e "${YELLOW}[5/5] Installing Python dependencies...${NC}"
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

# Success message
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Next steps:"
echo "  1. Activate the virtual environment:"
echo "     source ${VENV_PATH}/bin/activate"
echo ""
echo "  2. Create a .env file with your configuration (see README.md)"
echo "     Example: OPENAI_API_KEY=sk-proj-..."
echo ""
echo "  3. Run Billy:"
echo "     python main.py"
echo ""
echo "  4. (Optional) Set up systemd services as described in README.md"
echo ""


