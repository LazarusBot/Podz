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
    @State private var selectedFolder: LikeFolder?
    @State private var selectedPod: Pod?
    @State private var isEditMode = false
    @State private var folderPendingDeletion: LikeFolder?
    
    private var likedPods: [Pod] {
        podsStore.pods.filter { likesStore.isLiked($0) }
    }
    
    private func pods(in folder: LikeFolder) -> [Pod] {
        likesStore.pods(in: folder.id, from: likedPods)
    }
    
    var body: some View {
        if let pod = selectedPod {
            PodDetailView(pod: pod, onBack: { selectedPod = nil })
        } else if let folder = selectedFolder {
            folderContentView(folder: folder)
                .onChange(of: likesStore.likes) { _, _ in
                    if pods(in: folder).isEmpty { selectedFolder = nil }
                }
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
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Color.clear.frame(height: 100)
            }
        }
        .background(Color.appHomeBackground)
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
    
    private func folderContentView(folder: LikeFolder) -> some View {
        let folderPods = pods(in: folder)
        
        return ScrollView {
            VStack(spacing: 0) {
                ProfileTopBar(title: folder.name, onBack: { selectedFolder = nil })
                
                VStack(spacing: 30) {
                    ForEach(folderPods) { pod in
                        LennyResultCard(
                            pod: pod,
                            photoURL: podsStore.primaryPhotoByPodId[pod.id],
                            isSelected: true,
                            selectedIcon: "heart.fill",
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
        .background(Color.appHomeBackground)
    }
    
    // MARK: - Empty state
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart")
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
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
