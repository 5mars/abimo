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

    private let supabase = SupabaseService.shared

    // MARK: - Market Research (best-effort, never blocks the pipeline)

    /// Live web research digest from the research-market edge function.
    struct ResearchDigest: Codable {
        let comparables: [MarketComparable]
        let nicheNotes: String
        let demandSignals: [String]

        enum CodingKeys: String, CodingKey {
            case comparables
            case nicheNotes    = "niche_notes"
            case demandSignals = "demand_signals"
        }

        var isEmpty: Bool {
            comparables.isEmpty && nicheNotes.isEmpty && demandSignals.isEmpty
        }
    }

    /// Scouts the market via live web search. Returns nil on ANY failure or
    /// after ~25s — the analysis simply proceeds ungrounded.
    func researchMarket(_ text: String) async -> ResearchDigest? {
        let invoke = { [supabase] () async throws -> ResearchDigest in
            try await supabase.client.functions.invoke(
                "research-market",
                options: FunctionInvokeOptions(body: ["transcription": text])
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

    private struct AnalyzeRequest: Encodable {
        let transcription: String
        let research: ResearchDigest?
        let pivot: IdeaVariant?
    }

    func analyzeTranscription(
        _ text: String,
        research: ResearchDigest? = nil,
        pivot: IdeaVariant? = nil
    ) async throws -> SWOTAnalysisResponse {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        let response: SWOTAnalysisResponse = try await supabase.client.functions
            .invoke(
                "analyze-swot",
                options: FunctionInvokeOptions(
                    body: AnalyzeRequest(transcription: text, research: research, pivot: pivot)
                )
            )

        return response
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
            ideaVariants: response.ideaVariants
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
}
