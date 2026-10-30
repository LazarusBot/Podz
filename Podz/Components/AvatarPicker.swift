//
//  AvatarPicker.swift
//  Podz
//
//  Created by Max Prx on 19/08/2026.
//

import SwiftUI
import PhotosUI
internal import Auth
import Storage
import Supabase

/// Tap the avatar (or flip `isPickerPresented` from outside, `isInteractive`
/// false) → pick a photo → uploads to Supabase Storage → updates the
/// profile row automatically. Drop this in place of a plain AvatarView
/// anywhere you want the picture to be editable.
struct AvatarPicker: View {
    var currentImageURL: String?
    var size: CGFloat = 42
    /// Nil (default) clips to a circle, matching `AvatarView`'s own
    /// default — a value switches to a rounded square at that radius
    /// instead, e.g. ProfileEditView's own header avatar.
    var cornerRadius: CGFloat? = nil
    /// See `AvatarView.showsStroke` — passed straight through.
    var showsStroke: Bool = true
    /// Lets a second control open this same picker — e.g. ProfileEditView's
    /// header "edit profile picture" button triggers the identical upload
    /// flow as tapping the avatar itself, rather than each wiring up its
    /// own separate picker and upload logic. Nil (default) falls back to
    /// purely internal state, matching every call site this had before
    /// this parameter existed.
    var isPickerPresented: Binding<Bool>? = nil
    /// False renders a plain, non-interactive avatar — no tap gesture, no
    /// camera badge — driven entirely by `isPickerPresented` from outside
    /// instead. E.g. ProfileEditView's own header avatar, which is only
    /// ever edited via the header's shared "edit photo" menu, not by
    /// tapping the avatar directly. True (default) matches every call
    /// site this had before the parameter existed.
    var isInteractive: Bool = true

    @State private var internalPickerPresented = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var errorMessage: String?

    private var pickerPresented: Binding<Bool> {
        isPickerPresented ?? $internalPickerPresented
    }

    var body: some View {
        Group {
            if isInteractive {
                Button {
                    pickerPresented.wrappedValue = true
                } label: {
                    avatarContent
                }
                .disabled(isUploading)
                .accessibilityLabel("Change profile photo")
            } else {
                avatarContent
            }
        }
        .photosPicker(isPresented: pickerPresented, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await upload(item: newItem) }
        }
        .alert("Upload failed", isPresented: .constant(errorMessage != nil), actions: {
            Button("OK") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
    }

    private var avatarContent: some View {
        ZStack {
            AvatarView(imageName: currentImageURL, size: size, cornerRadius: cornerRadius, showsStroke: showsStroke)

            if isUploading {
                Circle()
                    .fill(Color.black.opacity(0.4))
                    .frame(width: size, height: size)
                ProgressView().tint(.white).scaleEffect(0.6)
            } else if isInteractive {
                // Small camera badge, bottom-right corner
                CameraBadge(size: size)
                    .offset(x: size * 0.32, y: size * 0.32)
            }
        }
    }

    private func upload(item: PhotosPickerItem) async {
        guard let userId = AuthManager.shared.session?.user.id else { return }

        isUploading = true
        defer { isUploading = false }

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let uiImage = UIImage(data: data),
                  let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
                errorMessage = "Couldn't read that image."
                return
            }

            let path = "\(userId.uuidString.lowercased())/avatar.jpg"

            try await supabase.storage
                .from("avatars")
                .upload(path, data: jpegData, options: FileOptions(contentType: "image/jpeg", upsert: true))

            let publicURL = try supabase.storage.from("avatars").getPublicURL(path: path)

            // Cache-bust so the new photo shows immediately instead of a
            // stale cached version at the same URL.
            let bustedURL = "\(publicURL.absoluteString)?t=\(Date().timeIntervalSince1970)"

            await AuthManager.shared.updateProfile(avatarURL: bustedURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// The pencil badge on the avatar's corner: the flat round pill from
/// `design.md`.
private struct CameraBadge: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "pencil")
            .font(.system(size: size * 0.16))
            .foregroundColor(.homeText.opacity(0.6))
            .frame(width: size * 0.34, height: size * 0.34)
            .background(Circle().fill(Color.homePill.opacity(0.95)))
            .overlay(Circle().strokeBorder(Color.homeBackground, lineWidth: 1))
    }
}
