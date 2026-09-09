//
//  TripPassView.swift
//  Podz
//
//  Created by Max Prx on 07/09/2026.
//

import SwiftUI
import UIKit
import PassKit
import Supabase

/// The "offline pass" for one upcoming trip — reached by tapping a trip
/// in `PodsView`. Renders entirely from `TripPass`, the denormalized
/// snapshot `TripPassStore` persists to disk specifically so this screen
/// still has something real to show with no signal — the actual use
/// case, since this app books mountain refuges, exactly where you're
/// most likely to open this with zero bars. No network calls of its own
/// to *render*: the photo comes from `PodPhoto`'s own disk-backed
/// `ImageCache` (already warm by the time a trip's been seen once in
/// `PodsView`), and the barcode is generated locally, on-device, from the
/// pass's own data.
///
/// "Add to Apple Wallet" is the one thing here that does need a network
/// call — building a real `.pkpass` requires a PKCS#7 signature from the
/// Pass Type ID certificate's private key, which can only ever live
/// server-side (see `supabase/functions/generate-trip-pass`), never
/// shipped inside this app. That's a one-time cost, though: once the
/// pass is actually in Wallet, opening it there has zero dependency on
/// Podz being installed, logged in, or online at all.
struct TripPassView: View {
    let pass: TripPass
    var onBack: () -> Void

    @StateObject private var podsStore = PodsStore.shared
    @State private var showPodDetail = false
    @State private var isFetchingPass = false
    @State private var passFetchError: String?
    /// How far the seam drag (see `seamDrag`) has currently pulled the
    /// two ticket halves apart — always springs back to 0 on release, see
    /// `ticketCard`'s own doc comment for why.
    @State private var tearGap: CGFloat = 0

    // Same persistent-top-bar metrics as PostDetailView/LikesView's own
    // folder screen — 44pt back button + 31pt padding top/bottom.
    private let topBarHeight: CGFloat = 106
    private let notchRadius: CGFloat = 11
    private let maxTearGap: CGFloat = 28

    private var nights: Int {
        guard let checkIn = Reservation.date(from: pass.checkIn),
              let checkOut = Reservation.date(from: pass.checkOut) else { return 0 }
        return Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 0
    }

    private var locationLine: String {
        [pass.region, pass.country].compactMap { $0 }.joined(separator: ", ")
    }

    /// Only real once `PodsStore` has actually fetched this session — nil
    /// (rather than a stale placeholder) is what hides the "View pod"
    /// link below when opened offline with nothing more than the pass
    /// itself cached.
    private var matchedPod: Pod? {
        podsStore.pods.first { $0.id == pass.podId }
    }

    var body: some View {
        if let matchedPod, showPodDetail {
            PodDetailView(pod: matchedPod, onBack: { showPodDetail = false })
        } else {
            content
        }
    }

    private var content: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    // Room for the persistent top bar below to float over.
                    Color.clear.frame(height: topBarHeight)

                    ticketCard
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                    Color.clear.frame(height: 60)
                }
            }
            .background(Color.appHomeBackground)

            ProfileTopBar(title: "Your pass", onBack: onBack)
        }
        .background(Color.appHomeBackground)
        .alert("Couldn't add to Wallet", isPresented: Binding(
            get: { passFetchError != nil },
            set: { if !$0 { passFetchError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(passFetchError ?? "")
        }
    }

    /// One continuous ticket, not two stacked cards — an info half and a
    /// barcode half, each punching its own two half-circle notches out of
    /// the edge where they meet (see `TicketTopShape`/`TicketBottomShape`)
    /// so together they read as a single perforated pass, the way a real
    /// boarding pass or event ticket is printed and torn along a dotted
    /// line. Dragging on that seam (see `seamDrag`) actually pulls the two
    /// halves apart, spring-loaded back together on release — playful,
    /// but the pass itself never actually separates or invalidates.
    private var ticketCard: some View {
        VStack(spacing: 0) {
            ticketInfoSection
                .background(TicketTopShape(notchRadius: notchRadius).fill(Color.appFieldBg, style: FillStyle(eoFill: true)))
                // Clipped *after* the background is added, not before —
                // this needs to trim both the photo (rounding its top
                // corners to match the card) and the notch-punch
                // background's own outer bleed (each notch circle is
                // centered exactly on the edge, half in/half out) in one
                // pass. Clipping first would leave that background layer,
                // added afterward, outside its reach entirely.
                .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(
                    topLeading: AppRadius.r15, bottomLeading: 0, bottomTrailing: 0, topTrailing: AppRadius.r15
                )))
                .overlay(alignment: .bottom) { seamOverlay }
                .offset(y: -tearGap / 2)
                .rotationEffect(.degrees(-tearGap / 12), anchor: .bottom)

            ticketStubSection
                .background(TicketBottomShape(notchRadius: notchRadius).fill(Color.appFieldBg, style: FillStyle(eoFill: true)))
                .clipShape(UnevenRoundedRectangle(cornerRadii: RectangleCornerRadii(
                    topLeading: 0, bottomLeading: AppRadius.r15, bottomTrailing: AppRadius.r15, topTrailing: 0
                )))
                .offset(y: tearGap / 2)
                .rotationEffect(.degrees(tearGap / 12), anchor: .top)
        }
        .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
    }

    /// The dashed tear line plus an invisible, generously taller hit
    /// target layered behind it (a bare 1pt line is nearly impossible to
    /// actually grab) — both centered exactly on the seam between the two
    /// halves via the `.offset` below undoing half of `.overlay(alignment:
    /// .bottom)`'s own default placement (flush with the section's bottom
    /// edge, not straddling it).
    private var seamOverlay: some View {
        ZStack {
            Color.clear
                .frame(height: 40)
                .contentShape(Rectangle())
                .gesture(seamDrag)

            // Inset by notchRadius on each side — the notch circles are
            // punched exactly there, so a full-width line would visibly
            // cross straight through both holes instead of stopping
            // cleanly at their edges.
            DashedLine().stroke(Color.black.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .frame(height: 1)
                .padding(.horizontal, notchRadius)
        }
        .offset(y: 20)
    }

    private var seamDrag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let magnitude = max(abs(value.translation.width), abs(value.translation.height))
                let newGap = min(magnitude, maxTearGap)
                // One tick right as the drag reaches full separation, not
                // continuously while dragging — matches ModeSwitchPill's
                // own reasoning for when a haptic actually reads as
                // meaningful feedback instead of noise.
                if newGap >= maxTearGap && tearGap < maxTearGap {
                    UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                }
                tearGap = newGap
            }
            .onEnded { _ in
                // Springs back together, always — the pass itself never
                // actually tears apart or invalidates, this is purely the
                // tactile "you could" of a perforated line.
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                    tearGap = 0
                }
            }
    }

    private var ticketInfoSection: some View {
        VStack(spacing: 0) {
            PodPhoto(url: pass.photoURL)
                .frame(height: 150)
                .clipped()
                .overlay(alignment: .topTrailing) {
                    if matchedPod != nil {
                        viewPodButton.padding(10)
                    }
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(pass.podName)
                    .font(AppFont.pillLabelBold(19))
                    .foregroundColor(.black)
                if !locationLine.isEmpty {
                    Text(locationLine)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.appTextMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)

            routeRow
                .padding(.horizontal, 16)
                .padding(.top, 18)

            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
                .padding(.horizontal, 16)
                .padding(.top, 18)

            infoGrid
                .padding(.horizontal, 16)
                .padding(.top, 16)

            if let address = pass.address {
                Text(address)
                    .font(AppFont.regularLabel(11))
                    .foregroundColor(.appTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
            }

            Color.clear.frame(height: 18)
        }
    }

    /// Same "go to the pod" affordance as `PostCard`'s own header — a
    /// bare gray glyph, no circle/background, over the photo rather than
    /// a separate labeled link competing for space below the card.
    private var viewPodButton: some View {
        Button {
            showPodDetail = true
        } label: {
            Image(systemName: "arrow.up.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appBorder)
                .frame(width: 32, height: 32)
        }
        .accessibilityLabel("View pod")
    }

    /// Check-in and check-out, called out the way a boarding pass calls
    /// out its two airport codes — the two dates that actually matter at
    /// a glance, not buried in the same-weight grid below with
    /// nights/guests/altitude.
    private var routeRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(dayMonth(pass.checkIn))
                    .font(AppFont.pillLabelBold(21))
                    .foregroundColor(.black)
                Text("Check-in")
                    .font(AppFont.regularLabel(11))
                    .foregroundColor(.appTextMuted)
            }

            DashedLine().stroke(Color.appBorder, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [2, 4]))
                .frame(height: 1)
                .padding(.top, 12)
                .frame(maxWidth: .infinity)

            VStack(alignment: .trailing, spacing: 2) {
                Text(dayMonth(pass.checkOut))
                    .font(AppFont.pillLabelBold(21))
                    .foregroundColor(.black)
                Text("Check-out")
                    .font(AppFont.regularLabel(11))
                    .foregroundColor(.appTextMuted)
            }
        }
    }

    private func dayMonth(_ dateString: String) -> String {
        guard let date = Reservation.date(from: dateString) else { return dateString }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter.string(from: date).uppercased()
    }

    /// Same label-over-value grid a real boarding pass uses for flight
    /// no./seat/gate — two explicit columns (Nights/Confirmation on the
    /// left, Guests/Coordinates on the right), not a flow-based grid that
    /// only happened to land in that arrangement — the same left/right
    /// column each field lives in regardless of whether coordinates are
    /// even present, matching `routeRow`'s own check-in/check-out split
    /// above it instead of drifting depending on the pass's own data.
    private var infoGrid: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 16) {
                gridField(label: "Nights", value: "\(nights) night\(nights == 1 ? "" : "s")")
                gridField(label: "Confirmation", value: pass.confirmationCode)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 16) {
                gridField(label: "Guests", value: "\(pass.guests) guest\(pass.guests == 1 ? "" : "s")")
                if let latitude = pass.latitude, let longitude = pass.longitude {
                    gridField(label: "Coordinates", value: String(format: "%.4f, %.4f", latitude, longitude))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func gridField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(AppFont.regularLabel(10))
                .tracking(0.5)
                .foregroundColor(.appTextMuted)
            Text(value)
                .font(AppFont.mediumLabel(14))
                .foregroundColor(.black)
        }
    }

    private var ticketStubSection: some View {
        VStack(spacing: 10) {
            BarcodeView(payload: pass.barcodePayload)
                .frame(height: 64)
                .padding(.horizontal, 20)

            Text(pass.confirmationCode)
                .font(AppFont.regularLabel(12))
                .tracking(3)
                .foregroundColor(.appTextMuted)

            Text("Available offline — no signal needed")
                .font(AppFont.regularLabel(11))
                .foregroundColor(.appAvailableGreen)
                .padding(.top, 4)

            if isFetchingPass {
                ProgressView()
                    .padding(.top, 8)
            } else {
                // Apple's own button, not a custom SwiftUI stand-in — a
                // real Wallet integration is expected to use this exact
                // control, not something that merely looks like it. Lives
                // inside the stub itself, not floating below the card —
                // this half of the ticket has the room for it, and it's
                // exactly the "get the barcode into Wallet" action this
                // half is already about.
                AddToWalletButton {
                    Task { await addToWallet() }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .padding(.bottom, 24)
    }

    /// Fetches a freshly signed `.pkpass` from `generate-trip-pass` (the
    /// one moment this screen actually needs a network call) and hands
    /// it to the system's own "Add to Wallet" sheet.
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

#Preview {
    TripPassView(
        pass: TripPass(
            reservationId: UUID(),
            podId: UUID(),
            podName: "Refuge du Goûter",
            address: nil,
            region: "Haute-Savoie",
            country: "France",
            latitude: 45.85000,
            longitude: 6.83000,
            altitudeM: 3835,
            photoURL: nil,
            checkIn: "2026-09-20",
            checkOut: "2026-09-22",
            guests: 2
        ),
        onBack: {}
    )
}
