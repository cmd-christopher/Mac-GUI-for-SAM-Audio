# SAM-Audio Isolation Utility

A local audio isolation utility powered by Meta's SAM-Audio model, optimized for Apple Silicon via MLX.

![SAM-Audio Interface](https://img.shields.io/badge/Platform-Apple%20Silicon-blue) ![Python](https://img.shields.io/badge/Python-3.10%2B-green) ![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

- 🎵 **Text-prompted audio isolation** - Describe what you want to extract (speech, vocals, drums, piano, etc.)
- 🖥️ **Modern web interface** - Dark theme with drag-and-drop upload
- 🍎 **Apple Silicon optimized** - Uses MLX for fast inference on M1/M2/M3 Macs
- 📦 **Easy setup** - Single script handles everything

## Requirements

- **Hardware**: Apple Silicon Mac (M1, M2, or M3)
- **RAM**: 16GB minimum (64GB recommended for best performance)
- **macOS**: 14.0 or later
- **Python**: 3.10 or later

## Quick Start

```bash
# Clone the repository
git clone <your-repo-url>
cd SAM-Audio

# Run the application (creates venv, installs deps, downloads model)
./run.sh
```

Then open **http://localhost:5001** in your browser.

> **Note**: On first run, the model (~4.8GB) will be downloaded automatically. This is a one-time process.

## Usage

1. **Upload** an audio file (MP3, WAV, FLAC, M4A, OGG, AAC)
2. **Describe** the sound to isolate (e.g., "speech", "piano", "drums")
3. **Click** "Isolate Audio"
4. **Listen** to the isolated audio and residual
5. **Download** the results as WAV files

### Example Prompts

| Prompt | Isolates |
|--------|----------|
| `speech` | Human voices |
| `vocals` | Singing in music |
| `drums` | Percussion |
| `piano` | Piano instrument |
| `guitar` | Guitar sounds |
| `music` | All musical elements |

## Project Structure

```
SAM-Audio/
├── app.py                 # Flask web application
├── audio_processor.py     # SAM-Audio model wrapper
├── requirements.txt       # Python dependencies
├── run.sh                 # Startup script
├── templates/
│   └── index.html         # Web interface
└── static/
    ├── css/style.css      # Styling
    └── js/app.js          # Frontend logic
```

## Technical Details

- **Model**: [mlx-community/sam-audio-large-fp16](https://huggingface.co/mlx-community/sam-audio-large-fp16)
- **Framework**: MLX (Apple's machine learning framework)
- **Backend**: Flask
- **Sample Rate**: 24kHz
- **Output Format**: WAV

## Troubleshooting

### Port 5001 in use
Edit `app.py` and change the port number on the last line.

### Model download fails
Ensure you have a stable internet connection. The model (~4.8GB) is downloaded from Hugging Face.

### Out of memory
Enable "Long audio mode" checkbox for files over 30 seconds - this uses chunked processing.

## Credits

- [SAM-Audio](https://ai.meta.com/blog/sam-audio/) by Meta AI
- [MLX](https://ml-explore.github.io/mlx/) by Apple
- [mlx-audio](https://github.com/lucasnewman/mlx-audio) by Lucas Newman

## License

MIT License - See LICENSE file for details.
