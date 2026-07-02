//
//  MascotMood.swift
//  Abimo
//

import Foundation
import UIKit

enum MascotMood: String, CaseIterable {
    case neutral
    case playful
    case grumpy
    case sassy

    /// Asset name for this mood, falling back to MascotNeutral for any mood
    /// whose art hasn't been added to the asset catalog yet — moods can ship
    /// one image at a time.
    var assetName: String {
        let preferred: String
        switch self {
        case .neutral: preferred = "MascotNeutral"
        case .playful: preferred = "MascotPlayful"
        case .grumpy:  preferred = "MascotGrumpy"
        case .sassy:   preferred = "MascotSassy"
        }
        return UIImage(named: preferred) != nil ? preferred : "MascotNeutral"
    }

    /// The face the critic makes when delivering a given score.
    static func forVerdict(_ verdict: ScoreVerdict) -> MascotMood {
        switch verdict {
        case .burnt, .halfBaked:       return .grumpy
        case .needsSeasoning:          return .sassy
        case .simmering, .chefsKiss:   return .playful
        }
    }
}
