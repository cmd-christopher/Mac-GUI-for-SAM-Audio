/**
 * SAM-Audio Isolator - Frontend JavaScript
 * Handles file upload, API communication, and audio playback
 */

// ============================================
// State Management
// ============================================
const state = {
    file: null,
    isProcessing: false,
    modelLoaded: false,
};

// ============================================
// DOM Elements
// ============================================
const elements = {
    // Upload
    uploadZone: document.getElementById('upload-zone'),
    fileInput: document.getElementById('file-input'),
    fileInfo: document.getElementById('file-info'),
    fileName: document.getElementById('file-name'),
    fileSize: document.getElementById('file-size'),
    removeFile: document.getElementById('remove-file'),

    // Original Audio Preview
    originalAudioPreview: document.getElementById('original-audio-preview'),
    originalWaveform: document.getElementById('original-waveform'),
    originalAudio: document.getElementById('original-audio'),

    // Description
    descriptionInput: document.getElementById('description-input'),
    suggestions: document.getElementById('suggestions'),

    // Options
    longAudioCheckbox: document.getElementById('long-audio-checkbox'),

    // Actions
    processButton: document.getElementById('process-button'),

    // Status
    modelStatus: document.getElementById('model-status'),

    // Sections
    processingSection: document.getElementById('processing-section'),
    processingMessage: document.getElementById('processing-message'),
    resultsSection: document.getElementById('results-section'),
    errorSection: document.getElementById('error-section'),
    errorMessage: document.getElementById('error-message'),

    // Results
    targetAudio: document.getElementById('target-audio'),
    residualAudio: document.getElementById('residual-audio'),
    targetDownload: document.getElementById('target-download'),
    residualDownload: document.getElementById('residual-download'),
    targetDescription: document.getElementById('target-description'),
    peakMemory: document.getElementById('peak-memory'),

    // Buttons
    newSeparation: document.getElementById('new-separation'),
    retryButton: document.getElementById('retry-button'),
};

// ============================================
// Utility Functions
// ============================================
function formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
}

function showSection(section) {
    // Hide all dynamic sections
    elements.processingSection.classList.add('hidden');
    elements.resultsSection.classList.add('hidden');
    elements.errorSection.classList.add('hidden');

    // Show requested section
    if (section) {
        section.classList.remove('hidden');
    }
}

function updateProcessButton() {
    const hasFile = state.file !== null;
    const hasDescription = elements.descriptionInput.value.trim().length > 0;
    const isReady = !state.isProcessing;

    elements.processButton.disabled = !(hasFile && hasDescription && isReady);
}

// ============================================
// API Functions
// ============================================
async function checkModelStatus() {
    try {
        const response = await fetch('/api/status');
        const data = await response.json();

        state.modelLoaded = data.model_loaded;

        if (data.model_loaded) {
            elements.modelStatus.classList.add('ready');
            elements.modelStatus.classList.remove('loading');
            elements.modelStatus.querySelector('.status-text').textContent = 'Model Ready';
        } else {
            elements.modelStatus.classList.add('loading');
            elements.modelStatus.classList.remove('ready');
            elements.modelStatus.querySelector('.status-text').textContent = 'Loading model...';

            // Try to load the model
            loadModel();
        }
    } catch (error) {
        console.error('Failed to check model status:', error);
        elements.modelStatus.querySelector('.status-text').textContent = 'Connection error';
    }
}

async function loadModel() {
    try {
        const response = await fetch('/api/load-model', { method: 'POST' });
        const data = await response.json();

        if (data.success) {
            state.modelLoaded = true;
            elements.modelStatus.classList.add('ready');
            elements.modelStatus.classList.remove('loading');
            elements.modelStatus.querySelector('.status-text').textContent = 'Model Ready';
        }
    } catch (error) {
        console.error('Failed to load model:', error);
    }
}

async function separateAudio() {
    if (!state.file) return;

    state.isProcessing = true;
    updateProcessButton();
    showSection(elements.processingSection);

    const description = elements.descriptionInput.value.trim();
    const useLongAudio = elements.longAudioCheckbox.checked;

    // Update processing message
    elements.processingMessage.textContent = useLongAudio
        ? 'Processing in chunks (this may take longer for better memory efficiency)...'
        : 'This may take a moment depending on file length';

    const formData = new FormData();
    formData.append('audio', state.file);
    formData.append('description', description);
    formData.append('use_long_audio', useLongAudio.toString());

    try {
        const response = await fetch('/api/separate', {
            method: 'POST',
            body: formData,
        });

        const data = await response.json();

        if (!response.ok || data.error) {
            throw new Error(data.error || 'Processing failed');
        }

        // Show results
        displayResults(data, description);

    } catch (error) {
        console.error('Separation failed:', error);
        elements.errorMessage.textContent = error.message;
        showSection(elements.errorSection);
    } finally {
        state.isProcessing = false;
        updateProcessButton();
    }
}

function displayResults(data, description) {
    // Set audio sources
    elements.targetAudio.src = data.target_url;
    elements.residualAudio.src = data.residual_url;

    // Set download links
    elements.targetDownload.href = data.target_url;
    elements.residualDownload.href = data.residual_url;

    // Set description
    elements.targetDescription.textContent = description;

    // Set metadata
    if (data.metadata) {
        elements.peakMemory.textContent = (data.metadata.peak_memory_gb || 0).toFixed(2);
    }

    // Draw real waveform visualizations based on actual audio data
    drawWaveform('target-waveform', '#10b981');
    drawWaveform('residual-waveform', '#f59e0b');
    drawRealWaveform('target-waveform', data.target_url, '#10b981');
    drawRealWaveform('residual-waveform', data.residual_url, '#f59e0b');

    showSection(elements.resultsSection);
}

function drawWaveform(containerId, color) {
    const container = document.getElementById(containerId);
    if (!container) return;

    // Show loading state
    container.innerHTML = '<div style="color: #64748b; font-size: 12px; text-align: center; width: 100%; padding: 20px;">Analyzing audio...</div>';
    container.style.display = 'flex';
    container.style.alignItems = 'center';
    container.style.justifyContent = 'center';
}

/**
 * Update waveform to show playhead position
 * @param {string} containerId - ID of the waveform container
 * @param {number} progress - Playback progress from 0 to 1
 * @param {string} playedColor - Color for played portion
 * @param {string} unplayedColor - Color for unplayed portion
 */
function updateWaveformPlayhead(containerId, progress, playedColor, unplayedColor) {
    const container = document.getElementById(containerId);
    if (!container) return;

    const bars = container.querySelectorAll('.waveform-bar');
    if (bars.length === 0) return;

    const playedBars = Math.floor(progress * bars.length);

    bars.forEach((bar, index) => {
        if (index < playedBars) {
            bar.style.background = playedColor;
            bar.style.opacity = '1';
        } else if (index === playedBars) {
            // Current bar - make it brighter
            bar.style.background = playedColor;
            bar.style.opacity = '1';
            bar.style.boxShadow = '0 0 4px ' + playedColor;
        } else {
            bar.style.background = unplayedColor;
            bar.style.opacity = '0.5';
            bar.style.boxShadow = 'none';
        }
    });
}

/**
 * Set up playhead tracking for an audio element and waveform
 * @param {HTMLAudioElement} audioElement - The audio player element
 * @param {string} containerId - ID of the waveform container
 * @param {string} playedColor - Color for played portion (brighter)
 * @param {string} unplayedColor - Color for unplayed portion (dimmer)
 */
function setupWaveformPlayhead(audioElement, containerId, playedColor, unplayedColor) {
    if (!audioElement) return;

    // Update on time change
    audioElement.addEventListener('timeupdate', () => {
        const progress = audioElement.duration ? audioElement.currentTime / audioElement.duration : 0;
        updateWaveformPlayhead(containerId, progress, playedColor, unplayedColor);
    });

    // Reset on ended
    audioElement.addEventListener('ended', () => {
        updateWaveformPlayhead(containerId, 0, playedColor, unplayedColor);
    });

    // Allow clicking on waveform to seek
    const container = document.getElementById(containerId);
    if (container) {
        container.style.cursor = 'pointer';
        container.addEventListener('click', (e) => {
            const rect = container.getBoundingClientRect();
            const clickX = e.clientX - rect.left;
            const progress = clickX / rect.width;
            if (audioElement.duration) {
                audioElement.currentTime = progress * audioElement.duration;
            }
        });
    }
}

/**
 * Draw a real waveform by analyzing the audio data
 * @param {string} containerId - ID of the container element
 * @param {string} audioUrl - URL of the audio file to analyze
 * @param {string} color - Color for the waveform bars
 */
async function drawRealWaveform(containerId, audioUrl, color) {
    const container = document.getElementById(containerId);
    if (!container) return;

    try {
        // Fetch the audio file
        const response = await fetch(audioUrl);
        const arrayBuffer = await response.arrayBuffer();

        // Decode the audio data
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);

        // Get the raw audio data (use first channel)
        const rawData = audioBuffer.getChannelData(0);

        // Number of bars to display
        const barCount = 80;
        const samplesPerBar = Math.floor(rawData.length / barCount);

        // Calculate amplitude for each bar
        const amplitudes = [];
        for (let i = 0; i < barCount; i++) {
            let sum = 0;
            const start = i * samplesPerBar;
            const end = start + samplesPerBar;

            // Calculate RMS (root mean square) for this segment
            for (let j = start; j < end && j < rawData.length; j++) {
                sum += rawData[j] * rawData[j];
            }
            const rms = Math.sqrt(sum / samplesPerBar);
            amplitudes.push(rms);
        }

        // Normalize amplitudes to 0-1 range
        const maxAmplitude = Math.max(...amplitudes, 0.01);
        const normalizedAmplitudes = amplitudes.map(a => a / maxAmplitude);

        // Clear container and draw bars
        container.innerHTML = '';
        container.style.display = 'flex';
        container.style.alignItems = 'flex-end';
        container.style.gap = '1px';

        for (let i = 0; i < barCount; i++) {
            const bar = document.createElement('div');
            bar.className = 'waveform-bar';
            // Minimum height of 5%, max of 95%
            const height = 5 + (normalizedAmplitudes[i] * 90);
            bar.style.cssText = `
                flex: 1;
                height: ${height}%;
                background: ${color};
                opacity: 0.5;
                border-radius: 1px;
                transition: background 0.1s ease, opacity 0.1s ease;
            `;
            container.appendChild(bar);
        }

        // Close the audio context to free resources
        audioContext.close();

    } catch (error) {
        console.error('Error drawing waveform:', error);
        // Fallback to simple bars if analysis fails
        container.innerHTML = '';
        container.style.display = 'flex';
        container.style.alignItems = 'flex-end';

        for (let i = 0; i < 60; i++) {
            const bar = document.createElement('div');
            bar.className = 'waveform-bar';
            bar.style.cssText = `
                flex: 1;
                height: ${20 + Math.random() * 60}%;
                background: ${color};
                opacity: 0.5;
            `;
            container.appendChild(bar);
        }
    }
}

/**
 * Draw a real waveform by analyzing a local File object
 * @param {File} file - The audio file to analyze
 * @param {string} containerId - ID of the container element
 * @param {string} color - Color for the waveform bars
 */
async function drawRealWaveformFromFile(file, containerId, color) {
    const container = document.getElementById(containerId);
    if (!container) return;

    try {
        // Read file as ArrayBuffer
        const arrayBuffer = await file.arrayBuffer();

        // Decode the audio data
        const audioContext = new (window.AudioContext || window.webkitAudioContext)();
        const audioBuffer = await audioContext.decodeAudioData(arrayBuffer);

        // Get the raw audio data (use first channel)
        const rawData = audioBuffer.getChannelData(0);

        // Number of bars to display
        const barCount = 80;
        const samplesPerBar = Math.floor(rawData.length / barCount);

        // Calculate amplitude for each bar
        const amplitudes = [];
        for (let i = 0; i < barCount; i++) {
            let sum = 0;
            const start = i * samplesPerBar;
            const end = start + samplesPerBar;

            // Calculate RMS (root mean square) for this segment
            for (let j = start; j < end && j < rawData.length; j++) {
                sum += rawData[j] * rawData[j];
            }
            const rms = Math.sqrt(sum / samplesPerBar);
            amplitudes.push(rms);
        }

        // Normalize amplitudes to 0-1 range
        const maxAmplitude = Math.max(...amplitudes, 0.01);
        const normalizedAmplitudes = amplitudes.map(a => a / maxAmplitude);

        // Clear container and draw bars
        container.innerHTML = '';
        container.style.display = 'flex';
        container.style.alignItems = 'flex-end';
        container.style.gap = '1px';

        for (let i = 0; i < barCount; i++) {
            const bar = document.createElement('div');
            bar.className = 'waveform-bar';
            // Minimum height of 5%, max of 95%
            const height = 5 + (normalizedAmplitudes[i] * 90);
            bar.style.cssText = `
                flex: 1;
                height: ${height}%;
                background: ${color};
                opacity: 0.5;
                border-radius: 1px;
                transition: background 0.1s ease, opacity 0.1s ease;
            `;
            container.appendChild(bar);
        }

        // Close the audio context to free resources
        audioContext.close();

    } catch (error) {
        console.error('Error drawing waveform from file:', error);
        // Fallback to simple bars if analysis fails
        container.innerHTML = '';
        container.style.display = 'flex';
        container.style.alignItems = 'flex-end';

        for (let i = 0; i < 60; i++) {
            const bar = document.createElement('div');
            bar.className = 'waveform-bar';
            bar.style.cssText = `
                flex: 1;
                height: ${20 + Math.random() * 60}%;
                background: ${color};
                opacity: 0.5;
            `;
            container.appendChild(bar);
        }
    }
}

function resetUI() {
    // Clear file
    state.file = null;
    elements.fileInput.value = '';
    elements.fileInfo.classList.add('hidden');
    elements.uploadZone.classList.remove('hidden');

    // Hide and clear original audio preview
    elements.originalAudioPreview.classList.add('hidden');
    elements.originalAudio.src = '';
    elements.originalWaveform.innerHTML = '';

    // Clear description
    elements.descriptionInput.value = '';

    // Clear checkbox
    elements.longAudioCheckbox.checked = false;

    // Clear results
    elements.targetAudio.src = '';
    elements.residualAudio.src = '';

    // Update button
    updateProcessButton();

    // Hide sections
    showSection(null);
}

// ============================================
// Event Handlers
// ============================================

// File Upload - Click
elements.uploadZone.addEventListener('click', () => {
    elements.fileInput.click();
});

// File Upload - Input Change
elements.fileInput.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (file) {
        handleFileSelect(file);
    }
});

// File Upload - Drag & Drop
elements.uploadZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    elements.uploadZone.classList.add('drag-over');
});

elements.uploadZone.addEventListener('dragleave', (e) => {
    e.preventDefault();
    elements.uploadZone.classList.remove('drag-over');
});

elements.uploadZone.addEventListener('drop', (e) => {
    e.preventDefault();
    elements.uploadZone.classList.remove('drag-over');

    const file = e.dataTransfer.files[0];
    if (file) {
        handleFileSelect(file);
    }
});

function handleFileSelect(file) {
    // Validate file type
    const validTypes = ['audio/mpeg', 'audio/mp3', 'audio/wav', 'audio/flac', 'audio/m4a', 'audio/ogg', 'audio/aac', 'audio/x-m4a'];
    const validExtensions = ['.mp3', '.wav', '.flac', '.m4a', '.ogg', '.aac'];

    const hasValidType = validTypes.includes(file.type);
    const hasValidExtension = validExtensions.some(ext => file.name.toLowerCase().endsWith(ext));

    if (!hasValidType && !hasValidExtension) {
        alert('Please upload a valid audio file (MP3, WAV, FLAC, M4A, OGG, or AAC)');
        return;
    }

    state.file = file;

    // Update UI
    elements.fileName.textContent = file.name;
    elements.fileSize.textContent = formatFileSize(file.size);
    elements.uploadZone.classList.add('hidden');
    elements.fileInfo.classList.remove('hidden');

    // Show original audio preview
    elements.originalAudioPreview.classList.remove('hidden');

    // Create object URL for the file and set as audio source
    const audioUrl = URL.createObjectURL(file);
    elements.originalAudio.src = audioUrl;

    // Draw waveform for original audio
    drawWaveform('original-waveform', '#3b82f6');
    drawRealWaveformFromFile(file, 'original-waveform', '#3b82f6');

    updateProcessButton();
}

// Remove File
elements.removeFile.addEventListener('click', () => {
    state.file = null;
    elements.fileInput.value = '';
    elements.fileInfo.classList.add('hidden');
    elements.uploadZone.classList.remove('hidden');

    // Hide and clear original audio preview
    elements.originalAudioPreview.classList.add('hidden');
    elements.originalAudio.src = '';
    elements.originalWaveform.innerHTML = '';

    updateProcessButton();
});

// Description Input
elements.descriptionInput.addEventListener('input', updateProcessButton);

// Suggestion Buttons
elements.suggestions.addEventListener('click', (e) => {
    if (e.target.tagName === 'BUTTON') {
        elements.descriptionInput.value = e.target.dataset.value;
        updateProcessButton();
    }
});

// Process Button
elements.processButton.addEventListener('click', separateAudio);

// New Separation
elements.newSeparation.addEventListener('click', resetUI);

// Retry Button
elements.retryButton.addEventListener('click', () => {
    showSection(null);
    updateProcessButton();
});

// Keyboard Shortcuts
document.addEventListener('keydown', (e) => {
    // Enter to process
    if (e.key === 'Enter' && !elements.processButton.disabled && !state.isProcessing) {
        separateAudio();
    }
});

// ============================================
// Initialization
// ============================================
document.addEventListener('DOMContentLoaded', () => {
    checkModelStatus();
    updateProcessButton();

    // Set up playhead tracking for all audio players
    // Original audio - blue colors
    setupWaveformPlayhead(elements.originalAudio, 'original-waveform', '#3b82f6', '#1e3a5f');

    // Target audio - green colors  
    setupWaveformPlayhead(elements.targetAudio, 'target-waveform', '#10b981', '#064e3b');

    // Residual audio - orange/amber colors
    setupWaveformPlayhead(elements.residualAudio, 'residual-waveform', '#f59e0b', '#78350f');
});
