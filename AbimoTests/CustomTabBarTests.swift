//
//  CustomTabBarTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

@MainActor
final class CustomTabBarTests: XCTestCase {

    // MARK: - AppTab.allCases Order

    func testAllCasesOrderIsIdeasRecordActionsProfile() {
        let cases = AppTab.allCases
        XCTAssertEqual(cases.count, 4,
                       "AppTab must have exactly 4 cases")
        XCTAssertEqual(cases[0], .ideas,
                       "First tab must be .ideas (rawValue 0)")
        XCTAssertEqual(cases[1], .record,
                       "Second tab must be .record (rawValue 1)")
        XCTAssertEqual(cases[2], .actions,
                       "Third tab must be .actions (rawValue 2)")
        XCTAssertEqual(cases[3], .profile,
                       "Fourth tab must be .profile (rawValue 3)")
    }

    func testRawValuesAreSequential() {
        XCTAssertEqual(AppTab.ideas.rawValue, 0)
        XCTAssertEqual(AppTab.record.rawValue, 1)
        XCTAssertEqual(AppTab.actions.rawValue, 2)
        XCTAssertEqual(AppTab.profile.rawValue, 3)
    }

    // MARK: - AppTab.iconName Mapping

    func testIconNameForIdeas() {
        XCTAssertEqual(AppTab.ideas.iconName, "lightbulb",
                       "Ideas tab icon must be 'lightbulb'")
    }

    func testIconNameForRecord() {
        XCTAssertEqual(AppTab.record.iconName, "mic",
                       "Record tab icon must be 'mic'")
    }

    func testIconNameForActions() {
        XCTAssertEqual(AppTab.actions.iconName, "bolt",
                       "Actions tab icon must be 'bolt'")
    }

    func testIconNameForProfile() {
        XCTAssertEqual(AppTab.profile.iconName, "person",
                       "Profile tab icon must be 'person'")
    }

    // MARK: - AppTab.selectedIconName Mapping

    func testSelectedIconNameForIdeas() {
        XCTAssertEqual(AppTab.ideas.selectedIconName, "lightbulb.fill",
                       "Ideas selected icon must be 'lightbulb.fill'")
    }

    func testSelectedIconNameForRecord() {
        XCTAssertEqual(AppTab.record.selectedIconName, "mic.fill",
                       "Record selected icon must be 'mic.fill'")
    }

    func testSelectedIconNameForActions() {
        XCTAssertEqual(AppTab.actions.selectedIconName, "bolt.fill",
                       "Actions selected icon must be 'bolt.fill'")
    }

    func testSelectedIconNameForProfile() {
        XCTAssertEqual(AppTab.profile.selectedIconName, "person.fill",
                       "Profile selected icon must be 'person.fill'")
    }

    // MARK: - No .notes Case

    func testNoNotesCase() {
        let allCaseNames = AppTab.allCases.map { "\($0)" }
        XCTAssertFalse(allCaseNames.contains("notes"),
                       "AppTab must not have a .notes case — it has been renamed to .ideas")
        XCTAssertTrue(allCaseNames.contains("ideas"),
                      "AppTab must have an .ideas case")
    }

    // MARK: - Default Tab

    func testDefaultTabIsIdeas() async {
        let coordinator = NavigationCoordinator()
        XCTAssertEqual(coordinator.selectedTab, .ideas,
                       "NavigationCoordinator must default selectedTab to .ideas")
    }
}
