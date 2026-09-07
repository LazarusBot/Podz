//
//  AppModeStore.swift
//  Podz
//
//  Created by Max Prx on 03/09/2026.
//

import Foundation
import Combine

/// Which shell a signed-in host currently sees — `MainTabView`'s hiker
/// experience, or the host dashboard (`HostTabView`). Independent of
/// `Profile.isHost`, which only gates *access* to host mode, not which
/// one is showing right now: a host is still a person who might want to
/// browse/book other pods as a guest, so this is a switch, not a one-way
/// upgrade — same idea as Airbnb's own traveling/hosting toggle. Read at
/// the top of `OnboardingView`'s routing alongside `isHost`; a non-host
/// always sees the hiker shell regardless of what this holds.
@MainActor
final class AppModeStore: ObservableObject {
    static let shared = AppModeStore()

    enum Mode: String {
        case hiker, host
    }

    @Published var mode: Mode {
        didSet { UserDefaults.standard.set(mode.rawValue, forKey: Self.storageKey) }
    }

    private static let storageKey = "podz.appMode"

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey), let saved = Mode(rawValue: raw) {
            mode = saved
        } else {
            mode = .hiker
        }
    }

    /// Called on sign-out — a fresh sign-in (possibly a different
    /// account entirely) always starts in hiker mode rather than
    /// inheriting whatever the previous session's user had switched to.
    func reset() {
        mode = .hiker
    }
}
