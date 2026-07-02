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

/// Everything needed to re-run a failed action-plan generation from the Actions tab.
struct PlanGenerationRetryContext {
    let analysis: SWOTAnalysis
    let transcriptionText: String
    let noteTitle: String
}

@MainActor
final class NavigationCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .ideas
    @Published var pendingNote: VoiceNote? = nil
    @Published var pendingPlanGeneration: Bool = false
    @Published var planGenerationRetry: PlanGenerationRetryContext? = nil
    /// Set by the recording pipeline so NoteDetailView opens the Taste Test
    /// sheet immediately on arrival instead of requiring another tap.
    @Published var pendingShowAnalysis: Bool = false

    func navigateToNote(_ note: VoiceNote) {
        selectedTab = .ideas
        pendingNote = note
    }

    /// Fire-and-forget plan generation that survives sheet dismissal.
    /// On failure the context is kept so the Actions tab can offer a retry
    /// instead of silently never showing the plan.
    func startPlanGeneration(analysis: SWOTAnalysis, transcriptionText: String, noteTitle: String) {
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
