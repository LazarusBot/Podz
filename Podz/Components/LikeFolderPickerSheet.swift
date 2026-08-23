//
//  LikeFolderPickerSheet.swift
//  Podz
//
//  Created by Max Prx on 23/08/2026.
//

import SwiftUI

struct LikeFolderPickerSheet: View {
    let pod: Pod
    var onDismiss: () -> Void

    @ObservedObject private var likesStore = LikesStore.shared
    @State private var isCreatingFolder = false
    @State private var newFolderName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: cancelAndDismiss) {
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

            Text("Save to folder")
                .font(AppFont.pillLabel(20))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.top, 8)
                .padding(.bottom, 20)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                    ForEach(likesStore.folders) { folder in
                        LikesFolderCard(
                            country: folder.name,
                            pods: likesStore.pods(in: folder.id, from: PodsStore.shared.pods),
                            photoURLs: PodsStore.shared.primaryPhotoByPodId,
                            scale: 0.8,
                            onTap: { saveLike(into: folder.id) }
                        )
                    }

                    if isCreatingFolder {
                        LikesFolderCard(
                            pods: [],
                            scale: 0.8,
                            editableName: $newFolderName,
                            onCommitName: commitNewFolder
                        )
                    } else {
                        newFolderTile
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer(minLength: 0)
        }
        .background(Color.appHomeBackground)
    }

    /// Dashed-outline empty folder tile — tap to start creating.
    private var newFolderTile: some View {
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                isCreatingFolder = true
                newFolderName = ""
            }
        } label: {
            VStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(.appTextMuted.opacity(0.5))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.appTextMuted)
                    )
                    .padding(.top, 8)

                Text("New folder")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.appTextMuted)
            }
            .scaleEffect(0.8)
        }
        .buttonStyle(.plain)
    }

    private func commitNewFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            // Empty name on submit — cancel, back to the normal grid.
            withAnimation(.easeOut(duration: 0.2)) {
                isCreatingFolder = false
            }
            return
        }

        Task {
            if let folder = await likesStore.createFolder(name: trimmed) {
                await likesStore.like(pod, folderId: folder.id)
            }
            onDismiss()
        }
    }

    private func saveLike(into folderId: UUID) {
        Task {
            await likesStore.like(pod, folderId: folderId)
            onDismiss()
        }
    }

    private func cancelAndDismiss() {
        isCreatingFolder = false
        onDismiss()
    }
}
