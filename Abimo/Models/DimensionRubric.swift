//
//  DimensionRubric.swift
//  Abimo
//
//  "What would raise this" — the next rubric row for each dimension,
//  rewritten as an instruction the founder can act on. Mirrors the rubric in
//  supabase/functions/analyze-swot/index.ts; keep the two in step.
//

import Foundation

enum DimensionRubric {

    /// One sentence on how to climb from `score` to the next row.
    static func nextStep(for key: DimensionKey, score: Int) -> String {
        switch key {
        case .problemSeverity:
            switch score {
            case ..<3:  return "Find a specific person with a specific pain — right now this reads as a solution looking for a problem."
            case 3...4: return "Show it costs people something today: time, money, or embarrassment. 'Mildly annoying' doesn't move the number."
            case 5...6: return "Prove people already pay or spend real hours on this. Severity 7+ needs visible spend, not complaints."
            case 7...8: return "Only desperate, underserved sufferers push this higher — name who they are and why nothing serves them."
            default:    return "Maxed. The problem is real; the other dimensions decide the score."
            }
        case .demandEvidence:
            switch score {
            case ..<3:  return "Right now this is a guess. Point at one small product people already pay for, or your own lived experience."
            case 3...4: return "To reach 5-6: cite an analogous small product that sells, or a problem you personally fight every week."
            case 5...6: return "To reach 7-8: the scout needs two small players charging real money — or you bring numbers (a poll, a waitlist)."
            case 7...8: return "9-10 is reserved for money on the table: pre-payments, revenue, or a 50+ waitlist."
            default:    return "Maxed. Demand is proven; ship."
            }
        case .marketQuality:
            switch score {
            case ..<3:  return "This niche is tiny, shrinking, or served for free. Pick a sharper corner where someone already pays."
            case 3...4: return "Crowded or dominated. The only way up is a narrower sub-niche with a visible gap a small player can fill."
            case 5...6: return "To reach 7-8: show a small player already making a living here — with a price and signs of customers."
            case 7...8: return "9-10 needs an obvious opening right now: a reachable, hungry niche nobody serves well."
            default:    return "Maxed. The niche is open; go take it."
            }
        case .feasibility:
            switch score {
            case ..<3:  return "As described this needs approvals, hardware, or deep pockets. Find the version a solo founder can test."
            case 3...4: return "Needs a team or funding just to test. What's the manual, no-code version you could run this month?"
            case 5...6: return "Buildable — but where do the first 100 customers come from? Name one channel you already have."
            case 7...8: return "To hit 9-10: describe how you'd validate it this weekend with zero code."
            default:    return "Maxed. Nothing is stopping you but the calendar."
            }
        case .differentiation:
            switch score {
            case ..<3:  return "A clone. Name the one thing an existing product can't copy in a sprint."
            case 3...4: return "A twist competitors could ship next week. Aim at an audience they ignore or a wedge they can't afford."
            case 5...6: return "Meaningful angle, not defensible. What compounds — owned distribution, data, a community?"
            case 7...8: return "9-10 is a genuinely novel insight or an unfair advantage only you have."
            default:    return "Maxed. This is the idea's edge; protect it."
            }
        }
    }

    /// The evidence-strength pill copy above the breakdown (scoring v2).
    static func evidenceStrengthCopy(_ strength: String?) -> (icon: String, text: String)? {
        switch strength {
        case "none": return ("magnifyingglass", "Unverified — the scout came back empty, so Demand and Market are capped at 5.")
        case "thin": return ("magnifyingglass", "Thin evidence — the scout found almost nothing relevant; Demand and Market are capped.")
        case "ok":   return ("checkmark.magnifyingglass", "Grounded — real comparables and prices from live web search.")
        case "rich": return ("checkmark.seal", "Well grounded — several real players, prices, and signals from live web search.")
        default:     return nil
        }
    }

    static func weightLabel(_ weight: Double?) -> String? {
        guard let weight else { return nil }
        return "×\(String(format: "%.2f", weight).replacingOccurrences(of: "0.", with: "."))"
    }
}
