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
        }
    }

    static func unlocked(in ctx: AchievementContext) -> Set<Achievement> {
        Set(allCases.filter { $0.isUnlocked(in: ctx) })
    }
}
