import SwiftUI

extension View {
    /// The "Error" alert shape repeated across ProfileEditView,
    /// LoginSecurityView, FriendsView, and AddFriendSheet — reads and
    /// clears a `String?` binding (usually a store's own `lastError`).
    /// One definition instead of four copies drifting apart over time.
    func errorAlert(_ message: Binding<String?>, title: String = "Error") -> some View {
        alert(title, isPresented: Binding(
            get: { message.wrappedValue != nil },
            set: { if !$0 { message.wrappedValue = nil } }
        )) {
            Button("OK") { message.wrappedValue = nil }
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}
