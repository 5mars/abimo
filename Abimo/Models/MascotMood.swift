//
//  MascotMood.swift
//  Abimo
//

import Foundation

enum MascotMood: String, CaseIterable {
    case neutral
    case playful
    case grumpy
    case sassy

    /// Asset name for this mood. All resolve to MascotNeutral until mood-specific assets are created.
    var assetName: String {
        // TODO: Replace with mood-specific assets when available
        "MascotNeutral"
    }
}
