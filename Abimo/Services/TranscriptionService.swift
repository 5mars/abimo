//
//  TranscriptionService.swift
//  Abimo
//
//  Created by Claude on 2026-03-03.
//

import Foundation
import Combine
import Supabase

@MainActor
class TranscriptionService: ObservableObject {
    @Published var transcriptionText: String = ""
    @Published var isTranscribing = false
    @Published var progress: Double = 0.0

    private let supabase = SupabaseService.shared

    // For Whisper: pass the Supabase storage URL string directly
    func transcribeWithWhisper(storageURL: String) async throws -> String {
        isTranscribing = true
        transcriptionText = ""
        progress = 0.0
        defer { isTranscribing = false }

        struct WhisperResponse: Codable {
            let text: String
        }

        struct WhisperRequest: Encodable {
            let audioUrl: String
        }

        let request = WhisperRequest(audioUrl: storageURL)

        let response: WhisperResponse = try await supabase.client.functions
            .invoke(
                "transcribe-audio",
                options: FunctionInvokeOptions(
                    body: request
                )
            )

        transcriptionText = response.text
        progress = 1.0
        return response.text
    }

}
