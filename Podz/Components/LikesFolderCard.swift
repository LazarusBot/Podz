//
//  LikesFolderCard.swift
//  Podz
//
//  Created by Max Prx on 22/08/2026.
//

import SwiftUI

/// A Likes folder: a flat tray (see `FolderTray`) with the pod photos
/// standing in it, and the folder's name below.
struct LikesFolderCard: View {
    var country: String? = nil
    let pods: [Pod]
    var photoURLs: [UUID: String] = [:]
    var scale: CGFloat = 1
    /// Base point size for the folder name label/field, before `scale`.
    /// Overridable per call site — LikeFolderPickerSheet wants it larger
    /// than the default LikesView grid does.
    var nameFontSize: CGFloat = 16
    var onTap: () -> Void = {}
    /// When set, the caption becomes an editable, auto-focused TextField
    /// instead of static text — used for the "creating a new folder"
    /// state in LikeFolderPickerSheet.
    var editableName: Binding<String>? = nil
    var onCommitName: (() -> Void)? = nil
    var showDeleteBadge: Bool = false
    var isWiggling: Bool = false
    var onDelete: () -> Void = {}
    var onLongPress: () -> Void = {}
    /// Extra content layered between the fanned photos and the opaque
    /// front panel — i.e. genuinely *behind* the front panel, not just
    /// drawn on top of this whole card from outside. Takes this view's
    /// own measured `side` (the icon's square size) so a caller can
    /// position/size things correctly without re-measuring or guessing
    /// it externally. Used by LikeFolderPickerSheet's "drop a pod into
    /// this folder" animation, which needs to visually duck behind the
    /// front panel as it lands — nil for every other call site.
    var incomingDropContent: ((CGFloat) -> AnyView)? = nil
    /// Avatars of friends this folder is currently shared with (read-only
    /// access, see ShareFolderSheet) — shown as a small overlapping stack
    /// on the front panel's bottom-leading corner, mirroring the count
    /// badge's own bottom-trailing corner.
    var sharedWithAvatarURLs: [String] = []
    @State private var isPressed = false
    @State private var wiggleAngle: Double = 0
    @FocusState private var isNameFocused: Bool
    
    private var previewPods: [Pod] { Array(pods.prefix(3)) }
    private var isEditing: Bool { editableName != nil }
    
    var body: some View {
        Group {
            if isEditing {
                folderVisual
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
                    folderVisual
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
        .rotationEffect(.degrees(isWiggling ? wiggleAngle : 0))
        .onChange(of: isWiggling) { _, wiggling in
            if wiggling {
                withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                    wiggleAngle = Double.random(in: 1.2...1.8)
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
    private var folderVisual: some View {
        VStack(spacing: 10) {
            FolderTray(
                previewPods: previewPods,
                photoURLs: photoURLs,
                totalCount: pods.count,
                sharedWithAvatarURLs: sharedWithAvatarURLs,
                incomingDropContent: incomingDropContent,
                showDeleteBadge: showDeleteBadge,
                scale: scale,
                onDelete: onDelete
            )
            .padding(.top, 8)
            
            if let editableName {
                TextField("Folder name", text: editableName)
                    .font(AppFont.pillLabel(nameFontSize * scale))
                    .fontWeight(.semibold)
                    .foregroundColor(.homeText)
                    .multilineTextAlignment(.center)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit { onCommitName?() }
                    .onAppear { isNameFocused = true }
            } else {
                Text(country ?? "")
                    .font(AppFont.pillLabel(nameFontSize * scale))
                    .fontWeight(.semibold)
                    .foregroundColor(.homeText)
                    .lineLimit(1)
            }
        }
        .scaleEffect(scale)
    }
}

/// Same as .plain, but explicitly locks opacity to 1 regardless of
/// press state — some system button styles subtly dim content on press
/// even with .plain, which fought against the folder's own base
/// transparency. The photo/panel animations already provide press
/// feedback, so no extra dimming is needed on top.
private struct NoFadeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(1)
    }
}
