import SwiftUI

/// "See all" — every pod as a two-column grid of the same cards.
struct HomeAllPodsSheet: View {
    let pods: [Pod]
    let photoURLs: [UUID: String]

    @State private var selectedPod: Pod?
    @Namespace private var zoomNamespace

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(pods) { pod in
                    HomePodCard(
                        pod: pod,
                        photoURL: photoURLs[pod.id],
                        zoomNamespace: zoomNamespace,
                        onTap: { selectedPod = pod }
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 40)
        }
        .background(Color.homeBackground.ignoresSafeArea())
        .fullScreenCover(item: $selectedPod) { pod in
            MinimalPodDetailView(pod: pod, onBack: { selectedPod = nil })
                .navigationTransition(.zoom(sourceID: pod.id, in: zoomNamespace))
        }
    }
}
