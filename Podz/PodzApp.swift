//
//  PodzApp.swift
//  Podz
//
//  Created by Max Prx on 10/08/2026.
//

import SwiftUI

@main
struct PodzApp: App {
    @AppStorage("hasSeenOnboarding") var hasSeenOnboarding = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            OnboardingView()
        }
    }
}
