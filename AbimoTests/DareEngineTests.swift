//
//  DareEngineTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

final class DareEngineTests: XCTestCase {

    private let calendar = Calendar.current

    // MARK: - Helpers

    private func action(
        planId: UUID = UUID(),
        minutes: Int = 20,
        completedHoursAgo: Int? = nil,
        completedDaysAgo: Int? = nil,
        hour: Int? = nil
    ) -> MicroAction {
        var completedAt: Date?
        if let completedDaysAgo {
            let day = calendar.date(byAdding: .day, value: -completedDaysAgo, to: Date())!
            completedAt = calendar.date(bySettingHour: hour ?? 14, minute: 0, second: 0, of: day)
        } else if let completedHoursAgo {
            completedAt = calendar.date(byAdding: .hour, value: -completedHoursAgo, to: Date())
        } else if let hour {
            completedAt = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date())
        }
        return MicroAction(
            id: UUID(),
            actionPlanId: planId,
            text: "t",
            doneCriteria: "d",
            timeEstimateMinutes: minutes,
            priority: 0,
            quadrant: nil,
            template: nil,
            actionType: nil,
            deepLinkData: nil,
            isCompleted: completedAt != nil,
            completedAt: completedAt,
            isCommitted: false,
            committedAt: nil,
            scheduledFor: nil,
            completionOutcome: nil,
            completionNote: nil,
            createdAt: Date()
        )
    }

    // MARK: - Deterministic selection

    func testDaresAreDeterministicPerDay() {
        let date = Date()
        XCTAssertEqual(DareEngine.dares(for: date), DareEngine.dares(for: date))
    }

    func testDaresReturnThreeDistinct() {
        let dares = DareEngine.dares(for: Date())
        XCTAssertEqual(dares.count, 3)
        XCTAssertEqual(Set(dares).count, 3)
    }

    func testDaresRotateAcrossDays() {
        // At least one of the next 5 days differs from today's trio.
        let today = DareEngine.dares(for: Date())
        let differs = (1...5).contains { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: Date())!
            return DareEngine.dares(for: day) != today
        }
        XCTAssertTrue(differs)
    }

    // MARK: - Predicates

    func testCompleteOneRequiresTodayCompletion() {
        let planId = UUID()
        XCTAssertFalse(DareEngine.isSatisfied(.completeOne, actionsByPlan: [planId: [action(planId: planId, completedDaysAgo: 1)]], streak: 0))
        XCTAssertTrue(DareEngine.isSatisfied(.completeOne, actionsByPlan: [planId: [action(planId: planId, hour: 13)]], streak: 0))
    }

    func testCompleteTwoCountsOnlyToday() {
        let planId = UUID()
        let actions = [action(planId: planId, hour: 10), action(planId: planId, completedDaysAgo: 1)]
        XCTAssertFalse(DareEngine.isSatisfied(.completeTwo, actionsByPlan: [planId: actions], streak: 0))
        let two = [action(planId: planId, hour: 10), action(planId: planId, hour: 15)]
        XCTAssertTrue(DareEngine.isSatisfied(.completeTwo, actionsByPlan: [planId: two], streak: 0))
    }

    func testQuickBiteNeedsShortEstimate() {
        let planId = UUID()
        XCTAssertFalse(DareEngine.isSatisfied(.quickBite, actionsByPlan: [planId: [action(planId: planId, minutes: 30, hour: 13)]], streak: 0))
        XCTAssertTrue(DareEngine.isSatisfied(.quickBite, actionsByPlan: [planId: [action(planId: planId, minutes: 10, hour: 13)]], streak: 0))
    }

    func testEarlyBirdBeforeNoon() {
        let planId = UUID()
        XCTAssertTrue(DareEngine.isSatisfied(.earlyBird, actionsByPlan: [planId: [action(planId: planId, hour: 9)]], streak: 0))
        XCTAssertFalse(DareEngine.isSatisfied(.earlyBird, actionsByPlan: [planId: [action(planId: planId, hour: 14)]], streak: 0))
    }

    func testTwoKitchensNeedsTwoPlansToday() {
        let a = UUID(), b = UUID()
        XCTAssertFalse(DareEngine.isSatisfied(.twoKitchens, actionsByPlan: [a: [action(planId: a, hour: 10)], b: [action(planId: b, completedDaysAgo: 1)]], streak: 0))
        XCTAssertTrue(DareEngine.isSatisfied(.twoKitchens, actionsByPlan: [a: [action(planId: a, hour: 10)], b: [action(planId: b, hour: 11)]], streak: 0))
    }

    func testExtendStreakNeedsCompletionAndStreak() {
        let planId = UUID()
        let doneToday = [action(planId: planId, hour: 13)]
        XCTAssertFalse(DareEngine.isSatisfied(.extendStreak, actionsByPlan: [planId: doneToday], streak: 1))
        XCTAssertTrue(DareEngine.isSatisfied(.extendStreak, actionsByPlan: [planId: doneToday], streak: 2))
        XCTAssertFalse(DareEngine.isSatisfied(.extendStreak, actionsByPlan: [:], streak: 5))
    }

    func testKeepYourWordMatchesCommittedAction() {
        let planId = UUID()
        let committed = action(planId: planId, hour: 13)
        XCTAssertTrue(DareEngine.isSatisfied(.keepYourWord, actionsByPlan: [planId: [committed]], streak: 0, committedActionId: committed.id))
        XCTAssertFalse(DareEngine.isSatisfied(.keepYourWord, actionsByPlan: [planId: [committed]], streak: 0, committedActionId: UUID()))
        XCTAssertFalse(DareEngine.isSatisfied(.keepYourWord, actionsByPlan: [planId: [committed]], streak: 0, committedActionId: nil))
    }

    // MARK: - XP

    func testDareXPWithChestBonus() {
        XCTAssertEqual(DareEngine.xp(latchedCount: 0), 0)
        XCTAssertEqual(DareEngine.xp(latchedCount: 1), 5)
        XCTAssertEqual(DareEngine.xp(latchedCount: 2), 10)
        XCTAssertEqual(DareEngine.xp(latchedCount: 3), 30) // 15 + 15 chest
    }

    // MARK: - Latch storage

    func testLatchRoundTrip() {
        let now = Date()
        let encoded = DareEngine.encodeLatch([.completeOne, .quickBite], for: now)
        XCTAssertEqual(DareEngine.decodeLatch(encoded, for: now), [.completeOne, .quickBite])
    }

    func testLatchResetsOnDayRollover() {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let encoded = DareEngine.encodeLatch([.completeOne], for: yesterday)
        XCTAssertEqual(DareEngine.decodeLatch(encoded, for: Date()), [])
    }

    func testLatchDecodeGarbageIsEmpty() {
        XCTAssertEqual(DareEngine.decodeLatch("", for: Date()), [])
        XCTAssertEqual(DareEngine.decodeLatch("nonsense", for: Date()), [])
    }
}
