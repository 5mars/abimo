//
//  SoundEngine.swift
//  Abimo
//

import AVFoundation

/// Celebration sounds, mirroring HapticEngine's fire-and-forget API.
/// Gated by the "sound_enabled" default (Settings toggle) and played through
/// an ambient-style session so the ringer switch is respected and background
/// music keeps playing. Never touches the session while recording owns it.
enum SoundEngine {

    enum Sound: String, CaseIterable {
        case pop      // action completed
        case chime    // milestone reached
        case fanfare  // plan completed
        case whoosh   // streak extended
    }

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "sound_enabled") as? Bool ?? true
    }

    private static var players: [Sound: AVAudioPlayer] = [:]

    /// Call from a view's .onAppear to pre-load the players.
    /// Safe to call multiple times.
    static func prepare() {
        for sound in Sound.allCases where players[sound] == nil {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "caf") else { continue }
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            players[sound] = player
        }
    }

    static func play(_ sound: Sound) {
        guard isEnabled else { return }
        configureSessionIfSafe()
        if players[sound] == nil { prepare() }
        guard let player = players[sound] else { return }
        player.currentTime = 0
        player.play()
    }

    static func pop()     { play(.pop) }
    static func chime()   { play(.chime) }
    static func fanfare() { play(.fanfare) }
    static func whoosh()  { play(.whoosh) }

    /// Switch to .ambient (silent-switch aware, mixes with music) unless the
    /// recorder or audio player currently owns the session with its own category.
    private static func configureSessionIfSafe() {
        let session = AVAudioSession.sharedInstance()
        guard session.category != .playAndRecord && session.category != .playback else { return }
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
    }
}
