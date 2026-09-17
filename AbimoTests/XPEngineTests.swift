//
//  XPEngineTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

final class XPEngineTests: XCTestCase {

    private let calendar = Calendar.current

    private func date(daysAgo: Int, hour: Int = 12) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: Date())!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    // MARK: - Per-day XP

    func testZeroCompletionsIsZeroXP() {
        XCTAssertEqual(XPEngine.xp(forCompletionsInDay: 0), 0)
    }

    func testSingleCompletionEarnsActionPlusFirstOfDayBonus() {
        XCTAssertEqual(XPEngine.xp(forCompletionsInDay: 1), 15)
    }

    func testThreeCompletionsEarnThirtyPlusBonus() {
        XCTAssertEqual(XPEngine.xp(forCompletionsInDay: 3), 35)
    }

    // MARK: - Totals

    func testTotalXPSumsAcrossDays() {
        // 2 actions today (25) + 1 yesterday (15) = 40
        let dates = [date(daysAgo: 0), date(daysAgo: 0, hour: 15), date(daysAgo: 1)]
        XCTAssertEqual(XPEngine.totalXP(completionDates: dates), 40)
    }

    func testTotalXPEmptyIsZero() {
        XCTAssertEqual(XPEngine.totalXP(completionDates: []), 0)
    }

    func testXpTodayIgnoresOtherDays() {
        let dates = [date(daysAgo: 0), date(daysAgo: 1), date(daysAgo: 2)]
        XCTAssertEqual(XPEngine.xpToday(completionDates: dates), 15)
    }

    func testXpTodayZeroWhenNothingToday() {
        XCTAssertEqual(XPEngine.xpToday(completionDates: [date(daysAgo: 1)]), 0)
    }

    // MARK: - Goal crossing

    func testFirstCompletionCrossesChillGoal() {
        // 0 -> 15 XP crosses a 15-XP goal
        XCTAssertTrue(XPEngine.completionCrossesGoal(completionsTodayAfter: 1, goal: 15))
    }

    func testFirstCompletionDoesNotCrossRegularGoal() {
        // 0 -> 15 XP does not reach 25
        XCTAssertFalse(XPEngine.completionCrossesGoal(completionsTodayAfter: 1, goal: 25))
    }

    func testSecondCompletionCrossesRegularGoal() {
        // 15 -> 25 XP crosses 25
        XCTAssertTrue(XPEngine.completionCrossesGoal(completionsTodayAfter: 2, goal: 25))
    }

    func testThirdCompletionDoesNotRecrossRegularGoal() {
        // 25 -> 35: already past the goal, no second banner
        XCTAssertFalse(XPEngine.completionCrossesGoal(completionsTodayAfter: 3, goal: 25))
    }

    func testFourthCompletionCrossesFiredUpGoal() {
        // 35 -> 45 crosses 45
        XCTAssertTrue(XPEngine.completionCrossesGoal(completionsTodayAfter: 4, goal: 45))
    }

    func testZeroCompletionsNeverCrosses() {
        XCTAssertFalse(XPEngine.completionCrossesGoal(completionsTodayAfter: 0, goal: 15))
    }

    // MARK: - Tier mapping

    func testTierFromStoredXPFallsBackToRegular() {
        XCTAssertEqual(DailyGoalTier(storedXP: 999), .regular)
        XCTAssertEqual(DailyGoalTier(storedXP: 15), .chill)
        XCTAssertEqual(DailyGoalTier(storedXP: 45), .firedUp)
    }
}

// MARK: - Achievement latch helpers

final class AchievementLatchTests: XCTestCase {

    private func context(actions: Int = 0, streak: Int = 0, xp: Int = 0, plans: Int = 0) -> AchievementContext {
        AchievementContext(
            ideaCount: 0,
            analysisCount: 0,
            completedActionCount: actions,
            completedPlanCount: plans,
            currentStreak: streak,
            bestScore: nil,
            completedActionsByAnalysisId: [:],
            scoresByAnalysisId: [:],
            totalXP: xp
        )
    }

    func testLatchRoundTrip() {
        let set: Set<Achievement> = [.lineCook, .onFire]
        XCTAssertEqual(Achievement.decodeLatch(Achievement.encodeLatch(set)), set)
    }

    func testDecodeGarbageIsEmpty() {
        XCTAssertEqual(Achievement.decodeLatch(""), [])
        XCTAssertEqual(Achievement.decodeLatch("bogus,unknown"), [])
    }

    func testFreshUnlocksExcludesPrevious() {
        // 5 actions unlocks lineCook; already-latched badges never repeat
        let fresh = Achievement.freshUnlocks(in: context(actions: 5), previous: [.lineCook])
        XCTAssertFalse(fresh.contains(.lineCook))
    }

    func testFreshUnlocksDetectsXPBadge() {
        let fresh = Achievement.freshUnlocks(in: context(xp: 100), previous: [])
        XCTAssertTrue(fresh.contains(.prepCook))
        XCTAssertFalse(fresh.contains(.sousChef))
    }

    func testZeroedContextUnlocksNothing() {
        XCTAssertTrue(Achievement.freshUnlocks(in: context(), previous: []).isEmpty)
    }
}
