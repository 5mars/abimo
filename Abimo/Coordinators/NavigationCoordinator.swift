//
//  NavigationCoordinator.swift
//  Abimo
//

import SwiftUI
import Combine

enum AppTab: Int, CaseIterable {
    case ideas = 0
    case record = 1
    case actions = 2
    case profile = 3

    var screenName: String {
        switch self {
        case .ideas:   return "tab_ideas"
        case .record:  return "tab_record"
        case .actions: return "tab_actions"
        case .profile: return "tab_profile"
        }
    }
}

extension AppTab {
    var iconName: String {
        switch self {
        case .ideas:   return "lightbulb"
        case .record:  return "mic"
        case .actions: return "bolt"
        case .profile: return "person"
        }
    }

    var selectedIconName: String {
        switch self {
        case .ideas:   return "lightbulb.fill"
        case .record:  return "mic.fill"
        case .actions: return "bolt.fill"
        case .profile: return "person.fill"
        }
    }
}

struct PendingPlanRoute: Equatable, Identifiable {
    let planId: UUID
    let analysisId: UUID
    var id: UUID { planId }
}

/// Everything needed to re-run a failed action-plan generation from the Actions tab.
struct PlanGenerationRetryContext {
    let analysis: SWOTAnalysis
    let transcriptionText: String
    let noteTitle: String
}

@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .ideas {
        didSet {
            guard selectedTab != oldValue else { return }
            AnalyticsService.shared.logScreen(selectedTab.screenName)
        }
    }
    @Published var pendingNote: VoiceNote? = nil
    @Published var pendingPlanGeneration: Bool = false
    @Published var planGenerationRetry: PlanGenerationRetryContext? = nil
    /// Set by the recording pipeline so NoteDetailView opens the Taste Test
    /// sheet immediately on arrival instead of requiring another tap.
    @Published var pendingShowAnalysis: Bool = false

    /// Deep-link targets from a notification tap. The Kitchen resolves the
    /// note id once its list has loaded; the Actions tab pushes the plan.
    @Published var pendingNoteId: UUID? = nil
    @Published var pendingPlan: PendingPlanRoute? = nil

    func handle(_ route: DeepRoute) {
        selectedTab = route.tab
        switch route {
        case .note(let id):
            pendingNoteId = id
        case .plan(let planId, let analysisId):
            pendingPlan = PendingPlanRoute(planId: planId, analysisId: analysisId)
        case .record, .actions, .profile, .report:
            break
        }
    }

    func navigateToNote(_ note: VoiceNote) {
        selectedTab = .ideas
        pendingNote = note
    }

    /// Fire-and-forget plan generation that survives sheet dismissal.
    /// On failure the context is kept so the Actions tab can offer a retry
    /// instead of silently never showing the plan.
    func startPlanGeneration(analysis: SWOTAnalysis, transcriptionText: String, noteTitle: String) {
        // A generation is already cooking (the pipeline fires one automatically;
        // the results CTA can request another before it lands) — let it finish.
        guard !pendingPlanGeneration else { return }
        pendingPlanGeneration = true
        planGenerationRetry = nil
        Task { @MainActor in
            let service = AIAnalysisService()
            do {
                _ = try await service.generateAndSaveActionPlan(
                    analysis: analysis,
                    transcriptionText: transcriptionText,
                    noteTitle: noteTitle
                )
            } catch {
                planGenerationRetry = PlanGenerationRetryContext(
                    analysis: analysis,
                    transcriptionText: transcriptionText,
                    noteTitle: noteTitle
                )
            }
            pendingPlanGeneration = false
        }
    }
}
