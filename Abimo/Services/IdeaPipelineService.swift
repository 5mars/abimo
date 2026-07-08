//
//  IdeaPipelineService.swift
//  Abimo
//

import Foundation
import Combine
import UIKit

/// Runs the full record → results pipeline with zero taps:
/// save upload → Whisper transcription → market scouting → SWOT analysis →
/// action plan. Every step persists to Supabase, so a failed run resumes from
/// the failed stage instead of redoing (and re-paying for) the earlier ones.
/// Scouting is the exception: best-effort, transient, never fails the run.
@MainActor
final class IdeaPipelineService: ObservableObject {

    enum Step: Int, CaseIterable, Equatable {
        case saving
        case transcribing
        case scouting
        case analyzing
        case planning

        var title: String {
            switch self {
            case .saving:       return "Taking your order"
            case .transcribing: return "Listening to every word"
            case .scouting:     return "Scouting the market"
            case .analyzing:    return "The critic is tasting…"
            case .planning:     return "Writing the recipe"
            }
        }

        var icon: String {
            switch self {
            case .saving:       return "tray.and.arrow.down.fill"
            case .transcribing: return "waveform"
            case .scouting:     return "binoculars.fill"
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
    /// True when the last failure was the free-tier idea cap (server-checked).
    /// The recording is retained — retry() re-enters at .saving after the
    /// user upgrades or deletes an idea.
    @Published private(set) var capHit = false
    private(set) var note: VoiceNote?
    private(set) var transcription: Transcription?
    private(set) var analysis: SWOTAnalysis?
    /// Web-research digest for the current run. Deliberately transient (not
    /// persisted): kept across retry() so a failed analysis doesn't re-pay
    /// for search; cleared by start().
    private var research: AIAnalysisService.ResearchDigest?

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
        research = nil
        stage = .idle
        capHit = false
        runTask = Task { await run(recordingVM: recordingVM, coordinator: coordinator) }
    }

    /// Re-run after a failure, keeping completed artifacts so only the failed
    /// stage (and later ones) execute again.
    func retry(recordingVM: RecordingViewModel, coordinator: NavigationCoordinator) {
        runTask?.cancel()
        capHit = false
        runTask = Task { await run(recordingVM: recordingVM, coordinator: coordinator) }
    }

    private func run(recordingVM: RecordingViewModel, coordinator: NavigationCoordinator) async {
        // 1. Save + upload
        if note == nil {
            stage = .running(.saving)
            // Free-tier cap pre-flight — authoritative server count, checked
            // before the upload so the audio is never spent on a blocked save.
            if !EntitlementService.shared.isPremium,
               let count = try? await supabase.countVoiceNotes(),
               count >= EntitlementService.freeIdeaLimit {
                capHit = true
                fail(.saving, "Kitchen's full — three dishes max on the free menu. Your recording is safe; free a slot or go Plus, then retry.")
                return
            }
            guard let saved = await recordingVM.saveRecording(title: VoiceNote.makeAutoTitle()) else {
                fail(.saving, recordingVM.errorMessage ?? "Couldn't save your recording")
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
                fail(.transcribing, "Couldn't hear that one: \(error.localizedDescription)")
                return
            }
        }
        guard let transcription, !Task.isCancelled else { return }

        // 3. SWOT analysis (also upgrades the auto-title to the AI idea name),
        // preceded by best-effort market scouting — an empty digest just means
        // the critic tastes without a market tour.
        if analysis == nil {
            if let existing = ((try? await supabase.fetchSWOTAnalysis(transcriptionId: transcription.id)) ?? nil) {
                analysis = existing
            } else {
                if research == nil {
                    stage = .running(.scouting)
                    research = await aiService.researchMarket(transcription.text)
                    HapticEngine.selection()
                }
                guard !Task.isCancelled else { return }
                stage = .running(.analyzing)
                do {
                    analysis = try await aiService.generateAndSaveSWOTAnalysis(
                        transcriptionId: transcription.id,
                        transcriptionText: transcription.text,
                        noteId: note.id,
                        currentNoteTitle: note.title,
                        research: research
                    )
                } catch {
                    fail(.analyzing, "The critic choked: \(error.localizedDescription)")
                    return
                }
            }
            if let analysis {
                try? await supabase.updateVoiceNoteAnalysisId(noteId: note.id, analysisId: analysis.id)
            }
            HapticEngine.selection()
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
        notifyIfBackgrounded(success: true)
    }

    // MARK: - Failure + background notification

    private func fail(_ step: Step, _ message: String) {
        stage = .failed(step, message)
        notifyIfBackgrounded(success: false)
    }

    /// The user kicked this off and may have left ("Finish in background") —
    /// tell them the kitchen is done. Direct response to a user action, so no
    /// settings gate; NotificationService no-ops without permission.
    private func notifyIfBackgrounded(success: Bool) {
        guard UIApplication.shared.applicationState != .active else { return }
        NotificationService.shared.scheduleNotification(
            id: "pipeline_done_\(note?.id.uuidString ?? UUID().uuidString)",
            title: success ? "Order up! 🍽️" : "Kitchen incident 🔥",
            body: success
                ? "The critic has tasted your idea. The verdict is plated and waiting."
                : "Your idea hit a snag mid-cook. Come back and I'll take it from the top.",
            delay: 1
        )
    }
}
