//
//  CameraViewController.swift
//  Visionkit
//
//  Created by JOHN PAUL SOLIVA on 2026/02/24.
//

import UIKit
import AVFoundation
import Vision

class CameraViewController: UIViewController {

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var lastProcessTime = Date()

    /// FastVLM inference service
    private let vlmService = VLMService()
    /// Toggle between Vision OCR and FastVLM
    var useVLM = true
    
    // OCR label (bottom)
    private let overlayLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = UIFont.monospacedSystemFont(ofSize: 16, weight: .semibold)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.text = ""
        return label
    }()

    // VLM label (top)
    private let vlmLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .yellow
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.text = "VLM: loading…"
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()

        // Load FastVLM model in background
        Task { @MainActor in
            await vlmService.load()
            vlmLabel.text = vlmService.isLoaded ? "VLM: ready" : "VLM: \(vlmService.statusMessage)"
        }
    }

    private func setupCamera() {
        captureSession.sessionPreset = .high
        
        for device in AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        ).devices {
            print("Found camera:", device.localizedName)
        }
  
        // Use HDMI camera
        guard let camera = AVCaptureDevice.default(.external, for: .video, position: .unspecified) else {
            print("HDMI camera not found")
            return
        }
  
        captureSession.addInput(try! AVCaptureDeviceInput(device: camera))

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_32BGRA
        ]
        captureSession.addOutput(output)
                
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        previewLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))

        view.layer.addSublayer(previewLayer)

        // Orientation for external HDMI camera
        // External capture cards typically deliver landscape frames.
        // Adjust the angle here if the preview is rotated:
        //   0 = no rotation, 90 = portrait, 180 = upside-down, 270 = landscape-left
        if let connection = previewLayer.connection {
            let angle: CGFloat = 0
            if connection.isVideoRotationAngleSupported(angle) {
                connection.videoRotationAngle = angle
            }
        }
        
        // Add overlay labels
        view.addSubview(overlayLabel)
        view.addSubview(vlmLabel)
        NSLayoutConstraint.activate([
            // OCR label at bottom
            overlayLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            overlayLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            overlayLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            // VLM label at top
            vlmLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            vlmLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            vlmLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
        ])

        captureSession.startRunning()
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        // Throttle to ~3 FPS
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) > 0.3 else { return }
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Always run Vision OCR on raw frame
        recognizeText(from: pixelBuffer)

        // Run OpenCV unwrap → FastVLM
        if useVLM {
            let bufferForVLM: CVPixelBuffer
            if let processed = OpenCVWrapper.unwrapCircularText(pixelBuffer) {
                bufferForVLM = processed
            } else {
                bufferForVLM = pixelBuffer
            }
            recognizeWithVLM(from: bufferForVLM)
        }
    }

    private func recognizeWithVLM(from pixelBuffer: CVPixelBuffer) {
        guard vlmService.isLoaded, !vlmService.running else { return }

        Task { @MainActor in
            let result = await vlmService.recognize(pixelBuffer: pixelBuffer)
            vlmLabel.text = "VLM: \(result)"
        }
    }

//    private func recognizeText(from pixelBuffer: CVPixelBuffer) {
//
//        let request = VNRecognizeTextRequest { request, error in
//            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
//
//            for observation in observations {
//                guard let candidate = observation.topCandidates(1).first else { continue }
//                print("Detected:", candidate.string, "Confidence:", candidate.confidence)
//            }
//        }
//
//        request.recognitionLevel = .accurate
//        request.usesLanguageCorrection = false
//
//        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
//                                            orientation: .right,
//                                            options: [:])
//
//        try? handler.perform([request])
//    }
    
    private func recognizeText(from pixelBuffer: CVPixelBuffer) {

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            var uniqueStrings = Set<String>()

            for observation in observations {

                guard let candidate = observation.topCandidates(3).first else { continue }

                let text = candidate.string
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let confidence = candidate.confidence

                // 🔥 Filter aggressively
                if confidence > 0.8 && text.count > 4 {
                    uniqueStrings.insert(text)
                }
            }

            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if uniqueStrings.isEmpty {
                    self.overlayLabel.text = ""
                } else {
                    let combined = uniqueStrings.joined(separator: " \n")
                    self.overlayLabel.text = combined
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en_US"]
        request.minimumTextHeight = 0.005
//        request.customWords = ["JAN", "LOT"]


//        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .right,
            options: [:]
        )
        try? handler.perform([request])
    }
}

