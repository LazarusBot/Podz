import SwiftUI

/// Reached from Profile: the plans saved from Lenny's summary, newest first.
/// Tap one to open it again (to look at the huts, change the answers, or book
/// it); "Delete" under it asks Lenny first.
struct SavedPlansView: View {
    var onBack: () -> Void

    @StateObject private var store = SavedPlansStore.shared
    @StateObject private var podsStore = PodsStore.shared
    @State private var opened: SavedPlan?
    @State private var selectedPod: Pod?
    @State private var pendingDeletion: SavedPlan?

    var body: some View {
        SectionPage(title: "Plans", onBack: onBack) {
            if store.plans.isEmpty {
                LennyEmptyState(title: "No plans yet", line: "Plan a trip with Lenny, then save it here to book later.")
            } else {
                ForEach(store.plans) { plan in
                    planRow(plan)
                }
            }
        }
        .task { store.reload() }
        .fullScreenCover(item: $opened) { plan in
            cover(for: plan)
        }
        .lennyAsks(
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            question: "Delete this plan?",
            confirm: "Delete",
            keep: "Keep it"
        ) {
            if let plan = pendingDeletion { store.remove(plan) }
            pendingDeletion = nil
        }
    }

    private func planRow(_ plan: SavedPlan) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { opened = plan } label: {
                VStack(alignment: .leading, spacing: 4) {
                    T(plan.title)
                        .font(AppFont.regularLabel(16))
                        .foregroundColor(.homeText)
                        .lineLimit(2)
                    Text(caption(of: plan))
                        .font(AppFont.regularLabel(13))
                        .foregroundColor(.homeSubtitle)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            T("Delete")
                .font(AppFont.regularLabel(13))
                .foregroundColor(.appBadgeRed)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
                .accessibilityAddTraits(.isButton)
                .onTapGesture { pendingDeletion = plan }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { Hairline().padding(.horizontal, 24) }
    }

    /// "4 stops · Loop · Saved 3 Nov".
    private func caption(of plan: SavedPlan) -> String {
        let count = plan.stops.count
        var parts = [tr("\(count) \(count == 1 ? "stop" : "stops")")]
        if plan.isLoop { parts.append(tr("Loop")) }
        parts.append(tr("Saved") + " " + plan.savedAt.formatted(.dateTime.day().month(.abbreviated)))
        return parts.joined(separator: "  ·  ")
    }

    // MARK: - A plan, opened again

    private func cover(for plan: SavedPlan) -> some View {
        LennySummaryView(
            entries: entries(of: plan),
            photoURLs: podsStore.primaryPhotoByPodId,
            onBack: { opened = nil },
            onOpenPod: { selectedPod = $0 },
            onViewReservations: {
                opened = nil
                TabRouter.shared.showsReservationsRequested = true
            },
            request: request(of: plan),
            isLoop: plan.isLoop,
            planTitle: plan.title,
            onExit: { opened = nil }
        )
        .fullScreenCover(item: $selectedPod) { pod in
            MinimalPodDetailView(pod: pod, onBack: { selectedPod = nil })
        }
    }

    /// The huts that are still in the app, in the plan's order.
    private func entries(of plan: SavedPlan) -> [LennySummaryView.Entry] {
        var previous: Pod?
        var entries: [LennySummaryView.Entry] = []
        for stop in plan.stops {
            guard let pod = podsStore.pods.first(where: { $0.id == stop.podId }) else { continue }
            entries.append(.init(
                stopName: stop.name, pod: pod, detail: stop.detail, isLennysPick: stop.isPick,
                stage: plan.isRoute ? previous.flatMap { LennyStage.between($0, pod) } : nil
            ))
            previous = pod
        }
        return entries
    }

    /// What was answered, to prefill the booking (a date in the past is dropped).
    private func request(of plan: SavedPlan) -> LennyRequest {
        var request = LennyRequest()
        request.guests = plan.guests
        request.nights = plan.nights
        if let date = plan.startDate, date >= Calendar.current.startOfDay(for: Date()) { request.startDate = date }
        return request
    }
}
