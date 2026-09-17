//
//  NodeIconCatalogTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

final class NodeIconCatalogTests: XCTestCase {

    private let kinds = JourneyChapterKind.allCases

    func testEveryKindHasFiveDistinctIconAssets() {
        for kind in kinds {
            let set = NodeIconCatalog.icons(for: kind)
            XCTAssertEqual(set.count, 5, "\(kind)")
            XCTAssertEqual(Set(set).count, 5, "\(kind) repeats an icon")
            XCTAssertTrue(set.allSatisfy { $0.hasPrefix("Icon") }, "\(kind) has a non-asset name")
            XCTAssertFalse(set.contains(NodeIconCatalog.trophy), "\(kind) must not use the trophy mid-chapter")
        }
    }

    func testNoIconIsSharedBetweenKinds() {
        var seen: [String: JourneyChapterKind] = [:]
        for kind in kinds {
            for name in NodeIconCatalog.icons(for: kind) {
                XCTAssertNil(seen[name], "\(name) used by both \(seen[name]!) and \(kind)")
                seen[name] = kind
            }
        }
    }

    func testChapterSequencesNeverRepeatNeighboursAndEndWithTheTrophy() {
        for kind in kinds {
            for count in 1...12 {
                let seq = (0..<count).map {
                    NodeIconCatalog.icon(for: kind, indexInChapter: $0, isLastInChapter: $0 == count - 1)
                }
                XCTAssertEqual(seq.last, NodeIconCatalog.trophy, "\(kind) x\(count)")
                XCTAssertFalse(seq.dropLast().contains(NodeIconCatalog.trophy), "\(kind) x\(count) trophy before the end")
                for (a, b) in zip(seq, seq.dropFirst()) {
                    XCTAssertNotEqual(a, b, "\(kind) x\(count) has adjacent repeats")
                }
            }
        }
    }

    func testActionLookupMatchesTheNodeAndFallsBackToSteps() {
        let a = action("weakness"), b = action("weakness"), c = action("opportunity")
        let chapters = JourneyChapterBuilder.build(from: [a, b, c])
        XCTAssertEqual(NodeIconCatalog.icon(for: a, in: chapters), NodeIconCatalog.icons(for: .fixWeakSpot)[0])
        XCTAssertEqual(NodeIconCatalog.icon(for: b, in: chapters), NodeIconCatalog.trophy, "last of its chapter")
        XCTAssertEqual(NodeIconCatalog.icon(for: c, in: chapters), NodeIconCatalog.trophy)

        let stranger = action("threat")
        XCTAssertEqual(NodeIconCatalog.icon(for: stranger, in: chapters), NodeIconCatalog.icons(for: .steps)[0])
    }

    private func action(_ quadrant: String) -> MicroAction {
        MicroAction(
            id: UUID(), actionPlanId: UUID(), text: "step", doneCriteria: "done",
            timeEstimateMinutes: 10, priority: 1, quadrant: quadrant, template: nil,
            actionType: nil, deepLinkData: nil, isCompleted: false, completedAt: nil,
            isCommitted: false, committedAt: nil, scheduledFor: nil,
            completionOutcome: nil, completionNote: nil, createdAt: Date()
        )
    }
}
