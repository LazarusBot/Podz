//
//  LennyItineraryParser.swift
//  Podz
//
//  Created by Max Prx on 21/08/2026.
//

import CoreLocation
import MapKit

/// Turns a place name into a coordinate (Apple Maps, no backend). Reading the
/// sentence itself is `LennyRequestParser`'s job.
enum LennyItineraryParser {
    /// Geocodes a place name into a coordinate + a human-readable region
    /// (e.g. "Dolomiti, Italian Alps") using CLGeocoder.
    static func geocode(_ placeName: String) async -> (coordinate: CLLocationCoordinate2D, region: String)? {
        guard let request = MKGeocodingRequest(addressString: placeName) else { return nil }
        do {
            let mapItems = try await request.mapItems
            guard let mapItem = mapItems.first else { return nil }
            let location = mapItem.location
            let region = mapItem.address?.shortAddress
            let resolvedRegion = (region?.isEmpty ?? true) ? placeName : region!
            return (location.coordinate, resolvedRegion)
        } catch {
            return nil
        }
    }
}
