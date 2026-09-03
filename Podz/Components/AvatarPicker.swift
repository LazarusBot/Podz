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

/// Tap the avatar → pick a photo → uploads to Supabase Storage →
/// updates the profile row automatically. Drop this in place of a plain
/// AvatarView anywhere you want the picture to be editable.
struct AvatarPicker: View {
    var currentImageURL: String?
    var size: CGFloat = 42

    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var errorMessage: String?

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                AvatarView(imageName: currentImageURL, size: size)

                if isUploading {
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: size, height: size)
                    ProgressView().tint(.white).scaleEffect(0.6)
                } else {
                    // Small camera badge, bottom-right corner
                    CameraBadge(size: size)
                        .offset(x: size * 0.32, y: size * 0.32)
                }
            }
        }
        .disabled(isUploading)
        .accessibilityLabel("Change profile photo")
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

/// Camera badge on the avatar's corner, in real Liquid Glass — matches
/// Figma's pencil/camera button style. Falls back to a plain material
/// circle pre-iOS 26.
private struct CameraBadge: View {
    let size: CGFloat

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                GlassEffectContainer {
                    icon
                        .glassEffect(.regular.tint(.white.opacity(0.1)), in: .circle)
                }
            } else {
                icon
                    .background(
                        Circle()
                            .fill(.ultraThinMaterial)
                            .overlay(Circle().fill(Color.black.opacity(0.1)))
                    )
            }
        }
        .overlay(Circle().strokeBorder(Color.white, lineWidth: 1))
    }

    private var icon: some View {
        Image(systemName: "pencil")
            .font(.system(size: size * 0.16))
            .foregroundColor(.black)
            .frame(width: size * 0.34, height: size * 0.34)
    }
}
