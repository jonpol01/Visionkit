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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    private func setupCamera() {
        captureSession.sessionPreset = .high

        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Camera not available")
            return
        }

        captureSession.addInput(input)

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
        view.layer.addSublayer(previewLayer)

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

        recognizeText(from: pixelBuffer)
        if let processedBuffer = OpenCVWrapper.preprocessPixelBuffer(pixelBuffer) {
            recognizeText(from: processedBuffer)
        }
//        recognizeText(from: image: CGImage)
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

                guard let candidate = observation.topCandidates(1).first else { continue }

                let text = candidate.string
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                let confidence = candidate.confidence

                // 🔥 Filter aggressively
                if confidence > 0.85 && text.count > 5 {
                    uniqueStrings.insert(text)
                }
            }

            DispatchQueue.main.async {
                for text in uniqueStrings {
                    print("VALID: \(text)")
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["en_US"]
        request.minimumTextHeight = 0.03

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        try? handler.perform([request])
    }
}
