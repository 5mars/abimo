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

// MARK: - Scoring v2 decoding

/// The edge function's v2 response and the swot_analyses row both carry the
/// scoring receipt; older rows carry none of it and must still decode.
final class ScoringV2DecodingTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    func testLegacyRowDecodesWithNilReceipt() throws {
        let json = """
        {"id":"\(UUID().uuidString)","transcription_id":"\(UUID().uuidString)",
         "strengths":[],"weaknesses":[],"opportunities":[],"threats":[],
         "summary":"old","created_at":"2026-07-08T12:00:00Z","viability_score":58,
         "dimension_scores":{"problemSeverity":6,"demandEvidence":5,"marketQuality":5,"feasibility":6,"differentiation":5}}
        """
        let row = try decoder.decode(SWOTAnalysis.self, from: Data(json.utf8))
        XCTAssertEqual(row.viabilityScore, 58)
        XCTAssertNil(row.scoreMeta)
        XCTAssertNil(row.dimensionEvidence)
        XCTAssertTrue(row.isLegacyScoring)
    }

    func testScoreMetaDecodesCapsAndAdjustments() throws {
        let json = """
        {"version":2,"weights":{"problemSeverity":0.2,"demandEvidence":0.25,"marketQuality":0.2,"feasibility":0.1,"differentiation":0.25},
         "rawDims":{"problemSeverity":6,"demandEvidence":6,"marketQuality":6,"feasibility":6,"differentiation":6},
         "cappedDims":{"problemSeverity":6,"demandEvidence":4,"marketQuality":5,"feasibility":6,"differentiation":6},
         "wm":5.3,"gate":1,"demandFactor":1,"raw":5.3,"mapped":54.4,
         "caps":[{"dim":"demandEvidence","from":6,"to":4,"reason":"unverified: no market research for this run"},
                 {"dim":"marketQuality","from":6,"to":5,"reason":"unverified: no market research for this run"}],
         "adjustments":[{"kind":"hedged","delta":-4,"reason":"every dimension sat in 4-6"}],
         "hedged":true,"verdictBand":"needs_seasoning","computedBand":"needs_seasoning","bandMismatch":false,"evidenceStrength":"none"}
        """
        let meta = try decoder.decode(ScoreMeta.self, from: Data(json.utf8))
        XCTAssertEqual(meta.version, 2)
        XCTAssertEqual(meta.cap(for: .demandEvidence)?.to, 4)
        XCTAssertEqual(meta.cap(for: .demandEvidence)?.from, 6)
        XCTAssertNil(meta.cap(for: .feasibility))
        XCTAssertEqual(meta.weight(for: .differentiation), 0.25)
        XCTAssertEqual(meta.hedged, true)
        XCTAssertEqual(meta.adjustments?.first?.delta, -4)
        XCTAssertEqual(meta.cappedDims?.value(for: .demandEvidence), 4)
    }

    func testResearchDigestDecodesLegacyAndV2Shapes() throws {
        let legacy = """
        {"comparables":[{"name":"X","what":"w","pricing":"$9/mo","status":"solo","url":""}],"niche_notes":"n","demand_signals":["s"]}
        """
        let old = try decoder.decode(ResearchDigest.self, from: Data(legacy.utf8))
        XCTAssertNil(old.market)
        XCTAssertNil(old.comparables.first?.priceAmount)
        XCTAssertFalse(old.isEmpty)

        let v2 = """
        {"comparables":[{"name":"X","what":"w","pricing":"$9/mo","status":"solo","url":"https://x.com",
           "price_amount":9,"price_currency":"USD","price_period":"month","charges_money":"yes","size":"solo",
           "user_count_hint":1200,"user_count_source":"site","last_active":"2025_or_later"}],
         "niche_notes":"n","demand_signals":["s"],
         "signals":[{"text":"t","url":"","source_type":"reddit","direction":"negative","strength":"strong","recency":"2025_or_later","count_hint":40}],
         "market":{"paid_comparables_found":1,"free_alternatives_dominate":"no","saturation":"sparse","small_players_making_money":"yes",
           "giant_blocks_niche":"no","giant_name":"","typical_price_low":9,"typical_price_high":9,"price_currency":"USD","search_quality":"ok","queries_run":["x app"]}}
        """
        let new = try decoder.decode(ResearchDigest.self, from: Data(v2.utf8))
        XCTAssertEqual(new.market?.paidComparablesFound, 1)
        XCTAssertEqual(new.comparables.first?.priceAmount, 9)
        XCTAssertEqual(new.comparables.first?.chargesMoney, "yes")
        XCTAssertEqual(new.signals?.first?.direction, "negative")
        XCTAssertEqual(new.market?.queriesRun, ["x app"])
    }

    func testRubricHasANextStepForEveryDimensionAndScore() {
        for key in DimensionKey.allCases {
            for score in 0...10 {
                XCTAssertFalse(DimensionRubric.nextStep(for: key, score: score).isEmpty, "\(key) \(score)")
            }
        }
        XCTAssertEqual(DimensionRubric.weightLabel(0.25), "×.25")
        XCTAssertNil(DimensionRubric.weightLabel(nil))
        XCTAssertNotNil(DimensionRubric.evidenceStrengthCopy("none"))
        XCTAssertNil(DimensionRubric.evidenceStrengthCopy(nil))
    }
}
