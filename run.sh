#!/bin/bash
# SAM-Audio Isolation Utility - Startup Script
# Creates virtual environment, installs dependencies, and runs the application

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${NC}           ${GREEN}SAM-Audio Isolation Utility${NC}                       ${BLUE}║${NC}"
echo -e "${BLUE}║${NC}     Powered by Meta's SAM-Audio & Apple MLX              ${BLUE}║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

VENV_DIR="venv"
REQUIREMENTS_FILE="requirements.txt"

# Check if Python 3 is available
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is required but not installed.${NC}"
    echo "Please install Python 3.10+ using Homebrew: brew install python@3.10"
    exit 1
fi

# Check Python version
PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo -e "${YELLOW}→${NC} Detected Python version: ${GREEN}$PYTHON_VERSION${NC}"

# Check if we're on Apple Silicon
if [[ $(uname -m) == "arm64" ]]; then
    echo -e "${YELLOW}→${NC} Running on Apple Silicon: ${GREEN}✓${NC}"
else
    echo -e "${RED}Warning: This application is optimized for Apple Silicon (M1/M2/M3).${NC}"
    echo -e "${RED}Performance may be limited on Intel Macs.${NC}"
fi

# Create virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo ""
    echo -e "${YELLOW}→${NC} Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    echo -e "${GREEN}✓${NC} Virtual environment created"
fi

# Activate virtual environment
echo -e "${YELLOW}→${NC} Activating virtual environment..."
source "$VENV_DIR/bin/activate"
echo -e "${GREEN}✓${NC} Virtual environment activated"

# Upgrade pip
echo -e "${YELLOW}→${NC} Upgrading pip..."
pip install --upgrade pip --quiet

# Install dependencies if requirements have changed
REQUIREMENTS_HASH_FILE="$VENV_DIR/.requirements_hash"
CURRENT_HASH=$(md5 -q "$REQUIREMENTS_FILE" 2>/dev/null || md5sum "$REQUIREMENTS_FILE" | cut -d' ' -f1)

if [ -f "$REQUIREMENTS_HASH_FILE" ]; then
    STORED_HASH=$(cat "$REQUIREMENTS_HASH_FILE")
else
    STORED_HASH=""
fi

if [ "$CURRENT_HASH" != "$STORED_HASH" ] || [ ! -f "$VENV_DIR/lib/python*/site-packages/mlx_audio" ]; then
    echo ""
    echo -e "${YELLOW}→${NC} Installing dependencies (this may take a few minutes on first run)..."
    pip install -r "$REQUIREMENTS_FILE"
    echo "$CURRENT_HASH" > "$REQUIREMENTS_HASH_FILE"
    echo -e "${GREEN}✓${NC} Dependencies installed"
else
    echo -e "${GREEN}✓${NC} Dependencies already up to date"
fi

# Create output directory
mkdir -p output uploads

echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Starting SAM-Audio Isolation Utility...${NC}"
echo ""
echo -e "Open your browser to: ${BLUE}http://localhost:5001${NC}"
echo ""
echo -e "${YELLOW}Note:${NC} On first run, the model will be downloaded (~2GB)."
echo -e "This is a one-time process and may take a few minutes."
echo ""
echo -e "Press ${RED}Ctrl+C${NC} to stop the server."
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Run the application
python app.py
