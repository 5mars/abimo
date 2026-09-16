//
//  DailyLoopStateTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

final class DailyLoopStateTests: XCTestCase {

    private func note(analysisId: UUID? = nil, daysAgo: Int = 0, title: String = "Idea") -> VoiceNote {
        let created = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return VoiceNote(id: UUID(), userId: UUID(), title: title, audioFileURL: "",
                         duration: 10, createdAt: created, updatedAt: created,
                         transcriptionId: nil, analysisId: analysisId)
    }

    private func plan(analysisId: UUID, daysAgo: Int = 0) -> ActionPlan {
        let created = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        return ActionPlan(id: UUID(), analysisId: analysisId, userId: UUID(), title: "p",
                          summary: "s", totalEstimateMinutes: 30, createdAt: created)
    }

    private func action(planId: UUID, done: Bool) -> MicroAction {
        MicroAction(id: UUID(), actionPlanId: planId, text: "t", doneCriteria: "d",
                    timeEstimateMinutes: 10, priority: 0, quadrant: nil, template: nil,
                    actionType: nil, deepLinkData: nil, isCompleted: done,
                    completedAt: done ? Date() : nil, isCommitted: false, committedAt: nil,
                    scheduledFor: nil, completionOutcome: nil, completionNote: nil, createdAt: Date())
    }

    private func resolve(notes: [VoiceNote] = [], plans: [ActionPlan] = [],
                         actions: [UUID: [MicroAction]] = [:],
                         cooking: Bool = false, pending: Bool = false, failed: Bool = false) -> DailyLoopState {
        DailyLoopState.resolve(notes: notes, plans: plans, actionsByPlan: actions,
                               pipelineCooking: cooking, planGenerationPending: pending,
                               planGenerationFailed: failed)
    }

    func testNoIdeas() {
        XCTAssertEqual(resolve(), .noIdeas)
    }

    func testFailureBeatsEverything() {
        let a = UUID(); let p = plan(analysisId: a)
        let state = resolve(notes: [note(analysisId: a)], plans: [p],
                            actions: [p.id: [action(planId: p.id, done: false)]], failed: true)
        XCTAssertEqual(state, .planFailed)
    }

    func testCookingBeatsActivePlan() {
        let a = UUID(); let p = plan(analysisId: a)
        XCTAssertEqual(resolve(plans: [p], actions: [p.id: [action(planId: p.id, done: false)]], cooking: true), .planCooking)
        XCTAssertEqual(resolve(plans: [p], actions: [p.id: [action(planId: p.id, done: false)]], pending: true), .planCooking)
    }

    func testActivePlanPrefersNewestWithOpenSteps() {
        let a1 = UUID(), a2 = UUID()
        let old = plan(analysisId: a1, daysAgo: 5), new = plan(analysisId: a2, daysAgo: 1)
        let state = resolve(plans: [old, new], actions: [
            old.id: [action(planId: old.id, done: false)],
            new.id: [action(planId: new.id, done: false)],
        ])
        XCTAssertEqual(state, .activePlan(planId: new.id, analysisId: a2))
    }

    func testActivePlanBeatsUntastedIdea() {
        let a = UUID(); let p = plan(analysisId: a)
        let state = resolve(notes: [note(), note(analysisId: a)], plans: [p],
                            actions: [p.id: [action(planId: p.id, done: false)]])
        if case .activePlan = state {} else { XCTFail("expected activePlan, got \(state)") }
    }

    func testUntastedIdeaWhenNoLivePlan() {
        let raw = note(title: "Raw")
        if case .ideaUntasted(let id, let title) = resolve(notes: [raw]) {
            XCTAssertEqual(id, raw.id); XCTAssertEqual(title, "Raw")
        } else { XCTFail() }
    }

    func testPlanMissingForAnalyzedNoteWithoutPlan() {
        let a = UUID()
        if case .planMissing(_, _, let analysisId) = resolve(notes: [note(analysisId: a)]) {
            XCTAssertEqual(analysisId, a)
        } else { XCTFail() }
    }

    func testAllChaptersDoneWhenEveryPlanIsFinished() {
        let a = UUID(); let p = plan(analysisId: a)
        let state = resolve(notes: [note(analysisId: a)], plans: [p],
                            actions: [p.id: [action(planId: p.id, done: true), action(planId: p.id, done: true)]])
        XCTAssertEqual(state, .allChaptersDone(planId: p.id, analysisId: a))
    }

    func testAnalyticsNamesAreStable() {
        XCTAssertEqual(DailyLoopState.noIdeas.analyticsName, "no_ideas")
        XCTAssertEqual(DailyLoopState.planCooking.analyticsName, "plan_cooking")
    }
}
