//
//  JourneyChapter.swift
//  Abimo
//
//  Chapters give the path a shape without touching the schema: actions are
//  grouped by the SWOT quadrant they serve, in the same order the plan
//  prompt already uses (weakness → opportunity → strength → threat). Pure
//  and unit-tested; the view is just a projection of `orderedActions`.
//

import SwiftUI

enum JourneyChapterKind: String, CaseIterable {
    case fixWeakSpot   // weakness
    case proveDemand   // opportunity
    case playYourEdge  // strength
    case watchRisks    // threat
    case steps         // fallback: no usable quadrant data
    case build         // a Plus chapter (2-5): one section, named by the ladder

    var title: String {
        switch self {
        case .fixWeakSpot:  return "Fix the weak spot"
        case .proveDemand:  return "Prove demand"
        case .playYourEdge: return "Play your edge"
        case .watchRisks:   return "Watch the risks"
        case .steps:        return "Your steps"
        case .build:        return "Next chapter"
        }
    }

    var color: Color {
        switch self {
        case .fixWeakSpot:  return .chapterPlum
        case .proveDemand:  return .chapterTeal
        case .playYourEdge: return .chapterGolden
        case .watchRisks:   return .chapterSage
        case .steps:        return .chapterTeal
        case .build:        return .chapterPlum
        }
    }

    var edgeColor: Color {
        switch self {
        case .fixWeakSpot:  return .chapterPlumEdge
        case .proveDemand:  return .chapterTealEdge
        case .playYourEdge: return .chapterGoldenEdge
        case .watchRisks:   return .chapterSageEdge
        case .steps:        return .chapterTealEdge
        case .build:        return .chapterPlumEdge
        }
    }

    var icon: String {
        switch self {
        case .fixWeakSpot:  return "bandage.fill"
        case .proveDemand:  return "person.2.wave.2.fill"
        case .playYourEdge: return "bolt.fill"
        case .watchRisks:   return "eye.fill"
        case .steps:        return "list.bullet"
        case .build:        return "hammer.fill"
        }
    }

    /// The plan prompt's quadrant vocabulary → chapter.
    init?(quadrant: String?) {
        switch quadrant?.lowercased() {
        case "weakness", "weaknesses":       self = .fixWeakSpot
        case "opportunity", "opportunities": self = .proveDemand
        case "strength", "strengths":        self = .playYourEdge
        case "threat", "threats":            self = .watchRisks
        default:                             return nil
        }
    }
}

struct JourneyChapter: Identifiable, Equatable {
    let kind: JourneyChapterKind
    let title: String
    let actions: [MicroAction]
    /// The plan chapter (`micro_actions.chapter`) these steps came from —
    /// 1 for the original plan, 2+ for Plus "next chapter" extensions.
    var part: Int = 1

    var id: String { "\(part)-\(kind.rawValue)" }
    /// The ladder rung for Plus chapters; nil for the free chapter.
    var rung: ChapterLadder.Rung? { part >= 2 ? ChapterLadder.rung(part) : nil }
    /// Banner colours: the rung's for chapters 2+, the quadrant's for chapter 1.
    var faceColor: Color { rung?.face ?? kind.color }
    var edgeColor: Color { rung?.edge ?? kind.edgeColor }
    var icon: String { rung?.icon ?? kind.icon }
    var completedCount: Int { actions.filter(\.isCompleted).count }
    var totalMinutes: Int { actions.reduce(0) { $0 + $1.timeEstimateMinutes } }
    var isComplete: Bool { !actions.isEmpty && actions.allSatisfy(\.isCompleted) }

    static func == (lhs: JourneyChapter, rhs: JourneyChapter) -> Bool {
        lhs.kind == rhs.kind && lhs.title == rhs.title && lhs.part == rhs.part
            && lhs.actions.map(\.id) == rhs.actions.map(\.id)
    }
}

enum JourneyChapterBuilder {
    private static let order: [JourneyChapterKind] = [.fixWeakSpot, .proveDemand, .playYourEdge, .watchRisks]

    /// Groups `actions` (already in display order) into chapters. Steps are
    /// first split by plan part (`chapterNumber`, ascending) so a Plus "next
    /// chapter" always reads after the original plan; within a part:
    /// - Every action needs a recognizable quadrant and at least two distinct
    ///   quadrants must appear; otherwise a single "Your steps" chapter is
    ///   returned so old plans (quadrant NULL) render unchanged.
    /// - A lone strength and a lone threat merge into one chapter.
    /// - Never more than three chapters per part: trailing single-action
    ///   chapters fold into the one before them.
    static func build(from actions: [MicroAction]) -> [JourneyChapter] {
        guard !actions.isEmpty else { return [] }
        let parts = Set(actions.map(\.chapterNumber)).sorted()
        return parts.flatMap { part -> [JourneyChapter] in
            let own = actions.filter { $0.chapterNumber == part }
            // Plus chapters are one beat on the ladder, not four SWOT beats.
            if part >= 2 {
                let title = ChapterLadder.rung(part)?.title ?? JourneyChapterKind.build.title
                return [JourneyChapter(kind: .build, title: title, actions: own, part: part)]
            }
            return buildPart(from: own).map {
                JourneyChapter(kind: $0.kind, title: $0.title, actions: $0.actions, part: part)
            }
        }
    }

    private static func buildPart(from actions: [MicroAction]) -> [JourneyChapter] {
        guard !actions.isEmpty else { return [] }

        var buckets: [JourneyChapterKind: [MicroAction]] = [:]
        for action in actions {
            guard let kind = JourneyChapterKind(quadrant: action.quadrant) else {
                return [JourneyChapter(kind: .steps, title: JourneyChapterKind.steps.title, actions: actions)]
            }
            buckets[kind, default: []].append(action)
        }
        guard buckets.keys.count >= 2 else {
            return [JourneyChapter(kind: .steps, title: JourneyChapterKind.steps.title, actions: actions)]
        }

        var chapters: [JourneyChapter] = order.compactMap { kind in
            guard let group = buckets[kind], !group.isEmpty else { return nil }
            return JourneyChapter(kind: kind, title: kind.title, actions: group)
        }

        // A single strength next to a single threat is one beat, not two.
        if let s = chapters.firstIndex(where: { $0.kind == .playYourEdge }),
           let t = chapters.firstIndex(where: { $0.kind == .watchRisks }),
           chapters[s].actions.count == 1, chapters[t].actions.count == 1 {
            let merged = JourneyChapter(
                kind: .playYourEdge,
                title: "Play your edge, watch the risks",
                actions: chapters[s].actions + chapters[t].actions
            )
            chapters.remove(at: t)
            chapters[s] = merged
        }

        // Cap at three: fold trailing singletons back into the previous chapter.
        while chapters.count > 3, let last = chapters.last, chapters.count >= 2 {
            let prev = chapters[chapters.count - 2]
            chapters.removeLast()
            chapters[chapters.count - 1] = JourneyChapter(
                kind: prev.kind,
                title: prev.title,
                actions: prev.actions + last.actions
            )
        }

        return chapters
    }
}
