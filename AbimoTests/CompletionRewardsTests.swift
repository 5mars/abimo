//
//  CompletionRewardsTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

final class CompletionRewardsTests: XCTestCase {

    func testBaseXPAddsFirstOfDayBonus() {
        XCTAssertEqual(CompletionRewards.baseXP(firstOfDay: false), XPEngine.actionXP)
        XCTAssertEqual(CompletionRewards.baseXP(firstOfDay: true), XPEngine.actionXP + XPEngine.firstOfDayBonus)
    }

    func testRowCountCountsEachEarnedThingOnce() {
        var r = CompletionRewards(xp: 10)
        XCTAssertEqual(r.rowCount, 1)
        r.milestone = 3
        XCTAssertEqual(r.rowCount, 2)
        r.streak = 4
        r.goalHit = 25
        r.badge = .lineCook
        XCTAssertEqual(r.rowCount, 5)
    }

    func testEnrichmentPreservesMilestoneCapturedEarlier() {
        // evaluateCelebrationState captures the milestone synchronously;
        // the async streak pass must build on it, not replace it.
        let early = CompletionRewards(xp: XPEngine.actionXP, milestone: 5)
        var later = early
        later.firstOfDay = true
        later.xp = CompletionRewards.baseXP(firstOfDay: true)
        later.streak = 3
        XCTAssertEqual(later.milestone, 5)
        XCTAssertEqual(later.xp, 15)
        XCTAssertEqual(later.rowCount, 3)
    }
}
