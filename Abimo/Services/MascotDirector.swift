//
//  MascotDirector.swift
//  Abimo
//
//  Decides when the mascot gets to speak. Event moments (reactions to
//  something the user did) always show; ambient moments (unprompted jabs)
//  are throttled hard so the critic stays funny instead of exhausting.
//

import Foundation
import Combine

@MainActor
final class MascotDirector: ObservableObject {
    static let shared = MascotDirector()

    @Published private(set) var currentMoment: MascotMoment?

    /// Hard cap on unprompted commentary per app session.
    private let ambientSessionCap = 2
    private var sessionAmbientCount = 0
    private var dismissTask: Task<Void, Never>?
    private let defaults = UserDefaults.standard

    /// Minimum gap between showings of the same ambient trigger.
    private func minInterval(for trigger: MascotMomentTrigger) -> TimeInterval {
        switch trigger {
        case .randomJab:                  return 4 * 3600
        case .emptyKitchen, .plansIdle:   return 24 * 3600
        default:                          return 0
        }
    }

    private init() {}

    func fire(_ trigger: MascotMomentTrigger) {
        if trigger.isAmbient {
            guard passesAmbientThrottle(trigger) else { return }
            // Don't talk over a celebration or an existing moment
            guard currentMoment == nil else { return }
            sessionAmbientCount += 1
            defaults.set(Date().timeIntervalSince1970, forKey: throttleDefaultsKey(trigger))
        }

        // Event moments replace whatever is showing (ambient or older event)
        show(MascotVoice.moment(for: trigger))
    }

    /// Roll the ~20% random-jab dice for a qualifying visit (tab switch).
    func maybeJab() {
        guard Double.random(in: 0..<1) < 0.2 else { return }
        fire(.randomJab)
    }

    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        currentMoment = nil
    }

    /// Call on app foreground: fires the welcome-back jab after a real gap.
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

    private var launchGate = Set<String>()

    // MARK: - Internals

    private func show(_ moment: MascotMoment) {
        dismissTask?.cancel()
        currentMoment = moment
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(moment.duration))
            guard !Task.isCancelled else { return }
            if self?.currentMoment?.id == moment.id {
                self?.currentMoment = nil
            }
        }
    }

    private func throttleDefaultsKey(_ trigger: MascotMomentTrigger) -> String {
        "mascot_last_shown_\(trigger.throttleKey)"
    }

    private func passesAmbientThrottle(_ trigger: MascotMomentTrigger) -> Bool {
        guard sessionAmbientCount < ambientSessionCap else { return false }
        let last = defaults.double(forKey: throttleDefaultsKey(trigger))
        let elapsed = Date().timeIntervalSince1970 - last
        return elapsed >= minInterval(for: trigger)
    }
}
