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

/// The pass for one upcoming stay: what you show at the door, and what you
/// need on the way, saved on the phone so it opens with no signal (a refuge is
/// exactly where there's none).
///
/// Everything renders from `TripPass`, the snapshot `TripPassStore` keeps on
/// disk: the photo comes from the disk-backed image cache and the barcode is
/// drawn on the device. Only "Add to Apple Wallet" needs the network, because
/// a real `.pkpass` is signed with a key that lives on the server
/// (`supabase/functions/generate-trip-pass`).
///
/// Same page recipe as the pages Profile opens (`design.md`): a 30 semiBold
/// title, flat content, the back pill and the page's action (**Directions**)
/// in the control stack.
struct TripPassView: View {
    let pass: TripPass
    var onBack: () -> Void

    @StateObject private var podsStore = PodsStore.shared
    @State private var showsPod = false
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

    /// "Starts in 5 days", "Starts tomorrow", "Today"; nil once it's under way.
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

    var body: some View {
        if let matchedPod, showsPod {
            MinimalPodDetailView(pod: matchedPod, onBack: { showsPod = false })
        } else {
            page
        }
    }

    // MARK: - The page

    private var page: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(pass.podName)
                        .font(AppFont.semiBoldLabel(30))
                        .tracking(-0.6)
                        .foregroundColor(.homeText)
                        .padding(.horizontal, 24)
                        .padding(.top, 25)

                    if !place.isEmpty || pass.altitudeM != nil {
                        Text([place.isEmpty ? nil : place, pass.altitudeM.map { "\($0) m" }].compactMap { $0 }.joined(separator: "  ·  "))
                            .font(AppFont.regularLabel(13))
                            .foregroundColor(.homeSubtitle)
                            .padding(.horizontal, 24)
                            .padding(.top, 6)
                    }

                    Color.clear
                        .frame(height: 200)
                        .overlay { PodPhoto(url: pass.photoURL) }
                        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
                        .padding(.horizontal, 24)
                        .padding(.top, 20)

                    stay
                    code
                    gettingThere
                    extras

                    Color.clear.frame(height: 190)
                }
            }

            BottomFade()

            HStack(spacing: 13) {
                DetailBackButton(action: onBack)
                DetailTextButton(title: "Directions", isHighlighted: canOpenMaps, action: openDirections)
                    .disabled(!canOpenMaps)
                    .opacity(canOpenMaps ? 1 : 0.45)
            }
            .padding(.horizontal, 24)
            // A cover respects the safe area: 40 here is the 74 from the edge.
            .padding(.bottom, 40)
        }
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

    // MARK: - Stay

    /// When, for how long, for how many, and how soon.
    private var stay: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(pass.rangeText)
                .font(AppFont.semiBoldLabel(22))
                .tracking(-0.4)
                .foregroundColor(.homeText)
            Text("\(pass.nights) \(pass.nights == 1 ? "night" : "nights")  ·  \(pass.guests) \(pass.guests == 1 ? "guest" : "guests")")
                .font(AppFont.regularLabel(14))
                .foregroundColor(.homeSubtitle)
            if let countdown {
                Text(countdown)
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeText)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Capsule().fill(Color.homePill))
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 28)
    }

    // MARK: - Code

    /// The confirmation code, big, and the barcode under it. The barcode sits
    /// on white in both modes: dark bars on a light ground are what scan.
    private var code: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confirmation code")
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)

            Button {
                UIPasteboard.general.string = pass.confirmationCode
                didCopyCode = true
                Task {
                    try? await Task.sleep(nanoseconds: 1_400_000_000)
                    didCopyCode = false
                }
            } label: {
                HStack(spacing: 10) {
                    Text(pass.confirmationCode)
                        .font(AppFont.semiBoldLabel(30))
                        .tracking(3)
                        .foregroundColor(.homeText)
                    Text(didCopyCode ? "Copied" : "Copy")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .underline(color: Color.homeSubtitle.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Confirmation code \(pass.confirmationCode). Double tap to copy")

            BarcodeView(payload: pass.barcodePayload)
                .frame(height: 80)
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
    }

    // MARK: - Getting there

    @ViewBuilder
    private var gettingThere: some View {
        let rows = detailRows
        if !rows.isEmpty {
            SectionHeading(title: "Getting there")
                .padding(.top, 12)
            ForEach(rows, id: \.label) { row in
                VStack(alignment: .leading, spacing: 5) {
                    Text(row.label)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                    Text(row.value)
                        .font(AppFont.semiBoldLabel(16))
                        .foregroundColor(.homeText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .overlay(alignment: .bottom) { Hairline().padding(.horizontal, 24) }
            }
        }
    }

    private var detailRows: [(label: String, value: String)] {
        var rows: [(String, String)] = []
        if let address = pass.address, !address.isEmpty { rows.append(("Address", address)) }
        if let lat = pass.latitude, let lng = pass.longitude {
            rows.append(("Coordinates", String(format: "%.4f, %.4f", lat, lng)))
        }
        if let altitude = pass.altitudeM { rows.append(("Altitude", "\(altitude) m")) }
        return rows
    }

    // MARK: - Extras

    /// Saved offline, view the pod, add to Wallet.
    private var extras: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Saved on this phone. It opens without signal.")
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
                .padding(.top, 20)

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
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Apple asks for its own button for this, not a lookalike.
            AddToWalletButton {
                Task { await addToWallet() }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .opacity(isFetchingPass ? 0.5 : 1)
            .disabled(isFetchingPass)
            .padding(.top, 12)
        }
        .padding(.horizontal, 24)
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
