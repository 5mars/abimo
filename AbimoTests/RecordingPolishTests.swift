//
//  RecordingPolishTests.swift
//  AbimoTests
//

import XCTest
@testable import Abimo

final class RecordingPolishTests: XCTestCase {
    // MARK: - WAVE-01: Audio Level Normalization

    func testAudioLevelNormalization_speechRange() {
        // Speech at -30 dB should map to ~0.31 (pow(5/35, 0.6))
        let level30 = AudioRecordingService.normalizeAudioLevel(averagePower: -30.0)
        XCTAssertEqual(level30, 0.31, accuracy: 0.02)

        // Speech at -10 dB should map to ~0.82 (pow(25/35, 0.6))
        let level10 = AudioRecordingService.normalizeAudioLevel(averagePower: -10.0)
        XCTAssertEqual(level10, 0.82, accuracy: 0.02)
    }

    func testAudioLevelFloor_silenceClamps() {
        // Silence at -160 dB should clamp to 0.0
        let level = AudioRecordingService.normalizeAudioLevel(averagePower: -160.0)
        XCTAssertEqual(level, 0.0, accuracy: 0.001)
    }

    func testAudioLevelCeiling_loudInput() {
        // Maximum at 0 dB should give 1.0
        let level0 = AudioRecordingService.normalizeAudioLevel(averagePower: 0.0)
        XCTAssertEqual(level0, 1.0, accuracy: 0.001)

        // Near-max at -1 dB should give ~0.98
        let level1 = AudioRecordingService.normalizeAudioLevel(averagePower: -1.0)
        XCTAssertEqual(level1, 0.98, accuracy: 0.02)
    }
}
