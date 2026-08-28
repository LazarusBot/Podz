//
//  CachedAsyncImage.swift
//  Podz
//
//  Created by Max Prx on 21/08/2026.
//

import SwiftUI
import ImageIO
import CryptoKit

/// Two-tier cache: an in-memory `NSCache` (instant, but wiped whenever
/// the app is terminated), backed by a disk cache in Caches/ that
/// survives across launches. Without the disk tier, every cold app open
/// re-downloaded every pod photo from scratch even for pods already
/// browsed last session — the "little wait before pictures show up on
/// open" — since NSCache alone has nothing left the moment the process
/// dies. Keeps decoded UIImages in memory ready to draw, rather than raw
/// data to redecode each time.
final class ImageCache {
    static let shared = ImageCache()
    private let memoryCache = NSCache<NSString, UIImage>()
    private let diskDirectory: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskDirectory = caches.appendingPathComponent("PodzImageCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }

    /// SHA256 of the URL, not the URL string itself — URLs contain `/`
    /// and other characters that aren't valid filenames, and a hash needs
    /// to be *stable* across launches (unlike Swift's own `hashValue`,
    /// which is randomly salted per process).
    private func diskPath(for url: String) -> URL {
        let digest = SHA256.hash(data: Data(url.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return diskDirectory.appendingPathComponent(hex)
    }

    func image(for url: String) -> UIImage? {
        if let cached = memoryCache.object(forKey: url as NSString) {
            return cached
        }
        guard let data = try? Data(contentsOf: diskPath(for: url)),
              let image = ImageLoader.decodeImage(from: data) else {
            return nil
        }
        memoryCache.setObject(image, forKey: url as NSString)
        return image
    }

    func set(_ image: UIImage, for url: String) {
        memoryCache.setObject(image, forKey: url as NSString)
        // Encoded synchronously (small, and keeps the write itself off
        // the calling code's critical path) so the detached write task
        // only captures Sendable values (Data, URL) — not the UIImage.
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        let path = diskPath(for: url)
        Task.detached(priority: .utility) {
            try? data.write(to: path)
        }
    }
}

/// Shared download + decode pipeline — used by `CachedAsyncImage` and by
/// anywhere else that needs a `UIImage` off a URL without the view-level
/// placeholder/fade machinery (PodDetailView's share card). Checking the
/// cache is left to each caller, since what "already have it" should do
/// differs (CachedAsyncImage avoids a placeholder flash; the share card
/// just skips straight to using it).
enum ImageLoader {
    enum LoadError: Error {
        case badURL
        case httpStatus(Int)
        case decodeFailed(mime: String, byteCount: Int)
    }

    static func load(urlString: String) async throws -> UIImage {
        guard let url = URL(string: urlString), urlString.hasPrefix("http") else {
            throw LoadError.badURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw LoadError.httpStatus(http.statusCode)
        }
        guard let image = decodeImage(from: data) else {
            let mime = (response as? HTTPURLResponse)?.mimeType ?? "unknown"
            throw LoadError.decodeFailed(mime: mime, byteCount: data.count)
        }
        return image
    }

    /// `UIImage(data:)` alone misses some formats ImageIO otherwise
    /// supports — WebP included, since it depends on which decoder
    /// `UIImage`'s own format-sniffing picks. Going through
    /// `CGImageSource` directly is the more complete path and is what
    /// actually recovers WebP (static frames; animated WebP still only
    /// decodes its first frame here, same as this app treats GIFs/APNGs).
    static func decodeImage(from data: Data) -> UIImage? {
        if let image = UIImage(data: data) {
            return image
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        // UIImage(cgImage:) alone ignores EXIF orientation — unlike
        // UIImage(data:), which applies it automatically. A portrait
        // photo with rotation metadata would otherwise report its raw
        // (rotated) pixel dimensions as its "ideal size," throwing off
        // any .aspectRatio(.fill) computed from it.
        return UIImage(cgImage: cgImage, scale: 1, orientation: exifOrientation(from: source))
    }

    private static func exifOrientation(from source: CGImageSource) -> UIImage.Orientation {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let raw = properties[kCGImagePropertyOrientation] as? UInt32 else {
            return .up
        }
        // Standard TIFF/EXIF orientation values (1-8) mapped to UIImage's
        // own enum, same table UIKit itself uses internally.
        switch raw {
        case 1: return .up
        case 2: return .upMirrored
        case 3: return .down
        case 4: return .downMirrored
        case 5: return .leftMirrored
        case 6: return .right
        case 7: return .rightMirrored
        case 8: return .left
        default: return .up
        }
    }
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
    /// Surfaced instead of silently falling back to `placeholder()` — a
    /// failed network request looks identical to a URL whose bytes just
    /// don't decode as an image, and both used to be indistinguishable
    /// from "still loading."
    @State private var loadError: String?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage).resizable()
            } else if let loadError {
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(loadError)
                        .font(.system(size: 9))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 4)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.red.opacity(0.35))
            } else {
                placeholder()
            }
        }
        .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else {
            uiImage = nil
            loadError = nil
            return
        }

        // Already downloaded once this session — show it immediately, no
        // placeholder flash. This check has to come *before* resetting
        // uiImage to nil below: `.task(id: url)` re-fires every time this
        // view gets recreated (e.g. TabView paging swaps pages in and
        // out), and clearing to nil first — even for an already-cached
        // photo — meant a guaranteed placeholder flash for a frame before
        // flipping right back, which is what was visible as "flashing."
        if let cached = ImageCache.shared.image(for: url) {
            loadError = nil
            uiImage = cached
            return
        }

        uiImage = nil
        loadError = nil

        do {
            let downloaded = try await ImageLoader.load(urlString: url)
            ImageCache.shared.set(downloaded, for: url)
            withAnimation(.easeOut(duration: 0.25)) {
                uiImage = downloaded
            }
        } catch ImageLoader.LoadError.badURL {
            loadError = "Bad URL: \(url)"
        } catch ImageLoader.LoadError.httpStatus(let code) {
            loadError = "HTTP \(code)"
        } catch ImageLoader.LoadError.decodeFailed(let mime, let byteCount) {
            loadError = "Can't decode (\(mime), \(byteCount) bytes)"
        } catch {
            loadError = error.localizedDescription
        }
    }
}
