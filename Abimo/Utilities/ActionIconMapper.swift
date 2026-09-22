//
//  ActionIconMapper.swift
//  Abimo
//

import Foundation

enum ActionIconMapper {
    /// Resolved icon pair for an action type.
    struct IconPair {
        let emoji: String
        let symbol: String
    }

    // MARK: - Lookup

    /// Returns an emoji and SF Symbol name for the given action type.
    /// Input is case-insensitive. Unknown or nil types return a sensible default.
    static func icon(for actionType: String?) -> (emoji: String, symbol: String) {
        let pair = mapping[actionType?.lowercased() ?? ""] ?? defaultIcon
        return (emoji: pair.emoji, symbol: pair.symbol)
    }

    // MARK: - Mapping Table

    private static let defaultIcon = IconPair(emoji: "\u{2705}", symbol: "checkmark.circle")

    private static let mapping: [String: IconPair] = [
        "email":   IconPair(emoji: "\u{1F4E7}", symbol: "envelope"),
        "search":  IconPair(emoji: "\u{1F50D}", symbol: "magnifyingglass"),
        "message": IconPair(emoji: "\u{1F4AC}", symbol: "message"),
        "post":    IconPair(emoji: "\u{1F4E2}", symbol: "megaphone"),
        "link":    IconPair(emoji: "\u{1F517}", symbol: "link"),
    ]
}
