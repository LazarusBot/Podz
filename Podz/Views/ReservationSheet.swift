//
//  ReservationSheet.swift
//  Podz
//
//  Created by Max Prx on 01/09/2026.
//

import SwiftUI

/// Book a stay at a partner pod, with Lenny (`design.md`): Lenny asks, three
/// rows answer (arrival, nights, guests), a short summary shows what will be
/// booked, and the control stack is back plus the highlighted **Reserve**. No
/// payment is collected (see SQL/reservations.sql). Booked, Lenny says so and
/// the pill becomes **View reservations**.
struct ReservationSheet: View {
    let pod: Pod
    /// The `beds_available_now` RPC result: the guest stepper's ceiling matches
    /// what the server will accept. The capacity trigger in
    /// SQL/reservations.sql is the real backstop (it rejects overbooking,
    /// races included); this just catches a doomed count early. `nil`
    /// (loading) falls back to the static total.
    var liveBedsAvailable: Int? = nil
    /// Closes the sheet.
    var onDismiss: () -> Void = {}
    /// Opens Profile > Reservations (the caller closes whatever is behind).
    var onViewReservations: () -> Void = {}

    @StateObject private var reservationsStore = ReservationsStore.shared

    @State private var arrival = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var nights = 2
    @State private var guests = 1
    @State private var isSubmitting = false
    @State private var didSucceed = false

    /// The tighter of the pod's static total and its live availability.
    private var maxGuests: Int {
        let staticCapacity = pod.bedsTotal ?? 8
        guard let liveBedsAvailable else { return max(staticCapacity, 1) }
        return max(min(staticCapacity, liveBedsAvailable), 1)
    }

    private var departure: Date {
        Calendar.current.date(byAdding: .day, value: nights, to: arrival) ?? arrival
    }

    private static let dayFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMM")
        return formatter
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    LennyReply(message: lennyMessage, mood: lennyMood)

                    if didSucceed {
                        confirmation
                    } else {
                        pickers
                        summary
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 190)
            }
            .scrollIndicators(.hidden)

            // Fade into the ground behind the buttons.
            BottomFade()

            HStack(spacing: 13) {
                DetailBackButton(action: onDismiss)
                if didSucceed {
                    DetailTextButton(title: "View reservations", isHighlighted: true, action: onViewReservations)
                } else {
                    DetailTextButton(title: isSubmitting ? "Reserving…" : "Reserve", isHighlighted: true, action: submit)
                        .disabled(isSubmitting)
                        .opacity(isSubmitting ? 0.6 : 1)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .animation(.smooth(duration: 0.3), value: reservationsStore.lastError)
        .sensoryFeedback(.success, trigger: didSucceed) { _, now in now }
        .onAppear { reservationsStore.lastError = nil }
    }

    // MARK: - Lenny

    private var lennyMessage: String? {
        if didSucceed { return "Booked! \(nights) \(nights == 1 ? "night" : "nights") for \(guests) \(guests == 1 ? "guest" : "guests") at \(pod.name). See you up there." }
        if isSubmitting { return nil }
        if let error = reservationsStore.lastError { return error }
        return "Tell me when you arrive, for how long and how many of you, and I'll reserve it."
    }

    private var lennyMood: LennyMood {
        if didSucceed { return .happy }
        if isSubmitting { return .working }
        return reservationsStore.lastError == nil ? .idle : .sorry
    }

    // MARK: - Form

    private var pickers: some View {
        VStack(spacing: 0) {
            StayDateRow(label: "Arrival", date: $arrival)
            StayStepperRow(label: "Nights", value: $nights, range: 1...14, unit: "night")
            StayStepperRow(label: "Guests", value: $guests, range: 1...maxGuests, unit: "guest")
        }
    }

    /// What will be booked, and what it costs today: nothing.
    private var summary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your stay")
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
            VStack(spacing: 0) {
                StaySummaryRow(label: "Dates", value: "\(Self.dayFormat.string(from: arrival)) → \(Self.dayFormat.string(from: departure))")
                if let live = liveBedsAvailable {
                    StaySummaryRow(label: "Beds free tonight", value: "\(live)")
                }
                StaySummaryRow(label: "Payment", value: "At the shelter")
            }
            Text("No payment is taken now.")
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)
                .padding(.top, 4)
        }
    }

    /// The pod's photo under Lenny's "Booked!", as the trip's first stop.
    private var confirmation: some View {
        PodPhoto(url: PodsStore.shared.primaryPhotoByPodId[pod.id], coordinate: pod.coordinate)
            .frame(height: 220)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pod.name)
                        .font(AppFont.semiBoldLabel(18))
                    Text("\(Self.dayFormat.string(from: arrival)) → \(Self.dayFormat.string(from: departure))")
                        .font(AppFont.regularLabel(13))
                }
                .foregroundColor(.white)
                .padding(18)
            }
            .transition(.scale(scale: 0.94).combined(with: .opacity))
    }

    // MARK: - Booking

    private func submit() {
        isSubmitting = true
        Task {
            let success = await reservationsStore.create(podId: pod.id, checkIn: arrival, checkOut: departure, guests: guests)
            isSubmitting = false
            if success {
                withAnimation(.smooth(duration: 0.4)) { didSucceed = true }
                // See `flashRecentReservationBadge`'s own doc comment.
                reservationsStore.flashRecentReservationBadge()
            }
        }
    }
}
