//
//  TripPassView.swift
//  Podz
//
//  Created by Max Prx on 07/09/2026.
//

import SwiftUI
import UIKit
import PassKit
import MapKit
import Supabase

/// The pass for one upcoming stay: what you show at the door, saved on the
/// phone so it opens with no signal (a refuge is exactly where there's none).
///
/// It's built like the pod detail, the app's signature page: a tall photo with
/// its big rounded bottom, the pod's name and altitude centered under it, then
/// the stay, the confirmation code and its barcode. Tap anywhere between the
/// photo and the buttons for the details (where it is, how to get there, Apple
/// Wallet); tap again to go back. The pills are back and **Directions**.
///
/// Everything renders from `TripPass`, the snapshot `TripPassStore` keeps on
/// disk: the photo comes from the disk-backed image cache and the barcode is
/// drawn on the device. Only "Add to Apple Wallet" needs the network, because
/// a real `.pkpass` is signed with a key that lives on the server
/// (`supabase/functions/generate-trip-pass`).
struct TripPassView: View {
    let pass: TripPass
    var onBack: () -> Void

    @StateObject private var podsStore = PodsStore.shared
    @State private var showsPod = false
    @State private var isExtended = false
    @State private var isFetchingPass = false
    @State private var passFetchError: String?
    @State private var didCopyCode = false

    /// Only real once `PodsStore` has fetched this session: nil hides "View pod"
    /// when this is opened offline with nothing but the pass cached.
    private var matchedPod: Pod? {
        podsStore.pods.first { $0.id == pass.podId }
    }

    private var place: String {
        [pass.region, pass.country].compactMap { $0 }.joined(separator: ", ")
    }

    /// "Starts in 5 days", "Starts tomorrow", "Starts today"; nil once it's under way.
    private var countdown: String? {
        guard let start = Reservation.date(from: pass.checkIn) else { return nil }
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: start).day ?? 0
        switch days {
        case ..<0: return nil
        case 0: return "Starts today"
        case 1: return "Starts tomorrow"
        default: return "Starts in \(days) days"
        }
    }

    private var canOpenMaps: Bool { pass.latitude != nil && pass.longitude != nil }

    /// Photo heights as a share of the screen: shorter than the pod detail's,
    /// since the code and barcode need the room.
    private func photoHeight(_ screenHeight: CGFloat) -> CGFloat {
        screenHeight * (isExtended ? 200.0 / 852 : 360.0 / 852)
    }

    var body: some View {
        if let matchedPod, showsPod {
            MinimalPodDetailView(pod: matchedPod, onBack: { showsPod = false })
        } else {
            page
        }
    }

    // MARK: - The page

    private var page: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                // The whole screen: this page ignores every safe area.
                Color.clear
                    .frame(width: proxy.size.width, height: photoHeight(proxy.size.height))
                    .overlay { PodPhoto(url: pass.photoURL) }
                    .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 75, bottomTrailingRadius: 75, style: .continuous))

                // Everything between the photo and the buttons is one tap
                // target: a tap anywhere here opens or closes the details.
                VStack(spacing: 0) {
                    detailTitle(pass.podName, detail: pass.altitudeM.map { "\($0)m" })
                        .foregroundColor(.homeText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 50)

                    if isExtended {
                        details
                            .transition(.opacity)
                    } else {
                        stay
                            .transition(.opacity)
                        Spacer(minLength: 0)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture { withAnimation(.smooth(duration: 0.45)) { isExtended.toggle() } }

                HStack(spacing: 13) {
                    DetailBackButton(action: onBack)
                    DetailTextButton(title: "Directions", isHighlighted: canOpenMaps, action: openDirections)
                        .disabled(!canOpenMaps)
                        .opacity(canOpenMaps ? 1 : 0.45)
                }
                .padding(.horizontal, 40)
                .padding(.top, 24)
                .controlStackPadding()
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .background(Color.homeBackground.ignoresSafeArea())
        .alert("Couldn't add to Wallet", isPresented: Binding(
            get: { passFetchError != nil },
            set: { if !$0 { passFetchError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(passFetchError ?? "")
        }
    }

    // MARK: - The stay and its code

    /// When, for how many, the code, and the barcode.
    private var stay: some View {
        VStack(spacing: 0) {
            Text("\(pass.rangeText)  ·  \(pass.nights) \(pass.nights == 1 ? "night" : "nights")  ·  \(pass.guests) \(pass.guests == 1 ? "guest" : "guests")")
                .font(AppFont.regularLabel(15))
                .foregroundColor(.homeBodyText)
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .padding(.horizontal, 32)

            if let countdown {
                Text(countdown)
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .padding(.top, 4)
            }

            // The code, big; tap it to copy.
            Button {
                UIPasteboard.general.string = pass.confirmationCode
                didCopyCode = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                    didCopyCode = false
                }
            } label: {
                VStack(spacing: 4) {
                    Text(pass.confirmationCode)
                        .font(AppFont.semiBoldLabel(30))
                        .tracking(3)
                        .foregroundColor(.homeText)
                    Text(didCopyCode ? "Copied" : "Confirmation code")
                        .font(AppFont.regularLabel(12))
                        .foregroundColor(.homeSubtitle)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 26)
            .accessibilityLabel("Confirmation code \(pass.confirmationCode). Double tap to copy")

            // On white in both modes: dark bars on a light ground are what scan.
            BarcodeView(payload: pass.barcodePayload)
                .frame(height: 64)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .frame(width: 300)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .padding(.top, 20)
        }
    }

    // MARK: - Details

    /// Where it is and how to get there, for when you tap.
    private var details: some View {
        ScrollView {
            VStack(spacing: 22) {
                if !place.isEmpty {
                    Text(place)
                        .font(AppFont.regularLabel(15))
                        .foregroundColor(.homeBodyText)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 6) {
                    ForEach(detailLines, id: \.self) { line in
                        Text(line)
                            .font(AppFont.regularLabel(14))
                            .foregroundColor(.homeSubtitle)
                            .multilineTextAlignment(.center)
                    }
                }

                Text("Saved on this phone. It opens without signal.")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)

                if matchedPod != nil {
                    Button { showsPod = true } label: {
                        HStack(spacing: 5) {
                            Text("View pod")
                                .font(AppFont.regularLabel(13))
                                .foregroundColor(.homeSubtitle)
                                .underline(color: Color.homeSubtitle.opacity(0.5))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.homeSubtitle)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                // Apple asks for its own button for this, not a lookalike.
                AddToWalletButton {
                    Task { await addToWallet() }
                }
                .frame(width: 240, height: 46)
                .opacity(isFetchingPass ? 0.5 : 1)
                .disabled(isFetchingPass)
            }
            .frame(maxWidth: 329)
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private var detailLines: [String] {
        var lines: [String] = []
        if let address = pass.address, !address.isEmpty { lines.append(address) }
        if let lat = pass.latitude, let lng = pass.longitude {
            lines.append(String(format: "%.4f, %.4f", lat, lng))
        }
        if let altitude = pass.altitudeM { lines.append("\(altitude) m altitude") }
        return lines
    }

    // MARK: - Actions

    /// Walking directions in Apple Maps.
    private func openDirections() {
        guard let lat = pass.latitude, let lng = pass.longitude else { return }
        let item = MKMapItem(location: CLLocation(latitude: lat, longitude: lng), address: nil)
        item.name = pass.podName
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }

    private func addToWallet() async {
        guard PKAddPassesViewController.canAddPasses() else {
            passFetchError = "Wallet isn't available on this device."
            return
        }
        isFetchingPass = true
        defer { isFetchingPass = false }
        do {
            let data: Data = try await supabase.functions.invoke(
                "generate-trip-pass",
                options: FunctionInvokeOptions(body: ["reservationId": pass.reservationId.uuidString])
            ) { data, _ in data }
            let pkPass = try PKPass(data: data)
            presentAddPasses(for: pkPass)
        } catch {
            passFetchError = "Couldn't create your Wallet pass. Check your connection and try again."
        }
    }

    private func presentAddPasses(for pkPass: PKPass) {
        guard let controller = PKAddPassesViewController(pass: pkPass),
              let root = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                .first?.rootViewController else { return }
        root.presentedViewController?.dismiss(animated: false)
        root.present(controller, animated: true)
    }
}
