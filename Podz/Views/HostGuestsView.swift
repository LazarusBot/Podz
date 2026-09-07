//
//  HostGuestsView.swift
//  Podz
//
//  Created by Max Prx on 03/09/2026.
//

import SwiftUI

/// The "Guests" tab inside `HostTabView` — every reservation made
/// against any pod this host owns, split Upcoming/Past the same way
/// `MyReservationsView` already does for the guest side. Read-only for
/// now: showing who's coming is the actual gap this tab was built to
/// close (see the conversation this shell came out of — "manage
/// hikers"); letting a host cancel someone else's reservation is a
/// different, more sensitive feature (does the guest get notified? is a
/// reason required?) that deserves its own pass rather than riding along
/// here.
struct HostGuestsView: View {
    @StateObject private var reservationsStore = ReservationsStore.shared

    private var upcoming: [Reservation] {
        reservationsStore.hostedReservations.filter { $0.isUpcoming }
    }

    private var past: [Reservation] {
        reservationsStore.hostedReservations.filter { !$0.isUpcoming }
    }

    var body: some View {
        VStack(spacing: 0) {
            ProfileTopBar(title: "Guests")

            if reservationsStore.hostedReservations.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "person.2")
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
                                    GuestReservationRow(
                                        reservation: reservation,
                                        guest: reservationsStore.profilesById[reservation.userId],
                                        podName: PodsStore.shared.pods.first { $0.id == reservation.podId }?.name
                                    )
                                }
                            }
                        }

                        if !past.isEmpty {
                            SectionLabel(title: "Past")
                            VStack(spacing: 0) {
                                ForEach(past) { reservation in
                                    GuestReservationRow(
                                        reservation: reservation,
                                        guest: reservationsStore.profilesById[reservation.userId],
                                        podName: PodsStore.shared.pods.first { $0.id == reservation.podId }?.name
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
        .task { await reservationsStore.fetchForHostedPods() }
    }
}

private struct GuestReservationRow: View {
    let reservation: Reservation
    let guest: Profile?
    /// Which of the host's (possibly several) pods this booking is
    /// against — a guest-only view doesn't need this since it's always
    /// their own pod photo/name already shown; a host with more than one
    /// pod does.
    let podName: String?

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
            AvatarView(imageName: guest?.avatarURL, size: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text(guest?.displayName ?? "Guest")
                    .font(AppFont.pillLabelBold(15))
                    .foregroundColor(.appTextPrimary)
                if let podName {
                    Text(podName)
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.appTextMuted)
                }
                Text(dateRange + " · \(reservation.guests) guest\(reservation.guests == 1 ? "" : "s")" + (reservation.status == "cancelled" ? " · Cancelled" : ""))
                    .font(AppFont.regularLabel(12))
                    .foregroundColor(reservation.status == "cancelled" ? .red : .appTextMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
        }
    }
}

#Preview {
    HostGuestsView()
}
