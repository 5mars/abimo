//
//  IdeaPipelineService.swift
//  Abimo
//

import Foundation
import Combine

/// Runs the full record → results pipeline with zero taps:
/// save upload → Whisper transcription → SWOT analysis → action plan.
/// Every step persists to Supabase, so a failed run resumes from the failed
/// stage instead of redoing (and re-paying for) the earlier ones.
@MainActor
final class IdeaPipelineService: ObservableObject {

    enum Step: Int, CaseIterable, Equatable {
        case saving
        case transcribing
        case analyzing
        case planning

        var title: String {
            switch self {
            case .saving:       return "Taking your order"
            case .transcribing: return "Listening to every word"
            case .analyzing:    return "The critic is tasting…"
            case .planning:     return "Writing the recipe"
            }
        }

        var icon: String {
            switch self {
            case .saving:       return "tray.and.arrow.down.fill"
            case .transcribing: return "waveform"
            case .analyzing:    return "fork.knife"
            case .planning:     return "list.bullet.clipboard.fill"
            }
        }
    }

    enum Stage: Equatable {
        case idle
        case running(Step)
        case failed(Step, String)
        case done
    }

    @Published private(set) var stage: Stage = .idle
    private(set) var note: VoiceNote?
    private(set) var transcription: Transcription?
    private(set) var analysis: SWOTAnalysis?

    private let supabase = SupabaseService.shared
    private let transcriptionService = TranscriptionService()
    private let aiService = AIAnalysisService()
    private var runTask: Task<Void, Never>?

    /// Begin a fresh run for a new recording. Cancels any still-running
    /// previous run (its persisted artifacts stay recoverable from the note).
    func start(recordingVM: RecordingViewModel, coordinator: NavigationCoordinator) {
        runTask?.cancel()
        note = nil
        transcription = nil
        analysis = nil
        stage = .idle
        runTask = Task { await run(recordingVM: recordingVM, coordinator: coordinator) }
    }

    /// Re-run after a failure, keeping completed artifacts so only the failed
    /// stage (and later ones) execute again.
    func retry(recordingVM: RecordingViewModel, coordinator: NavigationCoordinator) {
        runTask?.cancel()
        runTask = Task { await run(recordingVM: recordingVM, coordinator: coordinator) }
    }

    private func run(recordingVM: RecordingViewModel, coordinator: NavigationCoordinator) async {
        // 1. Save + upload
        if note == nil {
            stage = .running(.saving)
            guard let saved = await recordingVM.saveRecording(title: VoiceNote.makeAutoTitle()) else {
                stage = .failed(.saving, recordingVM.errorMessage ?? "Couldn't save your recording")
                return
            }
            note = saved
            HapticEngine.selection()
        }
        guard let note, !Task.isCancelled else { return }

        // 2. Transcribe (Whisper via edge function)
        if transcription == nil {
            stage = .running(.transcribing)
            do {
                if let existing = try await supabase.fetchTranscription(noteId: note.id) {
                    transcription = existing
                } else {
                    let signedURL = try await supabase.getSignedAudioURL(filePath: note.audioFileURL, expiresIn: 3600)
                    let text = try await transcriptionService.transcribeWithWhisper(storageURL: signedURL)
                    let new = Transcription(
                        id: UUID(),
                        noteId: note.id,
                        text: text,
                        language: "en",
                        confidence: nil,
                        createdAt: Date()
                    )
                    try await supabase.createTranscription(new)
                    transcription = new
                }
                HapticEngine.selection()
            } catch {
                stage = .failed(.transcribing, "Couldn't hear that one: \(error.localizedDescription)")
                return
            }
        }
        guard let transcription, !Task.isCancelled else { return }

        // 3. SWOT analysis (also upgrades the auto-title to the AI idea name)
        if analysis == nil {
            stage = .running(.analyzing)
            do {
                if let existing = ((try? await supabase.fetchSWOTAnalysis(transcriptionId: transcription.id)) ?? nil) {
                    analysis = existing
                } else {
                    analysis = try await aiService.generateAndSaveSWOTAnalysis(
                        transcriptionId: transcription.id,
                        transcriptionText: transcription.text,
                        noteId: note.id,
                        currentNoteTitle: note.title
                    )
                }
                if let analysis {
                    try? await supabase.updateVoiceNoteAnalysisId(noteId: note.id, analysisId: analysis.id)
                }
                HapticEngine.selection()
            } catch {
                stage = .failed(.analyzing, "The critic choked: \(error.localizedDescription)")
                return
            }
        }
        guard let analysis, !Task.isCancelled else { return }

        // 4. Action plan — fire-and-forget through the coordinator, which owns
        // the retry card in the Actions tab. The user lands on results while
        // the plan finishes cooking.
        stage = .running(.planning)
        let freshTitle = (try? await supabase.fetchVoiceNote(id: note.id))?.title ?? note.title
        coordinator.startPlanGeneration(
            analysis: analysis,
            transcriptionText: transcription.text,
            noteTitle: freshTitle
        )
        stage = .done
        HapticEngine.success()
    }
}
