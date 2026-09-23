//
//  PodScanCaptureView.swift
//  Podz
//
//  Created by Max Prx on 22/09/2026.
//

import SwiftUI
import RealityKit

/// Guided in-app 3D scan of a pod, using Apple's on-device Object Capture
/// (`ObjectCaptureSession` + `PhotogrammetrySession`) — no cloud call, no
/// Mac required; full on-device capture AND reconstruction since iOS 17.
/// Only ever presented when `ObjectCaptureSession.isSupported` is true
/// (checked by the caller, `AddPodView`) — this needs a LiDAR sensor and
/// doesn't degrade gracefully without one.
///
/// A shelter exterior is building-scale, not the tabletop-object case
/// Object Capture demos — so this uses **area mode**, not object mode.
/// Per Apple's own WWDC24 guidance, area mode isn't a config flag: it's
/// simply skipping `startDetecting()` (which shows a bounding-box UI for
/// isolating a discrete object) and going straight to `startCapturing()`.
struct PodScanCaptureView: View {
    var onComplete: (URL) -> Void
    var onCancel: () -> Void

    @State private var session: ObjectCaptureSession?
    @State private var captureFolder: URL?
    @State private var reconstructionProgress: Double?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            if reconstructionProgress != nil {
                reconstructingView
            } else if let session {
                captureView(session: session)
            } else {
                ProgressView().tint(.white)
            }
        }
        .background(Color.black.ignoresSafeArea())
        .task { startSession() }
        .task(id: captureStateDescription) { await handleStateChange() }
        .alert("Scan didn't complete", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { onCancel() }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Session lifecycle

    private func startSession() {
        let newSession = ObjectCaptureSession()
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("PodScan-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        captureFolder = folder
        newSession.start(imagesDirectory: folder)
        session = newSession
    }

    /// A plain `String`, not branching on `session.state` directly — sidesteps
    /// depending on `ObjectCaptureSession.CaptureState`'s own `Equatable`
    /// conformance (uncertain from docs alone), since `.task(id:)` only
    /// needs *some* Equatable value to key off, and re-fires whenever this
    /// description actually changes.
    private var captureStateDescription: String {
        guard let session else { return "none" }
        switch session.state {
        case .initializing: return "initializing"
        case .ready: return "ready"
        case .detecting: return "detecting"
        case .capturing: return "capturing"
        case .finishing: return "finishing"
        case .completed: return "completed"
        case .failed: return "failed"
        @unknown default: return "unknown"
        }
    }

    private func handleStateChange() async {
        guard let session else { return }
        switch session.state {
        case .completed:
            startReconstruction()
        case .failed:
            errorMessage = "The scan didn't finish — try again with more light and a slower pass around the pod."
        default:
            break
        }
    }

    // MARK: - Capture UI

    @ViewBuilder
    private func captureView(session: ObjectCaptureSession) -> some View {
        ZStack {
            ObjectCaptureView(session: session)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button {
                        session.cancel()
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color.black.opacity(0.4)))
                    }
                    .accessibilityLabel("Cancel scan")
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer()

                // `if case`, not `==` — avoids depending on
                // `CaptureState`'s own `Equatable` conformance, same
                // reasoning as `captureStateDescription` above.
                if case .ready = session.state {
                    // Area mode: straight to capturing, no bounding-box
                    // detection step — that's for isolating a single
                    // tabletop-sized object, not a building.
                    Button("Start scanning") {
                        session.startCapturing()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 40)
                } else if case .capturing = session.state {
                    Button("Finish scan") {
                        session.finish()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    // MARK: - Reconstruction

    private var reconstructingView: some View {
        VStack(spacing: 16) {
            ProgressView(value: reconstructionProgress ?? 0)
                .tint(.white)
                .frame(width: 200)
            Text("Building your 3D model…")
                .foregroundColor(.white)
            Text("This can take a few minutes.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(32)
    }

    private func startReconstruction() {
        guard let captureFolder else { return }
        reconstructionProgress = 0
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PodScanModel-\(UUID().uuidString).usdz")

        Task {
            do {
                let photogrammetrySession = try PhotogrammetrySession(input: captureFolder)
                // .reduced, not .full — keeps the result lightweight,
                // which is the whole point versus a raw capture dump.
                try photogrammetrySession.process(requests: [.modelFile(url: outputURL, detail: .reduced)])

                for try await output in photogrammetrySession.outputs {
                    switch output {
                    case .requestProgress(_, let fractionComplete):
                        reconstructionProgress = fractionComplete
                    case .requestComplete:
                        onComplete(outputURL)
                        return
                    case .requestError(_, let error):
                        errorMessage = error.localizedDescription
                        return
                    case .processingComplete:
                        return
                    default:
                        break
                    }
                }
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
