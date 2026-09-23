//
//  Pod3DModelView.swift
//  Podz
//
//  Created by Max Prx on 22/09/2026.
//

import SwiftUI
import SceneKit

/// Renders a pod's real, host-scanned 3D model (see `PodScanCaptureView`)
/// with free drag-to-orbit and pinch-to-zoom — `allowsCameraControl` gives
/// that natively, no custom gesture/animation code needed, because this is
/// a real complete captured object with no "unseen side" problem to work
/// around (unlike the depth-parallax and relief attempts before it).
struct Pod3DModelView: View {
    let modelURL: String
    /// Shown while the model downloads — the pod's own hero photo, so
    /// there's still something recognizable on screen instead of a blank
    /// placeholder.
    let fallbackPhotoURL: String?

    @State private var scene: SCNScene?

    var body: some View {
        ZStack {
            if let scene {
                SceneView(scene: scene, options: [.allowsCameraControl, .autoenablesDefaultLighting])
            } else {
                // Covers both "still downloading" and "failed to load" —
                // either way, the pod's own photo is a reasonable stand-in.
                PodPhoto(url: fallbackPhotoURL)
            }
        }
        .task(id: modelURL) { await load() }
    }

    private func load() async {
        scene = nil

        let data: Data?
        if let cached = PodModelFileCache.shared.data(for: modelURL) {
            data = cached
        } else if let url = URL(string: modelURL) {
            data = try? await URLSession.shared.data(from: url).0
            if let data { PodModelFileCache.shared.set(data, for: modelURL) }
        } else {
            data = nil
        }

        guard let data, !Task.isCancelled else { return }

        // SCNScene needs a file URL, not raw Data — write to a scratch
        // file (overwritten each load, not accumulated) rather than a
        // fresh UUID-named file per view, since nothing else needs to
        // keep it around after the scene's built.
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("PodModelPreview.usdz")
        try? data.write(to: tempURL, options: .atomic)
        scene = try? SCNScene(url: tempURL, options: nil)
    }
}
