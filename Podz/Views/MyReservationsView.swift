//
//  MyReservationsView.swift
//  Podz
//
//  Created by Max Prx on 01/09/2026.
//

import SwiftUI
import CoreLocation

/// Your own reservations — reached from ProfileView's "Reservations" row, and
/// from Lenny's plan once it's booked.
///
/// A trip is a run of stays booked one after the other: those Lenny planned
/// show together on the same numbered line as its summary, under "Planned with
/// Lenny", and are cancelled as one. A stay booked alone is just a row. The
/// page's action is Lenny: "Plan with Lenny" (highlighted while there's
/// nothing here yet). Tap a stay to look at its pod.
struct MyReservationsView: View {
    var onBack: () -> Void

    @StateObject private var reservationsStore = ReservationsStore.shared
    @StateObject private var podsStore = PodsStore.shared
    @State private var pendingCancellation: [Reservation] = []
    @StateObject private var tripPassStore = TripPassStore.shared
    @State private var selectedPod: Pod?
    @State private var selectedPass: TripPass?
    /// Which of Lenny's tips is showing.
    @State private var tipIndex = 0

    private var upcoming: [ReservationTrip] {
        ReservationTrip.group(reservationsStore.reservations.filter { $0.isUpcoming })
    }

    private var past: [Reservation] {
        reservationsStore.reservations
            .filter { !$0.isUpcoming }
            .sorted { $0.checkIn > $1.checkIn }
    }

    private var isEmpty: Bool { reservationsStore.reservations.isEmpty && tripPassStore.passes.isEmpty }

    var body: some View {
        SectionPage(
            title: "Reservations",
            onBack: onBack,
            trailing: {
                DetailTextButton(title: "Plan with Lenny", isHighlighted: isEmpty) {
                    TabRouter.shared.lennyRequested = true
                }
            },
            content: {
                if isEmpty {
                    emptyState
                } else if reservationsStore.reservations.isEmpty {
                    // Offline: the passes saved on the phone are what there is.
                    SectionHeading(title: "Saved on this phone")
                    ForEach(tripPassStore.passes) { pass in
                        savedPassRow(pass)
                    }
                } else {
                    if !upcoming.isEmpty {
                        SectionHeading(title: "Upcoming")
                        ForEach(upcoming) { trip in
                            tripBlock(trip)
                        }
                    }

                    if !past.isEmpty {
                        SectionHeading(title: "Past")
                        ForEach(past) { reservation in
                            stayRow(reservation, number: nil, isLast: true)
                                .opacity(0.6)
                                .overlay(alignment: .bottom) { Hairline().padding(.horizontal, 24) }
                        }
                    }

                    // Room for Lenny's bubble above the pills.
                    if !tips.isEmpty { Color.clear.frame(height: 120) }
                }
            }
        )
        // Lenny talks at the bottom, just above the pill row.
        .overlay(alignment: .bottom) {
            lennyTips
                .padding(.bottom, DetailLayout.controlStackGap + ScreenInsets.bottom + 83 + 10)
        }
        .task { await tripPassStore.refreshFromServer() }
        .fullScreenCover(item: $selectedPod) { pod in
            MinimalPodDetailView(pod: pod, onBack: { selectedPod = nil })
        }
        // An upcoming stay opens its pass (saved on the phone, works offline).
        .fullScreenCover(item: $selectedPass) { pass in
            TripPassView(pass: pass, onBack: { selectedPass = nil })
        }
        .alert(
            pendingCancellation.count > 1 ? "Cancel this trip?" : (pendingCancellation.first?.isExternal == true ? "Remove this stay?" : "Cancel this reservation?"),
            isPresented: Binding(
                get: { !pendingCancellation.isEmpty },
                set: { if !$0 { pendingCancellation = [] } }
            )
        ) {
            Button("Keep it", role: .cancel) {}
            Button(pendingCancellation.count > 1 ? "Cancel trip" : (pendingCancellation.first?.isExternal == true ? "Remove" : "Cancel reservation"), role: .destructive) {
                let stays = pendingCancellation
                Task { for stay in stays { await reservationsStore.cancel(stay) } }
            }
        } message: {
            Text(pendingCancellation.count > 1
                 ? "This cancels all \(pendingCancellation.count) stays and can't be undone."
                 : (pendingCancellation.first?.isExternal == true
                    ? "This only removes it from your list. To cancel the stay itself, tell the hut."
                    : "This can't be undone — you'll need to reserve again if you change your mind."))
        }
    }

    // MARK: - Lenny's tips

    private var tips: [String] {
        guard let next = upcoming.first else { return [] }
        return LennyTripTips.tips(for: next, pods: podsStore.pods)
    }

    /// Lenny talking about the next trip, at the bottom above the pills: one
    /// tip in its bubble (typing, then the text), and a caption to hear another.
    @ViewBuilder
    private var lennyTips: some View {
        if !tips.isEmpty {
            let message = tips[tipIndex % tips.count]
            VStack(alignment: .leading, spacing: 4) {
                LennyReply(message: message, mood: .idle)
                    .padding(.horizontal, 24)

                if tips.count > 1 {
                    Button {
                        withAnimation(.smooth(duration: 0.3)) { tipIndex = (tipIndex + 1) % tips.count }
                    } label: {
                        HStack(spacing: 5) {
                            Text("Another tip")
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
                    // Lined up with the bubble's text, past the avatar.
                    .padding(.leading, 24 + 38 + 18)
                }
            }
        }
    }

    // MARK: - Nothing yet

    /// Lenny's invitation, in place of a bare "No reservations yet".
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 14) {
            LennyAvatar(size: 40)
            Text("No trips yet")
                .font(AppFont.semiBoldLabel(20))
                .foregroundColor(.homeText)
            Text("Tell Lenny where you'd like to go, and for how long. It finds the pods and plans the stays for you.")
                .font(AppFont.regularLabel(14))
                .foregroundColor(.homeSubtitle)
                .lineSpacing(3)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    // MARK: - Saved passes (offline)

    private func savedPassRow(_ pass: TripPass) -> some View {
        Button { selectedPass = pass } label: {
            HStack(spacing: 14) {
                Color.clear
                    .frame(width: 64, height: 64)
                    .overlay { PodPhoto(url: pass.photoURL, coordinate: pass.latitude.flatMap { lat in pass.longitude.map { CLLocationCoordinate2D(latitude: lat, longitude: $0) } }) }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(pass.podName)
                        .font(AppFont.semiBoldLabel(16))
                        .foregroundColor(.homeText)
                        .lineLimit(1)
                    Text("\(pass.rangeText)  ·  \(pass.nights) \(pass.nights == 1 ? "night" : "nights")")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) { Hairline().padding(.horizontal, 24) }
        }
        .buttonStyle(.plain)
    }

    // MARK: - A trip

    private func tripBlock(_ trip: ReservationTrip) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if trip.isPlannedWithLenny {
                HStack(spacing: 8) {
                    LennyAvatar(size: 22)
                    Text("Planned with Lenny")
                        .font(AppFont.semiBoldLabel(13))
                        .foregroundColor(.homeText)
                    Spacer()
                }
                .padding(.horizontal, 24)

                Text("\(Reservation.rangeText(trip.checkIn, trip.checkOut))  ·  \(trip.nights) \(trip.nights == 1 ? "night" : "nights")  ·  \(trip.guests) \(trip.guests == 1 ? "guest" : "guests")")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.homeSubtitle)
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .padding(.bottom, 14)
            }

            ForEach(Array(trip.stays.enumerated()), id: \.element.id) { index, stay in
                stayRow(stay, number: trip.isPlannedWithLenny ? index + 1 : nil, isLast: index == trip.stays.count - 1)
            }

            cancelCaption(trip.isPlannedWithLenny ? "Cancel trip" : (trip.stays[0].isExternal ? "Remove" : "Cancel"))
                .padding(.horizontal, 24)
                .padding(.leading, trip.isPlannedWithLenny ? 38 : 0)
                .onTapGesture { pendingCancellation = trip.stays }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .bottom) { Hairline().padding(.horizontal, 24) }
    }

    private func cancelCaption(_ title: String) -> some View {
        Text(title)
            .font(AppFont.regularLabel(13))
            .foregroundColor(.appBadgeRed)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - A stay

    /// A pod's photo, its name and the nights. With a number it sits on the
    /// trip's numbered dotted line, like Lenny's summary.
    private func stayRow(_ reservation: Reservation, number: Int?, isLast: Bool) -> some View {
        let pod = podsStore.pods.first { $0.id == reservation.podId }
        return Button {
            if reservation.isUpcoming, let pass = tripPassStore.passes.first(where: { $0.reservationId == reservation.id }) {
                selectedPass = pass
            } else if let pod {
                selectedPod = pod
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                if let number {
                    VStack(spacing: 0) {
                        Text("\(number)")
                            .font(AppFont.semiBoldLabel(12))
                            .foregroundColor(.homeBackground)
                            .frame(width: 24, height: 24)
                            .background(Color.homeText, in: Circle())
                        if !isLast {
                            Rectangle()
                                .fill(Color.homeText.opacity(0.25))
                                .frame(width: 1)
                                .mask {
                                    VStack(spacing: 3) {
                                        ForEach(0..<40, id: \.self) { _ in Rectangle().frame(height: 2) }
                                    }
                                }
                                .frame(maxHeight: .infinity)
                                .padding(.top, 6)
                        }
                    }
                    .frame(width: 24)
                }

                HStack(spacing: 14) {
                    Color.clear
                        .frame(width: 64, height: 64)
                        .overlay { PodPhoto(url: podsStore.primaryPhotoByPodId[reservation.podId], coordinate: pod?.coordinate) }
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(pod?.name ?? "Pod")
                            .font(AppFont.semiBoldLabel(16))
                            .foregroundColor(.homeText)
                            .lineLimit(1)
                        Text("\(Reservation.rangeText(reservation.checkIn, reservation.checkOut))  ·  \(reservation.nights) \(reservation.nights == 1 ? "night" : "nights")")
                            .font(AppFont.regularLabel(13))
                            .foregroundColor(.homeSubtitle)
                            .lineLimit(1)
                        if number == nil || reservation.status == "cancelled" {
                            Text("\(reservation.guests) \(reservation.guests == 1 ? "guest" : "guests")" + (reservation.isExternal ? "  ·  Booked with the hut" : "") + (reservation.status == "cancelled" ? "  ·  Cancelled" : ""))
                                .font(AppFont.regularLabel(12))
                                .foregroundColor(reservation.status == "cancelled" ? .appBadgeRed : .homeSubtitle)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.bottom, isLast ? 0 : 20)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, number == nil ? 12 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Lenny's mark on a flat disc, the way it sits in the chat bubble.
struct LennyAvatar: View {
    var size: CGFloat = 30

    var body: some View {
        LennyMark(mood: .idle)
            .frame(width: size / 2, height: size / 2)
            .foregroundColor(.homeBackground)
            .frame(width: size, height: size)
            .background(Color.homeText, in: Circle())
    }
}
