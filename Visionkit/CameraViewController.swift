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

    /// Toggles
    private var showTopText = true
    private var showBottomText = true
    private var showDebugOverlay = true

    /// Circle debug overlay
    private let circleOverlay = CAShapeLayer()

    /// Accumulated unique text fragments from unwrapped OCR
    private var collectedTexts = Set<String>()
    private var lastCollectionReset = Date()

    // Buttons
    private let topTextButton = CameraViewController.makeToggleButton(title: "Top: ON", color: .systemGreen)
    private let bottomTextButton = CameraViewController.makeToggleButton(title: "Bottom: ON", color: .systemGreen)
    private let debugButton = CameraViewController.makeToggleButton(title: "Debug: ON", color: .systemGreen)

    private static func makeToggleButton(title: String, color: UIColor) -> UIButton {
        let btn = UIButton(type: .system)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font = UIFont.boldSystemFont(ofSize: 13)
        btn.setTitleColor(.white, for: .normal)
        btn.backgroundColor = color.withAlphaComponent(0.8)
        btn.layer.cornerRadius = 8
        btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        return btn
    }
    
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

    // Unwrapped OCR label (top)
    private let unwrappedLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .yellow
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.text = "Unwrapped: –"
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    private func setupCamera() {
        captureSession.sessionPreset = .hd4K3840x2160
        
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

        // Circle debug overlay
        circleOverlay.fillColor = UIColor.clear.cgColor
        circleOverlay.strokeColor = UIColor.green.cgColor
        circleOverlay.lineWidth = 2
        view.layer.addSublayer(circleOverlay)

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
        
        // Add overlay labels + buttons
        view.addSubview(overlayLabel)
        view.addSubview(unwrappedLabel)

        let buttonStack = UIStackView(arrangedSubviews: [topTextButton, bottomTextButton, debugButton])
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.axis = .vertical
        buttonStack.alignment = .trailing
        buttonStack.spacing = 8
        view.addSubview(buttonStack)

        topTextButton.addTarget(self, action: #selector(toggleTopText), for: .touchUpInside)
        bottomTextButton.addTarget(self, action: #selector(toggleBottomText), for: .touchUpInside)
        debugButton.addTarget(self, action: #selector(toggleDebug), for: .touchUpInside)

        NSLayoutConstraint.activate([
            // Raw OCR label at bottom
            overlayLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            overlayLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            overlayLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
            // Unwrapped OCR label at top
            unwrappedLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            unwrappedLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            unwrappedLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            // Button stack (top-right, below unwrapped label)
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            buttonStack.topAnchor.constraint(equalTo: unwrappedLabel.bottomAnchor, constant: 8),
        ])

        captureSession.startRunning()
    }

    @objc private func toggleTopText() {
        showTopText.toggle()
        unwrappedLabel.isHidden = !showTopText
        topTextButton.setTitle(showTopText ? "Top: ON" : "Top: OFF", for: .normal)
        topTextButton.backgroundColor = (showTopText ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.8)
        if !showTopText {
            collectedTexts.removeAll()
            unwrappedLabel.text = ""
        }
    }

    @objc private func toggleBottomText() {
        showBottomText.toggle()
        overlayLabel.isHidden = !showBottomText
        bottomTextButton.setTitle(showBottomText ? "Bottom: ON" : "Bottom: OFF", for: .normal)
        bottomTextButton.backgroundColor = (showBottomText ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.8)
    }

    @objc private func toggleDebug() {
        showDebugOverlay.toggle()
        debugButton.setTitle(showDebugOverlay ? "Debug: ON" : "Debug: OFF", for: .normal)
        debugButton.backgroundColor = (showDebugOverlay ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.8)
        if !showDebugOverlay {
            circleOverlay.path = nil
        }
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

        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)

        // Vision OCR on raw frame → bottom label
        if showBottomText {
            recognizeText(from: pixelBuffer, orientation: .right, label: overlayLabel, prefix: "", looseFilter: false)
        }

        // OpenCV unwrap → Vision OCR → top label
        // Run OpenCV if either top text or debug overlay needs it
        if showTopText || showDebugOverlay {
            if let unwrapped = OpenCVWrapper.unwrapCircularText(pixelBuffer) {
                if showTopText {
                    recognizeText(from: unwrapped, orientation: .up, label: unwrappedLabel, prefix: "", looseFilter: true, collectInto: true)
                }
            } else {
                if showTopText {
                    DispatchQueue.main.async { [weak self] in
                        self?.unwrappedLabel.text = "No circle detected"
                    }
                }
            }
        }

        // Draw circle overlay (independent toggle)
        if showDebugOverlay {
            drawCircleOverlay(bufferWidth: bufferWidth, bufferHeight: bufferHeight)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.circleOverlay.path = nil
            }
        }
    }

    private func recognizeText(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        label: UILabel,
        prefix: String,
        looseFilter: Bool,
        collectInto: Bool = false
    ) {
        let minConfidence: Float = looseFilter ? 0.3 : 0.8
        let minLength = looseFilter ? 1 : 4

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            var uniqueStrings = Set<String>()

            for observation in observations {
                guard let candidate = observation.topCandidates(3).first else { continue }

                let text = candidate.string
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if candidate.confidence > minConfidence && text.count > minLength {
                    uniqueStrings.insert(text)
                }
            }

            DispatchQueue.main.async {
                guard let self = self else { return }

                if collectInto {
                    // Reset collection every 10 seconds
                    if Date().timeIntervalSince(self.lastCollectionReset) > 10 {
                        self.collectedTexts.removeAll()
                        self.lastCollectionReset = Date()
                    }
                    if !uniqueStrings.isEmpty {
                        NSLog("[Unwrapped OCR] new: %@", uniqueStrings.joined(separator: " | "))
                    }
                    self.collectedTexts.formUnion(uniqueStrings)
                    let sorted = self.collectedTexts.sorted()
                    NSLog("[Unwrapped OCR] collected: %@", sorted.joined(separator: " | "))
                    label.text = sorted.isEmpty ? "\(prefix)–" : "\(prefix)\(sorted.joined(separator: " | "))"
                } else {
                    if uniqueStrings.isEmpty {
                        label.text = prefix.isEmpty ? "" : "\(prefix)–"
                    } else {
                        let combined = uniqueStrings.joined(separator: " \n")
                        label.text = "\(prefix)\(combined)"
                    }
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = looseFilter
        request.recognitionLanguages = ["en_US"]
        request.minimumTextHeight = looseFilter ? 0.002 : 0.005

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        try? handler.perform([request])
    }

    // MARK: - Circle debug overlay

    private func drawCircleOverlay(bufferWidth: Int, bufferHeight: Int) {
        guard let circleData = OpenCVWrapper.lastDetectedCircle(),
              circleData.count == 3 else {
            DispatchQueue.main.async { [weak self] in
                self?.circleOverlay.path = nil
            }
            return
        }

        let cx = CGFloat(circleData[0].floatValue)
        let cy = CGFloat(circleData[1].floatValue)
        let r  = CGFloat(circleData[2].floatValue)

        // Scale from pixel buffer coords to view coords
        let viewW = view.bounds.width
        let viewH = view.bounds.height
        let scaleX = viewW / CGFloat(bufferWidth)
        let scaleY = viewH / CGFloat(bufferHeight)

        // Mirror horizontally (matches the -1 scaleX transform on preview)
        let screenCx = viewW - (cx * scaleX)
        let screenCy = cy * scaleY
        let screenR  = r * min(scaleX, scaleY)

        let path = UIBezierPath(
            arcCenter: CGPoint(x: screenCx, y: screenCy),
            radius: screenR,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )

        DispatchQueue.main.async { [weak self] in
            self?.circleOverlay.path = path.cgPath
        }
    }
}

