//
//  AnalysisViewModel.swift
//  Abimo
//

import Foundation
import Combine

@MainActor
class AnalysisViewModel: ObservableObject {
    @Published var analysis: SWOTAnalysis?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let aiService = AIAnalysisService()
    private let supabase = SupabaseService.shared

    init() {}

    init(preloadedAnalysis: SWOTAnalysis) {
        self.analysis = preloadedAnalysis
    }

    func loadAnalysis(transcriptionId: UUID) async {
        guard analysis == nil else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            analysis = try await supabase.fetchSWOTAnalysis(transcriptionId: transcriptionId)
        } catch {
            errorMessage = "Failed to load analysis: \(error.localizedDescription)"
        }
    }

    /// Regenerates (or pivots) the analysis. This path always REPLACES any
    /// existing analysis for the transcription — retrying or re-tasting must
    /// never leave duplicate rows behind.
    func generateAnalysis(
        transcription: Transcription,
        noteTitle: String? = nil,
        pivot: IdeaVariant? = nil
    ) async {
        let previous = analysis
        analysis = nil          // show the cooking state while the critic re-judges
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            // Best-effort web research first — grounds the manual regenerate
            // path the same way the pipeline does; nil just means ungrounded.
            var researchText = transcription.text
            if let pivot {
                researchText += "\nPivot: \(pivot.title) — \(pivot.pitch)"
            }
            let research = await aiService.researchMarket(researchText)
            analysis = try await aiService.generateAndSaveSWOTAnalysis(
                transcriptionId: transcription.id,
                transcriptionText: transcription.text,
                noteId: transcription.noteId,
                currentNoteTitle: noteTitle,
                research: research,
                pivot: pivot,
                replaceExisting: true
            )
        } catch {
            analysis = previous   // keep showing the old taste test on failure
            errorMessage = "Failed to generate analysis: \(error.localizedDescription)"
        }
    }
}
