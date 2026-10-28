//
//  ReservationSheet.swift
//  Podz
//
//  Created by Max Prx on 01/09/2026.
//

import SwiftUI

/// Book a stay at this pod — no payment collected (see SQL/reservations.sql).
/// Grows in place inside PodDetailView's `reservationBar` (same pattern as
/// CategoryScroller's `filtersPanel` growing inside HomeSearchRow) rather
/// than presenting as a separate sheet — no header of its own since the
/// bar's own pod-name row already establishes context above it.
struct ReservationSheet: View {
    let pod: Pod
    /// Same `beds_available_now` RPC result PodDetailView's header pill
    /// and Reserve button already use (see its own doc comment there) —
    /// passed through so the guest stepper's ceiling matches what the
    /// server will actually accept instead of the pod's static total.
    /// The capacity-enforcing trigger in SQL/reservations.sql is the
    /// real backstop either way (it rejects overbooking server-side,
    /// race conditions included) — this just means a doomed guest count
    /// gets caught by the stepper's own bound instead of surfacing only
    /// after a round trip and a failed insert. `nil` (e.g. while it's
    /// still loading) falls back to the static total, same as elsewhere.
    var liveBedsAvailable: Int? = nil
    /// Collapses the bar back down — either PodDetailView's own toggle
    /// button fires this directly, or (from `submit()`) a successful
    /// reservation auto-collapses it after the confirmation state has
    /// shown for a moment.
    var onDismiss: () -> Void = {}

    @StateObject private var reservationsStore = ReservationsStore.shared
    @StateObject private var podsStore = PodsStore.shared

    @State private var checkIn = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var checkOut = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var guests = 1
    @State private var isSubmitting = false
    @State private var didSucceed = false
    /// Drives `confirmationState`'s own two-beat entrance — the pod photo
    /// springs in first, the checkmark badge lands on top a moment later.
    @State private var showConfirmationPhoto = false
    @State private var showConfirmationBadge = false

    /// The tighter of the pod's static total and its live availability —
    /// falls back to a sensible cap when neither is known, since
    /// StepperControl needs a real upper bound regardless.
    private var maxGuests: Int {
        let staticCapacity = pod.bedsTotal ?? 8
        guard let liveBedsAvailable else { return max(staticCapacity, 1) }
        return max(min(staticCapacity, liveBedsAvailable), 1)
    }

    private var nights: Int {
        max(Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 0, 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            dragIndicator
            if didSucceed {
                confirmationState
            } else {
                formState
            }
        }
    }

    /// Same grabber a real `.sheet(presentationDragIndicator: .visible)`
    /// would draw — signals this panel can be swiped down to dismiss,
    /// which isn't otherwise obvious now that it's plain inline content
    /// instead of an actual sheet presentation.
    private var dragIndicator: some View {
        Capsule()
            .fill(Color.appBorder)
            .frame(width: 36, height: 4)
            .padding(.top, 8)
            .padding(.bottom, 2)
    }

    private var formState: some View {
        VStack(spacing: 14) {
            FilterRow(title: "Check-in", helper: "Date of arrival at \(pod.name).") {
                DatePicker("", selection: $checkIn, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
                    .tint(.appAccentBlack)
                    .onChange(of: checkIn) { _, new in
                        // Checkout can't precede check-in — nudge it
                        // forward instead of letting the form sit in
                        // an invalid state the "in:" bound below would
                        // otherwise just silently clamp on next open.
                        if checkOut <= new {
                            checkOut = Calendar.current.date(byAdding: .day, value: 1, to: new) ?? new
                        }
                    }
            }

            FilterRow(title: "Checkout", helper: "Date of leaving \(pod.name).") {
                DatePicker("", selection: $checkOut, in: checkIn..., displayedComponents: .date)
                    .labelsHidden()
                    .tint(.appAccentBlack)
            }

            FilterRow(title: "Guests", helper: "Number of beds to reserve.") {
                StepperControl(value: $guests, range: 1...maxGuests, showsValueBackground: false, label: "guests")
            }

            if nights > 0 {
                Text("\(nights) night\(nights == 1 ? "" : "s")")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.appTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }

            if let error = reservationsStore.lastError {
                ErrorBanner(message: error)
            }

            Button(action: submit) {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("Confirm reservation")
                            .font(.system(size: 15, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .disabled(isSubmitting || nights <= 0)
            .pillStyle(fill: .appAccentBlack, border: .appBorder)
            .padding(.top, 8)

            // No payment collected — set expectations up front rather
            // than leaving "what happens after I tap Reserve" implicit.
            Text("No payment is taken now — you'll settle up at the shelter.")
                .font(.system(size: 11))
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 16)
        .animation(.easeOut(duration: AppMotion.snappy), value: reservationsStore.lastError)
    }

    private var confirmationState: some View {
        VStack(spacing: 14) {
            // A full-width photo with the pod's own name on it, not a
            // small circular avatar — the same photo+name-overlay
            // treatment PodsView's own hero trip card uses. A tiny
            // circle read as decorative; this reads as "here's the
            // actual place," which is the point.
            ZStack(alignment: .bottomLeading) {
                PodPhoto(url: podsStore.primaryPhotoByPodId[pod.id])
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipped()

                // Bottom-anchored gradient, not a flat scrim — keeps the
                // top of the photo visible while still giving the name
                // below enough contrast to read against whatever's there.
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)

                Text(pod.name)
                    .font(AppFont.pillLabelBold(18))
                    .foregroundColor(.white)
                    .padding(14)
            }
            .frame(height: 150)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.r15, style: .continuous))
            .overlay(alignment: .topTrailing) {
                // The checkmark still shows, just as a stamp in the
                // corner of the photo, arriving a beat after the photo
                // itself has already sprung in.
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.appAvailableGreen)
                    .background(Circle().fill(Color.white).frame(width: 22, height: 22))
                    .padding(10)
                    .scaleEffect(showConfirmationBadge ? 1 : 0.2)
                    .opacity(showConfirmationBadge ? 1 : 0)
            }
            .scaleEffect(showConfirmationPhoto ? 1 : 0.9)
            .opacity(showConfirmationPhoto ? 1 : 0)
            .offset(y: showConfirmationPhoto ? 0 : 8)

            Text("Reservation confirmed")
                .font(AppFont.pillLabelBold(16))
                .foregroundColor(.appTextPrimary)
            Text("\(nights) night\(nights == 1 ? "" : "s") · \(guests) guest\(guests == 1 ? "" : "s")")
                .font(AppFont.regularLabel(13))
                .foregroundColor(.appTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) {
                showConfirmationPhoto = true
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.2)) {
                showConfirmationBadge = true
            }
            // Right as the badge lands — matches ModeSwitchPill/HostTabBar's
            // own convention of a tick on the moment something "commits."
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            let success = await reservationsStore.create(podId: pod.id, checkIn: checkIn, checkOut: checkOut, guests: guests)
            isSubmitting = false
            if success {
                withAnimation(.easeOut(duration: AppMotion.standard)) {
                    didSucceed = true
                }
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                // Fired here, not right after `create()` resolves — see
                // `flashRecentReservationBadge`'s own doc comment.
                reservationsStore.flashRecentReservationBadge()
                onDismiss()
            }
        }
    }
}
