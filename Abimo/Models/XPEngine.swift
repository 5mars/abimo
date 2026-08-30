//
//  XPEngine.swift
//  Abimo
//
//  XP is always DERIVED from completion records, never stored — so it can't
//  drift from the truth. Pure static functions in the streakInfo mold:
//  dates in, numbers out, unit-testable with no actor or network in sight.
//
//  Rules (deliberately few):
//    - every completed action: 10 XP
//    - first completion of a day: +5 bonus
//    - daily dares (DareEngine): +5 each, +15 for clearing all three
//

import Foundation

enum XPEngine {
    static let actionXP = 10
    static let firstOfDayBonus = 5
    static let dareXP = 5
    static let daresClearedBonus = 15

    /// XP earned from `count` action completions within one day.
    static func xp(forCompletionsInDay count: Int) -> Int {
        guard count > 0 else { return 0 }
        return count * actionXP + firstOfDayBonus
    }

    /// Lifetime XP from action completions.
    static func totalXP(completionDates: [Date], calendar: Calendar = .current) -> Int {
        Dictionary(grouping: completionDates) { calendar.startOfDay(for: $0) }
            .values
            .reduce(0) { $0 + xp(forCompletionsInDay: $1.count) }
    }

    /// XP earned today from action completions.
    static func xpToday(completionDates: [Date], calendar: Calendar = .current, now: Date = Date()) -> Int {
        xp(forCompletionsInDay: completionDates.filter { calendar.isDate($0, inSameDayAs: now) }.count)
    }

    /// True when the Nth completion of the day (`completionsTodayAfter`) is
    /// the one that pushes today's XP over `goal` — fire the celebration on
    /// exactly that completion, not before, never twice.
    static func completionCrossesGoal(completionsTodayAfter: Int, goal: Int) -> Bool {
        guard completionsTodayAfter > 0 else { return false }
        return xp(forCompletionsInDay: completionsTodayAfter - 1) < goal
            && xp(forCompletionsInDay: completionsTodayAfter) >= goal
    }
}

// MARK: - Daily goal tiers

/// The user's daily XP target. Raw value IS the XP amount, persisted via
/// @AppStorage(DailyGoalTier.storageKey) so the setting survives as plain
/// UserDefaults.
enum DailyGoalTier: Int, CaseIterable, Identifiable {
    case chill = 15     // one action a day
    case regular = 25   // two actions
    case firedUp = 45   // four actions

    var id: Int { rawValue }

    static let storageKey = "daily_goal_xp"
    static let fallback: DailyGoalTier = .regular

    var title: String {
        switch self {
        case .chill:   return "Simmer"
        case .regular: return "Sizzle"
        case .firedUp: return "Full Flame"
        }
    }

    var subtitle: String {
        switch self {
        case .chill:   return "1 action a day \u{2022} 15 XP"
        case .regular: return "2 actions a day \u{2022} 25 XP"
        case .firedUp: return "4 actions a day \u{2022} 45 XP"
        }
    }

    /// Analytics-safe identifier.
    var analyticsName: String {
        switch self {
        case .chill:   return "chill"
        case .regular: return "regular"
        case .firedUp: return "fired_up"
        }
    }

    init(storedXP: Int) {
        self = DailyGoalTier(rawValue: storedXP) ?? .fallback
    }
}
