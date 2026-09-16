//
//  ActionPlan.swift
//  Abimo
//

import Foundation

// MARK: - ActionPlan

struct ActionPlan: Identifiable, Codable {
    let id: UUID
    let analysisId: UUID
    let userId: UUID
    let title: String
    let summary: String
    let totalEstimateMinutes: Int
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case analysisId          = "analysis_id"
        case userId              = "user_id"
        case title
        case summary
        case totalEstimateMinutes = "total_estimate_minutes"
        case createdAt           = "created_at"
    }
}

// MARK: - MicroAction

struct MicroAction: Identifiable, Codable, Hashable {
    let id: UUID
    let actionPlanId: UUID
    let text: String
    let doneCriteria: String
    let timeEstimateMinutes: Int
    let priority: Int
    let quadrant: String?
    let template: String?
    let actionType: String?
    let deepLinkData: DeepLinkData?
    var isCompleted: Bool
    var completedAt: Date?
    var isCommitted: Bool
    var committedAt: Date?
    var scheduledFor: Date?
    var completionOutcome: String?
    var completionNote: String?
    let createdAt: Date
    /// Which chapter of the plan this step belongs to. Optional so rows from
    /// before the column existed still decode; nil reads as chapter 1 and is
    /// omitted on insert so the DB default applies.
    var chapter: Int? = nil

    var chapterNumber: Int { chapter ?? 1 }

    enum CodingKeys: String, CodingKey {
        case id
        case actionPlanId        = "action_plan_id"
        case text
        case doneCriteria        = "done_criteria"
        case timeEstimateMinutes = "time_estimate_minutes"
        case priority
        case quadrant
        case template
        case actionType          = "action_type"
        case deepLinkData        = "deep_link_data"
        case isCompleted         = "is_completed"
        case completedAt         = "completed_at"
        case isCommitted         = "is_committed"
        case committedAt         = "committed_at"
        case scheduledFor        = "scheduled_for"
        case completionOutcome   = "completion_outcome"
        case completionNote      = "completion_note"
        case createdAt           = "created_at"
        case chapter
    }
}

// MARK: - Deep Link Data

struct DeepLinkData: Codable, Hashable {
    let urlScheme: String?
    let body: String?
    let subject: String?
    let query: String?

    enum CodingKeys: String, CodingKey {
        case urlScheme = "url_scheme"
        case body
        case subject
        case query
    }
}

// MARK: - Commitment

struct Commitment: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let microActionId: UUID
    let scheduledFor: Date?
    var status: String
    var completedAt: Date?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId          = "user_id"
        case microActionId   = "micro_action_id"
        case scheduledFor    = "scheduled_for"
        case status
        case completedAt     = "completed_at"
        case createdAt       = "created_at"
    }
}

// MARK: - AI Response (Edge Function JSON)

struct ActionPlanResponse: Codable {
    let title: String
    let summary: String
    let actions: [ActionPlanResponseItem]
}

struct ActionPlanResponseItem: Codable {
    let text: String
    let doneCriteria: String
    let timeEstimateMinutes: Int
    let priority: Int
    let quadrant: String?
    let template: String?
    let actionType: String?
    let deepLinkData: DeepLinkData?

    enum CodingKeys: String, CodingKey {
        case text
        case doneCriteria        = "done_criteria"
        case timeEstimateMinutes = "time_estimate_minutes"
        case priority
        case quadrant
        case template
        case actionType          = "action_type"
        case deepLinkData        = "deep_link_data"
    }
}
