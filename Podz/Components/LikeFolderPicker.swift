//
//  LikeFolderPicker.swift
//  Podz
//
//  Created by Max Prx on 23/08/2026.
//

import SwiftUI

/// Attach with `.likeFolderPicker(for: pod, isPresented: $showing)` on
/// any view with a heart button — presents a full sheet (large detent,
/// close X top-left) listing existing folders plus inline creation of
/// a new one.
struct LikeFolderPickerModifier: ViewModifier {
    let pod: Pod
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented) {
                LikeFolderPickerSheet(pod: pod, onDismiss: { isPresented = false })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func likeFolderPicker(for pod: Pod, isPresented: Binding<Bool>) -> some View {
        modifier(LikeFolderPickerModifier(pod: pod, isPresented: isPresented))
    }
}
