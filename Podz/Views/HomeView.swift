import SwiftUI

/// node 3779:2045 — "Home"
struct HomeView: View {
    @StateObject private var auth = AuthManager.shared
    @StateObject private var podsStore = PodsStore.shared
    @StateObject private var likesStore = LikesStore.shared
    @StateObject private var lenny = LennySearchViewModel.shared
    @StateObject private var homeSearch = HomeSearchState.shared
    @StateObject private var filters = HomeFiltersState.shared
    @State private var selectedPod: Pod?
    @State private var locationSearch = ""

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

                        HomeSearchRow(searchText: $locationSearch)

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
                        } else if lenny.phase == .editing && lenny.itineraryText.isEmpty {
                            awaitingLennyQueryState
                        } else if lenny.phase == .idle {
                            let query = locationSearch.trimmingCharacters(in: .whitespaces)
                            // Opening the search field clears the feed until
                            // a query is actually typed — showing every pod
                            // while the field sits empty and focused reads
                            // as "search does nothing".
                            let isAwaitingQuery = homeSearch.isExpanded && query.isEmpty
                            let nonEmptySections = isAwaitingQuery ? [] : podsStore.countries.compactMap { country -> (String, [Pod])? in
                                let pods = podsStore.pods(inCountry: country).filter { pod in
                                    let matchesQuery = query.isEmpty
                                        || country.localizedCaseInsensitiveContains(query)
                                        || (pod.region?.localizedCaseInsensitiveContains(query) ?? false)
                                    // Wifi/Pets/Check-in/Checkout stay display-only until `pods`
                                    // has data to filter them on — see HomeFiltersState.
                                    let matchesHikers = filters.hikers == 0 || (pod.bedsTotal ?? 0) >= filters.hikers
                                    return matchesQuery && matchesHikers
                                }
                                return pods.isEmpty ? nil : (country, pods)
                            }

                            if isAwaitingQuery {
                                awaitingQueryState
                            } else if podsStore.isLoading && podsStore.pods.isEmpty {
                                loadingState
                            } else if nonEmptySections.isEmpty {
                                emptyState
                            } else {
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
                        }

                        if lenny.phase == .idle {
                            // Leaves room so content doesn't hide behind the
                            // floating tab bar.
                            Color.clear.frame(height: 100)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    // Tapping anywhere that isn't a more specific control
                    // (the field itself, a chip, a pod card — those
                    // consume the tap first) collapses the search pill the
                    // same way submitting does. Attached to the ScrollView
                    // itself rather than its content — while Lenny's
                    // editing there's nothing below the pill yet, so the
                    // content is short and a catcher on just the VStack
                    // would leave most of the screen dead to this gesture.
                    if homeSearch.isExpanded {
                        homeSearch.isExpanded = false
                    }
                }
                .background(Color.appHomeBackground)
                .task { await podsStore.fetchPods() }
                .task { await likesStore.fetchAll() }
            }
        }
        .background(Color.appHomeBackground.ignoresSafeArea())
    }

    // MARK: - Feed states

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading pods…")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private var awaitingQueryState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text("Type a location to search.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    private var awaitingLennyQueryState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.hiking")
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text("Describe your hike and Lenny will find pods along the way.")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundColor(.appTextMuted)
            Text(emptyStateMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appTextMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    private var emptyStateMessage: String {
        if !locationSearch.isEmpty {
            return "No pods match \"\(locationSearch)\"."
        } else if filters.hikers > 0 {
            return "No pods sleep \(filters.hikers) or more."
        } else {
            return "No pods available yet."
        }
    }
}

#Preview {
    HomeView()
}
