//
//  PostComposerView.swift
//  Podz
//
//  Created by Max Prx on 27/08/2026.
//

import SwiftUI
import PhotosUI

/// Sheet for posting about a pod — text + up to 6 photos. `lockedPod`
/// pre-fills and locks the pod selector (PodDetailView's "Post about this"
/// entry point); leave nil for the feed's own compose button, which opens
/// a picker instead.
struct PostComposerView: View {
    var lockedPod: Pod? = nil
    var onPosted: () -> Void = {}

    @ObservedObject private var podsStore = PodsStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPod: Pod?
    /// Swaps this sheet's own body between composing and picking a pod —
    /// no nested `.sheet`. A second sheet stacked on top of this one used
    /// to open for "Choose a pod", which meant two separate dismiss
    /// gestures to get back to composing; this is the same one sheet the
    /// whole time, just showing different content.
    @State private var showingPodPicker = false
    @State private var podQuery = ""
    @State private var bodyText = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isPosting = false
    @State private var errorMessage: String?

    private var canPost: Bool { selectedPod != nil && !isPosting }

    private var filteredPods: [Pod] {
        guard !podQuery.isEmpty else { return podsStore.pods }
        return podsStore.pods.filter { $0.name.localizedCaseInsensitiveContains(podQuery) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // Same close-icon styling as every other sheet in the
                // app. Doubles as "back to composing" while the pod
                // picker is showing, instead of dismissing the whole
                // sheet from there.
                Button(action: {
                    if showingPodPicker {
                        showingPodPicker = false
                    } else {
                        dismiss()
                    }
                }) {
                    Image(systemName: showingPodPicker ? "chevron.left" : "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextMuted)
                        .frame(width: 31, height: 31)
                        .background(Circle().fill(Color(white: 0.93)))
                }
                Spacer()
                if !showingPodPicker {
                    Button(action: post) {
                        if isPosting {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(canPost ? .black : .appBorder)
                        }
                    }
                    .disabled(!canPost)
                    .accessibilityLabel("Post")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Own row below the icon buttons, centered — same title
            // placement as every other sheet (ShareFolderSheet,
            // PostsActivityView, AddFriendSheet...) instead of squeezed
            // between two Spacers in the icon row.
            Text(showingPodPicker ? "Choose a pod" : "New post")
                .font(AppFont.pillLabel(20))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.top, 8)
                .padding(.bottom, 12)

            if showingPodPicker {
                podPickerBody
            } else {
                composerBody
            }
        }
        .background(Color.appHomeBackground)
        .onAppear {
            if let lockedPod { selectedPod = lockedPod }
        }
        .onChange(of: selectedItems) { _, newItems in
            Task { await loadImages(from: newItems) }
        }
        .alert("Couldn't post", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // No outer ScrollView — this sized to its intrinsic content before,
    // leaving a block of empty space below it in the .medium sheet.
    // TextEditor stretching to fill what's left of the sheet (and
    // scrolling internally once the draft outgrows that) uses the space
    // instead of wasting it.
    private var composerBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            podSelector

            ZStack(alignment: .topLeading) {
                if bodyText.isEmpty {
                    Text("Write something about this pod...")
                        .font(AppFont.mediumLabel(15))
                        .foregroundColor(.appTextMuted)
                        .padding(.top, 8)
                        .padding(.leading, 5)
                }
                TextEditor(text: $bodyText)
                    .font(AppFont.mediumLabel(15))
                    .scrollContentBackground(.hidden)
            }
            .frame(maxHeight: .infinity)

            photoPicker
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var podSelector: some View {
        if let lockedPod {
            podChip(lockedPod, tappable: false)
        } else if let selectedPod {
            podChip(selectedPod, tappable: true)
        } else {
            Button { showingPodPicker = true } label: {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                    Text("Choose a pod")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(AppFont.mediumLabel(15))
                .foregroundColor(.appTextMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().strokeBorder(Color.appBorder, lineWidth: 0.5))
            }
        }
    }

    private func podChip(_ pod: Pod, tappable: Bool) -> some View {
        Button {
            if tappable { showingPodPicker = true }
        } label: {
            HStack(spacing: 10) {
                // Circle, not a rounded square — matches the capsule's
                // own fully-rounded silhouette instead of clashing with it.
                PodPhoto(url: podsStore.primaryPhotoByPodId[pod.id])
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
                Text(pod.name)
                    .font(AppFont.pillLabelSemiBold(15))
                    .foregroundColor(.black)
                Spacer()
                if tappable {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appTextMuted)
                }
            }
            .padding(.leading, 8)
            .padding(.vertical, 8)
            // Extra beyond the leading/vertical 8 — that reads fine
            // against the circular photo but left the chevron (a much
            // smaller glyph) looking swallowed by the capsule's curve.
            .padding(.trailing, 12)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().strokeBorder(Color.appBorder, lineWidth: 0.5))
        }
        .disabled(!tappable)
    }

    /// 90, not the original 70 — sized up along with the rest of this
    /// sheet's content so the photo row reads as a real section instead
    /// of a small strip.
    private let photoTileSize: CGFloat = 90

    private var photoPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                // Top/trailing padding below reserves room for each
                // thumbnail's remove button, which pokes outside its own
                // frame (top-right, via .offset) — without it, the
                // ScrollView clips straight to the thumbnails' own
                // bounds and cuts the button's top edge off.
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 6, matching: .images) {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 24))
                        Text("Add")
                            .font(AppFont.mediumLabel(12))
                    }
                    .foregroundColor(.appTextMuted)
                    .frame(width: photoTileSize, height: photoTileSize)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }

                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: photoTileSize, height: photoTileSize)
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        Button {
                            selectedImages.remove(at: index)
                            if index < selectedItems.count { selectedItems.remove(at: index) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: 6, y: -6)
                    }
                }
            }
            .padding(.top, 7)
            .padding(.trailing, 7)
        }
    }

    // MARK: - Pod picker (in-place, not a nested sheet)

    private var podPickerBody: some View {
        VStack(spacing: 0) {
            TextField("Search pods", text: $podQuery)
                .font(AppFont.mediumLabel(15))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().strokeBorder(Color.appBorder, lineWidth: 0.5))
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredPods) { pod in
                        Button {
                            selectedPod = pod
                            podQuery = ""
                            showingPodPicker = false
                        } label: {
                            HStack(spacing: 12) {
                                PodPhoto(url: podsStore.primaryPhotoByPodId[pod.id])
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pod.name)
                                        .font(AppFont.pillLabelSemiBold(15))
                                        .foregroundColor(.black)
                                    Text(pod.country)
                                        .font(AppFont.mediumLabel(12))
                                        .foregroundColor(.appTextMuted)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                        }
                    }
                }
            }
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        selectedImages = images
    }

    private func post() {
        guard let selectedPod else { return }
        isPosting = true
        Task {
            let success = await PostsStore.shared.createPost(pod: selectedPod, body: bodyText, images: selectedImages)
            isPosting = false
            if success {
                onPosted()
                dismiss()
            } else {
                errorMessage = PostsStore.shared.lastError ?? "Something went wrong."
            }
        }
    }
}
