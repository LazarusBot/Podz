//
//  PodzApp.swift
//  Podz
//
//  Created by Max Prx on 10/08/2026.
//

import SwiftUI

@main
struct PodzApp: App {
    init() {
        TapScaleButtonStyle.warmUp()
    }

    var body: some Scene {
        WindowGroup {
            OnboardingView()
                .onOpenURL { url in
                    DeepLinkRouter.shared.handle(url)
                }
                .task {
                    Analytics.shared.start()
                    DiagnosticsReporter.shared.start()
                }
        }
    }
}
