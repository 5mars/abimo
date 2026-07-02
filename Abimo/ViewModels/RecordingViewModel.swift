//
//  RecordingViewModel.swift
//  Abimo
//
//  Created by Claude on 2026-03-03.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class RecordingViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published var recordingFileURL: URL?

    private let audioService = AudioRecordingService()
    private let supabase = SupabaseService.shared
    private let permissionsManager = PermissionsManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Forward audioService changes so SwiftUI observes audioLevel/duration updates
        audioService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        // Forward permission changes so the denied-mic card appears/disappears live
        permissionsManager.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var recordingDuration: TimeInterval {
        audioService.recordingDuration
    }

    var audioLevel: Float {
        audioService.audioLevel
    }

    var micDenied: Bool {
        permissionsManager.microphoneDenied
    }

    func checkAndRequestPermissions() async -> Bool {
        if !permissionsManager.microphoneAuthorized {
            return await permissionsManager.requestMicrophonePermission()
        }
        return true
    }

    func openSettings() {
        PermissionsManager.openAppSettings()
    }

    func startRecording() async {
        errorMessage = nil

        // Check permissions
        guard await checkAndRequestPermissions() else {
            errorMessage = nil // denied state is rendered as a dedicated card, not an error string
            return
        }

        do {
            recordingFileURL = try audioService.startRecording()
            isRecording = true
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        guard let fileURL = audioService.stopRecording() else {
            errorMessage = "Failed to stop recording"
            return
        }
        recordingFileURL = fileURL
        isRecording = false
    }

    func cancelRecording() {
        audioService.cancelRecording()
        recordingFileURL = nil
        isRecording = false
        errorMessage = nil
    }

    func saveRecording(title: String) async -> VoiceNote? {
        guard let fileURL = recordingFileURL else {
            errorMessage = "No recording to save"
            return nil
        }

        guard let duration = AudioFileManager.getDuration(of: fileURL) else {
            errorMessage = "Could not determine recording duration"
            return nil
        }

        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        do {
            // Get current user
            guard let user = try await supabase.getCurrentUser() else {
                errorMessage = "Not authenticated"
                return nil
            }

            // Upload audio file
            let audioURL = try await supabase.uploadAudioFile(userId: user.id, fileURL: fileURL)

            // Create voice note record
            let voiceNote = VoiceNote(
                id: UUID(),
                userId: user.id,
                title: title,
                audioFileURL: audioURL,
                duration: duration,
                createdAt: Date(),
                updatedAt: Date(),
                transcriptionId: nil,
                analysisId: nil
            )

            try await supabase.createVoiceNote(voiceNote)

            // Clean up local file
            AudioFileManager.deleteFile(at: fileURL)
            recordingFileURL = nil

            // Schedule nudge if idea not analyzed within 24h
            NotificationScheduler.shared.scheduleIdeaNudge(noteId: voiceNote.id, noteTitle: title)

            return voiceNote
        } catch {
            errorMessage = "Failed to save recording: \(error.localizedDescription)"
            return nil
        }
    }
}
