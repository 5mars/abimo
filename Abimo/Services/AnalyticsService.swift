//
//  AnalyticsService.swift
//  Abimo
//

import Foundation
import FirebaseCore
import FirebaseAnalytics
import FirebaseCrashlytics

/// Every analytics event the app emits, in one place. Names are snake_case
/// (Firebase constraint: ≤40 chars, ≤25 params).
enum AnalyticsEvent {
    case signUp
    case login
    case ideaCreated
    case pipelineStageCompleted(stage: String)
    case pipelineCompleted(durationSec: Int)
    case pipelineFailed(stage: String, reason: String)
    case analysisViewed(scoreBand: String)
    case gateHit(gate: String)                 // "idea_cap" | "swot_lock"
    case paywallShown(context: String)         // PaywallView.Context rawValue
    case purchaseInitiated(productId: String)
    case purchaseSucceeded(productId: String)
    case purchaseFailed(reason: String)        // "cancelled" | "pending" | "unverified" | "error"
    case purchaseRestored
    case trialStarted(productId: String)

    var name: String {
        switch self {
        case .signUp:                 return AnalyticsEventSignUp
        case .login:                  return AnalyticsEventLogin
        case .ideaCreated:            return "idea_created"
        case .pipelineStageCompleted: return "pipeline_stage_completed"
        case .pipelineCompleted:      return "pipeline_completed"
        case .pipelineFailed:         return "pipeline_failed"
        case .analysisViewed:         return "analysis_viewed"
        case .gateHit:                return "gate_hit"
        case .paywallShown:           return "paywall_shown"
        case .purchaseInitiated:      return "purchase_initiated"
        case .purchaseSucceeded:      return "purchase_succeeded"
        case .purchaseFailed:         return "purchase_failed"
        case .purchaseRestored:       return "purchase_restored"
        case .trialStarted:           return "trial_started"
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .signUp, .login:
            return [AnalyticsParameterMethod: "email"]
        case .ideaCreated, .purchaseRestored:
            return nil
        case .pipelineStageCompleted(let stage):
            return ["stage": stage]
        case .pipelineCompleted(let durationSec):
            return ["duration_sec": durationSec]
        case .pipelineFailed(let stage, let reason):
            return ["stage": stage, "reason": String(reason.prefix(100))]
        case .analysisViewed(let scoreBand):
            return ["score_band": scoreBand]
        case .gateHit(let gate):
            return ["gate": gate]
        case .paywallShown(let context):
            return ["context": context]
        case .purchaseInitiated(let productId),
             .purchaseSucceeded(let productId),
             .trialStarted(let productId):
            return ["product_id": productId]
        case .purchaseFailed(let reason):
            return ["reason": reason]
        }
    }
}

/// The only type in the app that talks to Firebase. Views and services log
/// through the typed AnalyticsEvent enum so event names/params stay in one
/// place and Firebase never leaks into the rest of the codebase.
///
/// DEBUG behavior: collection is OFF so dev runs don't pollute production
/// data — unless launched with -FIRDebugEnabled (scheme argument), which
/// turns it on for Firebase DebugView testing.
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    private var isEnabled = false

    private init() {}

    /// Call first thing in AbimoApp.init(). Safe to call before
    /// GoogleService-Info.plist has been added to the target: it just no-ops.
    func configure() {
        guard FirebaseApp.app() == nil else { return }
        guard Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else {
            return
        }
        FirebaseApp.configure()

        #if DEBUG
        isEnabled = ProcessInfo.processInfo.arguments.contains("-FIRDebugEnabled")
        #else
        isEnabled = true
        #endif
        Analytics.setAnalyticsCollectionEnabled(isEnabled)
    }

    /// Ties events and crashes to the Supabase user. Pass nil on sign-out.
    func setUser(id: UUID?) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.setUserID(id?.uuidString)
        Crashlytics.crashlytics().setUserID(id?.uuidString ?? "")
    }

    func log(_ event: AnalyticsEvent) {
        guard isEnabled else { return }
        Analytics.logEvent(event.name, parameters: event.parameters)
    }

    /// Screen views for the four always-alive tabs (opacity-switched, so
    /// SwiftUI's automatic screen tracking never fires for them).
    func logScreen(_ name: String) {
        guard isEnabled else { return }
        Analytics.logEvent(AnalyticsEventScreenView, parameters: [
            AnalyticsParameterScreenName: name,
            AnalyticsParameterScreenClass: name,
        ])
    }
}
