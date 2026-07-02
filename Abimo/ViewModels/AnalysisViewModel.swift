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

    func generateAnalysis(transcription: Transcription, noteTitle: String? = nil) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            analysis = try await aiService.generateAndSaveSWOTAnalysis(
                transcriptionId: transcription.id,
                transcriptionText: transcription.text,
                noteId: transcription.noteId,
                currentNoteTitle: noteTitle
            )
        } catch {
            errorMessage = "Failed to generate analysis: \(error.localizedDescription)"
        }
    }
}
