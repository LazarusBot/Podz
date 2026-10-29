//
//  MyReservationsView.swift
//  Podz
//
//  Created by Max Prx on 01/09/2026.
//

import SwiftUI

/// Your own reservations — reached from ProfileView's "Reservations" row.
/// Pushed, not a sheet (same manual @State push/pop as FriendsView/
/// MyPostsView) — this is a real destination, not a lightweight overlay.
struct MyReservationsView: View {
    var onBack: () -> Void

    @StateObject private var reservationsStore = ReservationsStore.shared
    @StateObject private var podsStore = PodsStore.shared
    @State private var pendingCancellation: Reservation?

    private var upcoming: [Reservation] {
        reservationsStore.reservations.filter { $0.isUpcoming }
    }

    private var past: [Reservation] {
        reservationsStore.reservations.filter { !$0.isUpcoming }
    }

    var body: some View {
        VStack(spacing: 0) {
            ProfileTopBar(title: "Reservations", onBack: onBack)

            if reservationsStore.reservations.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .font(.system(size: 32))
                        .foregroundColor(.appTextMuted)
                    Text("No reservations yet.")
                        .font(AppFont.regularLabel(14))
                        .foregroundColor(.appTextMuted)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if !upcoming.isEmpty {
                            SectionLabel(title: "Upcoming")
                            VStack(spacing: 0) {
                                ForEach(upcoming) { reservation in
                                    ReservationRow(
                                        reservation: reservation,
                                        pod: podsStore.pods.first { $0.id == reservation.podId },
                                        photoURL: podsStore.primaryPhotoByPodId[reservation.podId],
                                        onCancel: { pendingCancellation = reservation }
                                    )
                                }
                            }
                        }

                        if !past.isEmpty {
                            SectionLabel(title: "Past")
                            VStack(spacing: 0) {
                                ForEach(past) { reservation in
                                    ReservationRow(
                                        reservation: reservation,
                                        pod: podsStore.pods.first { $0.id == reservation.podId },
                                        photoURL: podsStore.primaryPhotoByPodId[reservation.podId],
                                        onCancel: nil
                                    )
                                }
                            }
                        }

                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.appHomeBackground)
        .task { await reservationsStore.fetchMine() }
        .alert("Cancel this reservation?", isPresented: Binding(
            get: { pendingCancellation != nil },
            set: { if !$0 { pendingCancellation = nil } }
        )) {
            Button("Keep it", role: .cancel) {}
            Button("Cancel reservation", role: .destructive) {
                if let pendingCancellation {
                    Task { await reservationsStore.cancel(pendingCancellation) }
                }
            }
        } message: {
            Text("This can't be undone — you'll need to reserve again if you change your mind.")
        }
    }
}

private struct ReservationRow: View {
    let reservation: Reservation
    let pod: Pod?
    let photoURL: String?
    /// nil hides the Cancel button entirely — past/cancelled reservations
    /// aren't actionable.
    var onCancel: (() -> Void)?

    private var dateRange: String {
        guard let checkIn = Reservation.date(from: reservation.checkIn),
              let checkOut = Reservation.date(from: reservation.checkOut) else {
            return "\(reservation.checkIn) – \(reservation.checkOut)"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return "\(formatter.string(from: checkIn)) – \(formatter.string(from: checkOut))"
    }

    var body: some View {
        HStack(spacing: 12) {
            PodPhoto(url: photoURL)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.r12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(pod?.name ?? "Pod")
                    .font(AppFont.pillLabelBold(15))
                    .foregroundColor(.black)
                Text(dateRange)
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.appTextMuted)
                Text("\(reservation.guests) guest\(reservation.guests == 1 ? "" : "s")" + (reservation.status == "cancelled" ? " · Cancelled" : ""))
                    .font(AppFont.regularLabel(12))
                    .foregroundColor(reservation.status == "cancelled" ? .red : .appTextMuted)
            }

            Spacer()

            if let onCancel {
                Button(action: onCancel) {
                    Text("Cancel")
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.appBadgeRed)
                        .padding(.horizontal, 16)
                        .frame(height: 38)
                        .background(Capsule().fill(Color.homePill.opacity(0.95)))
                        .overlay(Capsule().strokeBorder(Color.homeBackground, lineWidth: 1))
                }
                .buttonStyle(TapScaleButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
        }
    }
}
