//
//  SWOTCourse.swift
//  Abimo
//
//  The Taste Test is served in courses: each SWOT quadrant becomes one
//  compact course card on the menu, opening a focused detail sheet.
//  This model is the single source of truth for quadrant theming and
//  item ordering, so card and sheet always agree on the "top item".
//

import SwiftUI

struct SWOTCourse: Identifiable {
    enum Kind: String, Identifiable, CaseIterable {
        case strengths, opportunities, weaknesses, threats

        var id: String { rawValue }

        var title: String {
            switch self {
            case .strengths:     return "The Wins"
            case .opportunities: return "Opportunities"
            case .weaknesses:    return "Weaknesses"
            case .threats:       return "Watch Out"
            }
        }

        /// Cooking-metaphor micro-caption above the title.
        var courseLabel: String {
            switch self {
            case .strengths:     return "The good stuff"
            case .opportunities: return "Room on the menu"
            case .weaknesses:    return "Needs seasoning"
            case .threats:       return "Kitchen hazards"
            }
        }

        var color: Color {
            switch self {
            case .strengths:     return .brandGreen
            case .opportunities: return .brandBlue
            case .weaknesses:    return .brand
            case .threats:       return .brandAmber
            }
        }

        var iconName: String {
            switch self {
            case .strengths:     return "checkmark.circle.fill"
            case .opportunities: return "arrow.up.circle.fill"
            case .weaknesses:    return "xmark.circle.fill"
            case .threats:       return "exclamationmark.triangle.fill"
            }
        }

        var emptyLine: String {
            switch self {
            case .strengths:     return "The critic found nothing to praise. Yet."
            case .opportunities: return "No openings spotted — tough market or thin brief."
            case .weaknesses:    return "Nothing here — that's a good sign"
            case .threats:       return "Nothing here — that's a good sign"
            }
        }
    }

    let kind: Kind
    /// Pre-sorted descending by score — index 0 is the free teaser item.
    let items: [SWOTItem]
    let avgScore: Double

    var id: String { kind.id }
    var topItem: SWOTItem? { items.first }
}

extension SWOTAnalysis {
    var courses: [SWOTCourse] {
        [
            SWOTCourse(kind: .strengths,
                       items: resolvedStrengths.sorted { $0.score > $1.score },
                       avgScore: avgStrengthScore),
            SWOTCourse(kind: .opportunities,
                       items: resolvedOpportunities.sorted { $0.score > $1.score },
                       avgScore: avgOpportunityScore),
            SWOTCourse(kind: .weaknesses,
                       items: resolvedWeaknesses.sorted { $0.score > $1.score },
                       avgScore: avgWeaknessScore),
            SWOTCourse(kind: .threats,
                       items: resolvedThreats.sorted { $0.score > $1.score },
                       avgScore: avgThreatScore),
        ]
    }
}

// MARK: - Critic's Verdict (the TL;DR)

struct CriticsVerdictCard: View {
    let summary: String?
    let verdict: ScoreVerdict

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "text.quote")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(verdict.color)
                Text("The Critic's Verdict")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPri)
                Spacer()
            }

            Text(displayedSummary)
                .font(.duoBody)
                .foregroundColor(.textPri)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .duoInset()
        }
        .duoPanel()
    }

    private var displayedSummary: String {
        if let summary, !summary.isEmpty { return summary }
        // Legacy rows have no summary — keep the layout, keep the voice.
        return "The critic ate the tasting notes. The courses below still tell the story."
    }
}

#Preview {
    CriticsVerdictCard(
        summary: "A solid core idea with real demand behind it, but the moat is thin and two competitors already serve the hungriest customers.",
        verdict: .simmering
    )
    .padding()
    .background(Color.appBg)
}
