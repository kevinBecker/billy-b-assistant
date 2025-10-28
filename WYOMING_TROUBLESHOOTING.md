# Wyoming Integration Troubleshooting Guide

This guide helps resolve common issues when installing and running Billy Bass with Wyoming integration.

## Common Installation Issues

### 1. Dependency Conflicts

**Error**: `wyoming-satellite 1.0.0 depends on wyoming==1.4.1` but `wyoming-openwakeword 1.8.2 depends on wyoming==1.2.0`

**Solution**: Use one of these approaches:

#### Option A: Minimal Installation (Recommended)
```bash
./install_wyoming_minimal.sh
```

#### Option B: Local Directory Installation
```bash
./install_wyoming_local.sh
```

#### Option C: Manual Installation
```bash
# Install core packages individually
pip install wyoming==1.5.4
pip install wyoming-satellite==1.4.1
pip install zeroconf pyring-buffer

# Install Billy's dependencies
pip install sounddevice websockets numpy scipy gpiozero python-dotenv pydub paho-mqtt requests openai aiohttp flask adafruit-circuitpython-motorkit adafruit-circuitpython-busdevice packaging
```

### 2. Python Environment Issues

**Error**: `No matching distributions available for your environment`

**Solutions**:
```bash
# Update pip
pip install --upgrade pip

# Update setuptools
pip install --upgrade setuptools

# Check Python version (requires 3.9+)
python3 --version

# Create virtual environment
python3 -m venv billy_env
source billy_env/bin/activate
pip install --upgrade pip
```

### 3. Missing Wyoming Package

**Error**: `ModuleNotFoundError: No module named 'wyoming'`

**Solutions**:
```bash
# Install Wyoming core package
pip install wyoming

# Or install specific version
pip install wyoming==1.5.4

# Check if installed
python3 -c "import wyoming; print(wyoming.__version__)"
```

### 4. Local Directory Installation Issues

**Error**: `file:///path/to/wyoming-satellite does not appear to be a Python project`

**Solutions**:
```bash
# Check if you're in the right directory
pwd
ls -la wyoming-satellite/

# Check if pyproject.toml exists
ls -la wyoming-satellite/pyproject.toml

# Try absolute path
pip install -e /absolute/path/to/wyoming-satellite

# Or use the local installation script
./install_wyoming_local.sh
```

## Runtime Issues

### 1. Audio Device Issues

**Error**: `No suitable input/output devices found`

**Solutions**:
```bash
# List audio devices
arecord -L
aplay -L

# Test microphone
arecord -f S16_LE -r 16000 -c 1 -t raw | aplay -f S16_LE -r 16000 -c 1 -t raw

# Update .env file with correct devices
echo "MIC_PREFERENCE=plughw:1,0" >> .env
echo "SPEAKER_PREFERENCE=plughw:1,0" >> .env
```

### 2. Wake Word Service Issues

**Error**: `Failed to connect to wake word service`

**Solutions**:
```bash
# Start wake word service manually
cd wyoming-satellite
./script/run --uri 'tcp://0.0.0.0:10400' --preload-model 'ok_nabu' --debug

# Check if service is running
netstat -tlnp | grep 10400

# Install wake word models
pip install wyoming-openwakeword
```

### 3. Import Errors

**Error**: `ModuleNotFoundError: No module named 'wyoming_satellite'`

**Solutions**:
```bash
# Check if installed
pip list | grep wyoming

# Reinstall
pip uninstall wyoming-satellite
pip install wyoming-satellite

# Or use local installation
./install_wyoming_local.sh
```

### 4. Permission Issues

**Error**: `Permission denied` or `Access denied`

**Solutions**:
```bash
# Run with proper permissions
sudo chmod +x *.sh
sudo chown -R pi:pi /path/to/billy-b-assistant-git

# Check file permissions
ls -la *.sh
ls -la wyoming-satellite/
```

## Testing and Verification

### 1. Run Test Suite
```bash
python3 test_billy_wyoming.py
```

### 2. Test Individual Components
```bash
# Test Wyoming imports
python3 -c "import wyoming; print('Wyoming OK')"
python3 -c "import wyoming_satellite; print('Wyoming-Satellite OK')"

# Test Billy imports
python3 -c "from core.movements import move_head; print('Billy movements OK')"
python3 -c "from billy_wyoming_config import create_billy_satellite_settings; print('Billy config OK')"
```

### 3. Test Audio
```bash
# Test microphone
arecord -f S16_LE -r 16000 -c 1 -t raw test.wav
aplay test.wav

# Test with specific device
arecord -D plughw:1,0 -f S16_LE -r 16000 -c 1 -t raw test.wav
aplay -D plughw:1,0 test.wav
```

## Alternative Installation Methods

### 1. Using Conda
```bash
# Create conda environment
conda create -n billy python=3.11
conda activate billy

# Install packages
conda install numpy scipy
pip install wyoming wyoming-satellite
```

### 2. Using Docker
```bash
# Create Dockerfile
cat > Dockerfile << EOF
FROM python:3.11-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements_wyoming_fixed.txt
CMD ["python3", "billy_wyoming_main.py"]
EOF

# Build and run
docker build -t billy-wyoming .
docker run -it --device /dev/snd billy-wyoming
```

### 3. Manual Package Installation
```bash
# Download and install packages manually
wget https://pypi.org/simple/wyoming/
pip install wyoming-1.5.4-py3-none-any.whl
```

## Getting Help

### 1. Check Logs
```bash
# Enable debug mode
export DEBUG_MODE=true
python3 billy_wyoming_main.py

# Check system logs
journalctl -u billy-wyoming.service
```

### 2. Common Solutions Summary

| Issue | Solution |
|-------|----------|
| Dependency conflicts | Use `./install_wyoming_minimal.sh` |
| Missing Wyoming package | `pip install wyoming` |
| Local install fails | Use `./install_wyoming_local.sh` |
| Audio issues | Check devices with `arecord -L` |
| Import errors | Reinstall with `pip install --force-reinstall` |
| Permission issues | Check file permissions and ownership |

### 3. Fallback Options

If all else fails, you can:

1. **Use the original Billy system** without Wyoming integration
2. **Install only essential packages** and skip optional features
3. **Use a different Python environment** (conda, venv, etc.)
4. **Install packages one by one** to identify the problematic package

## Success Indicators

You'll know the installation is working when:

- ✅ `python3 test_billy_wyoming.py` passes all tests
- ✅ `import wyoming_satellite` works without errors
- ✅ Audio devices are detected and working
- ✅ Billy's motors respond to test commands
- ✅ Wyoming services start without errors

Remember: The goal is to get Billy working with voice processing. If Wyoming integration is too complex, you can always fall back to the original Billy system!
