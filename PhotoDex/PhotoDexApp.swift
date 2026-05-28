//
//  PhotoDexApp.swift
//  PhotoDex
//
//  Created by Vlad Vorniceanu on 11.03.2024.
//

import SwiftUI

@main
struct PhotoDexApp: App {
    @AppStorage("eye4you.hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            MainMenuView()
                .fullScreenCover(isPresented: Binding(
                    get: { !hasSeenOnboarding },
                    set: { if !$0 { hasSeenOnboarding = true } }
                )) {
                    OnboardingView(onDismiss: { hasSeenOnboarding = true })
                }
        }
    }
}
