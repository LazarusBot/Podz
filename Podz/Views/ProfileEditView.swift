//
//  ProfileEditView.swift
//  Podz
//
//  Created by Max Prx on 20/08/2026.
//

import SwiftUI

/// node 3827:1465 — "Profile" edit screen. Reached by tapping the
/// avatar/name row at the top of ProfileView.
struct ProfileEditView: View {
    var onBack: () -> Void
    
    @StateObject private var auth = AuthManager.shared
    @State private var editingField: EditableField?
    @State private var editValue = ""
    
    private enum EditableField {
        case username, name, age, location
        
        var title: String {
            switch self {
            case .username: return "Edit username"
            case .name: return "Edit name"
            case .age: return "Update age"
            case .location: return "Edit location"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ProfileTopBar(title: "@\(auth.profile?.username ?? "guest")", onBack: onBack)
            
            AvatarPicker(currentImageURL: auth.profile?.avatarURL, size: 94)
                .padding(.horizontal, 24)
                .padding(.vertical, 31)
                .frame(maxWidth: .infinity)
                .background(Color.appHomeBackground)
            
            ProfileEditRow(
                value: auth.profile?.username.map { "@\($0)" } ?? "@guest",
                label: "Edit username"
            ) { startEditing(.username, current: auth.profile?.username ?? "") }
            
            ProfileEditRow(
                value: auth.profile?.fullName ?? "—",
                label: "Edit name"
            ) { startEditing(.name, current: auth.profile?.fullName ?? "") }
            
            ProfileEditRow(
                value: auth.profile?.age.map(String.init) ?? "—",
                label: "Update age"
            ) { startEditing(.age, current: auth.profile?.age.map(String.init) ?? "") }
            
            ProfileEditRow(
                value: auth.profile?.location ?? "—",
                label: "Edit location"
            ) { startEditing(.location, current: auth.profile?.location ?? "") }
            
            Spacer()
        }
        .background(Color.appHomeBackground)
        .errorAlert($auth.lastError)
        .alert(
            editingField?.title ?? "",
            isPresented: Binding(get: { editingField != nil }, set: { if !$0 { editingField = nil } })
        ) {
            TextField("", text: $editValue)
                .keyboardType(editingField == .age ? .numberPad : .default)
            Button("Cancel", role: .cancel) { editingField = nil }
            Button("Save") {
                guard let field = editingField else { return }
                let value = editValue
                Task { await save(field: field, value: value) }
            }
        }
    }
    
    private func startEditing(_ field: EditableField, current: String) {
        editValue = current
        editingField = field
    }
    
    private func save(field: EditableField, value: String) async {
        switch field {
        case .username:
            await auth.updateProfile(username: value)
        case .name:
            await auth.updateProfile(fullName: value)
        case .age:
            await auth.updateProfile(age: Int(value))
        case .location:
            await auth.updateProfile(location: value)
        }
    }
}

#Preview {
    ProfileEditView(onBack: {})
}
