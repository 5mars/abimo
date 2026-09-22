//
//  PlanCache.swift
//  Abimo
//
//  Plans and their steps, remembered for the session. Every screen that
//  shows a plan (the Pitch card, the Actions tab, the journey) used to
//  fetch it again on appear and show a spinner while it did. Now the last
//  known copy renders instantly and the fetch refreshes it in the background.
//

import Foundation

@MainActor
final class PlanCache {
    static let shared = PlanCache()

    struct Entry {
        let plan: ActionPlan
        let actions: [MicroAction]
        let fetchedAt: Date
        var progress: (completed: Int, total: Int) {
            (actions.filter(\.isCompleted).count, actions.count)
        }
    }

    private var byAnalysis: [UUID: Entry] = [:]

    func entry(analysisId: UUID) -> Entry? { byAnalysis[analysisId] }

    func entry(planId: UUID) -> Entry? { byAnalysis.values.first { $0.plan.id == planId } }

    func store(plan: ActionPlan, actions: [MicroAction]) {
        byAnalysis[plan.analysisId] = Entry(plan: plan, actions: actions, fetchedAt: Date())
    }

    func forget(analysisId: UUID) { byAnalysis[analysisId] = nil }

    /// Sign-out / account deletion: nothing from one account may leak into the next.
    func clear() { byAnalysis.removeAll() }
}
