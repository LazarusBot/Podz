//
//  AddPodView.swift
//  Podz
//
//  Created by Max Prx on 02/09/2026.
//

import SwiftUI
import PhotosUI
import UIKit
import RealityKit
internal import Auth

/// Presented as a sheet from `ProfilePromoCard`'s tap — that tap also
/// flips the current user into a host (see `ProfileView`'s `onTap`), so
/// by the time this is on-screen `AuthManager.shared.profile?.isHost` is
/// already true and `PodsStore.createPod` will be accepted server-side
/// (see SQL/host_accounts.sql's insert policy).
///
/// Five steps of exactly two fields each (basics / location / place /
/// capacity & description / photos), not one long scrollable form — same
/// idea as `PostRegisterOnboardingView`'s `step` + dots (its own
/// `OnboardingPaginationDots`, private to that file, so this has its own
/// small `StepDots` rather than reaching across files for it), adapted to
/// a plain forward/back form instead of a swipeable photo carousel.
struct AddPodView: View {
    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var auth = AuthManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    private let stepCount = 5

    @State private var name = ""
    @State private var podType = ""
    @State private var country = ""
    @State private var region = ""
    @State private var address = ""
    @State private var altitude = ""
    @State private var bedsTotal = 10
    @State private var description = ""
    @State private var selectedPodPhotoItems: [PhotosPickerItem] = []
    @State private var selectedPodPhotos: [UIImage] = []
    @State private var scannedModelURL: URL?
    @State private var isShowingScanCapture = false
    @State private var isSubmitting = false
    @State private var didSucceed = false
    @State private var errorMessage: String?

    /// Gates the Next/Create button per step — only `pods`' actual
    /// `not null` columns (name, pod_type, country) block advancing;
    /// everything else on this form is optional, same as `Pod` itself
    /// (photos included — a host who wants to add them later can, this
    /// screen just isn't the only chance to).
    private var canAdvance: Bool {
        switch step {
        case 0: !name.trimmed.isEmpty && !podType.trimmed.isEmpty
        case 1: !country.trimmed.isEmpty
        default: true
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(action: { dismiss() })
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Loading, then success, replace the whole step/form/footer
            // block below — not just a spinner inside the button — so
            // tapping "Create pod" reads as a real state change instead
            // of the sheet just sitting there while something happens in
            // the background. Same two-state idea as ReservationSheet's
            // own formState/confirmationState, adapted with an explicit
            // loading state in between since this call also uploads
            // photos, which takes long enough to want its own feedback
            // rather than jumping straight to "done."
            if didSucceed {
                successState
            } else if isSubmitting {
                loadingState
            } else {
                form
            }
        }
        // On the root view itself, not just the ScrollView inside it —
        // the ScrollView's own `.frame(maxHeight: .infinity)` wasn't
        // enough on its own to make the footer land on the true bottom
        // edge of the sheet; forcing the whole VStack to claim the sheet's
        // full proposed height (its `.medium`/`.large` detent) is what
        // actually pins it, rather than the VStack sizing itself down to
        // its content's own ideal height.
        .frame(maxHeight: .infinity)
        .background(Color.appHomeBackground)
        // The footer landing at the true bottom edge (fixed above) was
        // never the actual gap — that's the system's own bottom safe-area
        // inset reserved for the home indicator (~34pt), which no amount
        // of trimming `footer`'s own padding touches, since it's added on
        // top of that inset, not instead of it. Ignoring the safe area
        // here and giving `footer` its own deliberate bottom padding
        // (see there) is what actually puts a number on that distance.
        // `.container` only, not the unlabeled default (`.all`, which
        // also covers `.keyboard`) — ignoring the keyboard's safe area
        // too was what stopped this view from shifting up above it at
        // all, leaving the footer sitting right behind it instead of
        // moving up as it opens.
        .ignoresSafeArea(.container, edges: .bottom)
        .errorAlert($errorMessage, title: "Couldn't create pod")
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    // MARK: - Form (the pre-submit state)

    private var form: some View {
        VStack(spacing: 0) {
            // "Step X/Y" as the title itself, dots underneath — the count
            // carries the same "where am I" info as the dots, so a third,
            // different per-step caption on top of both would be one
            // signal too many.
            Text("Step \(step + 1)/\(stepCount)")
                .font(AppFont.regularLabel(16))
                .foregroundColor(.appTextMuted)
                .padding(.top, 12)

            StepDots(count: stepCount, activeIndex: step)
                .padding(.top, 8)

            // ScrollView fills the remaining space and pushes `footer`
            // to the true bottom edge, not just wherever the last field
            // happens to end — a fixed-height VStack member (the footer)
            // after a flexible one always lands at the bottom this way.
            ScrollView {
                Group {
                    switch step {
                    case 0: basicsStep
                    case 1: locationStep
                    case 2: placeStep
                    case 3: detailsStep
                    default: photosStep
                    }
                }
                .padding(.horizontal, 24)
                // More air above the fields than before — was 16, right
                // under the dots; the title/dots block and the fields now
                // read as two distinct groups instead of one crowded
                // block.
                .padding(.top, 32)
            }
            .frame(maxHeight: .infinity)

            footer
        }
    }

    // MARK: - Loading / success (the post-submit states)

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
            Text("Creating your pod…")
                .font(AppFont.regularLabel(15))
                .foregroundColor(.appTextMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var successState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 36))
                .foregroundColor(.appAvailableGreen)
            Text("Pod created")
                .font(AppFont.pillLabelBold(16))
                .foregroundColor(.appTextPrimary)
            Text(name)
                .font(AppFont.regularLabel(13))
                .foregroundColor(.appTextMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Steps

    private var basicsStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            FormField(label: "Name", placeholder: "Rifugio Passo Santner", text: $name)
            PickerFormField(label: "Type", placeholder: "Choose a type", selection: $podType, options: Self.podTypeOptions)
        }
    }

    private var locationStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            PickerFormField(label: "Country", placeholder: "Choose a country", selection: $country, options: Self.countryOptions)
            FormField(label: "Region", placeholder: "Süd Tirol", text: $region, isRequired: false)
        }
    }

    /// A short, real vocabulary — not exhaustive, but enough that a host
    /// picks a consistent value instead of typing "Refuge"/"refuge"/"Mtn
    /// hut" for the same kind of place (free text here is exactly what
    /// broke type-based filtering elsewhere in the app).
    private static let podTypeOptions = ["Refuge", "Hut", "Bivouac", "Cabin", "Lodge", "Shelter"]

    /// Real country names from Foundation's own locale data, not a
    /// hand-typed list — `NSLocale.isoCountryCodes` is ISO 3166-1 alpha-2
    /// codes only (actual countries, no continents/regions mixed in,
    /// unlike some newer `Locale.Region` listings).
    private static let countryOptions: [String] = {
        NSLocale.isoCountryCodes
            .compactMap { Locale.current.localizedString(forRegionCode: $0) }
            .sorted()
    }()

    private var placeStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            FormField(label: "Address", placeholder: "Passo Santner, Italy", text: $address, isRequired: false)
            FormField(label: "Altitude (m)", placeholder: "2734", text: $altitude, isRequired: false, keyboardType: .numberPad)
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 10) {
                // Same treatment as `SectionLabel` (uppercase, itemTitle
                // 12, 0.5 tracking, appTextMuted) — see `FormField`'s own
                // doc comment for why it's inlined here rather than using
                // that type directly.
                Text("Beds total".uppercased())
                    .font(AppFont.regularLabel(12))
                    .tracking(0.5)
                    .foregroundColor(.appTextMuted)
                StepperControl(value: $bedsTotal, range: 1...200, label: "beds")
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Description".uppercased())
                    .font(AppFont.regularLabel(12))
                    .tracking(0.5)
                    .foregroundColor(.appTextMuted)
                TextField("What makes this place worth the hike?", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                    .font(AppFont.mediumLabel(20))
                    .foregroundColor(.appTextPrimary)
                    .padding(.vertical, 8)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.appBorder).frame(height: 1)
                    }
            }
        }
    }

    /// Host avatar reuses `AvatarPicker` as-is — it already uploads to
    /// the `avatars` bucket and calls `AuthManager.updateProfile`
    /// internally on its own (see `ProfileEditView`'s identical usage),
    /// so there's nothing to wire here beyond dropping it in; it's the
    /// same photo shown everywhere else the host's profile appears, not
    /// a separate "host photo" concept. Pod photos are new — same
    /// `PhotosPicker` + thumbnail-grid pattern as `PostComposerView`'s
    /// own `photoPicker`, uploaded by `PodsStore.createPod` once this
    /// step's images are handed to it on submit.
    private var photosStep: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(spacing: 8) {
                AvatarPicker(currentImageURL: auth.profile?.avatarURL, size: 80)
                Text("Your host photo".uppercased())
                    .font(AppFont.regularLabel(12))
                    .tracking(0.5)
                    .foregroundColor(.appTextMuted)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 10) {
                Text("Photos of your pod".uppercased())
                    .font(AppFont.regularLabel(12))
                    .tracking(0.5)
                    .foregroundColor(.appTextMuted)
                podPhotoPicker
            }

            // Only shown when the device can actually run it — no button
            // that's guaranteed to fail the moment it's tapped.
            // `ObjectCaptureSession.isSupported` needs a LiDAR sensor
            // (iPhone 12 Pro+ / LiDAR iPad Pro); hosts without one just
            // don't see this, photos stay their only option.
            if ObjectCaptureSession.isSupported {
                podScanButton
            }
        }
        .fullScreenCover(isPresented: $isShowingScanCapture) {
            PodScanCaptureView(
                onComplete: { url in
                    scannedModelURL = url
                    isShowingScanCapture = false
                },
                onCancel: { isShowingScanCapture = false }
            )
        }
    }

    private var podScanButton: some View {
        Button {
            isShowingScanCapture = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: scannedModelURL == nil ? "cube.transparent" : "checkmark.circle.fill")
                Text(scannedModelURL == nil ? "Scan your pod in 3D (optional)" : "3D scan captured")
                    .font(AppFont.mediumLabel(14))
            }
            .foregroundColor(scannedModelURL == nil ? .appTextMuted : .black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: AppRadius.r14).fill(Color.appIconButtonBackground))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.r14).strokeBorder(Color.appBorder, lineWidth: 1))
        }
    }

    private let podPhotoTileSize: CGFloat = 90

    private var podPhotoPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Top/trailing padding reserves room for each thumbnail's
                // remove button, which pokes outside its own frame — same
                // reasoning as PostComposerView's identical photoPicker.
                PhotosPicker(selection: $selectedPodPhotoItems, maxSelectionCount: 6, matching: .images) {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 24))
                        Text("Add")
                            .font(AppFont.mediumLabel(12))
                    }
                    .foregroundColor(.appTextMuted)
                    .frame(width: podPhotoTileSize, height: podPhotoTileSize)
                    .background(RoundedRectangle(cornerRadius: AppRadius.r14).fill(Color.appIconButtonBackground))
                    .overlay(RoundedRectangle(cornerRadius: AppRadius.r14).strokeBorder(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }

                ForEach(Array(selectedPodPhotos.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: podPhotoTileSize, height: podPhotoTileSize)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.r14))

                        Button {
                            selectedPodPhotos.remove(at: index)
                            if index < selectedPodPhotoItems.count { selectedPodPhotoItems.remove(at: index) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: 6, y: -6)
                        .accessibilityLabel("Remove photo")
                    }
                }
            }
            .padding(.top, 7)
            .padding(.trailing, 7)
        }
        .onChange(of: selectedPodPhotoItems) { _, newItems in
            Task { await loadPodPhotos(from: newItems) }
        }
    }

    private func loadPodPhotos(from items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        selectedPodPhotos = images
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                // Same footprint as the primary button below (equal
                // width, same 50pt height) — plain text rather than a
                // second filled/bordered pill of its own, so it still
                // reads as the lesser of the two actions despite matching
                // its size.
                Button(action: { withAnimation(.easeOut(duration: AppMotion.snappy)) { step -= 1 } }) {
                    Text("Back")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.appTextMuted)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
            }

            Button(action: primaryAction) {
                HStack(spacing: 10) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(step == stepCount - 1 ? "Create pod" : "Next")
                            .font(.system(size: 17, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
            }
            .disabled(isSubmitting || !canAdvance)
            .pillStyle(fill: canAdvance ? .appAccentBlack : .appTextMuted, border: .appBorder)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        // The whole sheet now ignores the bottom safe area (see body's
        // own `.ignoresSafeArea(edges: .bottom)`), so this is the entire
        // gap to the true bottom edge — not stacked on top of the
        // system's own ~34pt home-indicator inset like it was before.
        .padding(.bottom, 20)
    }

    private func primaryAction() {
        if step < stepCount - 1 {
            withAnimation(.easeOut(duration: AppMotion.snappy)) { step += 1 }
        } else {
            submit()
        }
    }

    private func submit() {
        isSubmitting = true
        Task {
            guard let hostId = AuthManager.shared.session?.user.id else {
                isSubmitting = false
                errorMessage = "No active session — sign in again to list a pod."
                return
            }
            let inserted = await podsStore.createPod(
                PodInsert(
                    name: name.trimmed,
                    podType: podType.trimmed,
                    country: country.trimmed,
                    region: region.trimmed.isEmpty ? nil : region.trimmed,
                    address: address.trimmed.isEmpty ? nil : address.trimmed,
                    latitude: nil,
                    longitude: nil,
                    altitudeM: Int(altitude.trimmed),
                    bedsTotal: bedsTotal,
                    description: description.trimmed.isEmpty ? nil : description.trimmed,
                    hostId: hostId
                ),
                images: selectedPodPhotos,
                scannedModelURL: scannedModelURL
            )
            isSubmitting = false
            if inserted != nil {
                withAnimation(.easeOut(duration: AppMotion.standard)) {
                    didSucceed = true
                }
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                dismiss()
            } else if let storeError = podsStore.lastError {
                errorMessage = storeError
            }
        }
    }
}

/// Small dot row for this form's own 3 steps — `PostRegisterOnboardingView`
/// already has one (`OnboardingPaginationDots`), but it's `private` to
/// that file and Swift's `private` is file-scoped, not type-scoped, so
/// reaching it from here isn't possible without loosening its access
/// level for a completely unrelated flow. Same visual idea (active dot
/// wider, inactive ones dim), scoped to this file instead.
private struct StepDots: View {
    let count: Int
    let activeIndex: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == activeIndex ? Color.appAccentBlack : Color.appBorder)
                    .frame(width: index == activeIndex ? 20 : 6, height: 6)
            }
        }
    }
}

/// One labeled text field — a plain hairline underline, not a filled
/// capsule/card. A pill background on every one of 6 stacked fields read
/// as a form full of buttons; a bare line under the text keeps the focus
/// on the label/value pair itself. The label itself uses the same
/// treatment as `SectionLabel` (Profile/Friends/MyReservations/
/// PodDetailView's own section eyebrows) — uppercase, `itemTitle(12)`,
/// 0.5 tracking, `appTextMuted` — inlined rather than reaching for that
/// type directly, since `SectionLabel` bakes in its own 24pt horizontal +
/// 20pt top / 6pt bottom padding tuned for sitting directly in a
/// full-bleed list (see PodDetailView's own note on why nesting it inside
/// another padded container double-insets it), not for a field label.
private struct FormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isRequired: Bool = true
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text((isRequired ? label : "\(label) (optional)").uppercased())
                .font(AppFont.regularLabel(12))
                .tracking(0.5)
                .foregroundColor(.appTextMuted)
            // 20, not the old 15 — two fields is all a step holds now,
            // so each one can afford to actually use the space instead of
            // reading as a compact list-row value.
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .font(AppFont.mediumLabel(20))
                .foregroundColor(.appTextPrimary)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.appBorder).frame(height: 1)
                }
        }
    }
}

/// Same label/underline styling as `FormField` — a field that picks from
/// a real, known list (country, pod type) shouldn't invite typing
/// something that isn't one of them. Tapping the value row opens a sheet
/// list instead of the keyboard.
private struct PickerFormField: View {
    let label: String
    let placeholder: String
    @Binding var selection: String
    var isRequired: Bool = true
    let options: [String]

    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text((isRequired ? label : "\(label) (optional)").uppercased())
                .font(AppFont.regularLabel(12))
                .tracking(0.5)
                .foregroundColor(.appTextMuted)
            Button {
                isPresented = true
            } label: {
                HStack {
                    Text(selection.isEmpty ? placeholder : selection)
                        .font(AppFont.mediumLabel(20))
                        .foregroundColor(selection.isEmpty ? .appTextMuted : .appTextPrimary)
                    Spacer(minLength: 12)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.appTextMuted)
                }
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.appBorder).frame(height: 1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $isPresented) {
            PickerListSheet(title: label, options: options, selection: $selection)
        }
    }
}

/// The list itself — searchable, since `countryOptions` alone is ~195
/// rows. A short list (pod type) just renders with nothing to filter.
private struct PickerListSheet: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredOptions: [String] {
        guard !query.isEmpty else { return options }
        return options.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List(filteredOptions, id: \.self) { option in
                Button {
                    selection = option
                    dismiss()
                } label: {
                    HStack {
                        Text(option)
                            .foregroundColor(.appTextPrimary)
                        Spacer()
                        if option == selection {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.appTextPrimary)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

#Preview {
    AddPodView()
}
