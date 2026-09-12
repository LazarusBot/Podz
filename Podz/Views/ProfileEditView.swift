//
//  ProfileEditView.swift
//  Podz
//
//  Created by Max Prx on 20/08/2026.
//

import SwiftUI
import PhotosUI
import Storage
import Supabase

/// node 3827:1465 — "Profile" edit screen. Reached by tapping the
/// avatar/name row at the top of ProfileView.
struct ProfileEditView: View {
    var onBack: () -> Void

    @StateObject private var auth = AuthManager.shared
    @State private var editingField: EditableField?
    @State private var editValue = ""
    @State private var isEditPhotoMenuPresented = false
    @State private var isAvatarPickerPresented = false
    @State private var isHeaderPickerPresented = false
    @State private var selectedHeaderItem: PhotosPickerItem?
    @State private var isUploadingHeader = false

    /// Falls back to the same generic alpine photo `PostRegisterOnboardingView`/
    /// `OnboardingView` already use for decorative chrome, until a user
    /// sets their own via the header's "Edit header photo" menu item.
    private let headerPhotoHeight: CGFloat = 320
    private let avatarSize: CGFloat = 94

    private enum EditableField {
        case username, name, age, location
        
        var title: String {
            switch self {
            case .username: return "Edit username"
            case .name: return "Edit name"
            case .age: return "Update age"
            case .location: return "Edit location"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerPhoto

            ProfileEditRow(
                value: auth.profile?.username.map { "@\($0)" } ?? "@guest",
                label: "Edit username"
            ) { startEditing(.username, current: auth.profile?.username ?? "") }
            
            ProfileEditRow(
                value: auth.profile?.fullName ?? "—",
                label: "Edit name"
            ) { startEditing(.name, current: auth.profile?.fullName ?? "") }
            
            ProfileEditRow(
                value: auth.profile?.age.map(String.init) ?? "—",
                label: "Update age"
            ) { startEditing(.age, current: auth.profile?.age.map(String.init) ?? "") }
            
            ProfileEditRow(
                value: auth.profile?.location ?? "—",
                label: "Edit location"
            ) { startEditing(.location, current: auth.profile?.location ?? "") }
            
            Spacer()
        }
        .background(Color.appHomeBackground)
        .errorAlert($auth.lastError)
        .alert(
            editingField?.title ?? "",
            isPresented: Binding(get: { editingField != nil }, set: { if !$0 { editingField = nil } })
        ) {
            TextField("", text: $editValue)
                .keyboardType(editingField == .age ? .numberPad : .default)
            Button("Cancel", role: .cancel) { editingField = nil }
            Button("Save") {
                guard let field = editingField else { return }
                let value = editValue
                Task { await save(field: field, value: value) }
            }
        }
        // One shared entry point for both photos — headerPhoto's own
        // pencil button opens this instead of jumping straight to a
        // picker, since it now edits two different things depending on
        // which the person actually meant.
        .confirmationDialog("Edit photo", isPresented: $isEditPhotoMenuPresented, titleVisibility: .visible) {
            Button("Edit header photo") { isHeaderPickerPresented = true }
            Button("Edit profile picture") { isAvatarPickerPresented = true }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $isHeaderPickerPresented, selection: $selectedHeaderItem, matching: .images)
        .onChange(of: selectedHeaderItem) { _, newItem in
            guard let newItem else { return }
            Task { await uploadHeaderPhoto(newItem) }
        }
    }
    
    /// Scenic band behind the top bar, with `avatarRow` overlapping its own
    /// faded-out bottom edge rather than sitting in a separate flat-background
    /// section below it. Only the photo itself ignores the top safe area
    /// (so it bleeds under the status bar) — `ProfileTopBar` and
    /// `avatarRow` are ordinary siblings in the same `ZStack`, which is
    /// what keeps them at their normal, safe-area-respecting position
    /// instead of getting pulled up into the notch along with the photo;
    /// an earlier version ignored the safe area on the whole `ZStack`,
    /// which dragged the back/edit buttons up with it.
    ///
    /// The photo itself is given an explicit width (the real screen
    /// width, not just a height) rather than leaning on
    /// `.aspectRatio(contentMode: .fill)` plus a height alone — with only
    /// a height to go on, the fill computation reported its *own*,
    /// aspect-correct width upward as this view's ideal size, which was
    /// often wider than the screen and dragged every ancestor (this
    /// screen's own rows, and — since nothing between here and
    /// `MainTabView` clips to the device width either — the persistent
    /// bottom tab bar sitting alongside it) wider along with it.
    private var headerPhoto: some View {
        ZStack(alignment: .top) {
            headerImage
                .frame(width: UIScreen.main.bounds.width, height: headerPhotoHeight)
                .clipped()
                .overlay(
                    // Spans the photo's full height, not just its bottom
                    // portion — clear at the very top (0%), fully opaque
                    // `appHomeBackground` by the very bottom (100%).
                    LinearGradient(
                        colors: [.clear, Color.appHomeBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(edges: .top)

            if isUploadingHeader {
                // Same darkened-circle-plus-spinner idea as AvatarPicker's
                // own upload state, just sized to the whole band instead
                // of one small circle.
                Color.black.opacity(0.35)
                    .frame(width: UIScreen.main.bounds.width, height: headerPhotoHeight)
                ProgressView().tint(.white)
            }

            avatarRow
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            ProfileTopBar(
                title: "",
                onBack: onBack,
                trailingIcon: "pencil",
                onTrailingTap: { isEditPhotoMenuPresented = true },
                trailingAccessibilityLabel: "Edit photo",
                transparentBackground: true
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: headerPhotoHeight)
    }

    @ViewBuilder
    private var headerImage: some View {
        if let headerPhotoURL = auth.profile?.headerPhotoURL {
            PodPhoto(url: headerPhotoURL)
        } else {
            Image("bg")
                .resizable()
                .aspectRatio(contentMode: .fill)
        }
    }

    /// Square, borderless avatar (no rounding, no stroke — the photo
    /// behind it is already solid `appHomeBackground` by this point in
    /// the gradient, so the avatar's own edge reads cleanly without one),
    /// purely a display now (`isInteractive: false` — no tap, no camera
    /// badge), bottom-aligned with the name/caption beside it, overlapping
    /// the header photo's own faded lower edge. `headerPhoto`'s own pencil
    /// button is the one place that opens the picker now, via
    /// `AvatarPicker`'s externally-driven `isPickerPresented` binding.
    private var avatarRow: some View {
        HStack(alignment: .bottom, spacing: 15) {
            AvatarPicker(
                currentImageURL: auth.profile?.avatarURL,
                size: avatarSize,
                cornerRadius: 0,
                showsStroke: false,
                isPickerPresented: $isAvatarPickerPresented,
                isInteractive: false
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(auth.profile?.fullName ?? "—")
                    .font(AppFont.mediumLabel(16))
                    .foregroundColor(.black)
                Text("Edit profile picture")
                    .font(AppFont.regularLabel(11))
                    .foregroundColor(.appTextMuted)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private func startEditing(_ field: EditableField, current: String) {
        editValue = current
        editingField = field
    }
    
    private func save(field: EditableField, value: String) async {
        switch field {
        case .username:
            await auth.updateProfile(username: value)
        case .name:
            await auth.updateProfile(fullName: value)
        case .age:
            await auth.updateProfile(age: Int(value))
        case .location:
            await auth.updateProfile(location: value)
        }
    }

    /// Same upload shape as `AvatarPicker`'s own `upload(item:)` — stored
    /// in the same "avatars" bucket under a different filename
    /// ("header.jpg" vs. "avatar.jpg") in the owner's own folder rather
    /// than a separate bucket, so no new storage policy is needed. Not
    /// factored into a shared helper with `AvatarPicker`: the two differ
    /// in storage path, profile field, and (here) no visible
    /// picker/badge UI of its own to fold that logic into.
    private func uploadHeaderPhoto(_ item: PhotosPickerItem) async {
        guard let userId = AuthManager.shared.session?.user.id else { return }

        isUploadingHeader = true
        defer { isUploadingHeader = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
                auth.lastError = "Couldn't read that image."
                return
            }

            let path = "\(userId.uuidString.lowercased())/header.jpg"

            try await supabase.storage
                .from("avatars")
                .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))

            let publicURL = try supabase.storage.from("avatars").getPublicURL(path: path)
            let bustedURL = "\(publicURL.absoluteString)?t=\(Date().timeIntervalSince1970)"

            await auth.updateProfile(headerPhotoURL: bustedURL)
        } catch {
            auth.lastError = error.localizedDescription
        }
    }
}

#Preview {
    ProfileEditView(onBack: {})
}
