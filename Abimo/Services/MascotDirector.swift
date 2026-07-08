//
//  MascotDirector.swift
//  Abimo
//
//  Decides when the mascot gets to interrupt. Popups are Duolingo-style
//  center-screen moments that prompt an action — never random commentary.
//  Hard rules: max ONE popup per app session, each trigger has its own
//  cooldown, and a popup stays until the user acts or dismisses it.
//

import Foundation
import Combine

@MainActor
final class MascotDirector: ObservableObject {
    static let shared = MascotDirector()

    @Published private(set) var currentMoment: MascotMoment?

    /// Hard cap: the mascot interrupts at most once per app session.
    private let popupSessionCap = 1
    private var sessionPopupCount = 0
    private let defaults = UserDefaults.standard
    private let supabase = SupabaseService.shared

    /// Minimum gap between showings of the same trigger.
    private func minInterval(for trigger: MascotMomentTrigger) -> TimeInterval {
        switch trigger {
        case .streakAtRisk: return 20 * 3600   // once a day, evening-ish
        default:            return 0
        }
    }

    private init() {}

    func fire(_ trigger: MascotMomentTrigger) {
        guard sessionPopupCount < popupSessionCap else { return }
        guard currentMoment == nil else { return }
        guard passesThrottle(trigger) else { return }

        sessionPopupCount += 1
        defaults.set(Date().timeIntervalSince1970, forKey: throttleDefaultsKey(trigger))
        currentMoment = MascotVoice.moment(for: trigger)
    }

    func dismiss() {
        currentMoment = nil
    }

    /// Call once when the authenticated main screen first appears:
    /// greets a brand-new user with their first prompt to record.
    func fireFirstWelcomeIfNeeded() {
        let key = "mascot_first_welcome_shown"
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)
        fire(.firstWelcome)
    }

    /// Call on app foreground: fires the welcome-back popup after a real gap.
    func appBecameActive() {
        let key = "last_active_date"
        let now = Date()
        defer { defaults.set(now.timeIntervalSince1970, forKey: key) }

        let last = defaults.double(forKey: key)
        guard last > 0 else { return }
        let days = Calendar.current.dateComponents(
            [.day],
            from: Date(timeIntervalSince1970: last),
            to: now
        ).day ?? 0
        guard days >= 2 else { return }

        // Once per launch
        let launchKey = "mascot_absence_fired_this_launch"
        guard !launchGate.contains(launchKey) else { return }
        launchGate.insert(launchKey)

        fire(.returnedAfterAbsence(days: days))
    }

    /// Evening check: the user carried a streak into today but hasn't
    /// completed an action yet. Fetches completions itself so it can run
    /// from app open without any tab having loaded plan data.
    func evaluateStreakAtRisk() async {
        guard Calendar.current.component(.hour, from: Date()) >= 15 else { return }
        // Cheap gates first — skip the network entirely when a popup
        // already showed this session or the daily cooldown hasn't passed.
        guard sessionPopupCount < popupSessionCap, currentMoment == nil,
              passesThrottle(.streakAtRisk(days: 0)) else { return }

        guard let userId = try? await supabase.getCurrentUser()?.id,
              let allPlans = try? await supabase.fetchAllActionPlans(userId: userId) else { return }

        var dates: [Date] = []
        for plan in allPlans {
            let actions = (try? await supabase.fetchMicroActions(actionPlanId: plan.id)) ?? []
            dates.append(contentsOf: actions.compactMap(\.completedAt))
        }

        let atRisk = ActionPlanViewModel.streakEndingYesterday(completionDates: dates)
        guard atRisk >= 2 else { return }
        fire(.streakAtRisk(days: atRisk))
    }

    private var launchGate = Set<String>()

    // MARK: - Internals

    private func throttleDefaultsKey(_ trigger: MascotMomentTrigger) -> String {
        "mascot_last_shown_\(trigger.throttleKey)"
    }

    private func passesThrottle(_ trigger: MascotMomentTrigger) -> Bool {
        let last = defaults.double(forKey: throttleDefaultsKey(trigger))
        let elapsed = Date().timeIntervalSince1970 - last
        return elapsed >= minInterval(for: trigger)
    }
}
