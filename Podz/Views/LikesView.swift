//
//  LikesView.swift
//  Podz
//
//  Created by Max Prx on 22/08/2026.
//

import SwiftUI

/// One bubble on the Likes tab: a folder of yours, or one shared with you.
private enum LikesItem: Identifiable {
    case own(LikeFolder)
    case shared(SharedFolder)

    var id: UUID {
        switch self {
        case .own(let folder): folder.id
        case .shared(let folder): folder.id
        }
    }
}

/// Tab content for "Likes" — liked pods grouped into bubbles
/// "folders" by country. Tap a folder to see its pods, tap a pod for
/// the detail screen. Same self-contained navigation pattern as
/// HomeView/ProfileView (local @State toggles between screens).
struct LikesView: View {
    @StateObject private var likesStore = LikesStore.shared
    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var friendsStore = FriendsStore.shared
    // Shared with HomeView — feeds the floating tab bar's scroll-down
    // shrink (MainTabView), which used to only react to the Home feed's
    // own ScrollView. Every ScrollView here keeps the tab bar visible
    // (unlike FriendsView/ConversationView, which hide it outright), so
    // they all report their offset the same way Home's does.
    @StateObject private var scrollState = ScrollTrackingState.shared
    @State private var selectedFolder: LikeFolder?
    @State private var selectedSharedFolder: SharedFolder?
    @State private var selectedPod: Pod?
    @State private var isEditMode = false
    @State private var folderPendingDeletion: LikeFolder?
    @State private var folderPendingShare: LikeFolder?

    private var likedPods: [Pod] {
        podsStore.pods.filter { likesStore.isLiked($0) }
    }
    
    private func pods(in folder: LikeFolder) -> [Pod] {
        likesStore.pods(in: folder.id, from: likedPods)
    }

    /// Who a folder of yours is shared with (the same order every time).
    private func sharedWith(_ folder: LikeFolder) -> [FolderPerson] {
        // `friendIdsWithAccess` returns a Set — its iteration order isn't
        // guaranteed stable between separate calls, so without sorting,
        // this array's order (and therefore which avatar lands in which
        // on-screen slot) could come out differently on every re-render.
        // Scrolling re-evaluates this constantly, which is what made two
        // avatars appear to swap places mid-scroll — they genuinely were,
        // each time this recomputed in a new order.
        likesStore.friendIdsWithAccess(to: folder.id)
            .sorted { $0.uuidString < $1.uuidString }
            .compactMap { id in
                friendsStore.profilesById[id].map { FolderPerson(id: id, name: $0.displayName, avatarURL: $0.avatarURL) }
            }
    }

    var body: some View {
        // ZStack + `.animation(value:)` so the overview ⇄ folder swap
        // below has a persistent container to run its `.blurReplace`
        // transition in — a bare if/else at the root of `body` was a hard
        // cut. Only folder open/close animates here; a pod opens in its own
        // zoom-transitioned cover below.
        ZStack {
            if let folder = selectedFolder {
                folderContentView(folder: folder)
                    .onChange(of: likesStore.likes) { _, _ in
                        if pods(in: folder).isEmpty { selectedFolder = nil }
                    }
                    .transition(.blurReplace)
            } else if let sharedFolder = selectedSharedFolder {
                sharedFolderContentView(folder: sharedFolder)
                    .transition(.blurReplace)
            } else {
                foldersOverview
                    .transition(.blurReplace)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: selectedFolder?.id)
        .animation(.easeInOut(duration: 0.35), value: selectedSharedFolder?.id)
        // Same zoom-from-the-tapped-photo cover Home uses — the folder
        // grid stays mounted underneath (scroll position kept).
        .fullScreenCover(item: $selectedPod) { pod in
            MinimalPodDetailView(pod: pod, onBack: { selectedPod = nil })
        }
    }
    
    // MARK: - Folders overview
    
    private var foldersOverview: some View {
        ZStack(alignment: .bottom) {
            foldersScroll
            // The bubbles fade into the ground at the bottom, like the
            // folder view, so they slide under the tab bar.
            BottomFade()
        }
        .background(Color.homeBackground)
    }

    private var foldersScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    // Same style as Home's "Where to tonight?".
                    T("Likes")
                        .font(AppFont.semiBoldLabel(30))
                        .tracking(-0.6)
                        .foregroundColor(.homeText)
                    Spacer()
                    if isEditMode && !likesStore.folders.isEmpty {
                        Button(tr("Done")) {
                            withAnimation { isEditMode = false }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.homeText)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 25)

                if likesItems.isEmpty {
                    emptyState
                } else {
                    FolderBubbleCanvas(
                        items: likesItems,
                        podCount: podCount(of:),
                        width: ScreenInsets.screenWidth,
                        bottomRoom: 100,
                        // Apart on entry; pinch in to bring them closer.
                        startsLoose: true
                    ) { item, index, cell in
                        switch item {
                        case .own(let folder):
                            FolderBubble(
                                cell: cell,
                                name: folder.name,
                                pods: pods(in: folder),
                                photoURLs: podsStore.primaryPhotoByPodId,
                                mirrored: index % 2 == 1,
                                sharedWith: sharedWith(folder),
                                showDeleteBadge: isEditMode,
                                isWiggling: isEditMode,
                                onDelete: { folderPendingDeletion = folder },
                                onLongPress: { withAnimation { isEditMode = true } },
                                onTap: { selectedFolder = folder }
                            )
                        case .shared(let folder):
                            // Who it came from, on the bubble itself.
                            FolderBubble(
                                cell: cell,
                                name: folder.name,
                                subtitle: friendsStore.profilesById[folder.ownerId].map { "by \($0.displayName)" },
                                pods: likesStore.pods(inSharedFolder: folder.id, from: podsStore.pods),
                                photoURLs: podsStore.primaryPhotoByPodId,
                                mirrored: index % 2 == 1,
                                onTap: { selectedSharedFolder = folder }
                            )
                        }
                    }
                }

                Color.clear.frame(height: 100)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            scrollState.updateOffset(newValue)
        }
        .background(Color.homeBackground)
        // Needed to resolve friendIdsWithAccess into actual avatar URLs
        // for the bubbles' shared-with avatars — nothing else in this
        // view's own reachable path guarantees FriendsStore has loaded.
        .task { await friendsStore.fetchAll() }
        .onAppear {
            // ScrollTrackingState is one singleton shared by every
            // scrollable tab — without this, switching in from a tab
            // scrolled down elsewhere could compute a spurious delta
            // against that stale offset and flash the tab bar's shrink
            // for a beat, unrelated to any actual scrolling here. This
            // is the entry point for the whole tab (`selectedFolder`
            // etc. reset to nil on every fresh mount), so resetting
            // here covers switching into Likes generally.
            scrollState.reset()
        }
        .onChange(of: likesStore.folders) { _, newFolders in
            if newFolders.isEmpty {
                withAnimation { isEditMode = false }
            }
        }
        .alert(
            tr("Delete folder?"),
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { if !$0 { folderPendingDeletion = nil } }
            )
        ) {
            Button(tr("Cancel"), role: .cancel) { folderPendingDeletion = nil }
            Button(tr("Delete"), role: .destructive) {
                if let folder = folderPendingDeletion {
                    Task { await likesStore.deleteFolder(folder) }
                }
                folderPendingDeletion = nil
            }
        } message: {
            if let folder = folderPendingDeletion {
                T("\"\(folder.name)\" will be deleted, along with the likes inside it.")
            }
        }
    }
    private func podCount(of item: LikesItem) -> Int {
        switch item {
        case .own(let folder): pods(in: folder).count
        case .shared(let folder): likesStore.pods(inSharedFolder: folder.id, from: podsStore.pods).count
        }
    }

    /// Your folders, then the ones shared with you, as one run of bubbles.
    private var likesItems: [LikesItem] {
        likesStore.folders.map(LikesItem.own) + likesStore.foldersSharedWithMe.map(LikesItem.shared)
    }

    // MARK: - Inside one folder

    private func folderContentView(folder: LikeFolder) -> some View {
        MinimalFolderView(
            title: folder.name,
            sharedWith: sharedWith(folder),
            pods: pods(in: folder),
            photoURLs: podsStore.primaryPhotoByPodId,
            onBack: { selectedFolder = nil },
            onOpenPod: { selectedPod = $0 },
            // Opens ShareFolderSheet's per-friend access toggle list.
            onShare: { folderPendingShare = folder },
            // Press and hold a tile to take a pod out of the folder.
            onRemovePod: { pod in Task { await likesStore.removeLike(pod) } },
            // An empty folder: the pill asks "Add huts?" and goes to Home.
            onAddHuts: { TabRouter.shared.homeRequested = true }
        )
        .sheet(item: $folderPendingShare) { folder in
            ShareFolderSheet(folder: folder)
                // Short toggle list, no search field — doesn't need the
                // full sheet, same reasoning as PostComposerView.
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    /// A folder shared with you: the same screen, read-only (no share).
    private func sharedFolderContentView(folder: SharedFolder) -> some View {
        MinimalFolderView(
            title: folder.name,
            subtitle: friendsStore.profilesById[folder.ownerId].map { "Shared by \($0.displayName)" },
            pods: likesStore.pods(inSharedFolder: folder.id, from: podsStore.pods),
            photoURLs: podsStore.primaryPhotoByPodId,
            onBack: { selectedSharedFolder = nil },
            onOpenPod: { selectedPod = $0 }
        )
    }

    // MARK: - Empty state

    /// Lenny's invitation; the caption goes to Home to find huts.
    private var emptyState: some View {
        LennyEmptyState(
            title: "No likes yet",
            line: "Tap the heart on a hut and it lands here, in a folder.",
            caption: "Find huts",
            action: { TabRouter.shared.homeRequested = true }
        )
    }
}
