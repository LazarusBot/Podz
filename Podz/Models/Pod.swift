//
//  Pod.swift
//  Podz
//
//  Created by Max Prx on 20/08/2026.
//

// Models/Pod.swift
import Foundation

struct Pod: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var podType: String
    var country: String
    var region: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var altitudeM: Int?
    var bedsTotal: Int?
    var description: String?
    /// The host who created this pod — nil for every pod that existed
    /// before host accounts (see SQL/host_accounts.sql), not just newly
    /// created ones.
    var hostId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, name
        case podType = "pod_type"
        case country, region, address, latitude, longitude
        case altitudeM = "altitude_m"
        case bedsTotal = "beds_total"
        case description
        case hostId = "host_id"
    }
}

/// Insert body for `PodsStore.createPod` — same split as
/// `ReservationInsert`/`Reservation`: no `id` (server-generated), and
/// `hostId` is required here (unlike `Pod.hostId`, which stays optional
/// to cover pre-host-accounts pods already in the table).
struct PodInsert: Codable {
    var name: String
    var podType: String
    var country: String
    var region: String?
    var address: String?
    var latitude: Double?
    var longitude: Double?
    var altitudeM: Int?
    var bedsTotal: Int?
    var description: String?
    var hostId: UUID

    enum CodingKeys: String, CodingKey {
        case name
        case podType = "pod_type"
        case country, region, address, latitude, longitude
        case altitudeM = "altitude_m"
        case bedsTotal = "beds_total"
        case description
        case hostId = "host_id"
    }
}

struct PodRoom: Codable, Identifiable, Equatable {
    let id: UUID
    let podId: UUID
    var photoURL: String?
    var priceMin: Double
    var priceMax: Double
    var position: Int

    enum CodingKeys: String, CodingKey {
        case id
        case podId = "pod_id"
        case photoURL = "photo_url"
        case priceMin = "price_min"
        case priceMax = "price_max"
        case position
    }
}

struct PodPhotoRow: Codable {
    let podId: UUID
    let url: String

    enum CodingKeys: String, CodingKey {
        case podId = "pod_id"
        case url
    }
}

/// Insert body for one `pod_photos` row — same shape as `PostPhotoInsert`
/// (`PostsStore.createPost` uploads to Storage first, then inserts one of
/// these per photo with the resulting public URL).
struct PodPhotoInsert: Codable {
    var podId: UUID
    var url: String
    var position: Int

    enum CodingKeys: String, CodingKey {
        case podId = "pod_id"
        case url, position
    }
}
