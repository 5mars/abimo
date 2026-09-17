//
//  PermissionsManager.swift
//  Abimo
//
//  Created by Claude on 2026-03-03.
//

import Foundation
import AVFoundation
import Combine
import UIKit

@MainActor
class PermissionsManager: ObservableObject {
    @Published var microphoneAuthorized = false
    @Published var microphoneDenied = false

    init() {
        checkPermissions()
    }

    func checkPermissions() {
        switch AVAudioSession.sharedInstance().recordPermission {
        case .granted:
            microphoneAuthorized = true
            microphoneDenied = false
        case .denied:
            microphoneAuthorized = false
            microphoneDenied = true
        case .undetermined:
            microphoneAuthorized = false
            microphoneDenied = false
        @unknown default:
            microphoneAuthorized = false
            microphoneDenied = false
        }
    }

    func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                Task { @MainActor in
                    self.microphoneAuthorized = granted
                    self.microphoneDenied = !granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
