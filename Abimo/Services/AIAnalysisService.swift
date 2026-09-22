//
//  AIAnalysisService.swift
//  Abimo
//

import Foundation
import Supabase
import Combine

@MainActor
class AIAnalysisService: ObservableObject {
    @Published var isAnalyzing = false
    @Published var errorMessage: String?

    // Deallocating from inside another MainActor class's isolated deinit
    // (ActionPlanViewModel holds this service) nests two
    // swift_task_deinitOnExecutor hops, which double-frees in the Swift
    // runtime's TaskLocal scope teardown (crashes the whole test host).
    // A nonisolated deinit skips the second hop; nothing here needs the
    // main actor to tear down.
    nonisolated deinit {}

    private let supabase = SupabaseService.shared

    // MARK: - Market Research (best-effort, never blocks the pipeline)

    /// The digest type lives with the other analysis models now; kept as a
    /// nested alias so existing call sites read the same.
    typealias ResearchDigest = Abimo.ResearchDigest

    private struct ResearchRequest: Encodable {
        let transcription: String
        let pivot: IdeaVariant?
    }

    /// Scouts the market via live web search. Returns nil on ANY failure or
    /// after ~25s — the analysis simply proceeds ungrounded. A pivot is sent
    /// as its own field so the server's digest cache key matches the
    /// transcript hash analyze-swot computes.
    func researchMarket(_ text: String, pivot: IdeaVariant? = nil) async -> ResearchDigest? {
        let invoke = { [supabase] () async throws -> ResearchDigest in
            try await supabase.client.functions.invoke(
                "research-market",
                options: FunctionInvokeOptions(body: ResearchRequest(transcription: text, pivot: pivot))
            )
        }
        return await withTaskGroup(of: ResearchDigest?.self) { group in
            group.addTask { try? await invoke() }
            group.addTask {
                try? await Task.sleep(for: .seconds(25))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    // MARK: - SWOT Analysis

    /// "Work done since last tasting" — the critic re-judges with the
    /// founder's completed steps as new evidence. Server-side Plus-only.
    struct RetasteContext: Encodable {
        struct CompletedAction: Encodable {
            let text: String
            let outcome: String?
            let note: String?
        }
        let analysisId: UUID
        let completedActions: [CompletedAction]
        let previousScore: Int

        enum CodingKeys: String, CodingKey {
            case analysisId       = "analysis_id"
            case completedActions = "completed_actions"
            case previousScore    = "previous_score"
        }

        init(analysis: SWOTAnalysis, actions: [MicroAction]) {
            analysisId = analysis.id
            previousScore = analysis.viabilityScore ?? 0
            completedActions = actions.filter(\.isCompleted).prefix(30).map {
                CompletedAction(text: $0.text, outcome: $0.completionOutcome, note: $0.completionNote)
            }
        }
    }

    private struct AnalyzeRequest: Encodable {
        let transcription: String
        let research: ResearchDigest?
        let pivot: IdeaVariant?
        var retaste: RetasteContext? = nil
    }

    func analyzeTranscription(
        _ text: String,
        research: ResearchDigest? = nil,
        pivot: IdeaVariant? = nil,
        retaste: RetasteContext? = nil
    ) async throws -> SWOTAnalysisResponse {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        let response: SWOTAnalysisResponse = try await supabase.client.functions
            .invoke(
                "analyze-swot",
                options: FunctionInvokeOptions(
                    body: AnalyzeRequest(transcription: text, research: research, pivot: pivot, retaste: retaste)
                )
            )

        return response
    }

    /// Re-taste in place: same row id, score pushed onto the history, plan
    /// untouched. Reuses the digest stored on the row instead of spending a
    /// research credit.
    func retasteAnalysis(
        _ existing: SWOTAnalysis,
        transcriptionText: String,
        completedActions: [MicroAction]
    ) async throws -> SWOTAnalysis {
        let context = RetasteContext(analysis: existing, actions: completedActions)
        let response = try await analyzeTranscription(
            transcriptionText,
            research: existing.researchDigest,
            retaste: context
        )
        let updated = existing.retasted(
            with: response,
            research: existing.researchDigest,
            reason: "retaste after \(context.completedActions.count) steps"
        )
        try await supabase.updateSWOTAnalysisInPlace(updated)
        return updated
    }

    /// - Parameters:
    ///   - pivot: re-judge the idea as this remix (the transcript becomes
    ///     background context). A pivot is a deliberate rename, so the note
    ///     title always updates to the new ideaTitle.
    ///   - replaceExisting: delete any prior analysis (and its action plan)
    ///     for this transcription before saving — keeps one analysis per
    ///     transcription instead of accumulating duplicates.
    func generateAndSaveSWOTAnalysis(
        transcriptionId: UUID,
        transcriptionText: String,
        noteId: UUID? = nil,
        currentNoteTitle: String? = nil,
        research: ResearchDigest? = nil,
        pivot: IdeaVariant? = nil,
        replaceExisting: Bool = false
    ) async throws -> SWOTAnalysis {
        let response = try await analyzeTranscription(transcriptionText, research: research, pivot: pivot)

        if replaceExisting {
            try await supabase.deleteAnalysisArtifacts(transcriptionId: transcriptionId)
        }

        let analysis = SWOTAnalysis(
            id: UUID(),
            transcriptionId: transcriptionId,
            strengths: [],
            weaknesses: [],
            opportunities: [],
            threats: [],
            summary: response.summary,
            createdAt: Date(),
            strengthItems: response.strengths,
            weaknessItems: response.weaknesses,
            opportunityItems: response.opportunities,
            threatItems: response.threats,
            viabilityScore: response.viabilityScore,
            marketContext: response.marketContext,
            marketInsights: response.marketInsights,
            dimensionScores: response.dimensionScores,
            scoreRationale: response.scoreRationale,
            fatalFlaw: response.fatalFlaw,
            ideaVariants: response.ideaVariants,
            scoringVersion: response.scoringVersion,
            verdictBand: response.verdictBand,
            verdictReason: response.verdictReason,
            dimensionEvidence: response.dimensionEvidence,
            scoreMeta: response.scoreMeta,
            evidenceStrength: response.evidenceStrength,
            fatalFlawReason: response.fatalFlawReason,
            researchDigest: research,
            scoreAuditId: response.scoreAuditId
        )

        try await supabase.createSWOTAnalysis(analysis)

        // Upgrade an auto-generated recording title to the AI's idea name.
        // User-chosen titles are never touched — EXCEPT on a pivot, which is
        // a deliberate rename to the remix. A failed title update shouldn't
        // fail the analysis.
        if let noteId,
           let ideaTitle = response.ideaTitle?.trimmingCharacters(in: .whitespaces),
           !ideaTitle.isEmpty {
            let autoTitled = currentNoteTitle.map(VoiceNote.isAutoTitle) ?? false
            if pivot != nil || autoTitled {
                try? await supabase.updateVoiceNoteTitle(id: noteId, title: ideaTitle)
            }
        }

        return analysis
    }

    // MARK: - Action Plan Generation

    /// Returns the action plan title, using "{noteTitle}'s action plan" format when noteTitle is
    /// non-empty, otherwise falling back to the AI-generated title.
    static func planTitle(noteTitle: String, responseTitle: String) -> String {
        noteTitle.trimmingCharacters(in: .whitespaces).isEmpty ? responseTitle : "\(noteTitle)'s action plan"
    }

    func generateAndSaveActionPlan(analysis: SWOTAnalysis, transcriptionText: String, noteTitle: String = "") async throws -> (ActionPlan, [MicroAction]) {
        guard let userId = try await supabase.getCurrentUser()?.id else {
            throw NSError(domain: "AIAnalysisService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        // One plan per analysis: the pipeline auto-generates on every run, and
        // the results CTA can fire again — return the existing plan instead of
        // cooking (and paying for) a duplicate.
        if let existing = try await supabase.fetchActionPlan(analysisId: analysis.id) {
            let actions = try await supabase.fetchMicroActions(actionPlanId: existing.id)
            return (existing, actions)
        }

        struct ActionPlanRequest: Encodable {
            let analysisId: String
            let transcriptionText: String
            let swotSummary: String
            let strengths: [String]
            let weaknesses: [String]
            let opportunities: [String]
            let threats: [String]
            let viabilityScore: Int
            let dimensionScores: DimensionScores?
            let scoreRationale: String?
            let comparables: [String]?

            enum CodingKeys: String, CodingKey {
                case analysisId = "analysis_id"
                case transcriptionText = "transcription_text"
                case swotSummary = "swot_summary"
                case strengths, weaknesses, opportunities, threats
                case viabilityScore = "viability_score"
                case dimensionScores = "dimension_scores"
                case scoreRationale = "score_rationale"
                case comparables
            }
        }

        let requestBody = ActionPlanRequest(
            analysisId: analysis.id.uuidString,
            transcriptionText: transcriptionText,
            swotSummary: analysis.summary ?? "",
            strengths: analysis.resolvedStrengths.map(\.point),
            weaknesses: analysis.resolvedWeaknesses.map(\.point),
            opportunities: analysis.resolvedOpportunities.map(\.point),
            threats: analysis.resolvedThreats.map(\.point),
            viabilityScore: analysis.viabilityScore ?? 50,
            dimensionScores: analysis.dimensionScores,
            scoreRationale: analysis.scoreRationale,
            comparables: analysis.marketInsights?.comparables?.map {
                "\($0.name) — \($0.what), \($0.pricing)"
            }
        )

        let response: ActionPlanResponse = try await supabase.client.functions
            .invoke(
                "generate-action-plan",
                options: FunctionInvokeOptions(
                    body: requestBody
                )
            )

        let now = Date()
        let planId = UUID()
        let totalMinutes = response.actions.reduce(0) { $0 + $1.timeEstimateMinutes }

        let plan = ActionPlan(
            id: planId,
            analysisId: analysis.id,
            userId: userId,
            title: Self.planTitle(noteTitle: noteTitle, responseTitle: response.title),
            summary: response.summary,
            totalEstimateMinutes: totalMinutes,
            createdAt: now
        )

        let microActions = response.actions.map { item in
            MicroAction(
                id: UUID(),
                actionPlanId: planId,
                text: item.text,
                doneCriteria: item.doneCriteria,
                timeEstimateMinutes: item.timeEstimateMinutes,
                priority: item.priority,
                quadrant: item.quadrant,
                template: item.template,
                actionType: item.actionType,
                deepLinkData: item.deepLinkData,
                isCompleted: false,
                completedAt: nil,
                isCommitted: false,
                committedAt: nil,
                scheduledFor: nil,
                completionOutcome: nil,
                completionNote: nil,
                createdAt: now
            )
        }

        try await supabase.createActionPlan(plan)
        try await supabase.createMicroActions(microActions)

        return (plan, microActions)
    }

    // MARK: - Next chapter (Plus)

    struct ChapterResponse: Decodable {
        let title: String
        let summary: String
        let chapter: Int
        let actions: [ActionPlanResponseItem]
        let ladderTitle: String?
        enum CodingKeys: String, CodingKey { case title, summary, chapter, actions, ladderTitle = "ladder_title" }
    }

    /// Appends the next chapter to a finished plan. The server reads the
    /// transcript, analysis and completed steps itself — only the plan id
    /// travels. Returns the new actions (already persisted).
    func extendActionPlan(_ plan: ActionPlan, existing: [MicroAction], brief: ChapterBrief) async throws -> (chapter: Int, actions: [MicroAction]) {
        struct Body: Encodable {
            let actionPlanId: UUID
            let brief: ChapterBrief
            enum CodingKeys: String, CodingKey { case actionPlanId = "action_plan_id", brief }
        }
        let response: ChapterResponse = try await supabase.client.functions.invoke(
            "extend-action-plan",
            options: FunctionInvokeOptions(body: Body(actionPlanId: plan.id, brief: brief))
        )

        let now = Date()
        // Priorities continue after the last existing step so the default
        // ordering (priority ascending) keeps chapters in sequence.
        let base = (existing.map(\.priority).max() ?? 0)
        let actions = response.actions.map { item in
            MicroAction(
                id: UUID(),
                actionPlanId: plan.id,
                text: item.text,
                doneCriteria: item.doneCriteria,
                timeEstimateMinutes: item.timeEstimateMinutes,
                priority: base + item.priority,
                quadrant: item.quadrant,
                template: item.template,
                actionType: item.actionType,
                deepLinkData: item.deepLinkData,
                isCompleted: false,
                completedAt: nil,
                isCommitted: false,
                committedAt: nil,
                scheduledFor: nil,
                completionOutcome: nil,
                completionNote: nil,
                createdAt: now,
                chapter: response.chapter
            )
        }
        try await supabase.createMicroActions(actions)
        let total = (existing + actions).reduce(0) { $0 + $1.timeEstimateMinutes }
        try? await supabase.updateActionPlanEstimate(id: plan.id, totalMinutes: total)
        return (response.chapter, actions)
    }
}

// MARK: - Edge Function Response (camelCase — matches GPT-4o JSON output)

struct SWOTAnalysisResponse: Codable {
    let strengths: [SWOTItem]
    let weaknesses: [SWOTItem]
    let opportunities: [SWOTItem]
    let threats: [SWOTItem]
    let viabilityScore: Int
    let marketContext: String
    let marketInsights: MarketInsights
    let summary: String?
    let ideaTitle: String?
    let scoreRationale: String?
    let fatalFlaw: Bool?
    let dimensionScores: DimensionScores?
    let ideaVariants: [IdeaVariant]?
    // Scoring v2 (absent from responses of the previous function version)
    let scoringVersion: Int?
    let verdictBand: String?
    let verdictReason: String?
    let dimensionEvidence: DimensionEvidence?
    let scoreMeta: ScoreMeta?
    let evidenceStrength: String?
    let fatalFlawReason: String?
    let founderEvidence: FounderEvidence?
    let scoreAuditId: UUID?
}
