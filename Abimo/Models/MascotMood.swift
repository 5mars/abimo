//
//  MascotMood.swift
//  Abimo
//
//  Two layers, deliberately separate:
//    - MascotExpression: WHAT THE PICTURE SHOWS — one case per sprite in the
//      asset catalog (pose + face). Adding art = add a case + an imageset
//      named "Mascot<Case>" (MascotNeutral, MascotThumbsUp, ...).
//    - MascotMood: the critic's TONE OF VOICE (drives MascotVoice line pools).
//      `MascotMood.expression` below is THE table that decides which pose
//      carries each tone — reassign there, nothing else needs to change.
//  Screens that want a specific pose regardless of tone (a bored critic
//  waiting on a loading screen) pass an expression to MascotView directly.
//

import Foundation
import UIKit

// MARK: - Expression (art)

enum MascotExpression: String, CaseIterable {
    case neutral    // standing, half-lidded, flat mouth — the resting critic
    case grumpy     // arms crossed, scowl
    case thumbsUp   // smug approval, one eye squinted
    case sitting    // slumped on the floor, bored — waiting
    case waving     // eyes-closed grin, waving — delighted
    case crying     // tears, drooping — the critic actually feels it
    case shrug      // palms up, half-lidded — could go either way
    case sunglasses // aviators, deadpan — too cool to be impressed, is impressed
    case thumbsDown // one hoof down — nope
    case writing    // notepad and pen — taking notes, making the plan
    case cooking    // chef's hat at the stove — the critic at work

    /// Asset catalog name for this pose: "Mascot" + capitalized case name.
    var rawAssetName: String {
        "Mascot" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    /// Falls back to MascotNeutral for any pose whose art isn't in the
    /// catalog yet — expressions can ship one image at a time.
    var assetName: String {
        UIImage(named: rawAssetName) != nil ? rawAssetName : MascotExpression.neutral.rawAssetName
    }
}

// MARK: - Mood (voice)

enum MascotMood: String, CaseIterable {
    case neutral
    case playful
    case grumpy
    case sassy
    case sad        // burnt verdicts, failed cooks, lost streaks
    case meh        // "needs seasoning" — a shrug
    case nope       // "half-baked" — thumbs down
    case cool       // chef's kiss, big streaks — sunglasses on

    /// Which pose carries each tone of voice. Edit here to move an emotion.
    var expression: MascotExpression {
        switch self {
        case .neutral: return .neutral
        case .grumpy:  return .grumpy
        case .sassy:   return .thumbsUp
        case .playful: return .waving
        case .sad:     return .crying
        case .meh:     return .shrug
        case .nope:    return .thumbsDown
        case .cool:    return .sunglasses
        }
    }

    /// Asset name for this mood's pose (with the missing-art fallback).
    var assetName: String { expression.assetName }

    /// The face the critic makes when delivering a given score.
    static func forVerdict(_ verdict: ScoreVerdict) -> MascotMood {
        switch verdict {
        case .burnt:                   return .sad
        case .halfBaked:               return .nope
        case .needsSeasoning:          return .meh
        case .simmering:               return .sassy
        case .chefsKiss:               return .cool
        }
    }
}
