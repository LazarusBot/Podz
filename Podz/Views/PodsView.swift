//
//  PodsView.swift
//  Podz
//
//  Created by Max Prx on 07/09/2026.
//

import SwiftUI

/// Tab content for "Pods" — your own upcoming trips. The soonest one
/// gets a big hero card (the one you actually care about at a glance);
/// anything further out falls into a simpler list below it, same idea as
/// Airbnb/TripIt's own trips tab. Tapping either opens `TripPassView`,
/// the offline pass for that trip — reads straight from
/// `TripPassStore.passes` rather than assembling reservations/pods
/// itself, so this stays correct even opened cold with no signal. Past/
/// cancelled reservations and the cancel action still live in the fuller
/// history reached from Profile's own "Reservations" row
/// (`MyReservationsView`) — this tab is deliberately just the
/// forward-looking list.
struct PodsView: View {
    @StateObject private var reservationsStore = ReservationsStore.shared
    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var tripPassStore = TripPassStore.shared
    // Shared with HomeView/LikesView/MailboxView — feeds the floating tab
    // bar's scroll-down shrink (MainTabView).
    @StateObject private var scrollState = ScrollTrackingState.shared
    @State private var selectedPass: TripPass?

    var body: some View {
        if let pass = selectedPass {
            TripPassView(pass: pass, onBack: { selectedPass = nil })
        } else {
            listContent
        }
    }

    private var listContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header

                if tripPassStore.passes.isEmpty {
                    emptyState
                } else {
                    HeroTripCard(pass: tripPassStore.passes[0]) {
                        selectedPass = tripPassStore.passes[0]
                    }
                    .padding(.horizontal, 24)

                    if tripPassStore.passes.count > 1 {
                        SectionLabel(title: "Later")
                            .padding(.top, 24)

                        VStack(spacing: 0) {
                            ForEach(tripPassStore.passes.dropFirst()) { pass in
                                TripRow(pass: pass, onTap: { selectedPass = pass })

                                Divider()
                                    .background(Color.appBorder.opacity(0.4))
                                    .padding(.leading, 24 + 56 + 12)
                            }
                        }
                    }
                }

                // Room so the last row doesn't hide behind the floating tab bar.
                Color.clear.frame(height: 120)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            scrollState.updateOffset(newValue)
        }
        .background(Color.appHomeBackground)
        .task {
            // TripPassStore's own disk cache only gets overwritten once
            // both fetches actually succeed — see its `refresh` doc
            // comment for why an offline failure here must never wipe it.
            async let reservationsOK = reservationsStore.fetchMine()
            async let podsOK = podsStore.fetchPods()
            if await reservationsOK, await podsOK {
                tripPassStore.refresh(
                    reservations: reservationsStore.reservations,
                    pods: podsStore.pods,
                    photosByPodId: podsStore.primaryPhotoByPodId
                )
            }
        }
        .onAppear { scrollState.reset() }
    }

    private var header: some View {
        Text("Pods")
            .font(AppFont.pillLabel(24))
            .fontWeight(.heavy)
            .foregroundColor(.black)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mountain.2")
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text("No upcoming trips yet — reserve a pod to see it here.")
                .font(AppFont.regularLabel(14))
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }
}

/// The next trip, called out — full-width photo, a plain-language
/// countdown ("Tomorrow", "In 5 days") next to the dates so the one thing
/// worth knowing at a glance doesn't need reading the date range to work
/// out.
private struct HeroTripCard: View {
    let pass: TripPass
    let onTap: () -> Void

    private var dateRange: String {
        guard let checkIn = Reservation.date(from: pass.checkIn),
              let checkOut = Reservation.date(from: pass.checkOut) else {
            return "\(pass.checkIn) – \(pass.checkOut)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: checkIn)) – \(formatter.string(from: checkOut))"
    }

    private var countdown: String {
        guard let checkIn = Reservation.date(from: pass.checkIn) else { return "" }
        let today = Calendar.current.startOfDay(for: Date())
        let days = Calendar.current.dateComponents([.day], from: today, to: Calendar.current.startOfDay(for: checkIn)).day ?? 0
        switch days {
        case ..<1: return "Today"
        case 1: return "Tomorrow"
        default: return "In \(days) days"
        }
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                PodPhoto(url: pass.photoURL)
                    .frame(height: 220)
                    .clipped()

                // Bottom-anchored gradient, not a flat scrim over the
                // whole photo — keeps the top of the photo actually
                // visible while still giving the text below enough
                // contrast against whatever's behind it.
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(countdown.uppercased())
                        .font(AppFont.regularLabel(11))
                        .tracking(0.5)
                        .foregroundColor(.white.opacity(0.85))
                    Text(pass.podName)
                        .font(AppFont.pillLabelBold(20))
                        .foregroundColor(.white)
                    Text(dateRange)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.white.opacity(0.85))
                }
                .padding(16)
            }
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.r15, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct TripRow: View {
    let pass: TripPass
    let onTap: () -> Void

    private var dateRange: String {
        guard let checkIn = Reservation.date(from: pass.checkIn),
              let checkOut = Reservation.date(from: pass.checkOut) else {
            return "\(pass.checkIn) – \(pass.checkOut)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: checkIn)) – \(formatter.string(from: checkOut))"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                PodPhoto(url: pass.photoURL)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.r12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(pass.podName)
                        .font(AppFont.pillLabelBold(15))
                        .foregroundColor(.black)
                    Text(dateRange)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.appTextMuted)
                    Text("\(pass.guests) guest\(pass.guests == 1 ? "" : "s")")
                        .font(AppFont.regularLabel(12))
                        .foregroundColor(.appTextMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.appTextMuted)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            // Without this, taps landing on the Spacer between the text
            // block and the chevron report no hit area — same missing-
            // hit-area issue ProfileAccountRow/ProfileMenuRow had.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PodsView()
}
