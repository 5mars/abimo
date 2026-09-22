//
//  ChapterBrief.swift
//  Abimo
//
//  Chapters 2-5 are written for one specific founder. Before each one the
//  app asks four things — how technical they are, how much time, how much
//  money, and what they're in it for — and hands the answers to the server
//  with the request. This file is the brief, the fixed ladder the chapters
//  climb, and the server's error vocabulary. Mirrors _shared/chapters.ts.
//

import SwiftUI
import Supabase

// MARK: - Brief

struct ChapterBrief: Codable, Equatable {
    enum TechSkill: String, Codable, CaseIterable, Identifiable {
        case none, noCode = "no_code", canCode = "can_code"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .none:    return "I don't code"
            case .noCode:  return "No-code tools"
            case .canCode: return "I can code"
            }
        }
        var subtitle: String {
            switch self {
            case .none:    return "Steps use AI builders or a manual version"
            case .noCode:  return "Bubble, Glide, Zapier — that kind of thing"
            case .canCode: return "Real engineering steps are fair game"
            }
        }
    }

    enum Hours: String, Codable, CaseIterable, Identifiable {
        case few, evenings, fullTime = "full_time"
        var id: String { rawValue }
        var title: String {
            switch self {
            case .few:      return "A few hours a week"
            case .evenings: return "Evenings and weekends"
            case .fullTime: return "Full time"
            }
        }
        var subtitle: String {
            switch self {
            case .few:      return "Short steps, a month per chapter"
            case .evenings: return "Bigger steps, two or three weeks"
            case .fullTime: return "Half-day steps, one week"
            }
        }
    }

    enum Budget: String, Codable, CaseIterable, Identifiable {
        case zero, under500 = "under_500", under5k = "under_5k", more
        var id: String { rawValue }
        var title: String {
            switch self {
            case .zero:     return "$0"
            case .under500: return "Under $500"
            case .under5k:  return "Under $5,000"
            case .more:     return "More than that"
            }
        }
        var subtitle: String {
            switch self {
            case .zero:     return "Free tiers and sweat only"
            case .under500: return "Paid tools, a domain, a small ad test"
            case .under5k:  return "A freelancer for one piece, real ads"
            case .more:     return "Hiring help is on the table"
            }
        }
    }

    enum Goal: String, Codable, CaseIterable, Identifiable {
        case sideIncome = "side_income", quitJob = "quit_job", sellIt = "sell_it", curious
        var id: String { rawValue }
        var title: String {
            switch self {
            case .sideIncome: return "Side income"
            case .quitJob:    return "Quit my job"
            case .sellIt:     return "Build something sellable"
            case .curious:    return "Just curious"
            }
        }
        var subtitle: String {
            switch self {
            case .sideIncome: return "Fastest path to the first paying customers"
            case .quitJob:    return "Proof it's a real, repeatable business"
            case .sellIt:     return "Assets over services, everything measured"
            case .curious:    return "Cheap to reverse, learning first"
            }
        }
    }

    var techSkill: TechSkill
    var hoursPerWeek: Hours
    var budget: Budget
    var goal: Goal
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case techSkill = "tech_skill", hoursPerWeek = "hours_per_week", budget, goal, notes
    }

    static let `default` = ChapterBrief(techSkill: .none, hoursPerWeek: .evenings, budget: .zero, goal: .curious, notes: nil)
    static let maxNoteLength = 300
}

/// One stored brief (`chapter_briefs`), used to prefill the next sheet.
struct StoredChapterBrief: Decodable {
    let chapter: Int
    let techSkill: ChapterBrief.TechSkill
    let hoursPerWeek: ChapterBrief.Hours
    let budget: ChapterBrief.Budget
    let goal: ChapterBrief.Goal
    let notes: String?
    let title: String?
    let summary: String?

    enum CodingKeys: String, CodingKey {
        case chapter, techSkill = "tech_skill", hoursPerWeek = "hours_per_week", budget, goal, notes, title, summary
    }

    /// The answers alone — notes are per chapter, so they don't carry over.
    var brief: ChapterBrief {
        ChapterBrief(techSkill: techSkill, hoursPerWeek: hoursPerWeek, budget: budget, goal: goal, notes: nil)
    }
}

// MARK: - Ladder

/// The five chapters. One is the free taste; two to five are Plus, each
/// with a fixed theme and its own colour so the path visibly changes ground.
enum ChapterLadder {
    static let maxChapters = 5

    struct Rung {
        let number: Int
        let title: String
        let subtitle: String
        let icon: String
        let face: Color
        let edge: Color
        /// Soft band behind the chapter's section of the path.
        var band: Color { face.opacity(0.10) }
        var eyebrowTag: String {
            switch number {
            case 2: return "PROVE"
            case 3: return "BUILD"
            case 4: return "USERS"
            case 5: return "MONEY"
            default: return "TASTE"
            }
        }
    }

    static func rung(_ chapter: Int) -> Rung? {
        switch chapter {
        case 2: return Rung(number: 2, title: "Prove people care",
                            subtitle: "Go where the buyers already are and come back with a number.",
                            icon: "person.2.wave.2.fill", face: .chapterPlum, edge: .chapterPlumEdge)
        case 3: return Rung(number: 3, title: "Build the smallest real version",
                            subtitle: "The thinnest thing a stranger can actually use — with tools that fit you.",
                            icon: "hammer.fill", face: .brandBlue, edge: .brandBlueDark)
        case 4: return Rung(number: 4, title: "First real users",
                            subtitle: "Five to ten people using it, watched closely, fixed fast.",
                            icon: "person.3.fill", face: .brandOrange, edge: .brandCaramel)
        case 5: return Rung(number: 5, title: "Money and the call",
                            subtitle: "Charge for it, launch it, then decide: go, pivot, or stop.",
                            icon: "banknote.fill", face: .chapterSage, edge: .chapterSageEdge)
        default: return nil
        }
    }

    static func isFinal(_ partCount: Int) -> Bool { partCount >= maxChapters }
}

// MARK: - Errors

/// What the server actually said when a chapter couldn't be written, read
/// from the `code` field the edge function already sends — HTTP status alone
/// can't tell "finish this chapter first" from "that was the last one".
enum ChapterError: Equatable {
    case plusRequired
    case chapterOpen
    case finalChapter
    case rateLimited
    case briefRequired
    case other

    static func from(_ error: Error) -> ChapterError {
        guard case FunctionsError.httpError(let status, let data) = error else { return .other }
        let code = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["code"] as? String
        switch (status, code) {
        case (_, "plus_required"), (403, _): return .plusRequired
        case (_, "chapter_open"):            return .chapterOpen
        case (_, "final_chapter"):           return .finalChapter
        case (_, "brief_required"):          return .briefRequired
        case (_, "rate_limited"), (429, _):  return .rateLimited
        default:                             return .other
        }
    }

    /// Kitchen talk, not HTTP.
    var message: String {
        switch self {
        case .plusRequired:  return "That paddock is Plus-only. If you just subscribed, give the stable a minute to catch up."
        case .chapterOpen:   return "Finish every step on the path first — the critic writes the next chapter from what you did."
        case .finalChapter:  return "That was the last chapter. Re-taste the idea — or ship it."
        case .rateLimited:   return "Even Plus stallions rest. Back in the saddle tomorrow."
        case .briefRequired: return "The critic needs the four quick answers first."
        case .other:         return "The next chapter didn't saddle up. Try again in a moment."
        }
    }
}
