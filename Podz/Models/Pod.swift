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
    /// What a night costs per person (nil = not known: the hut sets it).
    var pricePerNight: Double?
    var priceCurrency: String?
    /// Hand-picked: shown first and ranked above the rest.
    var featured: Bool?

    /// "45 € / night", when the price is known.
    var priceText: String? {
        guard let price = pricePerNight else { return nil }
        let currency = priceCurrency ?? "EUR"
        let symbol = currency == "EUR" ? "€" : currency
        let amount = price.rounded() == price ? String(Int(price)) : String(format: "%.2f", price)
        return "\(amount) \(symbol) / night"
    }

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
        case listingStatus = "listing_status"
        case phone, email, website
        case bookingURL = "booking_url"
        case openingHours = "opening_hours"
        case source, facilities
        case featured
        case pricePerNight = "price_per_night"
        case priceCurrency = "price_currency"
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

