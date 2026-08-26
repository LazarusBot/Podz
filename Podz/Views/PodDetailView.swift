//
//  PodDetailView.swift
//  Podz
//
//  Created by Max Prx on 20/08/2026.
//

import SwiftUI
import MapKit

/// node 4028:586 — pod detail screen. No bottom tab bar here — MainTabView's
/// bar stays visible underneath, same pattern as ProfileEditView.
struct PodDetailView: View {
    let pod: Pod
    var onBack: () -> Void

    @State private var rooms: [PodRoom] = []
    @State private var isLoadingRooms = true
    @State private var heroPhotoURLs: [String]
    @State private var heroPageIndex = 0
    @State private var cameraPosition: MapCameraPosition = .automatic
    @ObservedObject private var likesStore = LikesStore.shared
    @State private var showFolderPicker = false

    /// Same boilerplate text for every pod for now — not pod-specific yet.
    private let cancellationPolicy = "For organisational reasons we ask you to inform us immediately of any changes or cancellations to your reservation. This will allow us to provide accomodation for other shelter seeking mountaineers."

    /// Seeded from the Home card's already-fetched primary photo so the
    /// hero shows something on the very first frame — the full ordered
    /// carousel only arrives once `photos(forPodId:)` resolves in `.task`.
    init(pod: Pod, onBack: @escaping () -> Void) {
        self.pod = pod
        self.onBack = onBack
        let seed = PodsStore.shared.primaryPhotoByPodId[pod.id]
        _heroPhotoURLs = State(initialValue: seed.map { [$0] } ?? [])
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                heroImage
                header
                Divider().padding(.horizontal, 20)
                pricesSection
                Divider().padding(.horizontal, 20)
                cancellationSection
                Divider().padding(.horizontal, 20)
                mapSection
                Color.clear.frame(height: 100)
            }
        }
        .scrollEdgeEffectStyle(.hard, for: .top)
        .ignoresSafeArea(edges: .top)
        .background(Color.appHomeBackground)
        .task {
            async let roomsTask = PodsStore.shared.rooms(forPodId: pod.id)
            async let photosTask = PodsStore.shared.photos(forPodId: pod.id)
            let (fetchedRooms, fetchedPhotos) = await (roomsTask, photosTask)
            rooms = fetchedRooms
            isLoadingRooms = false
            if !fetchedPhotos.isEmpty {
                heroPhotoURLs = fetchedPhotos
            }
            if let lat = pod.latitude, let lng = pod.longitude {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                )
            }
        }
    }

    // MARK: - Hero

    private var heroImage: some View {
        GeometryReader { proxy in
            // Overscroll pull-down grows and re-offsets the photo layer so
            // it stretches to fill the gap instead of leaving a gray strip
            // above it — the buttons overlay stays outside this transform
            // so it doesn't drift down with the stretch.
            let stretch = max(0, proxy.frame(in: .global).minY)

            ZStack(alignment: .top) {
                heroGallery
                    .frame(width: proxy.size.width, height: 260 + stretch)
                    .clipped()
                    .offset(y: -stretch)

                HStack(spacing: 12) {
                    CircleIconButton(systemName: "chevron.left", accessibilityLabel: "Back", action: onBack)
                    Spacer()
                    CircleIconButton(
                        systemName: likesStore.isLiked(pod) ? "heart.fill" : "heart",
                        tint: likesStore.isLiked(pod) ? .red : .black,
                        accessibilityLabel: likesStore.isLiked(pod) ? "Remove from likes" : "Add to likes"
                    ) {
                        if likesStore.isLiked(pod) {
                            Task { await likesStore.removeLike(pod) }
                        } else {
                            showFolderPicker = true
                        }
                    }
                    .likeFolderPicker(for: pod, isPresented: $showFolderPicker)
                    ShareLink(item: shareText) {
                        CircleIconGlyph(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
            }
        }
        .frame(height: 260)
    }

    @ViewBuilder
    private var heroGallery: some View {
        if heroPhotoURLs.count > 1 {
            TabView(selection: $heroPageIndex) {
                ForEach(Array(heroPhotoURLs.enumerated()), id: \.offset) { index, url in
                    PodPhoto(url: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        } else {
            PodPhoto(url: heroPhotoURLs.first)
        }
    }

    private var shareText: String {
        var text = pod.name
        if let region = pod.region {
            text += ", \(region)"
        }
        text += ", \(pod.country)"
        if let lat = pod.latitude, let lng = pod.longitude {
            text += "\nhttps://maps.apple.com/?ll=\(lat),\(lng)"
        }
        return text
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pod.name)
                .font(AppFont.pillLabel(24))
                .fontWeight(.black)
                .foregroundColor(.black)

            HStack(spacing: 10) {
                if let region = pod.region {
                    Text(region)
                        .font(AppFont.pillLabel(20))
                        .foregroundColor(Color(white: 0.67))
                    Circle().fill(Color(white: 0.67)).frame(width: 4, height: 4)
                }
                Text(pod.country)
                    .font(AppFont.pillLabel(20))
                    .foregroundColor(Color(white: 0.67))
            }

            if pod.altitudeM != nil || pod.bedsTotal != nil {
                HStack(spacing: 10) {
                    if let altitude = pod.altitudeM {
                        Text("\(altitude) m")
                            .font(AppFont.pillLabel(16))
                            .foregroundColor(Color(white: 0.67))
                    }
                    if pod.altitudeM != nil && pod.bedsTotal != nil {
                        Circle().fill(Color(white: 0.67)).frame(width: 4, height: 4)
                    }
                    if let beds = pod.bedsTotal {
                        Text("\(beds) beds available")
                            .font(AppFont.pillLabel(16))
                            .foregroundColor(Color(white: 0.67))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(white: 0.93)))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }

    // MARK: - Prices and bedrooms

    private var pricesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Prices and bedrooms")
                .font(AppFont.pillLabel(20))
                .fontWeight(.bold)
                .foregroundColor(.black)

            if isLoadingRooms {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 161)
            } else if rooms.isEmpty {
                Text("No rooms listed yet")
                    .font(AppFont.pillLabel(16))
                    .foregroundColor(Color(white: 0.67))
                    .frame(minHeight: 40)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(rooms) { room in
                            PodRoomCard(room: room)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Cancellation

    private var cancellationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Cancel & reservation changes")
                .font(AppFont.pillLabel(20))
                .fontWeight(.bold)
                .foregroundColor(.black)

            Text(cancellationPolicy)
                .font(AppFont.pillLabel(16))
                .foregroundColor(Color(white: 0.67))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    // MARK: - Map

    private var mapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Find us quickly in the wild")
                .font(AppFont.pillLabel(20))
                .fontWeight(.bold)
                .foregroundColor(.black)

            ZStack(alignment: .top) {
                if let lat = pod.latitude, let lng = pod.longitude {
                    // interactionModes: [] — this Map sits inside a
                    // vertical ScrollView, so its own pan/pinch would
                    // otherwise fight the page scroll. Tapping it opens
                    // the real, interactive map in Apple Maps instead.
                    Map(position: $cameraPosition, interactionModes: []) {
                        Marker(pod.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                    }
                    .onTapGesture { openInMaps(lat: lat, lng: lng) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Open \(pod.name) location in Maps")
                } else {
                    Rectangle().fill(Color.gray.opacity(0.2))
                }

                if let address = pod.address {
                    Text(address)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.88)))
                        .padding(.top, 12)
                        .allowsHitTesting(false)
                }
            }
            .frame(height: 283)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white, lineWidth: 1))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func openInMaps(lat: Double, lng: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
        mapItem.name = pod.name
        mapItem.openInMaps()
    }
}

/// Shared visual for the hero's floating circle buttons — factored out so
/// `ShareLink`'s label and `CircleIconButton`'s `Button` label can use the
/// exact same glyph/background/border without duplicating it.
private struct CircleIconGlyph: View {
    let systemName: String
    var tint: Color = .black

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(tint)
            .frame(width: 31, height: 31)
            .background(Circle().fill(Color.white.opacity(0.9)))
            .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))
    }
}

private struct CircleIconButton: View {
    let systemName: String
    var tint: Color = .black
    let accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            CircleIconGlyph(systemName: systemName, tint: tint)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct PodRoomCard: View {
    let room: PodRoom

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PodPhoto(url: room.photoURL)

            Text("\(room.priceMin, specifier: "%.2f")€ - \(room.priceMax, specifier: "%.2f")€")
                .font(AppFont.pillLabel(11))
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.white.opacity(0.33)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.75), lineWidth: 0.5))
                .padding(6)
        }
        .frame(width: 241, height: 161)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.75), lineWidth: 2))
    }
}

#Preview {
    PodDetailView(
        pod: Pod(id: UUID(), name: "Rifugio Passo Santner", podType: "Refuge", country: "Italia", region: "Süd Tirol", address: "Passo Santner, Italy", latitude: 46.4589, longitude: 11.6064, altitudeM: 2734, bedsTotal: 40, description: nil),
        onBack: {}
    )
}
