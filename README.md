# Visionkit

An iOS app for real-time text recognition on physical objects using a combination of computer vision and AI. Designed for reading engraved or printed text on cylindrical/circular parts via an external HDMI camera connected to an iPad.

## What it does

1. **Captures video** from an external HDMI camera (USB capture card → iPad)
2. **Unwraps circular text** using OpenCV — transforms curved/engraved text on round objects into a flat, readable strip
3. **Reads the text** using Apple Vision OCR with weighted consensus voting
4. **Corrects the text** using an on-device AI backend (selectable at runtime):
   - **Qwen3-4B** — text-only LLM (~2.5 GB, downloaded from HuggingFace). Takes high-confidence OCR candidates and corrects errors. Newer architecture, strong at text correction.
   - **FastVLM 1.5B** — vision+text model (~2.2 GB, bundled). Apple’s efficient VLM that can see the camera image alongside OCR hints.

### UI layout
- **Top** (yellow) — Consensus-voted OCR results with vote counts
- **Center** (blue) — AI-corrected text (from whichever backend is active)
- **Bottom** (white) — Live raw OCR output

## Architecture

```
HDMI Camera → AVCaptureSession
                  │
                  ├──→ Preview Layer (live feed)
                  │
                  ├──→ OpenCV clean/unwrap
                  │
                  ├──→ Vision OCR ──→ Live label (white, bottom)
                  │
                  ├──→ Weighted vote consensus ──→ Consensus label (yellow, top)
                  │
                  └──→ High-confidence candidates ──→ AI backend ──→ Corrected label (blue)
                                                       │
                                                       ├─ Qwen3-4B (text-only, via MLXLLM)
                                                       └─ FastVLM 1.5B (image+text, via MLXVLM)
```

### Key components

- **`CameraViewController.swift`** — Camera capture, OCR pipeline, consensus voting, AI backend dispatch, and all UI controls
- **`OpenCVWrapper.mm`** — C++/Objective-C++ wrapper for OpenCV: circular text detection (Hough circles), polar unwrapping, CLAHE enhancement, morphological processing, adaptive thresholding
- **`LLMService.swift`** — Text-only LLM backend using MLXLLM. Downloads and runs Qwen3-4B-4bit from HuggingFace for OCR text correction
- **`VLMService.swift`** — Vision+text backend wrapper around FastVLM. Provides `recognize(pixelBuffer:prompt:)` interface
- **`FastVLM.swift`** — Full FastVLM model architecture (Qwen2-based VLM with CoreML vision encoder). From [Apple's FastVLM](https://github.com/apple/ml-fastvlm)
- **`MediaProcessingExtensions.swift`** — Image preprocessing utilities for the VLM pipeline (resizing, cropping, normalization, planar conversion)

## Requirements

- iPad or iPhone with iOS 18.0+
- External USB HDMI capture card (for the camera input)
- Xcode 16+
- ~2.5 GB storage for Qwen3-4B model (downloaded on first run) + ~2.2 GB for FastVLM weights (bundled)

## Setup

### 1. Clone and checkout the feature branch

```bash
git clone https://github.com/jonpol01/Visionkit.git
cd Visionkit
git checkout feature/qwen3.5-backend
```

### 2. Get the FastVLM model weights

The model weights (~2.2 GB) are not included in the repo. You need the [apex-vlm](https://github.com/jonpol01/apex-vlm) project which contains them:

```bash
# Symlink the model directory
ln -s /path/to/apex-vlm/app/FastVLM/model Visionkit/model
```

Or download FastVLM weights directly from [Apple's model zoo](https://github.com/apple/ml-fastvlm#model-zoo) and place them in `Visionkit/model/`.

The model directory should contain:
- `config.json`
- `model.safetensors`
- `fastvithd.mlpackage/`
- `tokenizer.json`, `vocab.json`, `merges.txt`
- `preprocessor_config.json`, `processor_config.json`

### 3. Add model to Xcode project

In Xcode:
1. Right-click the **Visionkit** group → **Add Files to "Visionkit"**
2. Select the `Visionkit/model` directory
3. Choose **"Create folder references"** (blue folder icon)
4. Uncheck "Copy items if needed"
5. Ensure the Visionkit target is checked

### 4. Swift Package Dependencies

These should resolve automatically when you open the project. If not, add them manually:

- `https://github.com/ml-explore/mlx-swift` (0.29.1)
- `https://github.com/ml-explore/mlx-swift-examples` (2.29.1) — provides both `MLXVLM` and `MLXLLM`
- `https://github.com/huggingface/swift-transformers` (1.0.0)

### 5. OpenCV framework

The project requires `opencv2.framework` in the project root. Download it from [OpenCV releases](https://opencv.org/releases/) (iOS pack).

### 6. Build and run

Build and run on a physical device (not simulator — needs camera access and Metal GPU for MLX).

## Usage

- Point the external camera at a part with engraved/printed text
- **Bottom label** (white) — live raw OCR results
- **Top label** (yellow) — consensus-voted OCR with vote counts
- **Blue label** (above bottom) — AI-corrected text
- **AI: ON/OFF** — toggle AI correction
- **Qwen/FastVLM** (purple button) — switch between AI backends
- **Cam** — cycle between available cameras
- **Debug** — show/hide crosshair, circle detection, and text bounding boxes

The Qwen3-4B model (~2.5 GB) will download from HuggingFace on first use.

## License

FastVLM model code is from [Apple's ml-fastvlm](https://github.com/apple/ml-fastvlm) — see their LICENSE for model weights and code.
