"""
SAM-Audio Processor Module
Handles audio isolation using the SAM-Audio model via MLX.
"""

import os
from pathlib import Path
from typing import Optional, Tuple

# MLX Audio imports
from mlx_audio.sts import SAMAudio, SAMAudioProcessor, save_audio
import mlx.core as mx


class AudioProcessor:
    """
    Wrapper class for SAM-Audio model operations.
    Provides methods for loading the model and isolating audio based on text descriptions.
    """
    
    MODEL_ID = "mlx-community/sam-audio-large-fp16"
    
    def __init__(self, output_dir: str = "output"):
        """
        Initialize the AudioProcessor.
        
        Args:
            output_dir: Directory to save processed audio files
        """
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
        self.model: Optional[SAMAudio] = None
        self.processor: Optional[SAMAudioProcessor] = None
        self._loaded = False
    
    def load_model(self) -> bool:
        """
        Load the SAM-Audio model and processor.
        Downloads the model on first run.
        
        Returns:
            True if model loaded successfully, False otherwise
        """
        if self._loaded:
            return True
        
        try:
            print(f"Loading SAM-Audio model: {self.MODEL_ID}")
            print("This may take a moment on first run as the model downloads...")
            
            self.processor = SAMAudioProcessor.from_pretrained(self.MODEL_ID)
            self.model = SAMAudio.from_pretrained(self.MODEL_ID)
            
            self._loaded = True
            print("Model loaded successfully!")
            return True
            
        except Exception as e:
            print(f"Error loading model: {e}")
            return False
    
    @property
    def is_loaded(self) -> bool:
        """Check if the model is loaded."""
        return self._loaded
    
    @property
    def sample_rate(self) -> int:
        """Get the model's sample rate."""
        if self.model:
            return self.model.sample_rate
        return 24000  # Default SAM-Audio sample rate
    
    def isolate_audio(
        self,
        audio_path: str,
        description: str,
        use_long_audio: bool = False,
        chunk_seconds: float = 10.0,
        overlap_seconds: float = 3.0
    ) -> Tuple[Optional[str], Optional[str], dict]:
        """
        Isolate audio based on a text description.
        
        Args:
            audio_path: Path to the input audio file
            description: Text description of the sound to isolate (e.g., "speech", "piano")
            use_long_audio: Use chunked processing for long files (more memory efficient)
            chunk_seconds: Chunk size for long audio processing
            overlap_seconds: Overlap between chunks for smooth transitions
            
        Returns:
            Tuple of (target_path, residual_path, metadata)
            - target_path: Path to isolated target audio (what was described)
            - residual_path: Path to residual audio (everything else)
            - metadata: Dict with processing info (peak_memory, etc.)
        """
        if not self._loaded:
            if not self.load_model():
                return None, None, {"error": "Failed to load model"}
        
        try:
            # Get base filename for outputs
            input_path = Path(audio_path)
            base_name = input_path.stem
            
            # Process inputs
            print(f"Processing audio: {audio_path}")
            print(f"Description: {description}")
            
            batch = self.processor(
                descriptions=[description],
                audios=[str(audio_path)],
            )
            
            # Separate audio
            if use_long_audio:
                print("Using chunked processing for long audio...")
                result = self.model.separate_long(
                    audios=batch.audios,
                    descriptions=batch.descriptions,
                    chunk_seconds=chunk_seconds,
                    overlap_seconds=overlap_seconds,
                    anchor_ids=batch.anchor_ids,
                    anchor_alignment=batch.anchor_alignment,
                    ode_decode_chunk_size=50,
                )
            else:
                result = self.model.separate(
                    audios=batch.audios,
                    descriptions=batch.descriptions,
                    sizes=batch.sizes,
                    anchor_ids=batch.anchor_ids,
                    anchor_alignment=batch.anchor_alignment,
                    ode_decode_chunk_size=50,
                )
            
            # Save outputs
            target_path = self.output_dir / f"{base_name}_target.wav"
            residual_path = self.output_dir / f"{base_name}_residual.wav"
            
            save_audio(result.target[0], str(target_path), sample_rate=self.sample_rate)
            save_audio(result.residual[0], str(residual_path), sample_rate=self.sample_rate)
            
            metadata = {
                "peak_memory_gb": getattr(result, 'peak_memory', 0),
                "sample_rate": self.sample_rate,
                "description": description,
            }
            
            print(f"Target audio saved to: {target_path}")
            print(f"Residual audio saved to: {residual_path}")
            print(f"Peak memory: {metadata['peak_memory_gb']:.2f} GB")
            
            return str(target_path), str(residual_path), metadata
            
        except Exception as e:
            print(f"Error processing audio: {e}")
            return None, None, {"error": str(e)}


# Singleton instance for reuse
_processor: Optional[AudioProcessor] = None


def get_processor(output_dir: str = "output") -> AudioProcessor:
    """
    Get or create the global AudioProcessor instance.
    
    Args:
        output_dir: Directory to save processed audio files
        
    Returns:
        AudioProcessor instance
    """
    global _processor
    if _processor is None:
        _processor = AudioProcessor(output_dir)
    return _processor
