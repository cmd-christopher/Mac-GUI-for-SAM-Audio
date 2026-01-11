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
PYTHON_MIN_MAJOR=3
PYTHON_MIN_MINOR=10
LOCAL_PYTHON_DIR="$SCRIPT_DIR/.python"
LOCAL_PYTHON_BIN="$LOCAL_PYTHON_DIR/bin/python3"

python_version_ok() {
    local python="$1"
    local version
    version="$("$python" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")' 2>/dev/null || true)"
    if [ -z "$version" ]; then
        return 1
    fi
    local major="${version%%.*}"
    local minor="${version##*.}"
    if [ "$major" -gt "$PYTHON_MIN_MAJOR" ]; then
        return 0
    fi
    if [ "$major" -eq "$PYTHON_MIN_MAJOR" ] && [ "$minor" -ge "$PYTHON_MIN_MINOR" ]; then
        return 0
    fi
    return 1
}

find_python() {
    if [ -x "$LOCAL_PYTHON_BIN" ] && python_version_ok "$LOCAL_PYTHON_BIN"; then
        PYTHON="$LOCAL_PYTHON_BIN"
        return 0
    fi

    local candidate
    for candidate in /opt/homebrew/bin/python3.12 python3.12 python3.11 python3.10 python3; do
        if command -v "$candidate" &> /dev/null; then
            local resolved
            resolved="$(command -v "$candidate")"
            if python_version_ok "$resolved"; then
                PYTHON="$resolved"
                return 0
            fi
        elif [ -x "$candidate" ]; then
            if python_version_ok "$candidate"; then
                PYTHON="$candidate"
                return 0
            fi
        fi
    done
    return 1
}

bootstrap_python() {
    echo ""
    echo -e "${YELLOW}→${NC} No compatible Python found. Downloading a private runtime..."
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}curl is required to download Python automatically.${NC}"
        return 1
    fi

    local arch
    arch="$(uname -m)"
    local arch_tag
    case "$arch" in
        arm64) arch_tag="aarch64" ;;
        x86_64) arch_tag="x86_64" ;;
        *)
            echo -e "${RED}Unsupported architecture: $arch${NC}"
            return 1
            ;;
    esac

    local release_url
    release_url="https://api.github.com/repos/indygreg/python-build-standalone/releases/latest"
    local download_url
    download_url="$(curl -fsSL "$release_url" | grep -Eo "https://[^\"]+${arch_tag}-apple-darwin-install_only\\.tar\\.gz" | head -n 1)"

    if [ -z "$download_url" ]; then
        echo -e "${RED}Could not find a compatible Python download for macOS (${arch}).${NC}"
        return 1
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local archive="$tmp_dir/python.tar.gz"

    if ! curl -fL "$download_url" -o "$archive"; then
        echo -e "${RED}Failed to download Python runtime.${NC}"
        rm -rf "$tmp_dir"
        return 1
    fi

    rm -rf "$LOCAL_PYTHON_DIR"
    mkdir -p "$LOCAL_PYTHON_DIR"
    if ! tar -xzf "$archive" -C "$LOCAL_PYTHON_DIR" --strip-components=1; then
        echo -e "${RED}Failed to extract Python runtime.${NC}"
        rm -rf "$tmp_dir"
        return 1
    fi
    rm -rf "$tmp_dir"

    if [ ! -x "$LOCAL_PYTHON_BIN" ]; then
        echo -e "${RED}Bundled Python install did not produce $LOCAL_PYTHON_BIN.${NC}"
        return 1
    fi

    echo -e "${GREEN}✓${NC} Bundled Python installed to $LOCAL_PYTHON_DIR"
    return 0
}

if ! find_python; then
    if ! bootstrap_python; then
        echo ""
        echo -e "${RED}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║  ERROR: Python 3.10 or later is required but not found     ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}This application requires Python 3.10+ because mlx-audio${NC}"
        echo -e "${YELLOW}and other dependencies do not support older Python versions.${NC}"
        echo ""
        echo -e "${GREEN}To install Python 3.12 manually, choose one of these options:${NC}"
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
fi

if ! find_python; then
    echo -e "${RED}Failed to locate a usable Python after setup.${NC}"
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
echo -e "Open your browser to the URL printed by the app (starts at ${BLUE}http://localhost:5001${NC})"
echo -e "To force a specific port, run: ${GREEN}SAM_AUDIO_PORT=5005 ./run.sh${NC}"
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
