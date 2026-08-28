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
    @State private var showPodPicker = false
    @State private var bodyText = ""
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isPosting = false
    @State private var errorMessage: String?

    private var canPost: Bool { selectedPod != nil && !isPosting }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                    .foregroundColor(.black)
                Spacer()
                Text("New post")
                    .font(AppFont.pillLabel(18))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
                Button(action: post) {
                    if isPosting {
                        ProgressView()
                    } else {
                        Text("Post")
                            .fontWeight(.bold)
                            .foregroundColor(canPost ? .black : .appBorder)
                    }
                }
                .disabled(!canPost)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            ScrollView {
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
                            .frame(minHeight: 100)
                            .scrollContentBackground(.hidden)
                    }

                    photoPicker
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
        }
        .background(Color.appHomeBackground)
        .onAppear {
            if let lockedPod { selectedPod = lockedPod }
        }
        .sheet(isPresented: $showPodPicker) {
            PodPickerSheet(selectedPod: $selectedPod)
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

    @ViewBuilder
    private var podSelector: some View {
        if let lockedPod {
            podChip(lockedPod, tappable: false)
        } else if let selectedPod {
            podChip(selectedPod, tappable: true)
        } else {
            Button { showPodPicker = true } label: {
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
            if tappable { showPodPicker = true }
        } label: {
            HStack(spacing: 10) {
                PodPhoto(url: podsStore.primaryPhotoByPodId[pod.id])
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
            .padding(8)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().strokeBorder(Color.appBorder, lineWidth: 0.5))
        }
        .disabled(!tappable)
    }

    private var photoPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 6, matching: .images) {
                    VStack(spacing: 4) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 20))
                        Text("Add")
                            .font(AppFont.mediumLabel(11))
                    }
                    .foregroundColor(.appTextMuted)
                    .frame(width: 70, height: 70)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.appBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }

                ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 70, height: 70)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            selectedImages.remove(at: index)
                            if index < selectedItems.count { selectedItems.remove(at: index) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }
                        .offset(x: 5, y: -5)
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

/// Pod picker — same header+list sheet shape as LikeFolderPickerSheet.
private struct PodPickerSheet: View {
    @Binding var selectedPod: Pod?
    @ObservedObject private var podsStore = PodsStore.shared
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredPods: [Pod] {
        guard !query.isEmpty else { return podsStore.pods }
        return podsStore.pods.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.appTextMuted)
                        .frame(width: 31, height: 31)
                        .background(Circle().fill(Color(white: 0.93)))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Text("Choose a pod")
                .font(AppFont.pillLabel(20))
                .fontWeight(.bold)
                .foregroundColor(.black)
                .padding(.top, 8)
                .padding(.bottom, 12)

            TextField("Search pods", text: $query)
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
                            dismiss()
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
        .background(Color.appHomeBackground)
    }
}
