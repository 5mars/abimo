//
//  CompletionRewards.swift
//  Abimo
//
//  Everything one completion earned, gathered into a single receipt the
//  congrats sheet shows as a strip — instead of up to four banners stacking
//  on top of the path over eight seconds.
//

import Foundation

struct CompletionRewards: Equatable {
    var xp: Int
    var firstOfDay: Bool = false
    var milestone: Int? = nil       // 3, 5 or 7 steps done in this plan
    var streak: Int? = nil          // days, when this completion extended it
    var goalHit: Int? = nil         // the daily goal XP that was crossed
    var badge: Achievement? = nil   // a badge this completion unlocked

    /// Base XP for a completion at this point in the day.
    static func baseXP(firstOfDay: Bool) -> Int {
        XPEngine.actionXP + (firstOfDay ? XPEngine.firstOfDayBonus : 0)
    }

    var rowCount: Int {
        1 + (milestone != nil ? 1 : 0) + (streak != nil ? 1 : 0)
          + (goalHit != nil ? 1 : 0) + (badge != nil ? 1 : 0)
    }
}
