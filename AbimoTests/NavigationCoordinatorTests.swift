//
//  NavigationCoordinatorTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

@MainActor
final class NavigationCoordinatorTests: XCTestCase {

    // MARK: - Helpers

    private func makeVoiceNote() -> VoiceNote {
        VoiceNote(
            id: UUID(),
            userId: UUID(),
            title: "Test Idea",
            audioFileURL: "https://example.com/audio.m4a",
            duration: 10.0,
            createdAt: Date(),
            updatedAt: Date(),
            transcriptionId: nil,
            analysisId: nil
        )
    }

    // MARK: - Tests

    func testInitialSelectedTabIsIdeas() async {
        let coordinator = NavigationCoordinator()
        XCTAssertEqual(coordinator.selectedTab, .ideas,
                       "NavigationCoordinator must initialize with selectedTab == .ideas")
    }

    func testInitialPendingNoteIsNil() async {
        let coordinator = NavigationCoordinator()
        XCTAssertNil(coordinator.pendingNote,
                     "NavigationCoordinator must initialize with pendingNote == nil")
    }

    func testSettingSelectedTabUpdatesPublishedValue() async {
        let coordinator = NavigationCoordinator()
        coordinator.selectedTab = .record
        XCTAssertEqual(coordinator.selectedTab, .record,
                       "Setting selectedTab to .record must update the published value")
    }

    func testNavigateToNoteSetsSelectedTabAndPendingNote() async {
        let coordinator = NavigationCoordinator()
        let note = makeVoiceNote()

        coordinator.navigateToNote(note)

        XCTAssertEqual(coordinator.selectedTab, .ideas,
                       "navigateToNote must set selectedTab to .ideas")
        XCTAssertEqual(coordinator.pendingNote?.id, note.id,
                       "navigateToNote must set pendingNote to the given note")
    }

    func testClearingPendingNoteDoesNotChangeSelectedTab() async {
        let coordinator = NavigationCoordinator()
        coordinator.selectedTab = .record
        let note = makeVoiceNote()
        coordinator.pendingNote = note

        // Clear pendingNote
        coordinator.pendingNote = nil

        XCTAssertEqual(coordinator.selectedTab, .record,
                       "Clearing pendingNote must not change selectedTab")
        XCTAssertNil(coordinator.pendingNote,
                     "pendingNote must be nil after clearing")
    }

    func testPendingPlanGenerationDefaultsFalse() async {
        let coordinator = NavigationCoordinator()
        XCTAssertFalse(coordinator.pendingPlanGeneration,
                       "NavigationCoordinator must initialize with pendingPlanGeneration == false")
    }

    func testPendingPlanGenerationToggle() async {
        let coordinator = NavigationCoordinator()

        coordinator.pendingPlanGeneration = true
        XCTAssertTrue(coordinator.pendingPlanGeneration,
                      "pendingPlanGeneration must be true after setting to true")

        coordinator.pendingPlanGeneration = false
        XCTAssertFalse(coordinator.pendingPlanGeneration,
                       "pendingPlanGeneration must be false after setting to false")
    }
}
