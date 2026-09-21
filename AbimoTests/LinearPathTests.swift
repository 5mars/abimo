//
//  LinearPathTests.swift
//  AbimoTests
//
//  The path is linear: the lit step is always the first unfinished one in
//  chapter order, and everything after it is locked.
//

import XCTest
@testable import Abimo

@MainActor
final class LinearPathTests: XCTestCase {

    private func action(_ quadrant: String, priority: Int, done: Bool = false, chapter: Int? = nil) -> MicroAction {
        MicroAction(
            id: UUID(), actionPlanId: UUID(), text: "\(quadrant) \(priority)", doneCriteria: "done",
            timeEstimateMinutes: 10, priority: priority, quadrant: quadrant, template: nil,
            actionType: nil, deepLinkData: nil, isCompleted: done, completedAt: done ? Date() : nil,
            isCommitted: false, committedAt: nil, scheduledFor: nil,
            completionOutcome: nil, completionNote: nil, createdAt: Date(), chapter: chapter
        )
    }

    func testNextStepFollowsChapterOrderNotPriority() {
        // Priorities interleave across quadrants: the coach gave the opportunity
        // step priority 1, but "Fix the weak spot" renders first on the path.
        let vm = ActionPlanViewModel()
        vm.microActions = [
            action("opportunity", priority: 1),
            action("weakness", priority: 2),
            action("strength", priority: 3),
            action("weakness", priority: 4),
        ]
        let path = vm.pathActions
        XCTAssertEqual(path.map(\.quadrant), ["weakness", "weakness", "opportunity", "strength"])
        XCTAssertEqual(vm.nextRecommendedAction?.text, "weakness 2", "the lit node is the first step on the path")
    }

    func testNextStepIsFirstUnfinishedOnThePath() {
        let vm = ActionPlanViewModel()
        vm.microActions = [
            action("weakness", priority: 1, done: true),
            action("weakness", priority: 2, done: true),
            action("opportunity", priority: 3),
            action("opportunity", priority: 4),
        ]
        XCTAssertEqual(vm.nextRecommendedAction?.text, "opportunity 3")
        let next = vm.nextRecommendedAction?.id
        let states = vm.pathActions.map { nodeState(for: $0, nextId: next) }
        XCTAssertEqual(states, [.done, .done, .next, .locked])
    }

    func testPartTwoAlwaysComesAfterPartOne() {
        let vm = ActionPlanViewModel()
        vm.microActions = [
            action("weakness", priority: 1, done: false, chapter: 2),
            action("threat", priority: 1, done: true, chapter: 1),
            action("opportunity", priority: 2, done: true, chapter: 1),
        ]
        XCTAssertEqual(vm.pathActions.map(\.chapterNumber), [1, 1, 2])
        XCTAssertEqual(vm.nextRecommendedAction?.chapterNumber, 2)
    }

    func testAllDoneMeansNoLitNode() {
        XCTAssertNil(ActionPlanViewModel.nextStep(in: [action("weakness", priority: 1, done: true)]))
        XCTAssertNil(ActionPlanViewModel.nextStep(in: []))
    }
}
