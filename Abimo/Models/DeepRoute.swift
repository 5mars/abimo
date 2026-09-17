//
//  DeepRoute.swift
//  Abimo
//
//  Where a notification tap lands. Encoded into the notification's
//  userInfo as a short string so it survives the round trip through
//  UNUserNotificationCenter and older builds simply ignore it.
//

import Foundation

enum DeepRoute: Equatable {
    case record
    case actions
    case profile
    case report
    case note(UUID)
    case plan(planId: UUID, analysisId: UUID)

    var encoded: String {
        switch self {
        case .record:  return "record"
        case .actions: return "actions"
        case .profile: return "profile"
        case .report:  return "report"
        case .note(let id): return "note:\(id.uuidString)"
        case .plan(let planId, let analysisId): return "plan:\(planId.uuidString):\(analysisId.uuidString)"
        }
    }

    init?(encoded: String) {
        let parts = encoded.split(separator: ":").map(String.init)
        switch parts.first {
        case "record":  self = .record
        case "actions": self = .actions
        case "profile": self = .profile
        case "report":  self = .report
        case "note":
            guard parts.count == 2, let id = UUID(uuidString: parts[1]) else { return nil }
            self = .note(id)
        case "plan":
            guard parts.count == 3, let p = UUID(uuidString: parts[1]), let a = UUID(uuidString: parts[2]) else { return nil }
            self = .plan(planId: p, analysisId: a)
        default:
            return nil
        }
    }

    var tab: AppTab {
        switch self {
        case .record:          return .record
        case .actions, .plan, .report: return .actions
        case .profile:         return .profile
        case .note:            return .ideas
        }
    }
}
