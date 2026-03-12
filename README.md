# Visionkit

An iOS app for real-time text recognition on physical objects using a combination of computer vision and AI. Designed for reading engraved or printed text on cylindrical/circular parts via an external HDMI camera connected to an iPad.

## What it does

1. **Captures video** from an external HDMI camera (USB capture card → iPad)
2. **Unwraps circular text** using OpenCV — transforms curved/engraved text on round objects into a flat, readable strip
3. **Reads the text** using two engines running in parallel:
   - **Apple Vision OCR** (`VNRecognizeTextRequest`) — fast, traditional OCR shown at the bottom of the screen (white text)
   - **FastVLM** (Vision Language Model) — AI-powered text recognition shown at the top of the screen (yellow text)

The VLM understands context and can read text that traditional OCR struggles with, especially on preprocessed/unwrapped circular surfaces.

## Architecture

```
HDMI Camera → AVCaptureSession
                  │
                  ├──→ Preview Layer (live feed)
                  │
                  ├──→ Vision OCR ──→ Bottom label (white)
                  │
                  └──→ OpenCV Unwrap ──→ FastVLM ──→ Top label (yellow)
```

### Key components

- **`CameraViewController.swift`** — Manages the camera capture session, preview layer, and coordinates both recognition pipelines
- **`OpenCVWrapper.mm`** — C++/Objective-C++ wrapper for OpenCV operations: circular text detection (Hough circles), polar unwrapping, CLAHE enhancement, morphological processing, adaptive thresholding
- **`VLMService.swift`** — Lightweight wrapper around FastVLM that loads the model and provides a simple `recognize(pixelBuffer:prompt:)` interface
- **`FastVLM.swift`** — Full model architecture implementation (Qwen2-based VLM with CoreML vision encoder). From [Apple's FastVLM](https://github.com/apple/ml-fastvlm)
- **`MediaProcessingExtensions.swift`** — Image preprocessing utilities for the VLM pipeline (resizing, cropping, normalization, planar conversion)

## Requirements

- iPad or iPhone with iOS 18.0+
- External USB HDMI capture card (for the camera input)
- Xcode 16+
- ~2.2 GB storage for model weights

## Setup

### 1. Clone and checkout the feature branch

```bash
git clone https://github.com/jonpol01/Visionkit.git
cd Visionkit
git checkout feature/fastvlm-integration
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

- `https://github.com/ml-explore/mlx-swift` (0.21.2)
- `https://github.com/ml-explore/mlx-swift-examples` (2.21.2)
- `https://github.com/huggingface/swift-transformers` (0.1.18)

### 5. OpenCV framework

The project requires `opencv2.framework` in the project root. Download it from [OpenCV releases](https://opencv.org/releases/) (iOS pack).

### 6. Build and run

Build and run on a physical device (not simulator — needs camera access and Metal GPU for MLX).

## Usage

- Point the external camera at a part with text
- The **bottom label** (white) shows Vision OCR results
- The **top label** (yellow) shows FastVLM AI results
- Toggle VLM on/off by setting `useVLM` in `CameraViewController.swift`
- Adjust camera rotation angle in `setupCamera()` if the preview orientation is wrong

## License

FastVLM model code is from [Apple's ml-fastvlm](https://github.com/apple/ml-fastvlm) — see their LICENSE for model weights and code.
