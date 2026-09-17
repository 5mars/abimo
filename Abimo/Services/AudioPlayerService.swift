//
//  AudioPlayerService.swift
//  Abimo
//
//  Created by Claude on 2026-03-03.
//

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerService: NSObject, ObservableObject {
    @Published var isPlaying = false
    @Published var isLoading = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    var audioURL: URL?

    override init() {
        super.init()
    }

    func prepare(url: URL) async throws {
        isLoading = true
        defer { isLoading = false }

        audioURL = url

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)

        // Create audio player
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.prepareToPlay()
        duration = audioPlayer?.duration ?? 0
    }

    func play() {
        audioPlayer?.play()
        isPlaying = true
        startTimer()
        DareEngine.markPitchReplayed()   // "Listen back to one of your pitches"
    }

    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        progress = 0
        stopTimer()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.currentTime = self.audioPlayer?.currentTime ?? 0
                if self.duration > 0 {
                    self.progress = self.currentTime / self.duration
                }

                // Auto-stop at end
                if self.currentTime >= self.duration && self.duration > 0 {
                    self.stop()
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    deinit {
        // Clean up synchronously without MainActor
        timer?.invalidate()
        audioPlayer?.stop()
    }
}
