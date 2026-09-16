//
//  DareEngine.swift
//  Abimo
//
//  Daily dares: three rotating micro-quests judged purely from data the
//  Actions tab already holds — no backend, no new fetches. Pure static
//  functions in the XPEngine/streakInfo mold: state in, verdicts out.
//
//  Completed dares are LATCHED per day (a satisfied dare stays checked even
//  if the underlying action is later un-done) via the encode/decode helpers;
//  the card owns the @AppStorage.
//

import Foundation

// MARK: - Dare

enum Dare: String, CaseIterable, Identifiable {
    case completeOne      // complete 1 action
    case completeTwo      // complete 2 actions
    case finishPlate      // complete 3 actions
    case quickBite        // complete an action estimated <= 10 min
    case earlyBird        // complete an action before noon
    case twoKitchens      // complete actions from 2 different plans
    case extendStreak     // complete with a 2+ day streak
    case keepYourWord     // complete the action you committed to
    // Plan-less dares — the loop must have something to offer a founder
    // with no live plan, or the daily surface dies with the last step.
    case dropIdea         // record a new idea today
    case replayPitch      // listen back to one of your pitches
    case leaveNote        // leave a note on a step you finished

    var id: String { rawValue }

    /// Dares that don't require an open action plan.
    var needsPlan: Bool {
        switch self {
        case .dropIdea, .replayPitch: return false
        case .leaveNote:              return true   // needs a completion to annotate
        default:                      return true
        }
    }

    var title: String {
        switch self {
        case .completeOne:  return "Check off 1 action"
        case .completeTwo:  return "Check off 2 actions"
        case .finishPlate:  return "Check off 3 actions"
        case .quickBite:    return "Finish a step under 10 min"
        case .earlyBird:    return "Complete an action before noon"
        case .twoKitchens:  return "Work on 2 different ideas"
        case .extendStreak: return "Keep the streak alive"
        case .keepYourWord: return "Do the step you committed to"
        case .dropIdea:     return "Record a new idea"
        case .replayPitch:  return "Listen back to one of your pitches"
        case .leaveNote:    return "Leave a note on a step you finish"
        }
    }

    var icon: String {
        switch self {
        case .completeOne:  return "checkmark.circle.fill"
        case .completeTwo:  return "checkmark.seal.fill"
        case .finishPlate:  return "fork.knife"
        case .quickBite:    return "bolt.fill"
        case .earlyBird:    return "sunrise.fill"
        case .twoKitchens:  return "square.grid.2x2.fill"
        case .extendStreak: return "flame.fill"
        case .keepYourWord: return "hand.raised.fill"
        case .dropIdea:     return "mic.fill"
        case .replayPitch:  return "play.circle.fill"
        case .leaveNote:    return "square.and.pencil"
        }
    }
}

/// Signals a dare can't read from micro-actions alone.
struct DareContext: Equatable {
    var ideasRecordedToday: Int = 0
    var replayedPitchToday: Bool = false
}

// MARK: - DareEngine

enum DareEngine {

    /// Today's three dares — deterministic per calendar day (seeded from
    /// day-of-year and year), so every visit shows the same trio and the
    /// menu rotates at midnight. No randomness source, fully testable.
    ///
    /// With no open plan only plan-less dares are offered; otherwise at
    /// least one of the three is plan-less, so the day always has an exit
    /// that isn't "check off a step".
    static func dares(for date: Date, hasOpenActions: Bool = true, calendar: Calendar = .current) -> [Dare] {
        let shuffled = shuffledPool(for: date, calendar: calendar)
        if !hasOpenActions {
            return Array(shuffled.filter { !$0.needsPlan }.prefix(3))
        }
        var picked = Array(shuffled.prefix(3))
        if !picked.contains(where: { !$0.needsPlan }),
           let planless = shuffled.dropFirst(3).first(where: { !$0.needsPlan }) {
            picked[picked.count - 1] = planless
        }
        return picked
    }

    /// Whole pool in the day's deterministic order (xorshift Fisher–Yates).
    static func shuffledPool(for date: Date, calendar: Calendar = .current) -> [Dare] {
        let day = UInt64(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let year = UInt64(calendar.component(.year, from: date))
        var seed = (day &* 2_654_435_761) &+ (year &* 40_503)

        func next() -> UInt64 {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return seed
        }

        var pool = Dare.allCases
        var out: [Dare] = []
        while !pool.isEmpty {
            let idx = Int(next() % UInt64(pool.count))
            out.append(pool.remove(at: idx))
        }
        return out
    }

    /// Whether `dare` is satisfied right now, judged from all plans' actions.
    static func isSatisfied(
        _ dare: Dare,
        actionsByPlan: [UUID: [MicroAction]],
        streak: Int,
        committedActionId: UUID? = nil,
        context: DareContext = DareContext(),
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> Bool {
        let all = actionsByPlan.values.flatMap { $0 }
        let today = all.filter {
            guard let done = $0.completedAt else { return false }
            return calendar.isDate(done, inSameDayAs: now)
        }

        switch dare {
        case .completeOne: return today.count >= 1
        case .completeTwo: return today.count >= 2
        case .finishPlate: return today.count >= 3
        case .quickBite:
            return today.contains { $0.timeEstimateMinutes <= 10 }
        case .earlyBird:
            return today.contains {
                guard let done = $0.completedAt else { return false }
                return calendar.component(.hour, from: done) < 12
            }
        case .twoKitchens:
            let plansToday = actionsByPlan.filter { _, actions in
                actions.contains {
                    guard let done = $0.completedAt else { return false }
                    return calendar.isDate(done, inSameDayAs: now)
                }
            }
            return plansToday.count >= 2
        case .extendStreak:
            return !today.isEmpty && streak >= 2
        case .keepYourWord:
            guard let committedActionId else { return false }
            return today.contains { $0.id == committedActionId }
        case .dropIdea:
            return context.ideasRecordedToday >= 1
        case .replayPitch:
            return context.replayedPitchToday
        case .leaveNote:
            return today.contains { !($0.completionNote ?? "").isEmpty }
        }
    }

    // MARK: - Replay latch (set by the audio player, read by the card)

    static let replayLatchKey = "dare_replayed_day"

    static func markPitchReplayed(on date: Date = Date(), defaults: UserDefaults = .standard) {
        defaults.set(dayKey(for: date), forKey: replayLatchKey)
    }

    static func replayedPitch(on date: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        defaults.string(forKey: replayLatchKey) == dayKey(for: date)
    }

    /// XP earned from `latched` dares (chest bonus when all three are done).
    static func xp(latchedCount: Int) -> Int {
        latchedCount * XPEngine.dareXP + (latchedCount >= 3 ? XPEngine.daresClearedBonus : 0)
    }

    // MARK: - Day-keyed latch storage ("yyyy-MM-dd|dare1,dare2")

    static let latchStorageKey = "dares_done"

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Decodes the latch string; returns [] when it belongs to another day,
    /// so the latch self-resets at midnight.
    static func decodeLatch(_ stored: String, for date: Date, calendar: Calendar = .current) -> Set<Dare> {
        let parts = stored.split(separator: "|", maxSplits: 1)
        guard parts.count == 2, parts[0] == dayKey(for: date, calendar: calendar) else { return [] }
        return Set(parts[1].split(separator: ",").compactMap { Dare(rawValue: String($0)) })
    }

    static func encodeLatch(_ dares: Set<Dare>, for date: Date, calendar: Calendar = .current) -> String {
        "\(dayKey(for: date, calendar: calendar))|\(dares.map(\.rawValue).sorted().joined(separator: ","))"
    }
}
