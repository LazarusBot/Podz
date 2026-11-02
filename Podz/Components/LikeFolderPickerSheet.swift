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
    /// The folder that swells as the photo melts into it (its neighbours give way).
    @State private var swellingFolderId: UUID?

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
                // The folder that takes the photo swells, the others give way.
                swell: swellingFolderId == nil ? 1 : (swellingFolderId == folder.id ? 1.07 : 0.985),
                // The photo glides onto the bubble and shrinks into it.
                // Positioned in fractions of the bubble's diameter, from
                // its center.
                incomingDropContent: folder.id == savingIntoFolderId ? { diameter in
                    AnyView(
                        BubblePhoto(url: PodsStore.shared.primaryPhotoByPodId[pod.id], coordinate: pod.coordinate)
                            .scaleEffect(dropStage.scale * diameter / (FolderBubble.referenceRadius * 2))
                            .opacity(dropStage.opacity)
                            .offset(y: dropStage.yFraction * diameter)
                            .allowsHitTesting(false)
                    )
                } : nil,
                onTap: { saveLike(into: folder.id) }
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

    /// The pod's photo glides straight into the folder and melts into it, and the
    /// bubble answers: it swells a little while its neighbours give way, like foam
    /// taking a bump, then settles. No arc, no spin: the same calm as the rest of
    /// the app.
    private func saveLike(into folderId: UUID) {
        guard savingIntoFolderId == nil else { return }
        savingIntoFolderId = folderId
        dropStage = .start
        // A separate tick, so the overlay is drawn at its start before it moves.
        DispatchQueue.main.async {
            withAnimation(.smooth(duration: 0.38)) { dropStage = .landed }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                withAnimation(.smooth(duration: 0.22)) { dropStage = .melted }
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { swellingFolderId = folderId }
                // The data lands as the bubble swells: the photo joins the others
                // in the fan and the count rolls.
                Task { await likesStore.like(pod, folderId: folderId) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { swellingFolderId = nil }
                }
                // A beat to see it settle before the sheet closes.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { onDismiss() }
            }
        }
    }

    private func cancelAndDismiss() {
        isCreatingFolder = false
        onDismiss()
    }
}

/// Where the photo that drops into a folder is: straight above the bubble at
/// full size, then at its centre small (landed), then gone (melted into it).
/// x/yFraction are fractions of the bubble's diameter, from its center.
private struct FolderDropValues {
    var scale: CGFloat
    var yFraction: CGFloat
    var opacity: Double

    static let start = FolderDropValues(scale: 1.0, yFraction: -0.95, opacity: 1)
    static let landed = FolderDropValues(scale: 0.42, yFraction: 0, opacity: 1)
    static let melted = FolderDropValues(scale: 0.2, yFraction: 0, opacity: 0)
}
