//
//  SupabaseService.swift
//  Abimo
//
//  Created by Claude on 2026-03-03.
//

import Foundation
import Supabase

class SupabaseService {
    static let shared = SupabaseService()

    let client: SupabaseClient

    private init() {
        // TODO: Replace with your actual Supabase credentials
        let supabaseURL = URL(string: "https://ymbfqlrarlnqtzatgfah.supabase.co")!
        let supabaseAnonKey = "sb_publishable_HUIZRQ5EfaFU3EV-1IzqNQ_8uOBDJ39"

        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseAnonKey,
            options: .init(
                auth: .init(emitLocalSessionAsInitialSession: true)
            )
        )
    }

    // MARK: - Authentication

    func signUp(email: String, password: String) async throws -> User {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            redirectTo: URL(string: "noteai://auth-callback")
        )

        return User(
            id: response.user.id,
            email: response.user.email,
            createdAt: response.user.createdAt
        )
    }

    func signIn(email: String, password: String) async throws -> User {
        let response = try await client.auth.signIn(
            email: email,
            password: password
        )

        return User(
            id: response.user.id,
            email: response.user.email,
            createdAt: response.user.createdAt
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func getCurrentUser() async throws -> User? {
        do {
            let session = try await client.auth.session
            return User(
                id: session.user.id,
                email: session.user.email,
                createdAt: session.user.createdAt
            )
        } catch {
            // No session means user is not logged in
            return nil
        }
    }

    // MARK: - Voice Notes

    func createVoiceNote(_ note: VoiceNote) async throws {
        try await client
            .from("voice_notes")
            .insert(note)
            .execute()
    }

    func fetchVoiceNotes() async throws -> [VoiceNote] {
        let response: [VoiceNote] = try await client
            .from("voice_notes")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value

        return response
    }

    func fetchVoiceNote(id: UUID) async throws -> VoiceNote? {
        let response: [VoiceNote] = try await client
            .from("voice_notes")
            .select()
            .eq("id", value: id)
            .limit(1)
            .execute()
            .value

        return response.first
    }

    func deleteVoiceNote(id: UUID) async throws {
        try await client
            .from("voice_notes")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func updateVoiceNoteTitle(id: UUID, title: String) async throws {
        try await client
            .from("voice_notes")
            .update(["title": title])
            .eq("id", value: id)
            .execute()
    }

    func updateVoiceNoteAnalysisId(noteId: UUID, analysisId: UUID) async throws {
        try await client
            .from("voice_notes")
            .update(["analysis_id": analysisId.uuidString])
            .eq("id", value: noteId)
            .execute()
    }

    // MARK: - Counts

    func countVoiceNotes() async throws -> Int {
        struct IdOnly: Decodable { let id: UUID }
        let rows: [IdOnly] = try await client
            .from("voice_notes")
            .select("id")
            .execute()
            .value
        return rows.count
    }

    func countAnalyses() async throws -> Int {
        struct IdOnly: Decodable { let id: UUID }
        let rows: [IdOnly] = try await client
            .from("swot_analyses")
            .select("id")
            .execute()
            .value
        return rows.count
    }

    /// All of the user's viability scores keyed by analysis id (RLS scopes rows).
    func fetchViabilityScores() async throws -> [UUID: Int] {
        struct Row: Decodable {
            let id: UUID
            let viabilityScore: Int?
            enum CodingKeys: String, CodingKey {
                case id
                case viabilityScore = "viability_score"
            }
        }
        let rows: [Row] = try await client
            .from("swot_analyses")
            .select("id, viability_score")
            .execute()
            .value
        return rows.reduce(into: [:]) { dict, row in
            if let score = row.viabilityScore { dict[row.id] = score }
        }
    }

    // MARK: - Storage

    func uploadAudioFile(userId: UUID, fileURL: URL) async throws -> String {
        let fileName = "\(userId)/\(UUID().uuidString).m4a"
        let fileData = try Data(contentsOf: fileURL)

        let uploadResponse = try await client.storage
            .from("voice-recordings")
            .upload(
                fileName,
                data: fileData,
                options: FileOptions(contentType: "audio/m4a")
            )

        // Return the file path, not a URL (we'll generate signed URLs when needed)
        return uploadResponse.path
    }

    func getSignedAudioURL(filePath: String, expiresIn: Int = 3600) async throws -> String {
        // Generate a signed URL that allows temporary access to private files
        let signedURL = try await client.storage
            .from("voice-recordings")
            .createSignedURL(path: filePath, expiresIn: expiresIn)

        return signedURL.absoluteString
    }

    func downloadAudioFile(filePath: String) async throws -> URL {
        // Download the file data
        let data = try await client.storage
            .from("voice-recordings")
            .download(path: filePath)

        // Save to temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".m4a")
        try data.write(to: tempFile)

        return tempFile
    }

    func deleteAudioFile(filePath: String) async throws {
        try await client.storage
            .from("voice-recordings")
            .remove(paths: [filePath])
    }

    // MARK: - Transcriptions

    func createTranscription(_ transcription: Transcription) async throws {
        try await client
            .from("transcriptions")
            .insert(transcription)
            .execute()
    }

    func fetchTranscription(noteId: UUID) async throws -> Transcription? {
        let response: [Transcription] = try await client
            .from("transcriptions")
            .select()
            .eq("note_id", value: noteId)
            .execute()
            .value

        return response.first
    }

    func updateTranscription(_ transcription: Transcription) async throws {
        try await client
            .from("transcriptions")
            .update(transcription)
            .eq("id", value: transcription.id)
            .execute()
    }

    // MARK: - SWOT Analyses

    func createSWOTAnalysis(_ analysis: SWOTAnalysis) async throws {
        try await client
            .from("swot_analyses")
            .insert(analysis)
            .execute()
    }

    func fetchSWOTAnalysis(transcriptionId: UUID) async throws -> SWOTAnalysis? {
        let response: [SWOTAnalysis] = try await client
            .from("swot_analyses")
            .select()
            .eq("transcription_id", value: transcriptionId)
            .order("created_at", ascending: false)
            .execute()
            .value

        return response.first
    }

    /// Deletes every analysis for a transcription plus its dependent action
    /// plans and micro-actions. Client-side, child-first — no cascade
    /// assumption. Used before re-generating so a transcription never
    /// accumulates duplicate analyses.
    func deleteAnalysisArtifacts(transcriptionId: UUID) async throws {
        let analyses: [SWOTAnalysis] = try await client
            .from("swot_analyses")
            .select()
            .eq("transcription_id", value: transcriptionId)
            .execute()
            .value

        for analysis in analyses {
            let plans: [ActionPlan] = try await client
                .from("action_plans")
                .select()
                .eq("analysis_id", value: analysis.id)
                .execute()
                .value
            for plan in plans {
                try await client
                    .from("micro_actions")
                    .delete()
                    .eq("action_plan_id", value: plan.id)
                    .execute()
                try await client
                    .from("action_plans")
                    .delete()
                    .eq("id", value: plan.id)
                    .execute()
            }
            try await client
                .from("swot_analyses")
                .delete()
                .eq("id", value: analysis.id)
                .execute()
        }
    }

    // MARK: - Action Plans

    func createActionPlan(_ plan: ActionPlan) async throws {
        try await client
            .from("action_plans")
            .insert(plan)
            .execute()
    }

    func fetchActionPlan(analysisId: UUID) async throws -> ActionPlan? {
        let response: [ActionPlan] = try await client
            .from("action_plans")
            .select()
            .eq("analysis_id", value: analysisId)
            .execute()
            .value
        return response.first
    }

    func fetchAllActionPlans(userId: UUID) async throws -> [ActionPlan] {
        let response: [ActionPlan] = try await client
            .from("action_plans")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    // MARK: - Micro Actions

    func createMicroActions(_ actions: [MicroAction]) async throws {
        guard !actions.isEmpty else { return }
        try await client
            .from("micro_actions")
            .insert(actions)
            .execute()
    }

    func fetchMicroActions(actionPlanId: UUID) async throws -> [MicroAction] {
        let response: [MicroAction] = try await client
            .from("micro_actions")
            .select()
            .eq("action_plan_id", value: actionPlanId)
            .order("priority", ascending: true)
            .execute()
            .value
        return response
    }

    func toggleMicroAction(id: UUID, isCompleted: Bool, outcome: String? = nil, note: String? = nil) async throws {
        struct TogglePayload: Encodable {
            let is_completed: Bool
            let completed_at: Date?
            let completion_outcome: String?
            let completion_note: String?

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(is_completed, forKey: .is_completed)
                if let date = completed_at {
                    try container.encode(date, forKey: .completed_at)
                } else {
                    try container.encodeNil(forKey: .completed_at)
                }
                if let outcome = completion_outcome {
                    try container.encode(outcome, forKey: .completion_outcome)
                } else {
                    try container.encodeNil(forKey: .completion_outcome)
                }
                if let note = completion_note {
                    try container.encode(note, forKey: .completion_note)
                } else {
                    try container.encodeNil(forKey: .completion_note)
                }
            }

            enum CodingKeys: String, CodingKey {
                case is_completed, completed_at, completion_outcome, completion_note
            }
        }

        try await client
            .from("micro_actions")
            .update(TogglePayload(
                is_completed: isCompleted,
                completed_at: isCompleted ? Date() : nil,
                completion_outcome: outcome,
                completion_note: note
            ))
            .eq("id", value: id)
            .execute()
    }

    func commitMicroAction(id: UUID, scheduledFor: Date?) async throws {
        struct CommitPayload: Encodable {
            let is_committed: Bool
            let committed_at: Date?
            let scheduled_for: Date?

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(is_committed, forKey: .is_committed)
                if let date = committed_at {
                    try container.encode(date, forKey: .committed_at)
                } else {
                    try container.encodeNil(forKey: .committed_at)
                }
                if let date = scheduled_for {
                    try container.encode(date, forKey: .scheduled_for)
                } else {
                    try container.encodeNil(forKey: .scheduled_for)
                }
            }

            enum CodingKeys: String, CodingKey {
                case is_committed, committed_at, scheduled_for
            }
        }

        try await client
            .from("micro_actions")
            .update(CommitPayload(
                is_committed: true,
                committed_at: Date(),
                scheduled_for: scheduledFor
            ))
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Commitments

    func createCommitment(_ commitment: Commitment) async throws {
        try await client
            .from("commitments")
            .insert(commitment)
            .execute()
    }

    func fetchActiveCommitment(userId: UUID) async throws -> Commitment? {
        let response: [Commitment] = try await client
            .from("commitments")
            .select()
            .eq("user_id", value: userId)
            .eq("status", value: "active")
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
            .value
        return response.first
    }

    func updateCommitmentStatus(id: UUID, status: String, completedAt: Date? = nil) async throws {
        struct StatusPayload: Encodable {
            let status: String
            let completed_at: Date?

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(status, forKey: .status)
                if let date = completed_at {
                    try container.encode(date, forKey: .completed_at)
                } else {
                    try container.encodeNil(forKey: .completed_at)
                }
            }

            enum CodingKeys: String, CodingKey {
                case status, completed_at
            }
        }

        try await client
            .from("commitments")
            .update(StatusPayload(status: status, completed_at: completedAt))
            .eq("id", value: id)
            .execute()
    }

    // MARK: - Account Deletion

    func deleteAccount() async throws {
        let session = try await client.auth.session
        let userId = session.user.id

        // Delete storage files first (RPC won't handle storage)
        let files = try await client.storage
            .from("voice-recordings")
            .list(path: "\(userId)")
        if !files.isEmpty {
            let paths = files.map { "\(userId)/\($0.name)" }
            try await client.storage
                .from("voice-recordings")
                .remove(paths: paths)
        }

        // Delete all user data + auth record via server-side RPC
        try await client.rpc("delete_user_account").execute()
    }
}
