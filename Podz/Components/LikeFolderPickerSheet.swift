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
    /// Which folder a tap just targeted — drives the small floating
    /// photo drop-in below, local to that one card only (no cross-view
    /// position tracking needed since the animation starts and ends on
    /// the same card).
    @State private var savingIntoFolderId: UUID?
    @State private var dropStage = FolderDropValues.start

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(style: .pill, size: 44, action: cancelAndDismiss)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Text("Save to folder")
                .font(AppFont.semiBoldLabel(20))
                .foregroundColor(.homeText)
                .padding(.top, 8)
                .padding(.bottom, 20)

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(likesStore.folders) { folder in
                        LikesFolderCard(
                            country: folder.name,
                            folderId: folder.id,
                            pods: likesStore.pods(in: folder.id, from: PodsStore.shared.pods),
                            onTap: { saveLike(into: folder.id) },
                            // On top of the drawer: the photo lands on its
                            // handle and shrinks away. Positioned in
                            // fractions of the drawer's width, from its
                            // bottom-center.
                            incomingDropContent: folder.id == savingIntoFolderId ? { width in
                                AnyView(
                                    FolderFanPhoto(url: PodsStore.shared.primaryPhotoByPodId[pod.id], side: width * 0.24)
                                        .scaleEffect(dropStage.scale)
                                        .rotationEffect(.degrees(dropStage.rotationDegrees))
                                        .offset(x: dropStage.xFraction * width, y: dropStage.yFraction * width)
                                        .allowsHitTesting(false)
                                )
                            } : nil
                        )
                        // The freshly-created folder pops in with its pod
                        // already inside instead of just silently
                        // appearing — the "put the pod in it" moment
                        // commitNewFolder() is pausing to let play out.
                        .transition(.scale(scale: 0.7).combined(with: .opacity))
                    }

                    if isCreatingFolder {
                        LikesFolderCard(
                            pods: [],
                            editableName: $newFolderName,
                            onCommitName: commitNewFolder
                        )
                        .transition(.opacity)
                    } else {
                        newFolderTile
                            .padding(.top, 22)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            Spacer(minLength: 0)
        }
        .background(Color.homeBackground)
    }

    /// Dashed-outline empty tile — tap to start creating.
    private var newFolderTile: some View {
        Button {
            withAnimation(.easeOut(duration: AppMotion.snappy)) {
                isCreatingFolder = true
                newFolderName = ""
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                Text("New folder")
                    .font(AppFont.semiBoldLabel(14))
            }
            .foregroundColor(.homeSubtitle)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                    .foregroundColor(.homeSubtitle.opacity(0.5))
            )
        }
        .buttonStyle(.plain)
    }

    private func commitNewFolder() {
        let trimmed = newFolderName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            // Empty name on submit — cancel, back to the normal grid.
            withAnimation(.easeOut(duration: AppMotion.snappy)) {
                isCreatingFolder = false
            }
            return
        }

        Task {
            if let folder = await likesStore.createFolder(name: trimmed) {
                await likesStore.like(pod, folderId: folder.id)
            }
            // Let the new folder actually land in the grid instead of
            // the whole sheet vanishing the instant Done is tapped —
            // `folders.append` in createFolder already updated the grid
            // by this point, so reverting the editable tile back to the
            // plain "New folder" one surfaces the real folder — now
            // holding the pod — in its place before dismissing, the same
            // "confirm the tap landed" beat HomeSearchRow's Save button
            // gives its own panel before collapsing. A spring instead of
            // the plain easeOut used for the empty-name cancel path
            // below, so the folder reads as popping into place with the
            // pod inside it rather than just fading in.
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                isCreatingFolder = false
            }
            try? await Task.sleep(nanoseconds: 650_000_000)
            onDismiss()
            // The sheet's own dismiss transition still has to play out
            // after `onDismiss()` flips `isPresented` — waiting out that
            // system animation before flashing is what makes the badge
            // start once the sheet is actually gone, not while it's still
            // sliding down over the tab bar.
            try? await Task.sleep(nanoseconds: 350_000_000)
            likesStore.flashRecentLikeBadge()
        }
    }

    private func saveLike(into folderId: UUID) {
        savingIntoFolderId = folderId
        dropStage = .start
        // A separate tick before the first withAnimation — setting both
        // in the same synchronous block risks SwiftUI coalescing them
        // into a single render, where the overlay is inserted already at
        // its final values with nothing to visibly animate from (the
        // same reason HomeSearchRow's showControls fade-in waits a beat
        // after isFocused before animating in).
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: AppMotion.snappy)) {
                dropStage = .midArc
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Plain easeOut, not a spring — a spring here would
                // overshoot rotation past 42° and bounce back, which
                // reads as changing tumble direction instead of the
                // steady one-way spin the sketch shows.
                withAnimation(.easeOut(duration: 0.22)) {
                    dropStage = .landed
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withAnimation(.easeIn(duration: AppMotion.quick)) {
                        dropStage = .vanished
                    }
                    // The actual data update — and with it, the real
                    // photo's own pop-in transition and the count
                    // badge's roll — waits until *here*, once the decoy
                    // has landed and vanished, rather than firing the
                    // instant the tap registers. Both used to animate at
                    // the same time as the decoy's own flight, so the
                    // real photo's pop-in was playing out hidden behind/
                    // simultaneous with the decoy and never actually
                    // seen on its own.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        Task {
                            await likesStore.like(pod, folderId: folderId)
                            // A beat to actually see the real photo pop
                            // into the fan and the count roll, before
                            // the sheet dismisses.
                            try? await Task.sleep(nanoseconds: 1_500_000_000)
                            onDismiss()
                            // The sheet's own dismiss transition still has
                            // to play out after `onDismiss()` flips
                            // `isPresented` — waiting out that system
                            // animation before flashing is what makes the
                            // badge start once the sheet is actually gone,
                            // not while it's still sliding down over the
                            // tab bar.
                            try? await Task.sleep(nanoseconds: 350_000_000)
                            likesStore.flashRecentLikeBadge()
                        }
                    }
                }
            }
        }
    }

    private func cancelAndDismiss() {
        isCreatingFolder = false
        onDismiss()
    }
}

/// Fixed points the existing-folder "drop" overlay animates through: a fairly
/// direct diagonal descent (not a wide sideways swing), rotating in one
/// direction the whole way down (a tumble, not tilt-overshoot-settle-back).
/// x/yFraction are fractions of the *drawer's width* (handed in through
/// `incomingDropContent`), offset from the tray's bottom-center. start (well
/// above and left, nearly upright), midArc (partway down the same diagonal),
/// landed (on the drawer's handle, a touch smaller), vanished (shrinks to
/// nothing at that spot).
private struct FolderDropValues {
    var scale: CGFloat
    var rotationDegrees: Double
    var xFraction: CGFloat
    var yFraction: CGFloat

    static let start = FolderDropValues(scale: 1.1, rotationDegrees: -4, xFraction: 0.0, yFraction: -1.0)
    static let midArc = FolderDropValues(scale: 0.95, rotationDegrees: 20, xFraction: 0.07, yFraction: -0.5)
    static let landed = FolderDropValues(scale: 0.8, rotationDegrees: 42, xFraction: 0.12, yFraction: -0.03)
    static let vanished = FolderDropValues(scale: 0.15, rotationDegrees: 42, xFraction: 0.12, yFraction: -0.03)
}
