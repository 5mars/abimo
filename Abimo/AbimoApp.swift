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
        // Notification taps route into the app (must be set before launch finishes).
        NotificationRouter.shared.install()
        // Pre-warm the Taptic Engine and audio players so the first
        // celebration doesn't pay lazy-load latency.
        HapticEngine.prepare()
        SoundEngine.prepare()
        Self.logAppOpen(source: "launch")
    }

    /// One app_open per launch and per foreground, with the gap since the
    /// last one — the D1/D7 retention marker Firebase can't derive otherwise.
    static func logAppOpen(source: String) {
        let key = "analytics_last_open"
        let last = UserDefaults.standard.object(forKey: key) as? Date
        let days = last.map { Calendar.current.dateComponents([.day], from: $0, to: Date()).day ?? 0 } ?? -1
        UserDefaults.standard.set(Date(), forKey: key)
        AnalyticsService.shared.log(.appOpen(source: source, daysSinceLast: days, loopState: "n/a"))
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
                        Self.logAppOpen(source: "foreground")
                    default:
                        break
                    }
                }
        }
    }
}
