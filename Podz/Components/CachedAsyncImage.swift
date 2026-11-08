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
///
/// Built so scrolling never waits on it: photos are decoded **once, off the
/// main thread, already shrunk** to at most `ImageLoader.maxDisplayPixel` on
/// their long side (a 4000 px photo no longer costs 64 MB of memory nor a
/// decode in the middle of a scroll), the disk is read off the main thread
/// too, the memory tier is bounded by what the images weigh, and what is
/// saved to disk is the downloaded file itself (nothing is re-encoded).
final class ImageCache: @unchecked Sendable {
    static let shared = ImageCache()
    private let memoryCache = NSCache<NSString, UIImage>()
    /// The biggest picture seen of each photo, whatever size it was fetched at
    /// (Wikimedia photos come in several), so a screen that needs another size
    /// of a photo already on screen can show that one at once.
    private let anySizeCache = NSCache<NSString, UIImage>()
    private let diskDirectory: URL

    private init() {
        // About 150 MB of decoded photos; the system empties it on a memory
        // warning anyway.
        memoryCache.totalCostLimit = 150 * 1024 * 1024
        anySizeCache.totalCostLimit = 60 * 1024 * 1024
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

    /// Photos of the huts you liked or have a stay at, kept for when there's no
    /// signal (Application Support, not Caches: iOS doesn't empty it).
    private let packDirectory = OfflineStorage.subdirectory("images")

    private func packPath(for url: String) -> URL {
        let digest = SHA256.hash(data: Data(url.utf8))
        return packDirectory.appendingPathComponent(digest.map { String(format: "%02x", $0) }.joined())
    }

    /// Makes sure this photo is on the phone for good. True when it is.
    func keepForOffline(urlString: String) async -> Bool {
        let path = packPath(for: urlString)
        if FileManager.default.fileExists(atPath: path.path) { return true }
        guard let url = ImageLoader.secureURL(urlString),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse).map({ (200...299).contains($0.statusCode) }) ?? true,
              ImageLoader.decodeImage(from: data) != nil else { return false }
        try? data.write(to: path)
        return true
    }

    /// Already decoded in memory: instant, safe to ask while drawing.
    func cachedImage(for url: String) -> UIImage? {
        memoryCache.object(forKey: url as NSString)
    }

    /// From memory, or read from the phone and decoded off the calling thread.
    func image(for url: String) async -> UIImage? {
        if let cached = cachedImage(for: url) { return cached }
        return await Task.detached(priority: .userInitiated) { [self] in
            diskImage(for: url)
        }.value
    }

    private func diskImage(for url: String) -> UIImage? {
        let stored = (try? Data(contentsOf: diskPath(for: url))) ?? (try? Data(contentsOf: packPath(for: url)))
        guard let data = stored,
              let image = ImageLoader.decodeImage(from: data) else {
            return nil
        }
        remember(image, for: url)
        return image
    }

    private func remember(_ image: UIImage, for url: String) {
        // Weighed by its decoded size.
        let cost = Int(image.size.width * image.scale * image.size.height * image.scale * 4)
        memoryCache.setObject(image, forKey: url as NSString, cost: cost)
        let base = Self.baseKey(url) as NSString
        if let known = anySizeCache.object(forKey: base), known.size.width >= image.size.width { return }
        anySizeCache.setObject(image, forKey: base, cost: cost)
    }

    /// The same photo at whatever size is already in memory: sharper or softer
    /// than asked, but there, so a screen opening on it never shows a gray
    /// placeholder first.
    func anySizeImage(for url: String) -> UIImage? {
        anySizeCache.object(forKey: Self.baseKey(url) as NSString)
    }

    /// A photo's address with its size taken out ("/960px-Name.jpg" becomes
    /// "/px-Name.jpg"), so every size of one Wikimedia photo shares a key.
    private static func baseKey(_ url: String) -> String {
        guard url.contains("wikimedia.org"),
              let range = url.range(of: "/[0-9]+px-", options: .regularExpression) else { return url }
        return url.replacingCharacters(in: range, with: "/px-")
    }

    /// Keeps a downloaded photo: decoded in memory, and the file as it came on
    /// disk (written in the background, never re-encoded).
    func store(_ image: UIImage, data: Data, for url: String) {
        remember(image, for: url)
        let path = diskPath(for: url)
        Task.detached(priority: .utility) {
            try? data.write(to: path)
        }
    }
}

/// Shared download + decode pipeline, used by `CachedAsyncImage` and the
/// offline pack (`ImageCache.keepForOffline`). Checking the cache is left to
/// each caller.
enum ImageLoader {
    enum LoadError: Error {
        case badURL
        case httpStatus(Int)
        case decodeFailed(mime: String, byteCount: Int)
    }

    /// Photo URLs come from the database (and from OpenStreetMap or Wikimedia
    /// before that): only https with a host is ever fetched.
    static func secureURL(_ urlString: String) -> URL? {
        guard let url = URL(string: urlString), url.scheme?.lowercased() == "https",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    /// A photo bigger than this is refused rather than held in memory.
    private static let maxBytes = 25_000_000
    /// Nor is one that would decode into more pixels than this (a tiny file
    /// can claim a huge size).
    private static let maxPixels = 50_000_000

    /// What a download gives: the picture ready to draw, and the file as it came.
    struct Downloaded: @unchecked Sendable {
        let image: UIImage
        let data: Data
    }

    /// Photos are shown at most this many pixels on their long side (a bit more
    /// than a full-screen photo on the biggest iPhones): bigger files are
    /// shrunk when they're decoded.
    static let maxDisplayPixel: CGFloat = 1600

    /// One download per photo, shared by every view asking for it at once.
    private actor Coalescer {
        private var tasks: [String: Task<Downloaded, Error>] = [:]
        func load(_ urlString: String) async throws -> Downloaded {
            if let running = tasks[urlString] { return try await running.value }
            let task = Task { try await ImageLoader.fetch(urlString: urlString) }
            tasks[urlString] = task
            defer { tasks[urlString] = nil }
            return try await task.value
        }
    }
    private static let coalescer = Coalescer()

    static func load(urlString: String) async throws -> Downloaded {
        try await coalescer.load(urlString)
    }

    fileprivate static func fetch(urlString: String) async throws -> Downloaded {
        guard let url = secureURL(urlString) else {
            throw LoadError.badURL
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw LoadError.httpStatus(http.statusCode)
        }
        guard data.count <= maxBytes else {
            throw LoadError.decodeFailed(mime: "too large", byteCount: data.count)
        }
        guard let image = decodeImage(from: data) else {
            let mime = (response as? HTTPURLResponse)?.mimeType ?? "unknown"
            throw LoadError.decodeFailed(mime: mime, byteCount: data.count)
        }
        return Downloaded(image: image, data: data)
    }

    /// Decodes a photo, shrunk to `maxDisplayPixel` and fully decoded right
    /// here (call it off the main thread), so drawing it later costs nothing.
    /// Going through `CGImageSource` rather than `UIImage(data:)` also recovers
    /// formats `UIImage` misses (WebP, static frames), and applies the EXIF
    /// rotation.
    static func decodeImage(from data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              fitsInMemory(source) else { return nil }
        // Never blown up: a small photo keeps its own size.
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = (properties?[kCGImagePropertyPixelWidth] as? Int) ?? 0
        let height = (properties?[kCGImagePropertyPixelHeight] as? Int) ?? 0
        let longest = max(width, height)
        let limit = longest > 0 ? min(maxDisplayPixel, CGFloat(longest)) : maxDisplayPixel
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: limit
        ]
        if let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
            return UIImage(cgImage: cgImage)
        }
        return UIImage(data: data)
    }

    /// Reads the size from the header only, before anything is decoded.
    private static func fitsInMemory(_ source: CGImageSource) -> Bool {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else { return true }
        let (pixels, overflow) = width.multipliedReportingOverflow(by: height)
        return width > 0 && height > 0 && !overflow && pixels <= maxPixels
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
    /// The URL `uiImage` belongs to: a recycled view must not keep showing the
    /// previous photo while the next one is read.
    @State private var shownURL: String?
    /// Surfaced instead of silently falling back to `placeholder()` — a
    /// failed network request looks identical to a URL whose bytes just
    /// don't decode as an image, and both used to be indistinguishable
    /// from "still loading."
    @State private var loadError: String?

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
        guard let url else {
            uiImage = nil
            shownURL = nil
            loadError = nil
            return
        }

        // `.task(id: url)` re-fires every time this view is recreated (a TabView
        // paging, a grid recycling it), so the memory check comes first and the
        // old picture is only dropped when this view now has a different URL:
        // no placeholder flash for a photo already loaded, and never the
        // previous photo shown for the next one. Every step that waits checks
        // for cancellation, so a stale load can't overwrite a newer one.
        // In memory: shown at once, no placeholder flash (this is the path
        // that scrolling back and forth takes, and it never leaves the main
        // thread's budget).
        if let cached = ImageCache.shared.cachedImage(for: url) {
            loadError = nil
            uiImage = cached
            shownURL = url
            return
        }

        // Not in memory: this view may have been recycled for another photo, so
        // the old one goes now (never before the memory check above).
        if shownURL != url {
            uiImage = nil
            shownURL = nil
        }
        loadError = nil
        // Another size of this photo is already on screen elsewhere (the card
        // you tapped): show it now, and swap to the right one when it's here.
        if uiImage == nil, let standIn = ImageCache.shared.anySizeImage(for: url) {
            uiImage = standIn
        }

        // On the phone's disk: read and decoded off the main thread.
        if let stored = await ImageCache.shared.image(for: url) {
            guard !Task.isCancelled else { return }
            uiImage = stored
            shownURL = url
            return
        }
        guard !Task.isCancelled else { return }

        do {
            let downloaded = try await ImageLoader.load(urlString: url)
            ImageCache.shared.store(downloaded.image, data: downloaded.data, for: url)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: AppMotion.standard)) {
                uiImage = downloaded.image
            }
            shownURL = url
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
