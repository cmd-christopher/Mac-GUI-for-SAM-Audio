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

# Prefer Python 3.12, fall back to python3
if command -v /opt/homebrew/bin/python3.12 &> /dev/null; then
    PYTHON="/opt/homebrew/bin/python3.12"
elif command -v python3.12 &> /dev/null; then
    PYTHON="python3.12"
elif command -v python3.11 &> /dev/null; then
    PYTHON="python3.11"
elif command -v python3.10 &> /dev/null; then
    PYTHON="python3.10"
else
    echo ""
    echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  ERROR: Python 3.10 or later is required but not found     ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}This application requires Python 3.10+ because mlx-audio${NC}"
    echo -e "${YELLOW}and other dependencies do not support older Python versions.${NC}"
    echo ""
    echo -e "${GREEN}To install Python 3.12, choose one of these options:${NC}"
    echo ""
    echo -e "  ${BLUE}Option 1: Homebrew (recommended)${NC}"
    echo "    brew install python@3.12"
    echo ""
    echo -e "  ${BLUE}Option 2: pyenv${NC}"
    echo "    brew install pyenv"
    echo "    pyenv install 3.12"
    echo "    pyenv local 3.12"
    echo ""
    echo -e "  ${BLUE}Option 3: mise (formerly rtx)${NC}"
    echo "    brew install mise"
    echo "    mise install python@3.12"
    echo "    mise use python@3.12"
    echo ""
    echo -e "After installing, run ${GREEN}./run.sh${NC} again."
    echo ""
    exit 1
fi

# Check Python version
PYTHON_VERSION=$($PYTHON -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
echo -e "${YELLOW}→${NC} Using Python: ${GREEN}$PYTHON${NC} (version ${GREEN}$PYTHON_VERSION${NC})"

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
    echo -e "${YELLOW}→${NC} Creating virtual environment with $PYTHON..."
    $PYTHON -m venv "$VENV_DIR"
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
