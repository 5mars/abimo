//
//  NodeBubbleModelTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

final class NodeBubbleModelTests: XCTestCase {

    func testActionsPerState() {
        XCTAssertEqual(NodeBubbleModel.actions(for: .next), [.start])
        XCTAssertEqual(NodeBubbleModel.actions(for: .locked), [], "locked steps can't be started or promoted")
        XCTAssertEqual(NodeBubbleModel.actions(for: .done), [.undo, .details])
    }

    func testFrameDropsBelowTheNodeAndClampsToMargins() {
        let container: CGFloat = 360
        let centred = NodeBubbleModel.frame(nodeRect: CGRect(x: 142, y: 200, width: 76, height: 76), containerWidth: container, height: 120)
        XCTAssertEqual(centred.minY, 276 + NodeBubbleModel.gap)
        XCTAssertEqual(centred.width, 300)
        XCTAssertEqual(centred.midX, 180, accuracy: 0.5)

        let left = NodeBubbleModel.frame(nodeRect: CGRect(x: 20, y: 0, width: 76, height: 76), containerWidth: container, height: 120)
        XCTAssertEqual(left.minX, NodeBubbleModel.margin)

        let right = NodeBubbleModel.frame(nodeRect: CGRect(x: 264, y: 0, width: 76, height: 76), containerWidth: container, height: 120)
        XCTAssertEqual(right.maxX, container - NodeBubbleModel.margin)

        let narrow = NodeBubbleModel.frame(nodeRect: CGRect(x: 100, y: 0, width: 76, height: 76), containerWidth: 300, height: 120)
        XCTAssertEqual(narrow.width, 300 - NodeBubbleModel.margin * 2)
    }

    // MARK: - Auto-scroll

    func testNoScrollWhenNodeAndBubbleFit() {
        // viewport 100…900, no sticky header; node at 300, bubble ends 500
        XCTAssertNil(NodeBubbleModel.autoScrollNodeTop(
            nodeTop: 300, bubbleBottom: 500, visibleTop: 100, visibleBottom: 900, obstructedTop: 100))
    }

    func testBubbleBelowFoldScrollsUpJustEnough() {
        // node at 780 (viewport y 680), bubble ends 930 → 42pt past the fold incl. padding
        let target = NodeBubbleModel.autoScrollNodeTop(
            nodeTop: 780, bubbleBottom: 930, visibleTop: 100, visibleBottom: 900, obstructedTop: 100)
        XCTAssertEqual(target ?? -1, 680 - 42, accuracy: 0.001)
    }

    func testNodeUnderStickyHeaderScrollsDown() {
        // sticky header covers 100…166; node top at 140 is hidden under it
        let target = NodeBubbleModel.autoScrollNodeTop(
            nodeTop: 140, bubbleBottom: 330, visibleTop: 100, visibleBottom: 900, obstructedTop: 166)
        XCTAssertEqual(target ?? -1, 66 + NodeBubbleModel.autoScrollPadding, accuracy: 0.001)
    }

    func testBubbleWinsWhenBothCannotFit() {
        // tiny viewport: bubble overflow takes priority over the header
        let target = NodeBubbleModel.autoScrollNodeTop(
            nodeTop: 200, bubbleBottom: 420, visibleTop: 100, visibleBottom: 300, obstructedTop: 166)
        XCTAssertEqual(target ?? 0, 100 - 132, accuracy: 0.001)
    }

    func testScrollAnchorSolvesForNodeTop() {
        // node 76 tall in an 800 viewport: top at 362 → centre exactly
        XCTAssertEqual(NodeBubbleModel.scrollAnchorY(nodeTop: 362, nodeSize: 76, viewportHeight: 800), 0.5, accuracy: 0.001)
        XCTAssertEqual(NodeBubbleModel.scrollAnchorY(nodeTop: 0, nodeSize: 76, viewportHeight: 800), 0)
        XCTAssertEqual(NodeBubbleModel.scrollAnchorY(nodeTop: 5000, nodeSize: 76, viewportHeight: 800), 1)
    }
}
