//
//  ScoreVerdict.swift
//  Abimo
//

import SwiftUI

/// Single source of truth for how a viability score reads across the app.
/// Scores are intentionally harsh (most fresh ideas land 20-45), so the
/// verdict copy stays playful while the number tells the truth.
enum ScoreVerdict: CaseIterable {
    case burnt          // 0-19
    case halfBaked      // 20-39
    case needsSeasoning // 40-59
    case simmering      // 60-79
    case chefsKiss      // 80-100

    init(score: Int) {
        switch score {
        case ..<20:   self = .burnt
        case 20..<40: self = .halfBaked
        case 40..<60: self = .needsSeasoning
        case 60..<80: self = .simmering
        default:      self = .chefsKiss
        }
    }

    var label: String {
        switch self {
        case .burnt:          return "Burnt"
        case .halfBaked:      return "Half-Baked"
        case .needsSeasoning: return "Needs Seasoning"
        case .simmering:      return "Simmering"
        case .chefsKiss:      return "Chef's Kiss"
        }
    }

    var emoji: String {
        switch self {
        case .burnt:          return "🔥"
        case .halfBaked:      return "🥧"
        case .needsSeasoning: return "🧂"
        case .simmering:      return "🍲"
        case .chefsKiss:      return "🤌"
        }
    }

    var color: Color {
        switch self {
        case .burnt:          return .brandRed
        case .halfBaked:      return .brandOrange
        case .needsSeasoning: return .brandAmber
        case .simmering:      return .brandBlue
        case .chefsKiss:      return .brandGreen
        }
    }

    var caption: String {
        switch self {
        case .burnt:          return "The critic sent it back. Good news: the kitchen's still open."
        case .halfBaked:      return "There's something under the crust — it needs more time in the oven."
        case .needsSeasoning: return "Edible! But nobody's ordering seconds yet."
        case .simmering:      return "Smells promising. Time to see if anyone would pay for a plate."
        case .chefsKiss:      return "The critic went back for thirds. Move fast."
        }
    }
}
