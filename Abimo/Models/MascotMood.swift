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
    // Sept 2026 set — one pose per scenario, all in the passive-aggressive
    // critic register: impressed only grudgingly, quietly expecting a flop.
    case listening   // sitting, arms crossed, one ear turned — bracing for the pitch
    case searching   // magnifying glass, one huge suspicious eye — scouting the market
    case tasting     // spoon to the lips, eyes shut, doubtful pucker — judging
    case chefKiss    // reluctant chef's kiss, eyes rolled away — "fine. it's good."
    case spitTake    // spoon of smoking char held at arm's length, tongue out — burnt
    case seasoning   // salt shaker held high, nose up — "it needed this, clearly"
    case pointing    // points sideways without looking — "obviously, it's right there"
    case trophy      // trophy dangling at the hip, other hoof mid slow-clap
    case sleeping    // sprawled, yawning, one "z" — nothing here to judge
    case tapping     // glaring at a wristwatch, hoof tapping — waiting on you
    case facepalm    // hoof dragged down the face — "of course this happened"
    case flame       // streak torch held like a chore, sunglasses sliding down
    case worried     // sipping tea, side-eye smirk — hoping the streak breaks
    case horseshoe   // flipping a gold horseshoe, not watching — here's your XP
    case medal       // medal held out at arm's length, looking away — "take it."
    case dare        // hoof under chin, eyebrow up — "I bet you won't"
    case gallop      // side view, nose in the air — acting like it was his idea
    case flex        // hoof on chest, sarcastic "o" — "well, well, well"
    case shocked     // genuinely caught off guard, hoof rising to hide it
    case vip         // crooked crown, gold cushion, golden ticket — members only
    case bowtie      // teal bow tie, stiff maître d' bow, one eye peeking
    case doorman     // leaning on the stable half-door, sizing you up
    case sign        // blank wooden sign, flat stare — "stable's full"
    case stopwatch   // stopwatch held up — "and that's time."
    case receipt     // long receipt, half-moon glasses — tallying the evidence
    case welcomeBack // arms crossed, side glance — "oh, look who remembered"

    /// Asset catalog name for this pose: "Mascot" + capitalized case name.
    var rawAssetName: String {
        "Mascot" + rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    /// Falls back to MascotNeutral for any pose whose art isn't in the
    /// catalog yet — expressions can ship one image at a time.
    var assetName: String {
        UIImage(named: rawAssetName) != nil ? rawAssetName : MascotExpression.neutral.rawAssetName
    }

    /// The critic's reaction to a score — used where the verdict itself is
    /// the picture (the share card), not just the tone of a line.
    static func forVerdict(_ verdict: ScoreVerdict) -> MascotExpression {
        switch verdict {
        case .burnt:          return .spitTake
        case .halfBaked:      return .thumbsDown
        case .needsSeasoning: return .seasoning
        case .simmering:      return .tasting
        case .chefsKiss:      return .chefKiss
        }
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
        case .meh:     return .seasoning
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
