//
//  JourneyLayoutTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

final class JourneyLayoutTests: XCTestCase {

    private let layout = JourneyLayout()

    func testLateralPatternIsCentreRightCentreLeft() {
        XCTAssertEqual((0..<8).map(layout.lateralSlot), [0, 1, 0, -1, 0, 1, 0, -1])
    }

    func testCentreSlotsSitOnTheMidline() {
        let width: CGFloat = 320
        XCTAssertEqual(layout.center(0, width: width).x, width / 2)
        XCTAssertEqual(layout.center(2, width: width).x, width / 2)
        XCTAssertGreaterThan(layout.center(1, width: width).x, width / 2)
        XCTAssertLessThan(layout.center(3, width: width).x, width / 2)
    }

    func testNodesKeepAMarginOnNarrowScreens() {
        let width: CGFloat = 320
        for i in 0..<8 {
            let c = layout.center(i, width: width)
            XCTAssertGreaterThanOrEqual(c.x - layout.nodeSize / 2, 16, "node \(i) off the left edge")
            XCTAssertLessThanOrEqual(c.x + layout.nodeSize / 2, width - 16, "node \(i) off the right edge")
        }
    }

    func testContentHeightGrowsByOneStridePerNode() {
        XCTAssertEqual(layout.contentHeight(count: 0), 0)
        XCTAssertEqual(layout.contentHeight(count: 1), layout.nodeSize + DuoTokens.Edge.node)
        for n in 1..<7 {
            XCTAssertEqual(layout.contentHeight(count: n + 1) - layout.contentHeight(count: n), layout.stride)
        }
        XCTAssertEqual(layout.sectionHeight(count: 0), 0)
        XCTAssertEqual(layout.sectionHeight(count: 3), layout.topInset + layout.contentHeight(count: 3) + layout.bottomInset)
    }

    // MARK: - Sticky header selection

    func testStickyPicksTheLastChapterScrolledPastTheThreshold() {
        let order = ["a", "b", "c"]
        XCTAssertNil(JourneyStickyModel.currentChapterId(order: order, tops: ["a": 40, "b": 400, "c": 800], threshold: -58))
        XCTAssertEqual(JourneyStickyModel.currentChapterId(order: order, tops: ["a": -100, "b": 300, "c": 700], threshold: -58), "a")
        XCTAssertEqual(JourneyStickyModel.currentChapterId(order: order, tops: ["a": -900, "b": -200, "c": 300], threshold: -58), "b")
        XCTAssertEqual(JourneyStickyModel.currentChapterId(order: order, tops: ["c": -10, "b": -700, "a": -1400], threshold: -58), "b",
                       "dictionary order must not matter; c is still above the threshold")
        XCTAssertNil(JourneyStickyModel.currentChapterId(order: order, tops: [:], threshold: -58), "unmeasured chapters never stick")
    }
}
