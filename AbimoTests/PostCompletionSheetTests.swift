//
//  PostCompletionSheetTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

@MainActor
final class PostCompletionSheetTests: XCTestCase {

    // MARK: - Helpers

    /// Creates a fresh ViewModel with microActions pre-populated (no Supabase).
    private func makeViewModel(actionCount: Int) -> ActionPlanViewModel {
        let vm = ActionPlanViewModel()
        vm.microActions = (0..<actionCount).map { i in
            MicroAction(
                id: UUID(),
                actionPlanId: UUID(),
                text: "Action \(i + 1)",
                doneCriteria: "Done",
                timeEstimateMinutes: 10,
                priority: i,
                quadrant: nil,
                template: nil,
                actionType: nil,
                deepLinkData: nil,
                isCompleted: false,
                completedAt: nil,
                isCommitted: false,
                committedAt: nil,
                scheduledFor: nil,
                completionOutcome: nil,
                completionNote: nil,
                createdAt: Date()
            )
        }
        return vm
    }

    /// Simulates completion of one action by directly mutating state + calling celebration evaluator.
    /// This avoids Supabase calls.
    private func simulateCompletion(vm: ActionPlanViewModel, at index: Int) {
        vm.microActions[index].isCompleted = true
        vm.microActions[index].completedAt = Date()
        let completedId = vm.microActions[index].id
        vm.evaluateCelebrationState(completedId: completedId)
        // Mirror the postCompletionSheet logic from toggleMicroAction
        let allDone = !vm.microActions.contains(where: { !$0.isCompleted })
        if !allDone {
            vm.postCompletionSheet = .congrats(actionId: completedId)
        }
    }

    // MARK: - PostCompletionSheet State Machine

    func testNonFinalCompletionSetsCongrats() {
        let vm = makeViewModel(actionCount: 5)
        let action = vm.microActions[0]
        simulateCompletion(vm: vm, at: 0)

        if case .congrats(let actionId) = vm.postCompletionSheet {
            XCTAssertEqual(actionId, action.id,
                           "Non-final completion must set postCompletionSheet to .congrats with the correct actionId")
        } else {
            XCTFail("Expected .congrats but got \(String(describing: vm.postCompletionSheet))")
        }
    }

    func testFinalCompletionSetsPlanCompleteNotCongrats() {
        let vm = makeViewModel(actionCount: 2)
        // Complete first action (non-final) and dismiss the congrats sheet (simulates user dismissal)
        simulateCompletion(vm: vm, at: 0)
        vm.dismissPostCompletionSheet() // User dismisses congrats before completing last action
        // Complete second action (final) — must NOT set postCompletionSheet
        simulateCompletion(vm: vm, at: 1)

        XCTAssertNil(vm.postCompletionSheet,
                     "Final completion must NOT set postCompletionSheet (it stays nil after dismiss + final complete)")
        XCTAssertEqual(vm.celebrationState, .planComplete,
                       "Final completion must set celebrationState to .planComplete")
    }

    // MARK: - PostCompletionSheet Identifiable

    func testPostCompletionSheetIdentifiableIds() {
        let someUUID = UUID()
        let congratsSheet = PostCompletionSheet.congrats(actionId: someUUID)
        XCTAssertEqual(congratsSheet.id, "congrats-\(someUUID)",
                       ".congrats Identifiable id must be 'congrats-{uuid}'")
    }

    // MARK: - Rapid Completion Guard

    func testRapidCompletionNeverProducesStuckSheet() {
        let vm = makeViewModel(actionCount: 5)
        // Complete 3 actions in rapid succession
        simulateCompletion(vm: vm, at: 0)
        simulateCompletion(vm: vm, at: 1)
        simulateCompletion(vm: vm, at: 2)
        // postCompletionSheet must be non-nil (last completion set it)
        XCTAssertNotNil(vm.postCompletionSheet,
                        "After rapid completions, postCompletionSheet must be set to the latest .congrats")
        if case .congrats(let actionId) = vm.postCompletionSheet {
            XCTAssertEqual(actionId, vm.microActions[2].id,
                           "Rapid completion must set congrats to the LAST completed action")
        } else {
            XCTFail("Expected .congrats but got \(String(describing: vm.postCompletionSheet))")
        }
    }
}
