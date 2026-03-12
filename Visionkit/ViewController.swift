//
//  ViewController.swift
//  Visionkit
//
//  Created by JOHN PAUL SOLIVA on 2026/02/24.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {

    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var lastProcessTime = Date()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    private func setupCamera() {
        print("Setting up camera...")
        captureSession.sessionPreset = .high

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.external, .builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )

        for device in discovery.devices {
            print("Found camera:", device.localizedName)
        }

        guard let camera = discovery.devices.first else {
            print("No camera found")
            return
        }

        print("Using camera:", camera.localizedName)

        guard let input = try? AVCaptureDeviceInput(device: camera) else {
            print("Cannot create input")
            return
        }

        captureSession.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(output)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        captureSession.startRunning()
    }
//    private func setupCamera() {
//        captureSession.sessionPreset = .high
//
//        guard let camera = AVCaptureDevice.default(for: .video),
//              let input = try? AVCaptureDeviceInput(device: camera) else {
//            print("Camera not available")
//            return
//        }
//
//        captureSession.addInput(input)
//
//        let output = AVCaptureVideoDataOutput()
//        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
//        captureSession.addOutput(output)
//
//        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
//        previewLayer.videoGravity = .resizeAspectFill
//        previewLayer.frame = view.bounds
//        view.layer.addSublayer(previewLayer)
//
//        captureSession.startRunning()
//    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        // Throttle to ~3 FPS
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) > 0.3 else { return }
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        recognizeText(from: pixelBuffer)
    }

    private func recognizeText(from pixelBuffer: CVPixelBuffer) {

        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }

                print("Detected: \(candidate.string)")
                print("Confidence: \(candidate.confidence)")
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.minimumTextHeight = 0.02

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .right,
                                            options: [:])

        try? handler.perform([request])
    }
}
