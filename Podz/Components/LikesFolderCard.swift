//
//  LikesFolderCard.swift
//  Podz
//
//  Created by Max Prx on 22/08/2026.
//

import SwiftUI

/// A Likes folder as a colored drawer front (see `FolderDrawer`), with the
/// tap, press, long-press and edit-mode wiggle behavior the folder cards
/// always had.
struct LikesFolderCard: View {
    var country: String? = nil
    /// Picks the drawer's color; the same folder always gets the same one.
    var folderId: UUID? = nil
    var subtitle: String? = nil
    let pods: [Pod]
    var onTap: () -> Void = {}
    /// When set, the label becomes an editable, auto-focused name field —
    /// the "creating a new folder" state in LikeFolderPickerSheet.
    var editableName: Binding<String>? = nil
    var onCommitName: (() -> Void)? = nil
    var showDeleteBadge: Bool = false
    var isWiggling: Bool = false
    var onDelete: () -> Void = {}
    var onLongPress: () -> Void = {}
    /// Extra content layered on top of the drawer; takes its width. Used by
    /// LikeFolderPickerSheet's "drop a pod into this folder" animation; nil
    /// for every other call site.
    var incomingDropContent: ((CGFloat) -> AnyView)? = nil
    /// Avatars of friends this folder is shared with (or its owner, when it
    /// was shared with you), at the drawer's right end.
    var sharedWithAvatarURLs: [String] = []
    @State private var isPressed = false
    @State private var wiggleAngle: Double = 0

    private var isEditing: Bool { editableName != nil }

    var body: some View {
        Group {
            if isEditing {
                tray
            } else {
                Button {
                    guard !showDeleteBadge else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isPressed = false
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        onTap()
                    }
                } label: {
                    tray
                }
                .buttonStyle(NoFadeButtonStyle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isPressed && !showDeleteBadge {
                                withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
                            }
                        }
                        .onEnded { _ in }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .onEnded { _ in
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            onLongPress()
                        }
                )
            }
        }
        .scaleEffect(isPressed ? 0.98 : 1)
        .rotationEffect(.degrees(isWiggling ? wiggleAngle : 0))
        .onChange(of: isWiggling) { _, wiggling in
            if wiggling {
                withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                    wiggleAngle = Double.random(in: 0.8...1.2)
                }
            } else {
                withAnimation(.linear(duration: 0)) { wiggleAngle = 0 }
            }
        }
        .onChange(of: showDeleteBadge) { _, isEditing in
            if !isEditing {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }
    }

    private var tray: some View {
        FolderDrawer(
            name: country ?? "",
            subtitle: subtitle,
            count: pods.count,
            color: FolderColor.forFolder(folderId),
            editableName: editableName,
            onCommitName: onCommitName,
            sharedWithAvatarURLs: sharedWithAvatarURLs,
            incomingDropContent: incomingDropContent,
            showDeleteBadge: showDeleteBadge,
            onDelete: onDelete
        )
    }
}

/// Same as .plain, but explicitly locks opacity to 1 regardless of
/// press state — some system button styles subtly dim content on press
/// even with .plain. The press scale already provides feedback, so no
/// extra dimming is needed on top.
private struct NoFadeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(1)
    }
}
