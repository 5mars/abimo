//
//  JourneyChapterTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

final class JourneyChapterTests: XCTestCase {

    private func action(_ quadrant: String?, minutes: Int = 10, done: Bool = false) -> MicroAction {
        MicroAction(
            id: UUID(), actionPlanId: UUID(), text: "t", doneCriteria: "d",
            timeEstimateMinutes: minutes, priority: 0, quadrant: quadrant,
            template: nil, actionType: nil, deepLinkData: nil,
            isCompleted: done, completedAt: done ? Date() : nil,
            isCommitted: false, committedAt: nil, scheduledFor: nil,
            completionOutcome: nil, completionNote: nil, createdAt: Date()
        )
    }

    func testEmptyPlanHasNoChapters() {
        XCTAssertTrue(JourneyChapterBuilder.build(from: []).isEmpty)
    }

    func testQuadrantsGroupInFixedOrderRegardlessOfInput() {
        let actions = [action("threat"), action("strength"), action("opportunity"), action("weakness"),
                       action("opportunity"), action("weakness")]
        let chapters = JourneyChapterBuilder.build(from: actions)
        XCTAssertEqual(chapters.map(\.kind), [.fixWeakSpot, .proveDemand, .playYourEdge])
        // lone strength + lone threat merged
        XCTAssertEqual(chapters.last?.title, "Play your edge, watch the risks")
        XCTAssertEqual(chapters.last?.actions.count, 2)
    }

    func testOrderWithinChapterIsPreserved() {
        let a = action("weakness"), b = action("weakness"), c = action("opportunity")
        let chapters = JourneyChapterBuilder.build(from: [a, c, b])
        XCTAssertEqual(chapters.first?.actions.map(\.id), [a.id, b.id])
    }

    func testNilQuadrantFallsBackToSingleChapter() {
        let actions = [action(nil), action(nil), action(nil)]
        let chapters = JourneyChapterBuilder.build(from: actions)
        XCTAssertEqual(chapters.count, 1)
        XCTAssertEqual(chapters.first?.kind, .steps)
        XCTAssertEqual(chapters.first?.actions.count, 3)
    }

    func testMixedNilQuadrantFallsBack() {
        let chapters = JourneyChapterBuilder.build(from: [action("weakness"), action(nil), action("threat")])
        XCTAssertEqual(chapters.map(\.kind), [.steps])
    }

    func testSingleQuadrantFallsBack() {
        let chapters = JourneyChapterBuilder.build(from: [action("weakness"), action("weakness")])
        XCTAssertEqual(chapters.map(\.kind), [.steps])
    }

    func testNeverMoreThanThreeChapters() {
        // 2 weakness, 2 opportunity, 2 strength, 1 threat → threat can't merge
        // (strength has 2) so it folds into the previous chapter.
        let actions = [action("weakness"), action("weakness"), action("opportunity"), action("opportunity"),
                       action("strength"), action("strength"), action("threat")]
        let chapters = JourneyChapterBuilder.build(from: actions)
        XCTAssertEqual(chapters.count, 3)
        XCTAssertEqual(chapters.last?.actions.count, 3)
        XCTAssertEqual(chapters.reduce(0) { $0 + $1.actions.count }, 7)
    }

    func testChapterStats() {
        let chapters = JourneyChapterBuilder.build(from: [
            action("weakness", minutes: 10, done: true), action("weakness", minutes: 20),
            action("opportunity", minutes: 5),
        ])
        XCTAssertEqual(chapters.first?.completedCount, 1)
        XCTAssertEqual(chapters.first?.totalMinutes, 30)
        XCTAssertFalse(chapters.first!.isComplete)
    }

    func testQuadrantVocabularyIncludesPlurals() {
        XCTAssertEqual(JourneyChapterKind(quadrant: "Weaknesses"), .fixWeakSpot)
        XCTAssertEqual(JourneyChapterKind(quadrant: "OPPORTUNITY"), .proveDemand)
        XCTAssertNil(JourneyChapterKind(quadrant: "misc"))
    }
}
