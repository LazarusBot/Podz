//
//  LennyItineraryParser.swift
//  Podz
//
//  Created by Max Prx on 21/08/2026.
//

import NaturalLanguage
import CoreLocation
import MapKit

/// Extracts place names from free text using Apple's on-device NLP, then
/// geocodes each one. No LLM, no backend — everything runs locally.
enum LennyItineraryParser {
    /// Pulls out proper-noun place names using NLTagger's built-in name
    /// recognizer, filtered to Place tags.
    static func extractPlaceNames(from text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var places: [String] = []
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if tag == .placeName {
                places.append(String(text[range]))
            }
            return true
        }
        return places
    }
    
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
