//
//  AddFriendSheet.swift
//  Podz
//
//  Created by Max Prx on 26/08/2026.
//

import SwiftUI
internal import Auth

/// Username search + send-request flow, presented as a sheet from
/// FriendsView's floating "+" button.
struct AddFriendSheet: View {
    @StateObject private var friendsStore = FriendsStore.shared
    @StateObject private var auth = AuthManager.shared
    @State private var query = ""
    @State private var results: [Profile] = []
    /// Which row's request is currently in flight — drives that row's own
    /// spinner and disables its button, rather than a screen-wide loading
    /// state that would block every other row.
    @State private var sendingUserId: UUID?
    /// Surfaced instead of silently doing nothing on failure — tapping
    /// Add previously called sendRequest(), which on error just set
    /// FriendsStore.lastError with nothing in the UI reading it, so a
    /// failed request (backend permission issue, RLS, etc.) looked
    /// exactly like a completely unresponsive button.
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                CloseButton(action: { dismiss() })
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Text("Add a friend")
                .font(AppFont.pillLabel(20))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.top, 8)
                .padding(.bottom, 16)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.appTextMuted)
                TextField("Search by username", text: $query)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.appIconButtonBackground))
            .padding(.horizontal, 20)
            // Debounced via .task(id:) — every keystroke cancels the
            // previous in-flight search and starts a fresh one after a
            // short pause, instead of firing a request per character.
            .task(id: query) {
                try? await Task.sleep(nanoseconds: 300_000_000)
                guard !Task.isCancelled else { return }
                results = await friendsStore.searchProfiles(username: query)
            }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(results, id: \.id) { profile in
                        resultRow(for: profile)
                    }
                }
                .padding(.top, 16)
            }

            Spacer(minLength: 0)
        }
        .background(Color.appHomeBackground)
        .errorAlert($errorMessage, title: "Couldn't send request")
    }

    private func resultRow(for profile: Profile) -> some View {
        HStack(spacing: 12) {
            AvatarView(imageName: profile.avatarURL, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(AppFont.pillLabelBold(15))
                    .foregroundColor(.black)
                if let username = profile.username {
                    Text("@\(username)")
                        // Same Darker-Grotesque-vs-Inter size mismatch as
                        // FriendsView's `FriendRequestRow` — see there.
                        .font(AppFont.regularLabel(11))
                        .foregroundColor(.appTextMuted)
                }
            }
            Spacer()
            statusButton(for: profile)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func statusButton(for profile: Profile) -> some View {
        let existing = friendsStore.friendship(with: profile.id)

        switch existing?.status {
        case .accepted:
            Text("Friends")
                .font(AppFont.regularLabel(13))
                .foregroundColor(.appTextMuted)
        case .pending:
            if existing?.requesterId == auth.session?.user.id {
                Text("Requested")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.appTextMuted)
                    .padding(.trailing, 8)
            } else {
                // They already sent *you* one — nudge to respond from
                // FriendsView rather than duplicating Accept/Decline here.
                Text("Respond in Friends")
                    .font(AppFont.regularLabel(13))
                    .foregroundColor(.appTextMuted)
            }
        case .declined, nil:
            Button {
                sendingUserId = profile.id
                Task {
                    await friendsStore.sendRequest(to: profile.id)
                    // sendRequest sets this on failure but nothing was
                    // ever reading it — that's the "does nothing" bug.
                    if let error = friendsStore.lastError {
                        errorMessage = error
                        friendsStore.lastError = nil
                    }
                    sendingUserId = nil
                }
            } label: {
                Group {
                    if sendingUserId == profile.id {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Add")
                            .font(AppFont.pillLabelSemiBold(15))
                    }
                }
                .foregroundColor(.white)
                .frame(width: 72, height: 36)
                .background(Capsule().fill(Color.black))
            }
            .disabled(sendingUserId == profile.id)
        }
    }
}

#Preview {
    AddFriendSheet()
}
