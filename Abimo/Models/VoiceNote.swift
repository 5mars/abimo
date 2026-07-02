//
//  VoiceNote.swift
//  Abimo
//
//  Created by Claude on 2026-03-03.
//

import Foundation

struct VoiceNote: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let title: String
    let audioFileURL: String
    let duration: TimeInterval
    let createdAt: Date
    let updatedAt: Date
    var transcriptionId: UUID?
    var analysisId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case audioFileURL = "audio_file_url"
        case duration
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case transcriptionId = "transcription_id"
        case analysisId = "analysis_id"
    }
}

extension VoiceNote {
    /// Prefix used for titles the app generated itself (recording auto-save).
    /// Titles carrying it are safe to overwrite with the AI-generated idea name;
    /// anything else is treated as user-chosen and left alone.
    static let autoTitlePrefix = "Idea — "

    static func isAutoTitle(_ title: String) -> Bool {
        title.hasPrefix(autoTitlePrefix)
    }

    static func makeAutoTitle(date: Date = Date()) -> String {
        autoTitlePrefix + date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }
}
