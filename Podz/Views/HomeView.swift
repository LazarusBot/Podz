import SwiftUI

/// node 3779:2045 — "Home"
struct HomeView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var likesStore = LikesStore.shared
    @StateObject private var lenny = LennySearchViewModel.shared
    @State private var selectedPod: Pod?
    @State private var selectedCategory = "All"
    
    /// Lenny and All always come first, in that order — everything after
    /// is derived from the real pod_type values loaded from Supabase.
    private var categories: [CategoryScroller.Category] {
        [
            .init(title: "Lenny", icon: "lenny", gradientText: false),
            .init(title: "All")
        ] + podsStore.podTypes.map { type in
                .init(title: type, count: podsStore.count(forType: type))
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            if let pod = selectedPod {
                PodDetailView(pod: pod, onBack: { selectedPod = nil })
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        HomeHeader(
                            greeting: "Good morning,",
                            username: auth.profile?.username ?? "guest",
                            avatarImageName: auth.profile?.avatarURL
                        )
                        
                        if lenny.phase == .idle {
                            CategoryScroller(
                                categories: categories,
                                selected: $selectedCategory,
                                onTapLenny: { lenny.activate() }
                            )
                        } else {
                            LennySearchBar(viewModel: lenny)
                                .padding(.horizontal, 24)
                                .padding(.bottom, 20)
                        }
                        
                        if lenny.phase == .searching {
                            LennySearchSteps(steps: lenny.steps)
                        }
                        
                        if let error = lenny.errorMessage {
                            Text(error)
                                .font(.system(size: 12))
                                .foregroundColor(.red)
                                .padding(.horizontal, 24)
                        }
                        
                        if lenny.phase == .results {
                            LennyJourneyProgress(stops: lenny.journeyStops)
                            
                            VStack(spacing: 30) {
                                ForEach(lenny.matchingPods) { pod in
                                    LennyResultCard(
                                        pod: pod,
                                        photoURL: podsStore.primaryPhotoByPodId[pod.id],
                                        isSelected: lenny.selectedPodIDs.contains(pod.id),
                                        onToggleSelect: { lenny.toggleSelection(for: pod) },
                                        onTapCard: { selectedPod = pod }
                                    )
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 20)
                        } else if lenny.phase == .idle {
                            let nonEmptySections = podsStore.countries.compactMap { country -> (String, [Pod])? in
                                let pods = podsStore.pods(inCountry: country, type: selectedCategory)
                                return pods.isEmpty ? nil : (country, pods)
                            }
                            ForEach(nonEmptySections, id: \.0) { country, pods in
                                PodSection(
                                    title: "Preferred pods - \(country)",
                                    pods: pods,
                                    photoURLs: podsStore.primaryPhotoByPodId,
                                    showLikeButtons: true,
                                    onTapPod: { selectedPod = $0 }
                                )
                            }
                        }
                        
                        if lenny.phase == .idle {
                            // Leaves room so content doesn't hide behind the
                            // floating tab bar.
                            Color.clear.frame(height: 100)
                        }
                    }
                }
                .background(Color.appHomeBackground)
                .task { await podsStore.fetchPods() }
                .task { await likesStore.fetchAll() }
            }
        }
        .background(Color.appHomeBackground.ignoresSafeArea())
    }
}

#Preview {
    HomeView()
}
