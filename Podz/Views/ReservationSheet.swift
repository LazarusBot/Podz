//
//  ReservationSheet.swift
//  Podz
//
//  Created by Max Prx on 01/09/2026.
//

import SwiftUI

/// Book a stay at this pod — no payment collected (see SQL/reservations.sql).
/// Presented as a sheet from PodDetailView, same lightweight-overlay
/// pattern as PostComposerView/ShareFolderSheet rather than a pushed
/// screen, since this is a short, self-contained form.
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

    @StateObject private var reservationsStore = ReservationsStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var checkIn = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var checkOut = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var guests = 1
    @State private var isSubmitting = false
    @State private var didSucceed = false

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
            HStack {
                CloseButton(action: { dismiss() })
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Text("Reserve your stay")
                .font(AppFont.pillLabel(20))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Text(pod.name)
                .font(AppFont.mediumLabel(14))
                .foregroundColor(.appTextMuted)
                .padding(.bottom, 16)

            if didSucceed {
                confirmationState
            } else {
                formState
            }
        }
        .background(Color.appHomeBackground)
    }

    private var formState: some View {
        ScrollView {
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
                        .font(AppFont.mediumLabel(13))
                        .foregroundColor(.appTextMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }

                if let error = reservationsStore.lastError {
                    AuthErrorBanner(message: error)
                }

                Button(action: submit) {
                    HStack(spacing: 10) {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Reserve")
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
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, 20)
            .animation(.easeOut(duration: AppMotion.snappy), value: reservationsStore.lastError)
        }
    }

    private var confirmationState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.appAvailableGreen)
            Text("Reservation confirmed")
                .font(AppFont.pillLabelBold(18))
                .foregroundColor(.black)
            Text("\(nights) night\(nights == 1 ? "" : "s") · \(guests) guest\(guests == 1 ? "" : "s")")
                .font(AppFont.mediumLabel(14))
                .foregroundColor(.appTextMuted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 40)
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
                dismiss()
            }
        }
    }
}
