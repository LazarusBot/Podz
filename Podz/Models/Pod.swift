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

    enum CodingKeys: String, CodingKey {
        case id, name
        case podType = "pod_type"
        case country, region, address, latitude, longitude
        case altitudeM = "altitude_m"
        case bedsTotal = "beds_total"
        case description
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
