//
//  AudioRecordingService.swift
//  Abimo
//
//  Created by Claude on 2026-03-03.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioRecordingService: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0.0

    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var levelTimer: Timer?
    private var currentFileURL: URL?

    override init() {
        super.init()
    }

    func startRecording() throws -> URL {
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .default)
        try audioSession.setActive(true)

        // Create file URL
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "recording_\(Date().timeIntervalSince1970).m4a"
        let fileURL = documentsPath.appendingPathComponent(fileName)
        currentFileURL = fileURL

        // Configure recording settings
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        // Create and start recorder
        audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.prepareToRecord()
        audioRecorder?.record()

        isRecording = true
        recordingDuration = 0

        // Start duration timer
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.recordingDuration += 0.1
            }
        }

        // Start level monitoring
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.audioRecorder?.updateMeters()
            let averagePower = self.audioRecorder?.averagePower(forChannel: 0) ?? -160
            // Convert to 0-1 range using calibrated normalization
            let normalized = Self.normalizeAudioLevel(averagePower: averagePower)
            Task { @MainActor in
                self.audioLevel = normalized
            }
        }

        return fileURL
    }

    func stopRecording() -> URL? {
        audioRecorder?.stop()
        timer?.invalidate()
        levelTimer?.invalidate()
        timer = nil
        levelTimer = nil
        isRecording = false
        audioLevel = 0.0

        let fileURL = currentFileURL
        currentFileURL = nil

        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)

        return fileURL
    }

    func cancelRecording() {
        if let url = stopRecording() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Normalizes AVAudioRecorder averagePower (dB) to a 0–1 visual level.
    /// Maps [-50, 0] dB linearly to [0.0, 1.0]. Values below -50 dB clamp to 0.
    nonisolated static func normalizeAudioLevel(averagePower: Float) -> Float {
        let floorDb: Float = -50.0
        let clamped = max(floorDb, min(0.0, averagePower))
        return (clamped - floorDb) / (-floorDb)
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        let milliseconds = Int((duration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%01d", minutes, seconds, milliseconds)
    }
}
