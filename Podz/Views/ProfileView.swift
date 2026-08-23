//
//  ProfileView.swift
//  Podz
//
//  Created by Max Prx on 13/08/2026.
//

import SwiftUI

/// node 3827:1368 — "Profile"
struct ProfileView: View {
    var onBack: (() -> Void)? = nil
    @StateObject private var auth = AuthManager.shared
    @State private var showEditProfile = false
    @State private var showDeleteAccountConfirmation = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if showEditProfile {
                ProfileEditView(onBack: { showEditProfile = false })
            } else {
                VStack(spacing: 0) {
                    ProfileTopBar(title: "Profile", onBack: onBack)
                    
                    ProfileAccountRow(
                        name: auth.profile?.displayName ?? "Guest",
                        subtitle: auth.profile?.username.map { "@\($0)" } ?? "Show profile",
                        avatarImageName: auth.profile?.avatarURL,
                    ) {
                        showEditProfile = true
                    }
                    
                    ProfilePromoCard()
                    
                    VStack(spacing: 0) {
                        ProfileMenuRow(icon: "creditcard", title: "Payments and payouts")
                        ProfileMenuRow(icon: "lock.shield", title: "Login and security")
                        ProfileMenuRow(icon: "figure.roll", title: "Accessibility")
                    }
                    
                    Spacer()
                    
                    ProfileMenuRow(icon: "rectangle.portrait.and.arrow.right", title: "Log out", isDestructive: true) {
                        Task { await AuthManager.shared.signOut() }
                    }
                    
                    ProfileMenuRow(icon: "trash", title: "Delete account", isDestructive: true) {
                        showDeleteAccountConfirmation = true
                    }
                    // Room so the last row doesn't hide behind the floating tab bar.
                    Color.clear.frame(height: 120)
                }
                .background(Color.appHomeBackground)
                .alert("Delete your account?", isPresented: $showDeleteAccountConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Delete", role: .destructive) {
                        Task { await AuthManager.shared.deleteAccount() }
                    }
                } message: {
                    Text("This permanently deletes your account, profile, and liked pods. This can't be undone.")
                }
            }
        }
        .background(Color.appHomeBackground.ignoresSafeArea())
    }
}

#Preview {
    ProfileView()
}
