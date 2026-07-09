//
//  SWOTAutoGenerateTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

@MainActor
final class SWOTAutoGenerateTests: XCTestCase {

    // MARK: - Helpers

    private func makeSWOTAnalysis() -> SWOTAnalysis {
        SWOTAnalysis(
            id: UUID(),
            transcriptionId: UUID(),
            strengths: [],
            weaknesses: [],
            opportunities: [],
            threats: [],
            summary: nil,
            createdAt: Date(),
            strengthItems: [],
            weaknessItems: [],
            opportunityItems: [],
            threatItems: [],
            viabilityScore: nil,
            marketContext: nil,
            marketInsights: nil,
            dimensionScores: nil,
            scoreRationale: nil,
            fatalFlaw: nil,
            ideaVariants: nil
        )
    }

    // MARK: - Tests

    func testShouldAutoGenerateWhenAnalysisNilAndNoError() async {
        XCTAssertTrue(
            SWOTAnalysisView.shouldAutoGenerate(analysis: nil, errorMessage: nil),
            "Should auto-generate when no analysis exists and no error has occurred"
        )
    }

    func testShouldNotAutoGenerateWhenAnalysisExists() async {
        let analysis = makeSWOTAnalysis()
        XCTAssertFalse(
            SWOTAnalysisView.shouldAutoGenerate(analysis: analysis, errorMessage: nil),
            "Should NOT auto-generate when a preloaded analysis already exists"
        )
    }

    func testShouldNotAutoGenerateWhenErrorPresent() async {
        XCTAssertFalse(
            SWOTAnalysisView.shouldAutoGenerate(analysis: nil, errorMessage: "Something went wrong"),
            "Should NOT auto-generate when an error message is present (avoid retry loops)"
        )
    }
}
