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

    /// Guide overlays
    private let crosshairLayer = CAShapeLayer()
    private let ringOverlay = CAShapeLayer()
    private let circleOverlay = CAShapeLayer()
    private let textHighlightLayer = CAShapeLayer()

    /// Multi-frame voting: track how many times each text fragment is seen
    private var textVotes: [String: Int] = [:]
    private var lastVoteReset = Date()
    private let voteWindow: TimeInterval = 10  // seconds
    private let minVotesToShow = 3  // must be seen at least N times

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

    // Consensus label (top) — voted results from raw OCR
    private let consensusLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .yellow
        label.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 8
        label.layer.masksToBounds = true
        label.text = "Consensus: –"
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

        // Crosshair overlay
        crosshairLayer.fillColor = UIColor.clear.cgColor
        crosshairLayer.strokeColor = UIColor.green.cgColor
        crosshairLayer.lineWidth = 1
        view.layer.addSublayer(crosshairLayer)

        // Ring boundary overlay (inner/outer capture ring)
        ringOverlay.fillColor = UIColor.clear.cgColor
        ringOverlay.strokeColor = UIColor.cyan.cgColor
        ringOverlay.lineWidth = 1.5
        ringOverlay.lineDashPattern = [6, 4]
        view.layer.addSublayer(ringOverlay)

        // Detected circle overlay (visual only — does not affect unwrap)
        circleOverlay.fillColor = UIColor.clear.cgColor
        circleOverlay.strokeColor = UIColor.green.cgColor
        circleOverlay.lineWidth = 2
        view.layer.addSublayer(circleOverlay)

        // Text highlight overlay (shows what Vision is reading)
        textHighlightLayer.fillColor = UIColor.yellow.withAlphaComponent(0.15).cgColor
        textHighlightLayer.strokeColor = UIColor.yellow.cgColor
        textHighlightLayer.lineWidth = 1.5
        view.layer.addSublayer(textHighlightLayer)

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
        view.addSubview(consensusLabel)

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
            // Consensus label at top
            consensusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            consensusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            consensusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            // Button stack (top-right, below consensus label)
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            buttonStack.topAnchor.constraint(equalTo: consensusLabel.bottomAnchor, constant: 8),
        ])

        captureSession.startRunning()
    }

    @objc private func toggleTopText() {
        showTopText.toggle()
        consensusLabel.isHidden = !showTopText
        topTextButton.setTitle(showTopText ? "Top: ON" : "Top: OFF", for: .normal)
        topTextButton.backgroundColor = (showTopText ? UIColor.systemGreen : UIColor.systemRed).withAlphaComponent(0.8)
        if !showTopText {
            textVotes.removeAll()
            consensusLabel.text = "Consensus: –"
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
            crosshairLayer.path = nil
            ringOverlay.path = nil
            circleOverlay.path = nil
            textHighlightLayer.path = nil
        }
    }
}

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - GS1 filter

    /// Returns true if text looks like a GS1 code we care about: (01)... or (10)...
    private func isRelevantGS1(_ text: String) -> Bool {
        let patterns = ["(01)", "(10)", "(01", "(10", "01)", "10)"]
        return patterns.contains(where: { text.contains($0) })
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        // Throttle to ~2 FPS (bilateral filter on 4K is heavy)
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) > 0.5 else { return }
        lastProcessTime = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)

        // Use autoreleasepool to free OpenCV-created pixel buffers each frame
        autoreleasepool {
            // Clean frame for better OCR, then run Vision OCR → both labels
            let ocrBuffer: CVPixelBuffer
            if let cleaned = OpenCVWrapper.clean(forOCR: pixelBuffer) {
                ocrBuffer = cleaned
            } else {
                ocrBuffer = pixelBuffer
            }
            recognizeText(from: ocrBuffer, orientation: .right, showLive: showBottomText, showConsensus: showTopText)

            // Try circular unwrap — if circle found, also run OCR on unwrapped strip
            if let unwrapped = OpenCVWrapper.unwrapCircularText(pixelBuffer) {
                if showTopText {
                    recognizeUnwrapped(from: unwrapped)
                }
            }
        }

        // Run circle detection for visual overlay (separate from unwrap)
        OpenCVWrapper.detectCircle(pixelBuffer)

        // Draw guide overlay (independent toggle)
        if showDebugOverlay {
            drawGuideOverlay(bufferWidth: bufferWidth, bufferHeight: bufferHeight)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.crosshairLayer.path = nil
                self?.ringOverlay.path = nil
                self?.circleOverlay.path = nil
            }
        }
    }

    private func recognizeText(
        from pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        showLive: Bool,
        showConsensus: Bool
    ) {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            // Collect all top-3 candidates for voting
            var liveStrings = Set<String>()      // best candidate per region (for live label)
            var allCandidates: [(String, Float)] = []  // all candidates with confidence (for voting)
            var boundingBoxes: [CGRect] = []     // bounding boxes for debug highlight

            for observation in observations {
                let candidates = observation.topCandidates(3)
                guard let best = candidates.first else { continue }

                let bestText = best.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if best.confidence > 0.3 && bestText.count > 1 {
                    boundingBoxes.append(observation.boundingBox)
                }
                if best.confidence > 0.5 && bestText.count > 1 {
                    liveStrings.insert(bestText)
                }

                // Add all candidates for voting (weighted by rank)
                for (rank, candidate) in candidates.enumerated() {
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if candidate.confidence > 0.3 && text.count > 1 {
                        // Weight: rank 0 = 3 votes, rank 1 = 2, rank 2 = 1
                        let weight = Float(3 - rank)
                        allCandidates.append((text, weight))
                    }
                }
            }

            DispatchQueue.main.async {
                // Bottom: live OCR (best candidate per region)
                if showLive {
                    if liveStrings.isEmpty {
                        self.overlayLabel.text = ""
                    } else {
                        self.overlayLabel.text = liveStrings.joined(separator: " \n")
                    }
                }

                // Top: weighted voted consensus from all candidates
                if showConsensus {
                    // Reset votes periodically
                    if Date().timeIntervalSince(self.lastVoteReset) > self.voteWindow {
                        self.textVotes.removeAll()
                        self.lastVoteReset = Date()
                    }

                    // Add weighted votes — only for GS1-relevant text
                    for (text, weight) in allCandidates {
                        if self.isRelevantGS1(text) {
                            self.textVotes[text, default: 0] += Int(weight)
                        }
                    }

                    let confirmed = self.textVotes
                        .filter { $0.value >= self.minVotesToShow }
                        .sorted { $0.value > $1.value }
                        .map { "\($0.key)(\($0.value))" }

                    NSLog("[OCR votes] %@", self.textVotes.map { "\($0.key):\($0.value)" }.joined(separator: " | "))

                    self.consensusLabel.text = confirmed.isEmpty
                        ? "Consensus: –"
                        : confirmed.joined(separator: " | ")
                }

                // Draw text highlight bounding boxes
                if self.showDebugOverlay {
                    let viewW = self.view.bounds.width
                    let viewH = self.view.bounds.height
                    let highlightPath = UIBezierPath()

                    for bb in boundingBoxes {
                        // Vision normalized coords (bottom-left, .right orientation) → view coords
                        // With .right orientation and horizontal mirror on preview:
                        //   viewX = viewW * bb.minY
                        //   viewY = viewH * (1 - bb.maxX)
                        //   width/height swap due to 90° rotation
                        let rect = CGRect(
                            x: viewW * bb.minY,
                            y: viewH * (1 - bb.maxX),
                            width: viewW * bb.height,
                            height: viewH * bb.width
                        )
                        highlightPath.append(UIBezierPath(roundedRect: rect, cornerRadius: 2))
                    }

                    self.textHighlightLayer.path = highlightPath.cgPath
                } else {
                    self.textHighlightLayer.path = nil
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en_US"]
        request.minimumTextHeight = 0.003

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )
        try? handler.perform([request])
    }

    // MARK: - Unwrapped OCR (circular objects)

    /// Run OCR on the unwrapped circular strip and add votes to consensus.
    private func recognizeUnwrapped(from pixelBuffer: CVPixelBuffer) {
        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self = self else { return }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            var unwrappedCandidates: [(String, Int)] = []

            for observation in observations {
                for (rank, candidate) in observation.topCandidates(3).enumerated() {
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    if candidate.confidence > 0.3 && text.count > 1 {
                        unwrappedCandidates.append((text, 3 - rank))
                    }
                }
            }

            if !unwrappedCandidates.isEmpty {
                DispatchQueue.main.async {
                    // Add unwrapped votes — only GS1-relevant
                    for (text, weight) in unwrappedCandidates {
                        if self.isRelevantGS1(text) {
                            self.textVotes[text, default: 0] += weight
                        }
                    }
                    NSLog("[Unwrap OCR] added %d candidates to votes", unwrappedCandidates.count)
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en_US"]
        request.minimumTextHeight = 0.002

        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: .up,
            options: [:]
        )
        try? handler.perform([request])
    }

    // MARK: - Guide overlay (crosshair + ring + detected circle)

    private func drawGuideOverlay(bufferWidth: Int, bufferHeight: Int) {
        // Detected circle (visual only)
        var circlePath: CGPath? = nil
        if let circleData = OpenCVWrapper.lastDetectedCircle(), circleData.count == 3 {
            let cx = CGFloat(circleData[0].floatValue)
            let cy = CGFloat(circleData[1].floatValue)
            let r  = CGFloat(circleData[2].floatValue)

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
            circlePath = path.cgPath
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let viewW = self.view.bounds.width
            let viewH = self.view.bounds.height
            let centerX = viewW / 2
            let centerY = viewH / 2
            let guideR = min(viewW, viewH) * 0.40

            // Crosshair
            let crosshair = UIBezierPath()
            let armLen: CGFloat = 20
            crosshair.move(to: CGPoint(x: centerX - armLen, y: centerY))
            crosshair.addLine(to: CGPoint(x: centerX + armLen, y: centerY))
            crosshair.move(to: CGPoint(x: centerX, y: centerY - armLen))
            crosshair.addLine(to: CGPoint(x: centerX, y: centerY + armLen))
            self.crosshairLayer.path = crosshair.cgPath

            // Inner/outer capture ring (matches OpenCV rInner/rOuter)
            let ringPath = UIBezierPath()
            ringPath.append(UIBezierPath(
                arcCenter: CGPoint(x: centerX, y: centerY),
                radius: guideR * 0.45,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            ))
            ringPath.append(UIBezierPath(
                arcCenter: CGPoint(x: centerX, y: centerY),
                radius: guideR * 1.10,
                startAngle: 0,
                endAngle: .pi * 2,
                clockwise: true
            ))
            self.ringOverlay.path = ringPath.cgPath

            // Detected circle (green, visual reference only)
            self.circleOverlay.path = circlePath
        }
    }
}

