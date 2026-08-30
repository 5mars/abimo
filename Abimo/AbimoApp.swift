//
//  AbimoApp.swift
//  Abimo
//
//  Created by Jeremy Cinq-Mars on 2026-03-03.
//

import SwiftUI
import Supabase

@main
struct AbimoApp: App {
    @Environment(\.scenePhase) var scenePhase

    init() {
        // Firebase first so Crashlytics catches crashes from the very start.
        AnalyticsService.shared.configure()
        UserDefaults.standard.register(defaults: [
            "notif_inactivity": true,
            "notif_action_nudge": true,
            "notif_idea_nudge": true,
            "notif_streak": true,
            "sound_enabled": true
        ])
        // Start the StoreKit transaction listener before any purchase can occur.
        _ = EntitlementService.shared
        // Pre-warm the Taptic Engine and audio players so the first
        // celebration doesn't pay lazy-load latency.
        HapticEngine.prepare()
        SoundEngine.prepare()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                // The palette is hardcoded light (white surfaces, fixed hex
                // text) — force light so system chrome (sheets, alerts,
                // keyboards) can't come up dark against white cards.
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    try? SupabaseService.shared.client.auth.handle(url)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .background:
                        NotificationScheduler.shared.onBackground()
                    case .active:
                        NotificationScheduler.shared.onForeground()
                        MascotDirector.shared.appBecameActive()
                        Task { await EntitlementService.shared.refreshEntitlement() }
                    default:
                        break
                    }
                }
        }
    }
}
