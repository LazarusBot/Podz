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

    /// Zig-zag from the Paper frame: bubble centers alternate between 31% and
    /// 85.5% of the width, 253pt apart, the first one 177pt below the top of
    /// the scrolling area.
    private static let step: CGFloat = 253
    private static let firstCenterY: CGFloat = 177
    /// Room under the last bubble for the buttons.
    private static let bottomRoom: CGFloat = 170

    /// The folders to draw, plus the one being named, if any.
    private var bubbleCount: Int { likesStore.folders.count + (isCreatingFolder ? 1 : 0) }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                Text("Save to folder")
                    .font(AppFont.semiBoldLabel(30))
                    .tracking(-0.6)
                    .foregroundColor(.homeText)
                    .padding(.top, 36)
                    .padding(.bottom, 12)

                GeometryReader { proxy in
                    ScrollView {
                        bubbles(width: proxy.size.width)
                            .frame(
                                width: proxy.size.width,
                                height: Self.firstCenterY + Self.step * CGFloat(max(bubbleCount - 1, 0))
                                    + FolderBubble.diameter / 2 + Self.bottomRoom,
                                alignment: .topLeading
                            )
                    }
                }
            }

            actionRow
                .padding(.bottom, 40)
        }
        .background(Color.homeBackground)
    }

    private func bubbles(width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(likesStore.folders.enumerated()), id: \.element.id) { index, folder in
                FolderBubble(
                    name: folder.name,
                    pods: likesStore.pods(in: folder.id, from: PodsStore.shared.pods),
                    photoURLs: PodsStore.shared.primaryPhotoByPodId,
                    mirrored: index % 2 == 1,
                    // The photo falls onto the bubble and shrinks into it.
                    // Positioned in fractions of the bubble's diameter,
                    // from its center.
                    incomingDropContent: folder.id == savingIntoFolderId ? { diameter in
                        AnyView(
                            BubblePhoto(url: PodsStore.shared.primaryPhotoByPodId[pod.id])
                                .scaleEffect(dropStage.scale)
                                .rotationEffect(.degrees(dropStage.rotationDegrees))
                                .offset(x: dropStage.xFraction * diameter, y: dropStage.yFraction * diameter)
                                .allowsHitTesting(false)
                        )
                    } : nil,
                    onTap: { saveLike(into: folder.id) }
                )
                .position(center(forBubble: index, width: width))
                // The freshly-created folder pops in with its pod already
                // inside — the "put the pod in it" moment
                // commitNewFolder() is pausing to let play out.
                .transition(.scale(scale: 0.7).combined(with: .opacity))
            }

            if isCreatingFolder {
                FolderBubble(
                    name: "",
                    pods: [],
                    photoURLs: [:],
                    mirrored: likesStore.folders.count % 2 == 1,
                    editableName: $newFolderName,
                    onCommitName: commitNewFolder
                )
                .position(center(forBubble: likesStore.folders.count, width: width))
                .transition(.opacity)
            }
        }
    }

    private func center(forBubble index: Int, width: CGFloat) -> CGPoint {
        CGPoint(
            x: width * (index % 2 == 0 ? 0.31 : 0.855),
            y: Self.firstCenterY + Self.step * CGFloat(index)
        )
    }

    /// Back closes the sheet; "New folder" starts naming a new bubble (and
    /// is hidden while that's going on).
    private var actionRow: some View {
        HStack(spacing: 13) {
            DetailBackButton(action: cancelAndDismiss)

            if !isCreatingFolder {
                DetailTextButton(title: "New folder") {
                    withAnimation(.easeOut(duration: AppMotion.snappy)) {
                        isCreatingFolder = true
                        newFolderName = ""
                    }
                }
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
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

/// Fixed points the existing-folder "drop" overlay animates through: a
/// diagonal descent onto the bubble, rotating in one direction the whole
/// way (a tumble, not tilt-overshoot-settle-back), then shrinking into the
/// bubble's middle. x/yFraction are fractions of the bubble's diameter,
/// from its center.
private struct FolderDropValues {
    var scale: CGFloat
    var rotationDegrees: Double
    var xFraction: CGFloat
    var yFraction: CGFloat

    static let start = FolderDropValues(scale: 1.0, rotationDegrees: -4, xFraction: -0.25, yFraction: -1.0)
    static let midArc = FolderDropValues(scale: 0.9, rotationDegrees: 20, xFraction: -0.1, yFraction: -0.5)
    static let landed = FolderDropValues(scale: 0.5, rotationDegrees: 42, xFraction: 0.0, yFraction: 0.0)
    static let vanished = FolderDropValues(scale: 0.1, rotationDegrees: 42, xFraction: 0.0, yFraction: 0.0)
}
