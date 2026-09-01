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
                CloseButton(action: cancelAndDismiss)
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
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(likesStore.folders) { folder in
                        LikesFolderCard(
                            country: folder.name,
                            pods: likesStore.pods(in: folder.id, from: PodsStore.shared.pods),
                            photoURLs: PodsStore.shared.primaryPhotoByPodId,
                            scale: 0.8,
                            nameFontSize: 25,
                            onTap: { saveLike(into: folder.id) },
                            // Genuinely behind LikesFolderCard's own
                            // front panel (see its `incomingDropContent`
                            // doc) — an external .overlay() on the whole
                            // card, tried previously, can only ever draw
                            // on top of everything, which is why the
                            // photo used to visibly land above/on the
                            // folder instead of appearing to enter it.
                            // Positioned in fractions of `side`, the same
                            // coordinate system LikesFolderCard's own
                            // fanned photos use (offset from the icon's
                            // bottom-center) — landed's y sits inside the
                            // zone the front panel actually covers, so
                            // the panel drawn after this in z-order hides
                            // it there for free, no manual occlusion.
                            incomingDropContent: folder.id == savingIntoFolderId ? { side in
                                AnyView(
                                    PodPhoto(url: PodsStore.shared.primaryPhotoByPodId[pod.id])
                                        .frame(width: side * 0.5, height: side * 0.5)
                                        .clipShape(RoundedRectangle(cornerRadius: side * 0.06, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: side * 0.06, style: .continuous)
                                                .strokeBorder(Color.white, lineWidth: 2)
                                        )
                                        .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
                                        .scaleEffect(dropStage.scale)
                                        .rotationEffect(.degrees(dropStage.rotationDegrees))
                                        .offset(x: dropStage.xFraction * side, y: dropStage.yFraction * side)
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
                            scale: 0.8,
                            nameFontSize: 25,
                            editableName: $newFolderName,
                            onCommitName: commitNewFolder
                        )
                        .transition(.opacity)
                    } else {
                        newFolderTile
                            .transition(.opacity)
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
            withAnimation(.easeOut(duration: AppMotion.snappy)) {
                isCreatingFolder = true
                newFolderName = ""
            }
        } label: {
            VStack(spacing: 10) {
                // Outer footprint stays a plain square (aspectRatio 1,
                // same as LikesFolderCard's own GeometryReader square) —
                // shrinking the *outer* frame to the landscape ratio (the
                // previous attempt) desynced this tile's row height from
                // a real folder's whenever they land in the same grid
                // row, since LazyVGrid rows size to their tallest cell.
                // Bottom-anchoring a shorter, landscape dashed rect
                // inside the same square footprint gets the folder-like
                // proportions without disturbing that shared height —
                // exactly how LikesFolderCard bottom-anchors its own
                // 0.74x-tall back panel inside its square.
                GeometryReader { proxy in
                    let side = min(proxy.size.width, proxy.size.height)
                    RoundedRectangle(cornerRadius: AppRadius.r20)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundColor(.appTextMuted.opacity(0.5))
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.appTextMuted)
                        )
                        .frame(width: side, height: side * 0.74)
                        .frame(width: side, height: side, alignment: .bottom)
                }
                .aspectRatio(1, contentMode: .fit)
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

/// Fixed points the existing-folder "drop" overlay animates through, per
/// the user's own sketch: a fairly direct diagonal descent (not a wide
/// sideways swing), rotating consistently in one direction the whole way
/// down (a tumble, not tilt-overshoot-settle-back), passing behind the
/// folder's front panel as it lands. x/yFraction are fractions of `side`
/// (LikesFolderCard's own measured icon size, handed in via
/// `incomingDropContent`) in the *same* coordinate system its real
/// fanned photos use — offset from the icon's bottom-center, where the
/// front panel covers roughly y: -0.56×side (its top edge) down to 0
/// (the bottom). start (well above and left, nearly upright, roughly
/// actual size), midArc (partway down the same diagonal, still above the
/// panel's top edge), landed (inside the zone the front panel covers —
/// -0.28×side is well past -0.56×side — so it's the panel itself, drawn
/// after this in z-order, that hides it here, not any fade/shrink of
/// ours), vanished (shrinks further at that same spot, purely for a
/// settled feel — it's already hidden by then).
private struct FolderDropValues {
    var scale: CGFloat
    var rotationDegrees: Double
    var xFraction: CGFloat
    var yFraction: CGFloat

    static let start = FolderDropValues(scale: 1.1, rotationDegrees: -4, xFraction: -0.35, yFraction: -1.35)
    static let midArc = FolderDropValues(scale: 0.95, rotationDegrees: 20, xFraction: -0.12, yFraction: -0.78)
    static let landed = FolderDropValues(scale: 0.75, rotationDegrees: 42, xFraction: 0.02, yFraction: -0.28)
    static let vanished = FolderDropValues(scale: 0.15, rotationDegrees: 42, xFraction: 0.02, yFraction: -0.22)
}
