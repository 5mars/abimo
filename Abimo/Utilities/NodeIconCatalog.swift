//
//  NodeIconCatalog.swift
//  Abimo
//
//  Which kawaii icon a journey node wears. Chosen per chapter, cycling
//  through a small distinct set so neighbours never match; the last step
//  of a chapter is always the trophy. Pure, so the picker and the step
//  sheet can show exactly what the node shows.
//

import Foundation

enum NodeIconCatalog {
    static let trophy = "IconTrophy"

    /// Five distinct icons per chapter kind — cycling a set of five means
    /// no two adjacent nodes repeat, including the wrap from 4 back to 0.
    static func icons(for kind: JourneyChapterKind) -> [String] {
        switch kind {
        case .fixWeakSpot:  return ["IconHammer", "IconKey", "IconGlasses", "IconAbacus", "IconWhistle"]
        case .proveDemand:  return ["IconTarget", "IconBinoculars", "IconMagnifier", "IconCompass", "IconDuck"]
        case .playYourEdge: return ["IconStar", "IconLightbulb", "IconSun", "IconFeather", "IconPalette"]
        case .watchRisks:   return ["IconRaincloud", "IconSnowflake", "IconMoon", "IconCactus", "IconMushroom"]
        case .steps:        return ["IconBook", "IconPencil", "IconClock", "IconLeaf", "IconAcorn"]
        }
    }

    static func icon(for kind: JourneyChapterKind, indexInChapter: Int, isLastInChapter: Bool) -> String {
        if isLastInChapter { return trophy }
        let set = icons(for: kind)
        return set[max(0, indexInChapter) % set.count]
    }

    /// The icon a given action shows on the path — for the picker and the
    /// step sheet. Falls back to the "Your steps" set when the action isn't
    /// in any chapter (should not happen; keeps the call site total).
    static func icon(for action: MicroAction, in chapters: [JourneyChapter]) -> String {
        for chapter in chapters {
            if let index = chapter.actions.firstIndex(where: { $0.id == action.id }) {
                return icon(for: chapter.kind, indexInChapter: index, isLastInChapter: index == chapter.actions.count - 1)
            }
        }
        return icons(for: .steps)[0]
    }
}
