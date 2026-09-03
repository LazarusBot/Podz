//
//  MyPodsView.swift
//  Podz
//
//  Created by Max Prx on 02/09/2026.
//

import SwiftUI
internal import Auth

/// A host's own pods — reached from ProfileView's "Hosting" section
/// (shown only when `auth.profile?.isHost` is true). Same manual
/// @State push/pop pattern as FriendsView/MyPostsView/MyReservationsView,
/// not NavigationStack — this app doesn't use one anywhere. The trailing
/// "+" opens the same `AddPodView` sheet the Profile promo card does.
struct MyPodsView: View {
    var onBack: () -> Void

    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var auth = AuthManager.shared
    @State private var showAddPod = false
    /// Confirm-before-delete, same pattern as MyReservationsView's own
    /// `pendingCancellation` — a plain trailing "Delete" text button, not
    /// a swipe gesture (FriendsView's `SwipeToDeleteRow` is the swipe
    /// version of this, but it's `private` to that file — Swift's
    /// `private` is file-scoped, so reaching it from here isn't possible
    /// without loosening its access level for a row type meant for
    /// friendships, not pods).
    @State private var pendingDeletion: Pod?

    private var myPods: [Pod] {
        guard let userId = auth.session?.user.id else { return [] }
        return podsStore.pods.filter { $0.hostId == userId }
    }

    var body: some View {
        VStack(spacing: 0) {
            ProfileTopBar(
                title: "My pods",
                onBack: onBack,
                trailingIcon: "plus",
                onTrailingTap: { showAddPod = true },
                trailingAccessibilityLabel: "List a new pod"
            )

            if myPods.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "house")
                        .font(.system(size: 32))
                        .foregroundColor(.appTextMuted)
                    Text("No pods listed yet — tap + to add your first one.")
                        .font(AppFont.mediumLabel(14))
                        .foregroundColor(.appTextMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(myPods) { pod in
                            MyPodRow(
                                pod: pod,
                                photoURL: podsStore.primaryPhotoByPodId[pod.id],
                                onDelete: { pendingDeletion = pod }
                            )
                        }
                        Color.clear.frame(height: 40)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.appHomeBackground)
        .task { await podsStore.fetchPods() }
        .sheet(isPresented: $showAddPod) {
            AddPodView()
        }
        .alert("Delete this pod?", isPresented: Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let pendingDeletion {
                    Task { await podsStore.deletePod(pendingDeletion) }
                }
            }
        } message: {
            Text("This removes it for every guest immediately, along with its photos and any reservations against it. This can't be undone.")
        }
    }
}

private struct MyPodRow: View {
    let pod: Pod
    let photoURL: String?
    let onDelete: () -> Void

    private var locationLine: String {
        [pod.region, pod.country].compactMap { $0 }.joined(separator: ", ")
    }

    var body: some View {
        HStack(spacing: 12) {
            PodPhoto(url: photoURL)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.r12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(pod.name)
                    .font(AppFont.pillLabelBold(15))
                    .foregroundColor(.appTextPrimary)
                Text(locationLine)
                    .font(AppFont.mediumLabel(13))
                    .foregroundColor(.appTextMuted)
                if let beds = pod.bedsTotal {
                    Text("\(beds) bed\(beds == 1 ? "" : "s")")
                        .font(AppFont.mediumLabel(12))
                        .foregroundColor(.appTextMuted)
                }
            }

            Spacer()

            Button(action: onDelete) {
                Text("Delete")
                    .font(AppFont.mediumLabel(13))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.06)).frame(height: 0.5)
        }
    }
}

#Preview {
    MyPodsView(onBack: {})
}
