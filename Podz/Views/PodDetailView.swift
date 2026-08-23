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
    @State private var heroPhotoURL: String?
    @State private var cameraPosition: MapCameraPosition = .automatic
    
    /// Same boilerplate text for every pod for now — not pod-specific yet.
    private let cancellationPolicy = "For organisational reasons we ask you to inform us immediately of any changes or cancellations to your reservation. This will allow us to provide accomodation for other shelter seeking mountaineers."
    
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
            rooms = await PodsStore.shared.rooms(forPodId: pod.id)
            heroPhotoURL = PodsStore.shared.primaryPhotoByPodId[pod.id]
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
        ZStack(alignment: .top) {
            GeometryReader { proxy in
                PodPhoto(url: heroPhotoURL)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            }
            .frame(height: 260)
            
            HStack {
                CircleIconButton(systemName: "chevron.left", action: onBack)
                Spacer()
                CircleIconButton(systemName: "square.and.arrow.up") { }
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pod.name)
                .font(AppFont.pillLabel(24))
                .fontWeight(.black)
                .foregroundColor(.black)
            
            HStack(spacing: 10) {
                Text(pod.region ?? "")
                    .font(AppFont.pillLabel(20))
                    .foregroundColor(Color(white: 0.67))
                if pod.region != nil {
                    Circle().fill(Color(white: 0.67)).frame(width: 4, height: 4)
                }
                Text(pod.country)
                    .font(AppFont.pillLabel(20))
                    .foregroundColor(Color(white: 0.67))
            }
            
            HStack(spacing: 10) {
                if let altitude = pod.altitudeM {
                    Text("\(altitude) m")
                        .font(AppFont.pillLabel(16))
                        .foregroundColor(Color(white: 0.67))
                }
                Circle().fill(Color(white: 0.67)).frame(width: 4, height: 4)
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
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(rooms) { room in
                        PodRoomCard(room: room)
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
                    Map(position: $cameraPosition) {
                        Marker(pod.name, coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                    }
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
                }
            }
            .frame(height: 283)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.white, lineWidth: 1))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}

private struct CircleIconButton: View {
    let systemName: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.black)
                .frame(width: 31, height: 31)
        }
        .background(Circle().fill(Color.white.opacity(0.9)))
        .overlay(Circle().strokeBorder(Color.appBorder, lineWidth: 0.5))
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
