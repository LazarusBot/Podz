//
//  CachedAsyncImage.swift
//  Podz
//
//  Created by Max Prx on 21/08/2026.
//

import SwiftUI

/// In-memory cache so the same photo doesn't re-download every time its
/// view is recreated (scrolling a list in and out of view, navigating
/// back to a screen). Keeps decoded UIImages ready to draw, rather than
/// raw data to redecode each time.
final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, UIImage>()
    private init() {}

    func image(for url: String) -> UIImage? { cache.object(forKey: url as NSString) }
    func set(_ image: UIImage, for url: String) { cache.setObject(image, forKey: url as NSString) }
}

/// Drop-in replacement for the AsyncImage pattern used across the app
/// (AvatarView, PodPhoto). Adds two things AsyncImage doesn't give you:
/// - in-memory caching, so repeat appearances are instant instead of
///   re-downloading every time
/// - a smooth fade-in on first load, instead of the image popping in
///   the instant the network call finishes
struct CachedAsyncImage<Placeholder: View>: View {
    let url: String?
    @ViewBuilder var placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage).resizable()
            } else {
                placeholder()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        uiImage = nil
        guard let url, let imageURL = URL(string: url), url.hasPrefix("http") else { return }

        // Already downloaded once this session — show it immediately,
        // no fade needed, it should feel instant.
        if let cached = ImageCache.shared.image(for: url) {
            uiImage = cached
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: imageURL)
            guard let downloaded = UIImage(data: data) else { return }
            ImageCache.shared.set(downloaded, for: url)
            withAnimation(.easeOut(duration: 0.25)) {
                uiImage = downloaded
            }
        } catch {
            // Stays nil — placeholder keeps showing, no crash.
        }
    }
}
