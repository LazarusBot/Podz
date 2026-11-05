import SwiftUI
import PhotosUI
import Combine

/// The questions Lenny asks about a stay that is over, on the hut's own page in
/// the same card layout as "Did you book it?": how it went, then (optionally)
/// photos to keep with the stay, then a thank-you. The answers live in
/// `StayFeedbackStore`; this holds where the conversation is.
@MainActor
final class StayFeedbackFlow: ObservableObject {
    enum Step: Equatable {
        case rating
        case photos
        case thanks
    }

    @Published var step = Step.rating
    @Published var mood: StayFeedback.Mood?
    @Published var photoCount = 0
    @Published var showsPicker = false
    @Published var items: [PhotosPickerItem] = []

    private let store = StayFeedbackStore.shared

    /// A new question: start from the top.
    func restart() {
        step = .rating
        mood = nil
        photoCount = store.pendingStay.map { store.photoCount(for: $0.id) } ?? 0
        items = []
    }

    func choose(_ mood: StayFeedback.Mood) {
        self.mood = mood
        store.answer(mood)
        step = .photos
    }

    func backToRating() { step = .rating }

    func done() { step = .thanks }

    func skip() { store.skip() }

    func finish() { store.finish() }

    /// Keeps what was picked with the stay.
    func loadPicked() async {
        let picked = items
        items = []
        guard let id = store.pendingStay?.id else { return }
        for item in picked {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let jpeg = await Task.detached(priority: .userInitiated, operation: { StayFeedbackStore.jpeg(from: data) }).value,
                  store.addPhoto(jpeg, to: id)
            else { continue }
            photoCount = store.photoCount(for: id)
        }
    }
}

extension AnyTransition {
    /// How a question arrives on the pod's page: it rises from the bottom after
    /// the photo has settled into its card (`delay` is how long after).
    static func risesIn(after delay: Double) -> AnyTransition {
        .asymmetric(
            insertion: AnyTransition.move(edge: .bottom).combined(with: .opacity)
                .animation(.spring(response: 0.6, dampingFraction: 0.82).delay(delay)),
            removal: .opacity
        )
    }
}

/// Lenny's bubble for the stay's questions, with "Not now" under the first.
struct StayFeedbackLenny: View {
    @ObservedObject var flow: StayFeedbackFlow
    let podName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LennyReply(message: message, mood: flow.mood == .bad && flow.step == .photos ? .idle : .happy)
            if flow.step == .rating {
                Button(action: flow.skip) {
                    HStack(spacing: 5) {
                        T("Not now")
                            .font(AppFont.regularLabel(13))
                            .foregroundColor(.homeSubtitle)
                            .underline(color: Color.homeSubtitle.opacity(0.5))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.homeSubtitle)
                    }
                    .padding(.vertical, 4)
                    .captionTapArea(outset: 10)
                }
                .buttonStyle(.plain)
                // Lined up with the bubble's text, past the avatar.
                .padding(.leading, 38 + 18)
            }
        }
        .id(flow.step)
        .animation(.smooth(duration: 0.3), value: flow.step)
    }

    private var message: String {
        switch flow.step {
        case .rating:
            "Welcome back! How was your stay at \(podName)?"
        case .photos:
            if flow.photoCount > 0 {
                flow.photoCount == 1 ? "Kept 1 photo. Anything else?" : "Kept \(flow.photoCount) photos. Anything else?"
            } else if flow.mood == .good {
                "Glad to hear it! Want to keep a few photos with your stay?"
            } else {
                "Sorry it wasn't better. Want to keep a photo with your stay?"
            }
        case .thanks:
            "Thanks! It's kept with your stay in Reservations."
        }
    }
}

/// The control stack for the stay's questions: back, then the answers.
struct StayFeedbackControls: View {
    @ObservedObject var flow: StayFeedbackFlow
    /// Back from the first question leaves the page (counts as "Not now").
    var onLeave: () -> Void
    var onViewReservations: () -> Void

    var body: some View {
        ZStack {
            row
                .id(flow.step)
        }
        .animation(.smooth(duration: 0.3), value: flow.step)
        .photosPicker(
            isPresented: $flow.showsPicker,
            selection: $flow.items,
            maxSelectionCount: 6,
            matching: .images
        )
        .onChange(of: flow.items) { _, items in
            guard !items.isEmpty else { return }
            Task { await flow.loadPicked() }
        }
    }

    @ViewBuilder
    private var row: some View {
        HStack(spacing: 13) {
            switch flow.step {
            case .rating:
                DetailBackButton(action: onLeave)
                DetailTextButton(title: "Not great") { flow.choose(.bad) }
                DetailTextButton(title: "Good") { flow.choose(.good) }
            case .photos:
                DetailBackButton(action: flow.backToRating)
                DetailTextButton(title: flow.photoCount > 0 ? "Add more" : "Add photos") { flow.showsPicker = true }
                DetailTextButton(title: flow.photoCount > 0 ? "Done" : "Skip", isHighlighted: flow.photoCount > 0, action: flow.done)
            case .thanks:
                DetailBackButton(action: flow.finish)
                DetailTextButton(title: "View reservations", isHighlighted: true, action: onViewReservations)
            }
        }
    }
}
