//
//  LennyResultCard.swift
//  Podz
//
//  Created by Max Prx on 21/08/2026.
//

import SwiftUI

/// Full-width selectable pod card in Lenny's results (node 3829:2137) —
/// square photo, details row below with a round selection button
/// instead of just navigating on tap.
struct LennyResultCard: View {
    let pod: Pod
    var photoURL: String?
    var isSelected: Bool
    var selectedIcon: String = "checkmark"
    var enableFolderPicker: Bool = false
    /// LikesView's folder cards pass PodCard.scaledCornerRadius(for: 345)
    /// so the rounding matches PodCard's at this much bigger photo size;
    /// left at Lenny's original 10 everywhere else.
    var photoCornerRadius: CGFloat = 10
    var onToggleSelect: () -> Void = {}
    var onTapCard: () -> Void = {}
    @State private var showFolderPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Button(action: onTapCard) {
                PodPhoto(url: photoURL)
                    .frame(width: 345, height: 345)
                    .clipShape(RoundedRectangle(cornerRadius: photoCornerRadius))
                    .overlay(RoundedRectangle(cornerRadius: photoCornerRadius).strokeBorder(Color.white.opacity(0.75), lineWidth: 3))
            }
            .buttonStyle(.plain)
            
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(pod.name)
                        .font(AppFont.pillLabel(20))
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    Text("24-27 July")
                        .font(AppFont.pillLabel(14))
                        .foregroundColor(.black)
                    HStack(spacing: 5) {
                        Circle().fill(Color.appAvailableGreen).frame(width: 8, height: 8)
                        Text("\(pod.bedsTotal ?? 0) beds available")
                            .font(AppFont.pillLabel(14))
                            .foregroundColor(.appAvailableGreen)
                    }
                }
                
                Spacer()
                
                Button {
                    if enableFolderPicker && !isSelected {
                        showFolderPicker = true
                    } else {
                        onToggleSelect()
                    }
                } label: {
                    Circle()
                        .fill(isSelected ? Color.appAccentBlack : Color.white)
                        .frame(width: 25, height: 25)
                        .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))
                        .overlay {
                            if isSelected {
                                Image(systemName: selectedIcon)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                }
                .likeFolderPicker(for: pod, isPresented: $showFolderPicker)
            }
            .padding(.horizontal, 5)
        }
        .frame(width: 345)
    }
}
