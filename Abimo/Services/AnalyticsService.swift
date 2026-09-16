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
    case analysisViewed(scoreBand: String, scoringVersion: Int)
    // gate: idea_cap | swot_items | market_intel | remixes | evidence_receipt | retaste | next_chapter | daily_cap
    // source: pipeline | quadrant_sheet | analysis_card | slot_pill | profile | wrap_up | mascot | dare
    case gateHit(gate: String, source: String)
    case paywallShown(context: String)         // PaywallView.Context analyticsName
    case paywallDismissed(context: String, selectedProductId: String, secondsOpen: Int, sawTrialCTA: Bool)
    case paywallPlanSelected(productId: String)
    case entitlementChanged(from: String, to: String, source: String)   // free|plus ; purchase|restore|refresh
    case appOpen(source: String, daysSinceLast: Int, loopState: String) // launch|foreground|notification
    case notificationOpened(id: String, kind: String)
    case actionCompleted(quadrant: String, minutes: Int, outcome: String, completionsToday: Int, streak: Int)
    case actionUncompleted
    case planCompleted(actions: Int, daysToComplete: Int)
    case nextChapterRequested(chapter: Int)
    case nextChapterGenerated(chapter: Int, actions: Int)
    case retasteRequested(previousScore: Int)
    case retasteCompleted(previousScore: Int, newScore: Int)
    case streakExtended(days: Int, via: String)
    case sparkShown(kind: String)
    case sparkTapped(kind: String)
    case shareInitiated(surface: String, scoreBand: String)
    case shareCompleted(surface: String, scoreBand: String)
    case aiCapHit(fn: String)
    case purchaseInitiated(productId: String)
    case purchaseSucceeded(productId: String)
    case purchaseFailed(reason: String)        // "cancelled" | "pending" | "unverified" | "error"
    case purchaseRestored
    case trialStarted(productId: String)
    case walkInStarted
    case walkInStepCompleted(step: String)     // WalkInStep rawValue
    case walkInSkipped(step: String)
    case walkInCompleted
    case dailyGoalHit(tier: String)            // DailyGoalTier analyticsName
    case goalTierChanged(tier: String)
    case dareCompleted(kind: String)           // Dare rawValue
    case daresCleared

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
        case .paywallDismissed:       return "paywall_dismissed"
        case .paywallPlanSelected:    return "paywall_plan_selected"
        case .entitlementChanged:     return "entitlement_changed"
        case .appOpen:                return "app_open"
        case .notificationOpened:     return "notification_opened"
        case .actionCompleted:        return "action_completed"
        case .actionUncompleted:      return "action_uncompleted"
        case .planCompleted:          return "plan_completed"
        case .nextChapterRequested:   return "next_chapter_requested"
        case .nextChapterGenerated:   return "next_chapter_generated"
        case .retasteRequested:       return "retaste_requested"
        case .retasteCompleted:       return "retaste_completed"
        case .streakExtended:         return "streak_extended"
        case .sparkShown:             return "spark_shown"
        case .sparkTapped:            return "spark_tapped"
        case .shareInitiated:         return "share_initiated"
        case .shareCompleted:         return "share_completed"
        case .aiCapHit:               return "ai_cap_hit"
        case .purchaseInitiated:      return "purchase_initiated"
        case .purchaseSucceeded:      return "purchase_succeeded"
        case .purchaseFailed:         return "purchase_failed"
        case .purchaseRestored:       return "purchase_restored"
        case .trialStarted:           return "trial_started"
        case .walkInStarted:          return "walk_in_started"
        case .walkInStepCompleted:    return "walk_in_step_completed"
        case .walkInSkipped:          return "walk_in_skipped"
        case .walkInCompleted:        return "walk_in_completed"
        case .dailyGoalHit:           return "daily_goal_hit"
        case .goalTierChanged:        return "goal_tier_changed"
        case .dareCompleted:          return "dare_completed"
        case .daresCleared:           return "dares_cleared"
        }
    }

    var parameters: [String: Any]? {
        switch self {
        case .signUp, .login:
            return [AnalyticsParameterMethod: "email"]
        case .ideaCreated, .purchaseRestored, .walkInStarted, .walkInCompleted, .daresCleared, .actionUncompleted:
            return nil
        case .dailyGoalHit(let tier), .goalTierChanged(let tier):
            return ["tier": tier]
        case .dareCompleted(let kind), .sparkShown(let kind), .sparkTapped(let kind):
            return ["kind": kind]
        case .paywallDismissed(let context, let productId, let seconds, let sawTrial):
            return ["context": context, "selected_product_id": productId, "seconds_open": seconds, "saw_trial_cta": sawTrial ? 1 : 0]
        case .paywallPlanSelected(let productId):
            return ["product_id": productId]
        case .entitlementChanged(let from, let to, let source):
            return ["from": from, "to": to, "source": source]
        case .appOpen(let source, let days, let loopState):
            return ["source": source, "days_since_last": days, "loop_state": loopState]
        case .notificationOpened(let id, let kind):
            return ["id": String(id.prefix(100)), "kind": kind]
        case .actionCompleted(let quadrant, let minutes, let outcome, let completionsToday, let streak):
            return ["quadrant": quadrant, "minutes": minutes, "outcome": outcome, "completions_today": completionsToday, "streak": streak]
        case .planCompleted(let actions, let days):
            return ["actions": actions, "days_to_complete": days]
        case .nextChapterRequested(let chapter):
            return ["chapter": chapter]
        case .nextChapterGenerated(let chapter, let actions):
            return ["chapter": chapter, "actions": actions]
        case .retasteRequested(let previous):
            return ["previous_score": previous]
        case .retasteCompleted(let previous, let new):
            return ["previous_score": previous, "new_score": new, "delta": new - previous]
        case .streakExtended(let days, let via):
            return ["days": days, "via": via]
        case .shareInitiated(let surface, let band), .shareCompleted(let surface, let band):
            return ["surface": surface, "score_band": band]
        case .aiCapHit(let fn):
            return ["fn": fn]
        case .walkInStepCompleted(let step), .walkInSkipped(let step):
            return ["step": step]
        case .pipelineStageCompleted(let stage):
            return ["stage": stage]
        case .pipelineCompleted(let durationSec):
            return ["duration_sec": durationSec]
        case .pipelineFailed(let stage, let reason):
            return ["stage": stage, "reason": String(reason.prefix(100))]
        case .analysisViewed(let scoreBand, let scoringVersion):
            return ["score_band": scoreBand, "scoring_version": scoringVersion]
        case .gateHit(let gate, let source):
            return ["gate": gate, "source": source]
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
