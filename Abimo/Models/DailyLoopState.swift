//
//  DailyLoopState.swift
//  Abimo
//
//  One pure function decides what the Actions tab's "today" surface is —
//  so a founder with no plan, or with every plan finished, still has a
//  reason to be here instead of a dead end. Priority order matters: a
//  failure wins over cooking, a live plan wins over housekeeping.
//

import Foundation

enum DailyLoopState: Equatable {
    /// Nothing recorded yet (the walk-in tour owns first run).
    case noIdeas
    /// A recorded idea that never got its taste test.
    case ideaUntasted(noteId: UUID, title: String)
    /// Analyzed, but no plan exists (an old row, or a plan that never landed).
    case planMissing(noteId: UUID, title: String, analysisId: UUID)
    /// The pipeline or plan generation is running.
    case planCooking
    /// Plan generation failed — the retry card is the surface.
    case planFailed
    /// At least one plan has steps left.
    case activePlan(planId: UUID, analysisId: UUID)
    /// Every plan is finished — time for what's next.
    case allChaptersDone(planId: UUID, analysisId: UUID)

    static func resolve(
        notes: [VoiceNote],
        plans: [ActionPlan],
        actionsByPlan: [UUID: [MicroAction]],
        pipelineCooking: Bool,
        planGenerationPending: Bool,
        planGenerationFailed: Bool
    ) -> DailyLoopState {
        if planGenerationFailed { return .planFailed }
        if planGenerationPending || pipelineCooking { return .planCooking }

        // Newest plan with something left to do.
        let byRecency = plans.sorted { $0.createdAt > $1.createdAt }
        if let live = byRecency.first(where: { plan in
            (actionsByPlan[plan.id] ?? []).contains { !$0.isCompleted }
        }) {
            return .activePlan(planId: live.id, analysisId: live.analysisId)
        }

        let notesByRecency = notes.sorted { $0.createdAt > $1.createdAt }
        if let raw = notesByRecency.first(where: { $0.analysisId == nil }) {
            return .ideaUntasted(noteId: raw.id, title: raw.title)
        }

        let planAnalysisIds = Set(plans.map(\.analysisId))
        if let orphan = notesByRecency.first(where: { note in
            guard let analysisId = note.analysisId else { return false }
            return !planAnalysisIds.contains(analysisId)
        }), let analysisId = orphan.analysisId {
            return .planMissing(noteId: orphan.id, title: orphan.title, analysisId: analysisId)
        }

        if let last = byRecency.first, !(actionsByPlan[last.id] ?? []).isEmpty {
            return .allChaptersDone(planId: last.id, analysisId: last.analysisId)
        }

        return .noIdeas
    }

    /// Analytics-safe label.
    var analyticsName: String {
        switch self {
        case .noIdeas:          return "no_ideas"
        case .ideaUntasted:     return "idea_untasted"
        case .planMissing:      return "plan_missing"
        case .planCooking:      return "plan_cooking"
        case .planFailed:       return "plan_failed"
        case .activePlan:       return "active_plan"
        case .allChaptersDone:  return "all_done"
        }
    }
}
