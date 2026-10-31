//
//  ProfileEditView.swift
//  Podz
//
//  Created by Max Prx on 20/08/2026.
//

import SwiftUI

/// Edit profile: your photo, then the four fields written right where they
/// are (no pop-up). Nothing is sent until **Save**, the page's action beside
/// back, which lights up once something changed. The return key moves down the
/// fields and, on the last one, saves.
struct ProfileEditView: View {
    var onBack: () -> Void

    @StateObject private var auth = AuthManager.shared
    @FocusState private var focused: Field?
    @State private var showsPhotoPicker = false
    @State private var username = ""
    @State private var fullName = ""
    @State private var age = ""
    @State private var location = ""
    @State private var isSaving = false
    @State private var didLoad = false

    private enum Field: Hashable {
        case username, fullName, age, location
    }

    // MARK: - What changed

    private var originalUsername: String { auth.profile?.username ?? "" }
    private var originalName: String { auth.profile?.fullName ?? "" }
    private var originalAge: String { auth.profile?.age.map(String.init) ?? "" }
    private var originalLocation: String { auth.profile?.location ?? "" }

    private var cleanedUsername: String {
        username.trimmingCharacters(in: .whitespaces).lowercased().replacingOccurrences(of: " ", with: "")
    }

    private var hasChanges: Bool {
        cleanedUsername != originalUsername
            || fullName.trimmingCharacters(in: .whitespaces) != originalName
            || ageChanged
            || location.trimmingCharacters(in: .whitespaces) != originalLocation
    }

    /// Clearing the age isn't a change (a profile can't lose it here).
    private var ageChanged: Bool {
        let years = age.trimmingCharacters(in: .whitespaces)
        return !years.isEmpty && years != originalAge
    }

    /// A username is required; an age, when given, is a number.
    private var isValid: Bool {
        !cleanedUsername.isEmpty && (age.trimmingCharacters(in: .whitespaces).isEmpty || Int(age.trimmingCharacters(in: .whitespaces)) != nil)
    }

    private var canSave: Bool { hasChanges && isValid && !isSaving }

    // MARK: - Body

    var body: some View {
        SectionPage(
            title: "Edit profile",
            onBack: onBack,
            trailing: {
                DetailTextButton(title: isSaving ? "Saving…" : "Save", isHighlighted: canSave, action: save)
                    .disabled(!canSave)
                    .opacity(canSave || isSaving ? 1 : 0.45)
            },
            content: {
                photo
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .padding(.bottom, 24)

                field(.username, label: "Username", text: $username, prefix: "@", submit: .next)
                field(.fullName, label: "Name", text: $fullName, submit: .next)
                field(.age, label: "Age", text: $age, keyboard: .numberPad, submit: .next)
                field(.location, label: "Location", text: $location, submit: .done)
            }
        )
        .errorAlert($auth.lastError)
        .onAppear(perform: load)
        .onChange(of: auth.profile?.username) { _, _ in load() }
        .onSubmit(of: .text) { advance() }
    }

    // MARK: - Photo

    /// The round photo and a caption to change it: tapping either opens the
    /// photo picker (the upload itself is `AvatarPicker`'s).
    private var photo: some View {
        HStack(spacing: 20) {
            Button { showsPhotoPicker = true } label: {
                AvatarPicker(
                    currentImageURL: auth.profile?.avatarURL,
                    size: 96,
                    cornerRadius: nil,
                    showsStroke: false,
                    isPickerPresented: $showsPhotoPicker,
                    isInteractive: false
                )
            }
            .buttonStyle(TapScaleButtonStyle())
            .accessibilityLabel("Change profile photo")

            VStack(alignment: .leading, spacing: 6) {
                Text("Your photo")
                    .font(AppFont.semiBoldLabel(16))
                    .foregroundColor(.homeText)
                Button { showsPhotoPicker = true } label: {
                    HStack(spacing: 5) {
                        Text("Change photo")
                            .font(AppFont.regularLabel(13))
                            .foregroundColor(.homeSubtitle)
                            .underline(color: Color.homeSubtitle.opacity(0.5))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.homeSubtitle)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Fields

    /// A small label over the value, written in place; the line under it turns
    /// solid while it has the keyboard.
    private func field(
        _ id: Field,
        label: String,
        text: Binding<String>,
        prefix: String? = nil,
        keyboard: UIKeyboardType = .default,
        submit: SubmitLabel
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.regularLabel(13))
                .foregroundColor(.homeSubtitle)

            HStack(spacing: 2) {
                if let prefix {
                    Text(prefix)
                        .font(AppFont.semiBoldLabel(17))
                        .foregroundColor(.homeSubtitle)
                }
                TextField("", text: text, prompt: Text("—").foregroundColor(.homeSubtitle))
                    .font(AppFont.semiBoldLabel(17))
                    .foregroundColor(.homeText)
                    .tint(.homeText)
                    .keyboardType(keyboard)
                    .textInputAutocapitalization(id == .username ? .never : .words)
                    .autocorrectionDisabled(id == .username)
                    .submitLabel(submit)
                    .focused($focused, equals: id)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .onTapGesture { focused = id }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.homeText.opacity(focused == id ? 0.6 : 0.08))
                .frame(height: focused == id ? 1 : 0.5)
                .padding(.horizontal, 24)
        }
        .animation(.easeOut(duration: 0.2), value: focused)
    }

    /// Return moves to the next field; on the last one it saves.
    private func advance() {
        switch focused {
        case .username: focused = .fullName
        case .fullName: focused = .age
        case .age: focused = .location
        case .location:
            focused = nil
            if canSave { save() }
        case nil: break
        }
    }

    // MARK: - Loading and saving

    /// The fields start as the profile says (once, so typing isn't overwritten).
    private func load() {
        guard !didLoad, auth.profile != nil else { return }
        didLoad = true
        username = originalUsername
        fullName = originalName
        age = originalAge
        location = originalLocation
    }

    /// Sends only what changed, then goes back.
    private func save() {
        guard canSave else { return }
        focused = nil
        isSaving = true
        Task {
            let name = fullName.trimmingCharacters(in: .whitespaces)
            let place = location.trimmingCharacters(in: .whitespaces)
            let years = age.trimmingCharacters(in: .whitespaces)
            await auth.updateProfile(
                username: cleanedUsername != originalUsername ? cleanedUsername : nil,
                fullName: name != originalName ? name : nil,
                age: ageChanged ? Int(years) : nil,
                location: place != originalLocation ? place : nil
            )
            isSaving = false
            if auth.lastError == nil { onBack() }
        }
    }
}

#Preview {
    ProfileEditView(onBack: {})
}
