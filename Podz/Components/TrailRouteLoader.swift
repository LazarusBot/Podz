//
//  TrailRouteLoader.swift
//  Podz
//
//  Created by Max Prx on 09/09/2026.
//

import Foundation
import Combine
import SwiftUI
import MapKit

/// Loads a real walking route from the nearest parking to a pod's own
/// coordinate, then flies the map's own camera along it as it reveals a
/// few points at a time — the same self-drawing-route-plus-flyover
/// flourish Strava plays on its own activity maps, backed by an actual
/// `MKDirections` route instead of a decorative shape.
///
/// Owns `cameraPosition` outright rather than leaving `PodDetailView` to
/// coordinate two independent camera writers — the resting shelter shot
/// (`showShelter`, also the arrival shot once the flyover finishes) and
/// the flyover itself are one continuous camera story, not two features
/// that happen to share a `Map`.
///
/// Two on-device lookups, both silently skipped on failure rather than
/// falling back to a fake line: `MKLocalSearch` for the nearest parking (a
/// stand-in "trailhead" — most refuges have no road access of their own,
/// so this is the closest real-world approximation of "where you'd
/// actually start"), then `MKDirections` walking directions from there to
/// the pod. Apple's own walking-directions coverage often doesn't reach a
/// remote mountain refuge at all, so an empty result here is the common
/// case, not a bug — the camera just stays on `showShelter`'s resting shot
/// and no trail draws in.
@MainActor
final class TrailRouteLoader: ObservableObject {
    @Published private(set) var revealedCoordinates: [CLLocationCoordinate2D] = []
    @Published var cameraPosition: MapCameraPosition = .automatic

    private var fullRoute: [CLLocationCoordinate2D] = []
    private var revealTask: Task<Void, Never>?
    /// Guards `startFlyover` so a flickering scroll-visibility signal
    /// (scrolling past `mapSection`, back up, past it again) kicks off the
    /// lookups and the flyover at most once.
    private var hasStartedFlyover = false

    /// The resting shot — centered on the shelter itself, tilted for the
    /// map's own realistic-elevation terrain to actually read as 3D. Also
    /// where the flyover below lands once it finishes, so this is the one
    /// place that framing is defined. Safe to call before the flyover has
    /// even been requested — it's what the map shows while
    /// `mapSection` is still off-screen.
    func showShelter(_ coordinate: CLLocationCoordinate2D) {
        cameraPosition = .camera(
            MapCamera(centerCoordinate: coordinate, distance: 350, heading: 0, pitch: 60)
        )
    }

    /// Kicks off the parking/directions lookups and the flyover — call
    /// only once `mapSection` has actually scrolled into view (see
    /// `PodDetailView`'s `onScrollVisibilityChange`), not the moment the
    /// screen loads: nobody's watching yet at that point, and it burns two
    /// network calls for pods the person never scrolls down to.
    func startFlyover(to destination: CLLocationCoordinate2D) async {
        guard !hasStartedFlyover else { return }
        hasStartedFlyover = true
        guard let start = await nearestParking(near: destination) else { return }
        guard let coordinates = await walkingRouteCoordinates(from: start, to: destination),
              coordinates.count > 1 else { return }
        fullRoute = coordinates
        reveal(destination: destination)
    }

    private func nearestParking(near coordinate: CLLocationCoordinate2D) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "parking"
        request.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 8000, longitudinalMeters: 8000)
        request.resultTypes = .pointOfInterest

        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return response.mapItems
            .map(\.placemark.coordinate)
            .min { lhs, rhs in
                CLLocation(latitude: lhs.latitude, longitude: lhs.longitude).distance(from: origin)
                    < CLLocation(latitude: rhs.latitude, longitude: rhs.longitude).distance(from: origin)
            }
    }

    private func walkingRouteCoordinates(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async -> [CLLocationCoordinate2D]? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .walking

        guard let response = try? await MKDirections(request: request).calculate(),
              let route = response.routes.first else { return nil }
        return route.polyline.coordinates
    }

    /// Walks the camera stop-by-stop along the route's own points, one
    /// continuous eased animation per hop. Fewer, longer hops read as
    /// smoother than more, shorter ones — each heading change is its own
    /// discrete "hop" no matter how long its own animation is, so cutting
    /// the number of hops (not just stretching their duration) is what
    /// actually gets rid of the hop-iness, on top of also being slower
    /// overall. Smoothness of the camera's own motion is the priority here
    /// over how quickly it arrives.
    ///
    /// The line's growth is split into several smaller increments across
    /// that same per-hop window rather than jumping straight to the hop's
    /// endpoint the instant it starts — `MapPolyline` is a real MapKit
    /// overlay, not a `Shape`, so it has no `.trim`-style API of its own,
    /// and revealing the whole hop's worth of line up front (an earlier
    /// version of this) made the drawn line visibly lead the camera rather
    /// than the two reading as one movement.
    private func reveal(destination: CLLocationCoordinate2D) {
        revealTask?.cancel()
        let total = fullRoute.count
        guard total > 1 else { return }

        // Evenly spaced by point index, not by actual distance — simple,
        // and slow enough per hop that uneven real-world spacing between
        // stops doesn't read as a pacing problem.
        let waypointCount = min(8, total - 1)
        let hopDuration = 2.5
        let lineSubSteps = 10
        let subStepDuration = hopDuration / Double(lineSubSteps)

        cameraPosition = .camera(
            MapCamera(centerCoordinate: fullRoute[0], distance: 380, heading: 0, pitch: 55)
        )
        revealedCoordinates = [fullRoute[0]]

        revealTask = Task {
            // Lets the starting pose actually land on screen before the
            // walk and the line take off together.
            try? await Task.sleep(for: .seconds(0.3))
            guard !Task.isCancelled else { return }

            var previousIndex = 0
            var previousCoordinate = fullRoute[0]

            for step in 1...waypointCount {
                guard !Task.isCancelled else { return }
                let index = min(total - 1, (total - 1) * step / waypointCount)
                let coordinate = fullRoute[index]

                let heading = Self.bearing(from: previousCoordinate, to: coordinate)
                withAnimation(.easeInOut(duration: hopDuration)) {
                    cameraPosition = .camera(
                        MapCamera(centerCoordinate: coordinate, distance: 380, heading: heading, pitch: 55)
                    )
                }

                for subStep in 1...lineSubSteps {
                    guard !Task.isCancelled else { return }
                    let subIndex = previousIndex + (index - previousIndex) * subStep / lineSubSteps
                    revealedCoordinates = Array(fullRoute[0...max(subIndex, previousIndex)])
                    try? await Task.sleep(for: .seconds(subStepDuration))
                }

                previousIndex = index
                previousCoordinate = coordinate
            }

            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.8)) {
                showShelter(destination)
            }
        }
    }

    /// Initial great-circle bearing from `start` to `end`, in degrees —
    /// what `MapCamera.heading` expects so the flyover looks like it's
    /// facing the way it's walking rather than staying north-up the whole
    /// time.
    private static func bearing(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let lat1 = start.latitude * .pi / 180
        let lon1 = start.longitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let lon2 = end.longitude * .pi / 180
        let deltaLon = lon2 - lon1

        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }
}

private extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
