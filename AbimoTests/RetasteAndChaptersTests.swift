//
//  RetasteAndChaptersTests.swift
//  AbimoTests
//
//  Two invariants Plus depends on: a re-taste keeps the analysis row's id
//  (so action plans and history are never orphaned), and a plan's parts
//  (chapter 1, chapter 2, …) render in order on the journey.
//

import XCTest
@testable import Abimo

final class RetasteAndChaptersTests: XCTestCase {

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private func response(score: Int) throws -> SWOTAnalysisResponse {
        let json = """
        {"strengths":[{"id":"\(UUID().uuidString)","point":"Founder knows the trade","score":70,"category":"Team"}],
         "weaknesses":[],"opportunities":[],"threats":[],
         "viabilityScore":\(score),"marketContext":"small","summary":"re-judged",
         "marketInsights":{"market_size":null,"growth_rate":null,"trend_direction":"up","key_competitors":[],"comparables":[]},
         "scoringVersion":2,"verdictBand":"simmering"}
        """
        return try decoder.decode(SWOTAnalysisResponse.self, from: Data(json.utf8))
    }

    private func existing(score: Int) -> SWOTAnalysis {
        SWOTAnalysis(
            id: UUID(), transcriptionId: UUID(),
            strengths: [], weaknesses: [], opportunities: [], threats: [],
            summary: "first taste", createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            strengthItems: nil, weaknessItems: nil, opportunityItems: nil, threatItems: nil,
            viabilityScore: score, marketContext: nil, marketInsights: nil,
            dimensionScores: nil, scoreRationale: nil, fatalFlaw: nil, ideaVariants: nil
        )
    }

    // MARK: - Re-taste

    func testRetasteKeepsIdentityAndPushesOldScoreOntoHistory() throws {
        let before = existing(score: 46)
        let after = before.retasted(with: try response(score: 58), research: nil, reason: "retaste after 6 steps")

        XCTAssertEqual(after.id, before.id, "plans hang off this id — it must survive")
        XCTAssertEqual(after.transcriptionId, before.transcriptionId)
        XCTAssertEqual(after.createdAt, before.createdAt)
        XCTAssertEqual(after.viabilityScore, 58)
        XCTAssertEqual(after.previousScore, 46)
        XCTAssertEqual(after.scoreHistory?.count, 1)
        XCTAssertEqual(after.scoreHistory?.first?.reason, "retaste after 6 steps")
        XCTAssertEqual(after.retasteCount, 1)
        XCTAssertEqual(after.summary, "re-judged")
    }

    func testSecondRetasteAppendsToHistory() throws {
        let first = existing(score: 46).retasted(with: try response(score: 58), research: nil, reason: "r1")
        let second = first.retasted(with: try response(score: 61), research: nil, reason: "r2")

        XCTAssertEqual(second.scoreHistory?.map(\.score), [46, 58])
        XCTAssertEqual(second.previousScore, 58)
        XCTAssertEqual(second.retasteCount, 2)
    }

    func testHistoryRoundTripsThroughSnakeCaseKeys() throws {
        let after = existing(score: 40).retasted(with: try response(score: 52), research: nil, reason: "r")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(after)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(object["score_history"])
        XCTAssertEqual(object["retaste_count"] as? Int, 1)

        let back = try decoder.decode(SWOTAnalysis.self, from: data)
        XCTAssertEqual(back.previousScore, 40)
    }

    // MARK: - Chapters (plan parts)

    private func action(_ quadrant: String, chapter: Int? = nil, done: Bool = false) -> MicroAction {
        MicroAction(
            id: UUID(), actionPlanId: UUID(), text: "step", doneCriteria: "done",
            timeEstimateMinutes: 10, priority: 1, quadrant: quadrant, template: nil,
            actionType: nil, deepLinkData: nil, isCompleted: done, completedAt: nil,
            isCommitted: false, committedAt: nil, scheduledFor: nil,
            completionOutcome: nil, completionNote: nil, createdAt: Date(), chapter: chapter
        )
    }

    func testNilChapterReadsAsPartOne() {
        XCTAssertEqual(action("weakness").chapterNumber, 1)
        XCTAssertEqual(action("weakness", chapter: 3).chapterNumber, 3)
    }

    func testPartsRenderInOrderWithUniqueIds() {
        // Chapter 2 arrives appended after chapter 1, but even if the input
        // order were scrambled, parts must sort ascending.
        let actions = [
            action("weakness", chapter: 2), action("opportunity", chapter: 2),
            action("weakness", chapter: 1, done: true), action("opportunity", chapter: 1, done: true),
        ]
        let chapters = JourneyChapterBuilder.build(from: actions)

        XCTAssertEqual(chapters.map(\.part), [1, 1, 2, 2])
        XCTAssertEqual(Set(chapters.map(\.id)).count, chapters.count, "ids must stay unique across parts")
        XCTAssertTrue(chapters[0].isComplete && chapters[1].isComplete)
        XCTAssertFalse(chapters[2].isComplete)
    }

    func testSinglePartPlanIsUnchanged() {
        let actions = [action("weakness"), action("opportunity"), action("strength")]
        let chapters = JourneyChapterBuilder.build(from: actions)
        XCTAssertEqual(chapters.map(\.kind), [.fixWeakSpot, .proveDemand, .playYourEdge])
        XCTAssertTrue(chapters.allSatisfy { $0.part == 1 })
    }
}
