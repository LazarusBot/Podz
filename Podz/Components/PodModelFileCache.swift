//
//  PodModelFileCache.swift
//  Podz
//
//  Created by Max Prx on 22/09/2026.
//

import Foundation
import CryptoKit

/// Same two-tier shape as `ImageCache` in `CachedAsyncImage.swift` — an
/// `NSCache` memory tier backed by a disk directory keyed by SHA256(url) —
/// but for raw `.usdz` `Data` instead of `UIImage`. A `.usdz` isn't
/// decodable as an image, so it can't reuse `ImageCache` directly.
final class PodModelFileCache {
    static let shared = PodModelFileCache()
    private let memoryCache = NSCache<NSString, NSData>()
    private let diskDirectory: URL

    private init() {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskDirectory = caches.appendingPathComponent("PodzModelCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }

    private func diskPath(for url: String) -> URL {
        let digest = SHA256.hash(data: Data(url.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        return diskDirectory.appendingPathComponent(hex)
    }

    func data(for url: String) -> Data? {
        if let cached = memoryCache.object(forKey: url as NSString) {
            return cached as Data
        }
        guard let data = try? Data(contentsOf: diskPath(for: url)) else { return nil }
        memoryCache.setObject(data as NSData, forKey: url as NSString)
        return data
    }

    func set(_ data: Data, for url: String) {
        memoryCache.setObject(data as NSData, forKey: url as NSString)
        let path = diskPath(for: url)
        Task.detached(priority: .utility) {
            try? data.write(to: path)
        }
    }
}
