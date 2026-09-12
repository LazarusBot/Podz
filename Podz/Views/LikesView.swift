//
//  LikesView.swift
//  Podz
//
//  Created by Max Prx on 22/08/2026.
//

import SwiftUI

/// Tab content for "Likes" — liked pods grouped into transparent glass
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

    private func sharedWithAvatarURLs(for folder: LikeFolder) -> [String] {
        // `friendIdsWithAccess` returns a Set — its iteration order isn't
        // guaranteed stable between separate calls, so without sorting,
        // this array's order (and therefore which avatar lands in which
        // on-screen slot) could come out differently on every re-render.
        // Scrolling re-evaluates this constantly, which is what made two
        // avatars appear to swap places mid-scroll — they genuinely were,
        // each time this recomputed in a new order.
        likesStore.friendIdsWithAccess(to: folder.id)
            .sorted { $0.uuidString < $1.uuidString }
            .compactMap { friendsStore.profilesById[$0]?.avatarURL }
    }

    var body: some View {
        if let pod = selectedPod {
            PodDetailView(pod: pod, onBack: { selectedPod = nil })
        } else if let folder = selectedFolder {
            folderContentView(folder: folder)
                .onChange(of: likesStore.likes) { _, _ in
                    if pods(in: folder).isEmpty { selectedFolder = nil }
                }
        } else if let sharedFolder = selectedSharedFolder {
            sharedFolderContentView(folder: sharedFolder)
        } else {
            foldersOverview
        }
    }
    
    // MARK: - Folders overview
    
    private var foldersOverview: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Likes")
                        .font(AppFont.pillLabel(24))
                        .fontWeight(.heavy)
                        .foregroundColor(.black)
                    Spacer()
                    if isEditMode && !likesStore.folders.isEmpty {
                        Button("Done") {
                            withAnimation { isEditMode = false }
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.appAccentBlack)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                if likesStore.folders.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        ForEach(likesStore.folders) { folder in
                            LikesFolderCard(
                                country: folder.name,
                                pods: pods(in: folder),
                                photoURLs: podsStore.primaryPhotoByPodId,
                                onTap: { selectedFolder = folder }, showDeleteBadge: isEditMode,
                                isWiggling: isEditMode,
                                onDelete: { folderPendingDeletion = folder },
                                onLongPress: {
                                    withAnimation { isEditMode = true }
                                },
                                sharedWithAvatarURLs: sharedWithAvatarURLs(for: folder)
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }

                if !likesStore.foldersSharedWithMe.isEmpty {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                        ForEach(likesStore.foldersSharedWithMe) { folder in
                            VStack(spacing: 2) {
                                // Owner's avatar in the same bottom-left
                                // spot owner-side cards show the friend
                                // they shared with — same visual language
                                // either direction, plus the "by X" caption
                                // underneath for the actual name.
                                LikesFolderCard(
                                    country: folder.name,
                                    pods: likesStore.pods(inSharedFolder: folder.id, from: podsStore.pods),
                                    photoURLs: podsStore.primaryPhotoByPodId,
                                    onTap: { selectedSharedFolder = folder },
                                    sharedWithAvatarURLs: [friendsStore.profilesById[folder.ownerId]?.avatarURL].compactMap { $0 }
                                )
                                if let owner = friendsStore.profilesById[folder.ownerId] {
                                    Text("by \(owner.displayName)")
                                        .font(AppFont.regularLabel(12))
                                        .foregroundColor(.appTextMuted)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Color.clear.frame(height: 100)
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { _, newValue in
            scrollState.updateOffset(newValue)
        }
        .background(Color.appHomeBackground)
        // Needed to resolve friendIdsWithAccess into actual avatar URLs
        // for LikesFolderCard's shared-with stack — nothing else in this
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
            "Delete folder?",
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { if !$0 { folderPendingDeletion = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) { folderPendingDeletion = nil }
            Button("Delete", role: .destructive) {
                if let folder = folderPendingDeletion {
                    Task { await likesStore.deleteFolder(folder) }
                }
                folderPendingDeletion = nil
            }
        } message: {
            if let folder = folderPendingDeletion {
                Text("\"\(folder.name)\" will be deleted, along with the likes inside it.")
            }
        }
    }
    // MARK: - Inside one folder

    // 44 (back button) + 31pt padding top/bottom — matches ProfileTopBar's
    // own metrics exactly, since it copies its visual style.
    private let folderTopBarHeight: CGFloat = 106

    private func folderContentView(folder: LikeFolder) -> some View {
        let folderPods = pods(in: folder)

        return ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    // Room for the persistent top bar below to float over
                    // — without this, a folder with enough pods to scroll
                    // carried the back button away with the rest of the
                    // content instead of keeping it reachable.
                    Color.clear.frame(height: folderTopBarHeight)

                    VStack(spacing: 30) {
                        ForEach(folderPods) { pod in
                            LennyResultCard(
                                pod: pod,
                                photoURL: podsStore.primaryPhotoByPodId[pod.id],
                                isSelected: true,
                                selectedIcon: "heart.fill",
                                photoCornerRadius: PodCard.scaledCornerRadius(for: 345),
                                onToggleSelect: { Task { await likesStore.removeLike(pod) } },
                                onTapCard: { selectedPod = pod }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                    Color.clear.frame(height: 100)
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, newValue in
                scrollState.updateOffset(newValue)
            }
            .background(Color.appHomeBackground)

            ProfileTopBar(
                title: folder.name,
                onBack: { selectedFolder = nil },
                // Opens ShareFolderSheet's per-friend access toggle
                // list, not the native share sheet — "link" reads as
                // "manage sharing access" instead of "export/send".
                trailingIcon: "link",
                onTrailingTap: { folderPendingShare = folder },
                trailingAccessibilityLabel: "Share folder"
            )
        }
        .sheet(item: $folderPendingShare) { folder in
            ShareFolderSheet(folder: folder)
                // Short toggle list, no search field — doesn't need the
                // full sheet, same reasoning as PostComposerView.
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Inside a folder shared with you (read-only)

    private func sharedFolderContentView(folder: SharedFolder) -> some View {
        let folderPods = likesStore.pods(inSharedFolder: folder.id, from: podsStore.pods)

        return ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    // Same persistent-top-bar reasoning as folderContentView.
                    Color.clear.frame(height: folderTopBarHeight)

                    VStack(spacing: 30) {
                        ForEach(folderPods) { pod in
                            LennyResultCard(
                                pod: pod,
                                photoURL: podsStore.primaryPhotoByPodId[pod.id],
                                isSelected: true,
                                selectedIcon: "heart.fill",
                                photoCornerRadius: PodCard.scaledCornerRadius(for: 345),
                                // No-op, not removeLike — this isn't your like
                                // to remove. Read-only for now.
                                onToggleSelect: {},
                                onTapCard: { selectedPod = pod }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)

                    Color.clear.frame(height: 100)
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, newValue in
                scrollState.updateOffset(newValue)
            }
            .background(Color.appHomeBackground)

            // No trailing share icon — you can't re-share a folder that
            // isn't yours.
            ProfileTopBar(title: folder.name, onBack: { selectedSharedFolder = nil })
        }
    }

    // MARK: - Empty state
    
    private var emptyState: some View {
        VStack(spacing: 24) {
            LikesEmptyStateIllustration()

            Text("No likes yet — tap the heart on a pod in your feed.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }
}

/// The big sad outline heart plus three small broken-heart accents,
/// each beating on its own independent `HeartbeatImage` period with a
/// slight phase offset — matches Figma's own `get_motion_context` for
/// node 4512:392 (the three small hearts are `motion.div`s there; the
/// big heart isn't animated). Positions/sizes are that frame's own
/// layout percentages converted to points on a 276x198 canvas (the big
/// heart's native SVG size), laid out at native scale and scaled down
/// together via one `scaleEffect` — same approach, and the same
/// `.topLeading`-alignment fix, as `PodsView`'s own
/// `PodsEmptyStateIllustration` (see that type's doc comment for why
/// the final `.frame`'s alignment has to match the `scaleEffect`
/// anchor, or the scaled content ends up centered inside its own
/// oversized *reported* size instead of filling the display frame).
private struct LikesEmptyStateIllustration: View {
    private let canvasSize = CGSize(width: 276, height: 198)
    // Matches PodsEmptyStateIllustration's own displayed *height*
    // (202.455 * 280/418 ≈ 135.6pt), not its displayWidth verbatim — the
    // two canvases have different aspect ratios (276x198 here vs
    // 418x202.455 there), so matching width alone left this one visibly
    // taller despite both nominally being "280".
    private let displayWidth: CGFloat = 135.6 / 198 * 276
    private let smallHeartSize = CGSize(width: 75.1, height: 66.98)

    private var scale: CGFloat { displayWidth / canvasSize.width }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("BigHeartIllustration")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 223.23, height: 197.525)
                .offset(x: 24.87, y: 0.475)

            HeartbeatImage(
                imageName: "SmallHeartIllustration",
                size: smallHeartSize,
                rotationAmplitudeDegrees: 4,
                bounceAmplitude: 6,
                scaleUp: 1.07,
                scaleDown: 0.97,
                initialDelaySeconds: 0.5
            )
            .offset(x: 0, y: 61.76)

            HeartbeatImage(
                imageName: "SmallHeartIllustration",
                size: smallHeartSize,
                rotationAmplitudeDegrees: 4,
                bounceAmplitude: 6,
                scaleUp: 1.07,
                scaleDown: 0.97,
                initialDelaySeconds: 1.0
            )
            .offset(x: 200.9, y: 0)

            HeartbeatImage(
                imageName: "SmallHeartIllustration",
                size: smallHeartSize,
                rotationAmplitudeDegrees: 4,
                bounceAmplitude: 6,
                scaleUp: 1.07,
                scaleDown: 0.97,
                initialDelaySeconds: 0
            )
            .offset(x: 172.5, y: 120.76)
        }
        .frame(width: canvasSize.width, height: canvasSize.height, alignment: .topLeading)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(width: displayWidth, height: canvasSize.height * scale, alignment: .topLeading)
    }
}
