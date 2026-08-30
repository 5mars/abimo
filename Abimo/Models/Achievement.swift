//
//  Achievement.swift
//  Abimo
//

import Foundation

/// Everything achievements are judged against, derived from data the profile
/// already fetches — no dedicated backend table.
struct AchievementContext {
    let ideaCount: Int
    let analysisCount: Int
    let completedActionCount: Int
    let completedPlanCount: Int
    let currentStreak: Int
    let bestScore: Int?
    /// Completed-action count per analysis, for score-linked achievements.
    let completedActionsByAnalysisId: [UUID: Int]
    let scoresByAnalysisId: [UUID: Int]
    /// Lifetime XP (derived via XPEngine), for the XP-tier badges.
    var totalXP: Int = 0
}

enum Achievement: String, CaseIterable, Identifiable {
    case firstOrder       // first idea recorded
    case tasteTested      // first analysis
    case lineCook         // 5 actions completed
    case onFire           // 3-day streak
    case marathonChef     // 7-day streak
    case fullCourse       // first completed plan
    case chefsKiss        // first 80+ score
    case kitchenComeback  // survive a sub-20 score and still complete an action on it
    case prepCook         // 100 lifetime XP
    case sousChef         // 500 lifetime XP

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstOrder:      return "First Order"
        case .tasteTested:     return "Taste Tested"
        case .lineCook:        return "Line Cook"
        case .onFire:          return "On Fire"
        case .marathonChef:    return "Marathon Chef"
        case .fullCourse:      return "Full Course"
        case .chefsKiss:       return "Chef's Kiss"
        case .kitchenComeback: return "Kitchen Comeback"
        case .prepCook:        return "Prep Cook"
        case .sousChef:        return "Sous Chef"
        }
    }

    var subtitle: String {
        switch self {
        case .firstOrder:      return "Record your first idea"
        case .tasteTested:     return "Get your first taste test"
        case .lineCook:        return "Complete 5 actions"
        case .onFire:          return "Hit a 3-day streak"
        case .marathonChef:    return "Hit a 7-day streak"
        case .fullCourse:      return "Finish a whole plan"
        case .chefsKiss:       return "Score 80+ from the critic"
        case .kitchenComeback: return "Take action on a Burnt idea"
        case .prepCook:        return "Earn 100 XP"
        case .sousChef:        return "Earn 500 XP"
        }
    }

    var icon: String {
        switch self {
        case .firstOrder:      return "mic.fill"
        case .tasteTested:     return "fork.knife"
        case .lineCook:        return "checkmark.seal.fill"
        case .onFire:          return "flame.fill"
        case .marathonChef:    return "calendar.badge.checkmark"
        case .fullCourse:      return "trophy.fill"
        case .chefsKiss:       return "star.fill"
        case .kitchenComeback: return "arrow.uturn.up.circle.fill"
        case .prepCook:        return "carrot.fill"
        case .sousChef:        return "crown.fill"
        }
    }

    func isUnlocked(in ctx: AchievementContext) -> Bool {
        switch self {
        case .firstOrder:   return ctx.ideaCount >= 1
        case .tasteTested:  return ctx.analysisCount >= 1
        case .lineCook:     return ctx.completedActionCount >= 5
        case .onFire:       return ctx.currentStreak >= 3
        case .marathonChef: return ctx.currentStreak >= 7
        case .fullCourse:   return ctx.completedPlanCount >= 1
        case .chefsKiss:    return (ctx.bestScore ?? 0) >= 80
        case .kitchenComeback:
            return ctx.scoresByAnalysisId.contains { id, score in
                score < 20 && (ctx.completedActionsByAnalysisId[id] ?? 0) >= 1
            }
        case .prepCook: return ctx.totalXP >= 100
        case .sousChef: return ctx.totalXP >= 500
        }
    }

    static func unlocked(in ctx: AchievementContext) -> Set<Achievement> {
        Set(allCases.filter { $0.isUnlocked(in: ctx) })
    }

    // MARK: - Latch storage (shared by the profile grid and in-session toasts)

    /// UserDefaults key for the earned-badge latch. Latched badges never
    /// re-lock, even when the underlying stat (a streak) lapses.
    static let latchStorageKey = "unlocked_achievements"

    static func decodeLatch(_ stored: String) -> Set<Achievement> {
        Set(stored.split(separator: ",").compactMap { Achievement(rawValue: String($0)) })
    }

    static func encodeLatch(_ achievements: Set<Achievement>) -> String {
        achievements.map(\.rawValue).sorted().joined(separator: ",")
    }

    /// Badges newly earned in `ctx` that aren't in `previous` — the set to
    /// celebrate and latch. Never returns anything already latched, so a
    /// zeroed-out context field can only delay a badge, never revoke one.
    static func freshUnlocks(in ctx: AchievementContext, previous: Set<Achievement>) -> Set<Achievement> {
        unlocked(in: ctx).subtracting(previous)
    }
}
