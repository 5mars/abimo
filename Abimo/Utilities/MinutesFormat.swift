//
//  MinutesFormat.swift
//  Abimo
//
//  Chapters 2+ have steps measured in hours, so raw "180 min" reads badly.
//  One formatter for every minutes label on the journey and the wrap-up.
//

import Foundation

enum MinutesFormat {
    /// "25 min", "1 h", "3 h 20 min". Zero → "0 min".
    static func short(_ minutes: Int) -> String {
        let m = max(0, minutes)
        if m < 60 { return "\(m) min" }
        let h = m / 60, rest = m % 60
        return rest == 0 ? "\(h) h" : "\(h) h \(rest) min"
    }

    /// Eyebrow variant, upper-case friendly: "25 MIN", "3 H 20 MIN".
    static func eyebrow(_ minutes: Int) -> String {
        short(minutes).uppercased()
    }
}
