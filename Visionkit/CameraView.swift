//
//  CameraView.swift
//  Visionkit
//
//  Created by JOHN PAUL SOLIVA on 2026/02/24.
//

import SwiftUI

struct CameraView: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}
