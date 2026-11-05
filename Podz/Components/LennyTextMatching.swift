import Foundation

/// How a hand-typed search reads a place, the way Lenny does: "haute savoi",
/// "Haute-Savoie" and "HAUTE  SAVOIE" are one name, accents don't matter, and
/// one wrong letter is forgiven ("Chamonx", "Haute Savoe"). The words may be
/// the start of a name too, since the list updates while you type.
///
/// The names are folded once per pod and kept (`PodSearchIndex`), and the
/// query once per keystroke, so a search over thousands of pods stays quick.
struct PodSearchQuery {
    fileprivate let words: [String]
    fileprivate let phrase: String

    init(_ text: String) {
        words = LennyText.words(in: LennyText.fold(text)).map(\.word)
        phrase = words.joined(separator: " ")
    }

    var isEmpty: Bool { words.isEmpty }

    func matches(_ pod: Pod) -> Bool {
        guard !isEmpty else { return false }
        for field in PodSearchIndex.shared.fields(of: pod) {
            if field.text.contains(phrase) { return true }
            // The same words with a typo, wherever they sit in the name.
            let size = words.count
            guard size <= field.words.count else { continue }
            if size == 1 {
                if field.words.contains(where: { LennyText.isTypo(phrase, of: $0) }) { return true }
                continue
            }
            for start in 0...(field.words.count - size)
                where LennyText.isTypo(phrase, of: field.words[start..<(start + size)].joined(separator: " ")) {
                return true
            }
        }
        return false
    }
}

/// A pod's name, country and region, folded and split into words once.
final class PodSearchIndex {
    nonisolated(unsafe) static let shared = PodSearchIndex()

    struct Field {
        let text: String
        let words: [String]
    }

    private struct Entry {
        let source: [String]
        let fields: [Field]
    }

    private var entries: [UUID: Entry] = [:]
    private let lock = NSLock()

    func prepare(_ pods: [Pod]) {
        for pod in pods { _ = fields(of: pod) }
    }

    func fields(of pod: Pod) -> [Field] {
        let source = [pod.name, pod.country, pod.region ?? ""]
        lock.lock()
        defer { lock.unlock() }
        if let entry = entries[pod.id], entry.source == source { return entry.fields }
        let fields = source.filter { !$0.isEmpty }.map { value -> Field in
            let words = LennyText.words(in: LennyText.fold(value)).map(\.word)
            return Field(text: words.joined(separator: " "), words: words)
        }
        entries[pod.id] = Entry(source: source, fields: fields)
        return fields
    }
}
