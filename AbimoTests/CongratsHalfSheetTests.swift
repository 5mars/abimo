//
//  CongratsHalfSheetTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

@MainActor
final class CongratsHalfSheetTests: XCTestCase {

    // The congrats copy moved from a static pool on the sheet to MascotVoice
    // (the in-app critic voice). These verify the same guarantees there.

    func testActionCompletedMomentsAreNeverEmpty() {
        for count in [1, 3, 5, 7] {
            let moment = MascotVoice.moment(for: .actionCompleted(count: count))
            XCTAssertFalse(moment.line.isEmpty,
                           "actionCompleted moment must always produce a line")
        }
    }

    func testActionCompletedCountTemplateIsFilled() {
        for _ in 0..<20 {
            let moment = MascotVoice.moment(for: .actionCompleted(count: 4))
            XCTAssertFalse(moment.line.contains("{count}"),
                           "Templated {count} must be substituted: '\(moment.line)'")
        }
    }

    func testEveryVerdictHasAScoreRevealLine() {
        for verdict in ScoreVerdict.allCases {
            let moment = MascotVoice.moment(for: .scoreRevealed(verdict: verdict))
            XCTAssertFalse(moment.line.isEmpty,
                           "scoreRevealed moment must produce a line for \(verdict)")
        }
    }

    func testSheetPhaseEnumHasBothCases() {
        let congrats = SheetPhase.congrats
        let picker = SheetPhase.picker
        XCTAssertNotEqual(String(describing: congrats), String(describing: picker),
                          "SheetPhase must have distinct congrats and picker cases")
    }
}
