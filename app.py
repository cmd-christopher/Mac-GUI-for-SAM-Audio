"""
SAM-Audio Isolation Utility - Flask Application
A web interface for isolating audio using Meta's SAM-Audio model.
"""

import os
import uuid
from pathlib import Path
import socket
from flask import Flask, render_template, request, jsonify, send_file
from werkzeug.utils import secure_filename

from audio_processor import get_processor

# Configuration
UPLOAD_FOLDER = Path("uploads")
OUTPUT_FOLDER = Path("output")
ALLOWED_EXTENSIONS = {"mp3", "wav", "flac", "m4a", "ogg", "aac"}
DEFAULT_PORT = 5001
PORT_ENV_VAR = "SAM_AUDIO_PORT"

# Create directories
UPLOAD_FOLDER.mkdir(parents=True, exist_ok=True)
OUTPUT_FOLDER.mkdir(parents=True, exist_ok=True)

# Initialize Flask app
app = Flask(__name__)
app.config["UPLOAD_FOLDER"] = UPLOAD_FOLDER
app.config["MAX_CONTENT_LENGTH"] = 500 * 1024 * 1024  # 500MB max file size

# Initialize audio processor
processor = get_processor(str(OUTPUT_FOLDER))


def allowed_file(filename: str) -> bool:
    """Check if file has an allowed extension."""
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


def find_available_port(start_port: int, host: str = "0.0.0.0") -> int:
    """Find the first available port starting from start_port."""
    for port in range(start_port, 65536):
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as sock:
            try:
                sock.bind((host, port))
            except OSError:
                continue
            return port
    raise RuntimeError(f"No available ports found starting from {start_port}")


def get_server_port(start_port: int, host: str = "0.0.0.0") -> int:
    """Resolve the server port once and reuse across the Flask reloader."""
    env_port = os.environ.get(PORT_ENV_VAR)
    if env_port:
        try:
            return int(env_port)
        except ValueError:
            pass
    port = find_available_port(start_port, host=host)
    os.environ[PORT_ENV_VAR] = str(port)
    return port


def is_reloader_process() -> bool:
    """Return True when running inside the Werkzeug reloader child."""
    return os.environ.get("WERKZEUG_RUN_MAIN") == "true"


@app.route("/")
def index():
    """Serve the main page."""
    return render_template("index.html")


@app.route("/api/status")
def status():
    """Get the model status."""
    return jsonify({
        "model_loaded": processor.is_loaded,
        "model_id": processor.MODEL_ID,
        "sample_rate": processor.sample_rate,
    })


@app.route("/api/load-model", methods=["POST"])
def load_model():
    """Load the model (downloads on first run)."""
    success = processor.load_model()
    return jsonify({
        "success": success,
        "model_loaded": processor.is_loaded,
    })


@app.route("/api/separate", methods=["POST"])
def separate_audio():
    """
    Separate audio based on a text description.
    
    Form data:
        - audio: Audio file (MP3, WAV, etc.)
        - description: Text description of sound to isolate
        - use_long_audio: Optional, use chunked processing for long files
    """
    # Validate file
    if "audio" not in request.files:
        return jsonify({"error": "No audio file provided"}), 400
    
    file = request.files["audio"]
    if file.filename == "":
        return jsonify({"error": "No file selected"}), 400
    
    if not allowed_file(file.filename):
        return jsonify({
            "error": f"Invalid file type. Allowed: {', '.join(ALLOWED_EXTENSIONS)}"
        }), 400
    
    # Validate description
    description = request.form.get("description", "").strip()
    if not description:
        return jsonify({"error": "No description provided"}), 400
    
    # Save uploaded file
    filename = secure_filename(file.filename)
    unique_id = str(uuid.uuid4())[:8]
    base_name = Path(filename).stem
    extension = Path(filename).suffix
    unique_filename = f"{base_name}_{unique_id}{extension}"
    
    upload_path = UPLOAD_FOLDER / unique_filename
    file.save(str(upload_path))
    
    try:
        # Process audio
        use_long = request.form.get("use_long_audio", "false").lower() == "true"
        
        target_path, residual_path, metadata = processor.isolate_audio(
            str(upload_path),
            description,
            use_long_audio=use_long,
        )
        
        if target_path is None:
            return jsonify({
                "error": metadata.get("error", "Processing failed")
            }), 500
        
        return jsonify({
            "success": True,
            "target_url": f"/audio/{Path(target_path).name}",
            "residual_url": f"/audio/{Path(residual_path).name}",
            "metadata": metadata,
        })
        
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    
    finally:
        # Clean up uploaded file
        if upload_path.exists():
            upload_path.unlink()


@app.route("/audio/<filename>")
def serve_audio(filename: str):
    """Serve processed audio files."""
    file_path = OUTPUT_FOLDER / secure_filename(filename)
    if not file_path.exists():
        return jsonify({"error": "File not found"}), 404
    return send_file(file_path, mimetype="audio/wav")


if __name__ == "__main__":
    debug_mode = True
    use_reloader = debug_mode
    port = get_server_port(DEFAULT_PORT)
    show_banner = not use_reloader or is_reloader_process()

    if show_banner:
        if port != DEFAULT_PORT:
            print(f"Port {DEFAULT_PORT} is in use; using {port} instead.")
        print("\n" + "="*60)
        print("  SAM-Audio Isolation Utility")
        print("="*60)
        print(f"\nModel: {processor.MODEL_ID}")
        print("\nStarting server...")
        print(f"Open http://localhost:{port} in your browser\n")
        
        # Pre-load model in development
        print("Loading model (this may take a moment on first run)...")
        processor.load_model()
    
    app.run(
        debug=debug_mode,
        host="0.0.0.0",
        port=port,
        use_reloader=use_reloader,
    )
