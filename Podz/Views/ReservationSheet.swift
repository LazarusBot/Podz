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

    @StateObject private var reservationsStore = ReservationsStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var checkIn = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @State private var checkOut = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
    @State private var guests = 1
    @State private var isSubmitting = false
    @State private var didSucceed = false

    /// Falls back to a sensible cap when the pod has no recorded bed
    /// count — StepperControl needs a real upper bound regardless.
    private var maxGuests: Int { max(pod.bedsTotal ?? 8, 1) }

    private var nights: Int {
        max(Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 0, 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextMuted)
                        .frame(width: 31, height: 31)
                        .background(Circle().fill(Color(white: 0.93)))
                }
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
                    StepperControl(value: $guests, range: 1...maxGuests, showsValueBackground: false)
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
            .animation(.easeOut(duration: 0.2), value: reservationsStore.lastError)
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
                withAnimation(.easeOut(duration: 0.25)) {
                    didSucceed = true
                }
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                dismiss()
            }
        }
    }
}
