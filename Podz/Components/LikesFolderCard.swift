//
//  LikesFolderCard.swift
//  Podz
//
//  Created by Max Prx on 22/08/2026.
//

import SwiftUI

/// Closed folder icon styled after iOS Shared Album folders — pod
/// photos fanned out, sandwiched between a thin back panel (just a
/// rim peeking above/behind them) and an opaque front panel that
/// covers their lower half, giving the "tucked into a pocket" look.
struct LikesFolderCard: View {
    var country: String? = nil
    let pods: [Pod]
    var photoURLs: [UUID: String] = [:]
    var scale: CGFloat = 1
    var onTap: () -> Void = {}
    /// When set, the caption becomes an editable, auto-focused TextField
    /// instead of static text — used for the "creating a new folder"
    /// state in LikeFolderPickerSheet.
    var editableName: Binding<String>? = nil
    var onCommitName: (() -> Void)? = nil
    var showDeleteBadge: Bool = false
    var isWiggling: Bool = false
    var onDelete: () -> Void = {}
    var onLongPress: () -> Void = {}
    @State private var isPressed = false
    @State private var wiggleAngle: Double = 0
    @FocusState private var isNameFocused: Bool
    
    private var previewPods: [Pod] { Array(pods.prefix(3)) }
    private var isEditing: Bool { editableName != nil }
    
    var body: some View {
        Group {
            if isEditing {
                folderVisual
            } else {
                Button {
                    guard !showDeleteBadge else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                        isPressed = false
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 250_000_000)
                        onTap()
                    }
                } label: {
                    folderVisual
                }
                .buttonStyle(NoFadeButtonStyle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !isPressed && !showDeleteBadge {
                                withAnimation(.easeOut(duration: 0.1)) { isPressed = true }
                            }
                        }
                        .onEnded { _ in }
                )
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.4)
                        .onEnded { _ in
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            onLongPress()
                        }
                )
            }
        }
        .rotationEffect(.degrees(isWiggling ? wiggleAngle : 0))
        .onChange(of: isWiggling) { _, wiggling in
            if wiggling {
                withAnimation(.easeInOut(duration: 0.12).repeatForever(autoreverses: true)) {
                    wiggleAngle = Double.random(in: 1.2...1.8)
                }
            } else {
                withAnimation(.linear(duration: 0)) { wiggleAngle = 0 }
            }
        }
        .onChange(of: showDeleteBadge) { _, isEditing in
            if !isEditing {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }
    }
    private var folderVisual: some View {
        VStack(spacing: 10) {
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let backPanelHeight = side * 0.74
                let frontPanelHeight = side * 0.56
                
                ZStack(alignment: .bottom) {
                    // Back panel — a thin sliver, mostly hidden behind
                    // the photos, its tab just peeking above them.
                    FolderShape(tabHeightRatio: 0.10, cornerRadius: side * 0.12)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            FolderShape(tabHeightRatio: 0.10, cornerRadius: side * 0.12)
                                .fill(Color.appAccentBlack.opacity(0.06))
                        )
                        .overlay(
                            FolderShape(tabHeightRatio: 0.10, cornerRadius: side * 0.12)
                                .stroke(Color.white.opacity(0.7), lineWidth: 0.5)
                        )
                        .frame(height: backPanelHeight)

                    // Photos — fanned, rotated, tops clearing the
                    // back panel's top edge so they read as "coming
                    // out of" the folder rather than floating above it.
                    ForEach(Array(previewPods.enumerated()), id: \.element.id) { index, pod in
                        PodPhoto(url: photoURLs[pod.id])
                            .frame(width: side * 0.58, height: side * 0.58)
                            .clipShape(RoundedRectangle(cornerRadius: side * 0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: side * 0.06)
                                    .strokeBorder(Color.white, lineWidth: 2)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            .rotationEffect(.degrees(isPressed ? 0 : rotation(for: index)))
                            .offset(
                                x: isPressed ? 0 : xOffset(for: index, side: side),
                                y: isPressed ? -side * 0.10 : -side * 0.22
                            )
                            .scaleEffect(isPressed ? 0.85 : 1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                    }
                    
                    ZStack(alignment: .bottomTrailing) {
                        RoundedRectangle(cornerRadius: side * 0.12)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: side * 0.12)
                                    .fill(Color.white.opacity(0.18))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: side * 0.12)
                                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)
                            )
                            .shadow(color: .black.opacity(0.08), radius: 3, y: 2)
                        
                        PodCountBadge(count: pods.count)
                            .padding(side * 0.06)
                    }
                    .frame(height: frontPanelHeight)
                }
                .frame(width: side, height: side, alignment: .bottom)
                .overlay(alignment: .topTrailing) {
                    if showDeleteBadge {
                        Button(action: onDelete) {
                            Image(systemName: "minus")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color.red))
                                .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
                                .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        }
                        // Land on the back panel's visible frosted corner
                        // (skip past the empty space above it, then its
                        // own transparent tab gap), drawn last so it
                        // paints above the photo stack too.
                        .offset(
                            x: 4 * scale,
                            y: (side - backPanelHeight) + backPanelHeight * 0.10 - 6 * scale
                        )
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(.top, 8)
            
            if let editableName {
                TextField("Folder name", text: editableName)
                    .font(AppFont.pillLabel(14 * scale))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit { onCommitName?() }
                    .onAppear { isNameFocused = true }
            } else {
                Text(country ?? "")
                    .font(AppFont.pillLabel(14 * scale))
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .lineLimit(1)
            }
        }
        .scaleEffect(scale)
    }
    
    private func rotation(for index: Int) -> Double { [-9, 6, -3][index % 3] }
    private func xOffset(for index: Int, side: CGFloat) -> CGFloat {
        [-side * 0.15, side * 0.13, side * 0.01][index % 3]
    }
}

/// Small circular badge showing how many pods are in a folder — node
/// 4313:2539. Black filled circle, white bold number, matches the same
/// counter badge pattern already used on category chips elsewhere.
private struct PodCountBadge: View {
    let count: Int
    
    var body: some View {
        Text("\(count)")
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.white)
            .frame(minWidth: 22, minHeight: 22)
            .background(Circle().fill(Color.appAccentBlack))
            .overlay(Circle().strokeBorder(Color.white, lineWidth: 1.5))
            .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
    }
}

/// Same as .plain, but explicitly locks opacity to 1 regardless of
/// press state — some system button styles subtly dim content on press
/// even with .plain, which fought against the folder's own base
/// transparency. The photo/panel animations already provide press
/// feedback, so no extra dimming is needed on top.
private struct NoFadeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(1)
    }
}
