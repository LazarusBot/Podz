import Foundation

/// Every corner radius used in the app, named — previously a bare
/// literal typed fresh at each call site (12 distinct values across
/// ~47 places), with nothing recording which ones were meant to match
/// each other versus which just happened to land on a nearby number.
/// Named by value rather than by size (small/medium/large) since the
/// actual scale isn't a clean progression — these are the values
/// already in use, not a redesigned scale, so nothing on screen
/// changes from this file existing.
enum AppRadius {
    static let r4: CGFloat = 4
    static let r5: CGFloat = 5
    static let r8: CGFloat = 8
    static let r10: CGFloat = 10
    static let r12: CGFloat = 12
    static let r14: CGFloat = 14
    static let r15: CGFloat = 15
    static let r18: CGFloat = 18
    static let r20: CGFloat = 20
    static let r21: CGFloat = 21
    static let r24: CGFloat = 24
    static let r26: CGFloat = 26
}
