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
    /// The folder the photo is melting into, and where its centre is, so every
    /// other bubble can give way away from it.
    @State private var swellingFolderId: UUID?
    @State private var pressCenter: CGPoint?

    /// What the canvas draws: each folder, plus the one being named.
    private enum Slot: Identifiable {
        case folder(LikeFolder)
        case creating

        var id: String {
            switch self {
            case .folder(let folder): folder.id.uuidString
            case .creating: "creating"
            }
        }
    }

    private func podCount(of slot: Slot) -> Int {
        switch slot {
        case .folder(let folder): likesStore.pods(in: folder.id, from: PodsStore.shared.pods).count
        case .creating: 0
        }
    }

    private var slots: [Slot] {
        likesStore.folders.map(Slot.folder) + (isCreatingFolder ? [.creating] : [])
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                T("Save to folder")
                    .font(AppFont.semiBoldLabel(30))
                    .tracking(-0.6)
                    .foregroundColor(.homeText)
                    .padding(.top, 36)
                    .padding(.bottom, 12)

                GeometryReader { proxy in
                    ScrollView {
                        FolderBubbleCanvas(
                            items: slots,
                            podCount: podCount(of:),
                            width: proxy.size.width,
                            bottomRoom: 170
                        ) { slot, index, cell in
                            bubble(for: slot, index: index, cell: cell)
                        }
                    }
                }
            }

            BottomFade()

            actionRow
                .padding(.bottom, DetailLayout.controlStackGap)
        }
        .background(Color.homeBackground)
    }

    @ViewBuilder
    private func bubble(for slot: Slot, index: Int, cell: FoamCell) -> some View {
        switch slot {
        case .folder(let folder):
            FolderBubble(
                cell: cell,
                name: folder.name,
                pods: likesStore.pods(in: folder.id, from: PodsStore.shared.pods),
                photoURLs: PodsStore.shared.primaryPhotoByPodId,
                mirrored: index % 2 == 1,
                // The folder that takes the photo swells; every other one gives way
                // (a shift away from it and a hair smaller, a beat later the farther
                // it is), so the bump travels through the foam.
                swell: swellScale(for: folder.id, cell: cell),
                reactionOffset: reactionOffset(for: folder.id, cell: cell),
                reactionDelay: reactionDelay(for: folder.id, cell: cell),
                // The photo glides onto the bubble and shrinks into it.
                // Positioned in fractions of the bubble's diameter, from
                // its center.
                incomingDropContent: folder.id == savingIntoFolderId ? { diameter in
                    AnyView(
                        BubblePhoto(url: PodsStore.shared.primaryPhotoByPodId[pod.id], coordinate: pod.coordinate)
                            // Flattening against the edge: its bottom stays put.
                            .scaleEffect(x: dropStage.stretch, y: dropStage.squash, anchor: .bottom)
                            .scaleEffect(dropStage.scale * diameter / (FolderBubble.referenceRadius * 2))
                            .opacity(dropStage.opacity)
                            .offset(y: dropStage.yFraction * diameter)
                            .allowsHitTesting(false)
                    )
                } : nil,
                onTap: { saveLike(into: folder.id, at: cell.center) }
            )
            // The freshly-created folder pops in with its pod already
            // inside — the "put the pod in it" moment commitNewFolder() is
            // pausing to let play out.
            .transition(.scale(scale: 0.7).combined(with: .opacity))
        case .creating:
            FolderBubble(
                cell: cell,
                name: "",
                pods: [],
                photoURLs: [:],
                mirrored: index % 2 == 1,
                editableName: $newFolderName,
                onCommitName: commitNewFolder
            )
            .transition(.opacity)
        }
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
            // Empty name on submit — cancel, back to the bubbles.
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
        }
    }

    // MARK: - The foam's reaction

    /// How far the bump reaches, in points.
    private let reach: CGFloat = 460

    private func distance(from cell: FoamCell) -> CGFloat? {
        guard let pressCenter else { return nil }
        return hypot(cell.center.x - pressCenter.x, cell.center.y - pressCenter.y)
    }

    private func swellScale(for id: UUID, cell: FoamCell) -> CGFloat {
        guard swellingFolderId != nil else { return 1 }
        if id == swellingFolderId { return 1.06 }
        let falloff = max(0, 1 - (distance(from: cell) ?? reach) / reach)
        return 1 - 0.025 * falloff
    }

    /// Away from the bubble taking the photo, less the farther it is.
    private func reactionOffset(for id: UUID, cell: FoamCell) -> CGSize {
        guard swellingFolderId != nil, id != swellingFolderId, let pressCenter,
              let d = distance(from: cell), d > 1 else { return .zero }
        let falloff = max(0, 1 - d / reach)
        let push = 10 * falloff
        return CGSize(width: (cell.center.x - pressCenter.x) / d * push, height: (cell.center.y - pressCenter.y) / d * push)
    }

    /// The bump reaches the far bubbles a beat later.
    private func reactionDelay(for id: UUID, cell: FoamCell) -> Double {
        guard id != swellingFolderId, let d = distance(from: cell) else { return 0 }
        return Double(min(d / 1800, 0.25))
    }

    // MARK: - Saving

    /// The pod's photo glides straight down to the folder and, the moment it
    /// touches the edge, adapts to it: it flattens into the foam and melts there
    /// (it never goes to the middle). The bubble answers at the same instant, a
    /// soft swell, and the whole foam gives way and settles, a wave from the
    /// bubble outward. No arc, no spin.
    private func saveLike(into folderId: UUID, at center: CGPoint) {
        guard savingIntoFolderId == nil else { return }
        savingIntoFolderId = folderId
        pressCenter = center
        dropStage = .start
        // A separate tick, so the card is drawn at its start before it moves.
        DispatchQueue.main.async {
            withAnimation(.smooth(duration: 0.32)) { dropStage = .touching }
            // Contact: the card adapts to the edge and the foam answers.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.smooth(duration: 0.32)) { dropStage = .absorbed }
                withAnimation(.smooth(duration: 0.5)) { swellingFolderId = folderId }
                // The data lands with the swell: the photo joins the others in the
                // fan and the count rolls.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    Task { await likesStore.like(pod, folderId: folderId) }
                }
                // The foam lets go and settles.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.smooth(duration: 0.6)) { swellingFolderId = nil }
                }
                // A beat to see it settle before the sheet closes.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) { onDismiss() }
            }
        }
    }

    private func cancelAndDismiss() {
        isCreatingFolder = false
        onDismiss()
    }
}

/// Where the photo that drops into a folder is: above the bubble (start), just
/// touching its top edge (touching), then flattened into that edge and gone
/// (absorbed). yFraction is a fraction of the bubble's diameter, from its center
/// (the edge is at -0.5).
private struct FolderDropValues {
    var scale: CGFloat
    var yFraction: CGFloat
    var opacity: Double
    /// Wider and flatter as it adapts to the edge.
    var stretch: CGFloat
    var squash: CGFloat

    static let start = FolderDropValues(scale: 0.8, yFraction: -1.1, opacity: 1, stretch: 1, squash: 1)
    static let touching = FolderDropValues(scale: 0.8, yFraction: -0.69, opacity: 1, stretch: 1, squash: 1)
    static let absorbed = FolderDropValues(scale: 0.8, yFraction: -0.52, opacity: 0, stretch: 1.12, squash: 0.08)
}
