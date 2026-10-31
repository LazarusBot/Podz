//
//  Pod.swift
//  Podz
//
//  Created by Max Prx on 20/08/2026.
//

// Models/Pod.swift
import Foundation
import CoreLocation

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
    /// Set after creation, not at insert — a host's optional in-app LiDAR
    /// scan (see SQL/pod_3d_models.sql) uploads after the pod row and any
    /// photos already exist, same reason it's not on `PodInsert` either.
    var modelURL: String?
    /// "partner" (bookable in the app) or "listed" (information only: book
    /// through the hut). Nil reads as a partner, like every pod before this.
    var listingStatus: String?
    /// How to reach a listed hut, whichever it has.
    var phone: String?
    var email: String?
    var website: String?
    var bookingURL: String?
    var openingHours: String?
    /// Where a listed hut's information comes from ("osm"), for the credit.
    var source: String?
    /// What the hut has on site ("Meals", "Showers"...). Nil = not known.
    var facilities: [String]?

    /// A partner hut is reserved in the app; a listed one is booked through
    /// the hut itself.
    var isBookable: Bool { listingStatus != "listed" }

    /// Some way to book a listed hut through the hut itself.
    var hasContact: Bool {
        [phone, email, website, bookingURL].contains { !($0 ?? "").isEmpty }
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case podType = "pod_type"
        case country, region, address, latitude, longitude
        case altitudeM = "altitude_m"
        case bedsTotal = "beds_total"
        case description
        case hostId = "host_id"
        case modelURL = "model_url"
        case listingStatus = "listing_status"
        case phone, email, website
        case bookingURL = "booking_url"
        case openingHours = "opening_hours"
        case source, facilities
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
    /// Author and licence of a photo taken from Wikimedia Commons.
    var credit: String?

    enum CodingKeys: String, CodingKey {
        case podId = "pod_id"
        case url, credit
    }
}

extension Pod {
    /// Where it is, for the satellite picture a pod gets when it has no photo.
    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
