//
//  NodeBubbleModelTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

final class NodeBubbleModelTests: XCTestCase {

    func testActionsPerState() {
        XCTAssertEqual(NodeBubbleModel.actions(for: .next), [.start])
        XCTAssertEqual(NodeBubbleModel.actions(for: .open), [.start, .pickAsNext])
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
}
