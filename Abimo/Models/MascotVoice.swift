//
//  MascotVoice.swift
//  Abimo
//
//  In-app mascot speech — first-person one-liners from the food critic.
//  Same variant-pool pattern as NotificationCopy (which stays notification-
//  only: it needs titles and "— Abimo" signoffs; this is spoken dialogue).
//  Tone rule: roast the idea or the situation, never the founder.
//

import Foundation

enum MascotMomentTrigger: Equatable {
    case scoreRevealed(verdict: ScoreVerdict)
    case actionCompleted(count: Int)
    case streakExtended(days: Int)
    case planComplete
    case returnedAfterAbsence(days: Int)
    case emptyKitchen
    case plansIdle
    case randomJab

    /// Stable key for per-trigger throttle timestamps.
    var throttleKey: String {
        switch self {
        case .scoreRevealed:        return "scoreRevealed"
        case .actionCompleted:      return "actionCompleted"
        case .streakExtended:       return "streakExtended"
        case .planComplete:         return "planComplete"
        case .returnedAfterAbsence: return "returnedAfterAbsence"
        case .emptyKitchen:         return "emptyKitchen"
        case .plansIdle:            return "plansIdle"
        case .randomJab:            return "randomJab"
        }
    }

    /// Ambient moments are unprompted commentary and get throttled;
    /// event moments respond to something the user just did and always show.
    var isAmbient: Bool {
        switch self {
        case .emptyKitchen, .plansIdle, .randomJab: return true
        default: return false
        }
    }
}

struct MascotMoment: Identifiable, Equatable {
    let id = UUID()
    let trigger: MascotMomentTrigger
    let line: String
    let mood: MascotMood
    var duration: TimeInterval = 4.5
}

enum MascotVoice {

    static func moment(for trigger: MascotMomentTrigger) -> MascotMoment {
        let (lines, mood) = pool(for: trigger)
        var line = lines.randomElement() ?? ""
        switch trigger {
        case .actionCompleted(let count):
            line = line.replacingOccurrences(of: "{count}", with: "\(count)")
        case .streakExtended(let days), .returnedAfterAbsence(let days):
            line = line.replacingOccurrences(of: "{days}", with: "\(days)")
        default:
            break
        }
        return MascotMoment(trigger: trigger, line: line, mood: mood)
    }

    // MARK: - Variant pools

    private static func pool(for trigger: MascotMomentTrigger) -> (lines: [String], mood: MascotMood) {
        switch trigger {
        case .scoreRevealed(let verdict):
            switch verdict {
            case .burnt:
                return ([
                    "I've seen soup with a better business model.",
                    "Sending this back to the kitchen. The kitchen declined.",
                    "Good news: from here, every direction is up.",
                    "The smoke alarm went off. That's my review.",
                ], .grumpy)
            case .halfBaked:
                return ([
                    "Raw in the middle, ambitious at the edges.",
                    "There's a filling in there somewhere. Keep baking.",
                    "I've tasted worse. I've also tasted food.",
                ], .grumpy)
            case .needsSeasoning:
                return ([
                    "Edible. Nobody said delicious.",
                    "A pinch of validation and this might actually be something.",
                    "Salt. It needs salt. And customers.",
                ], .sassy)
            case .simmering:
                return ([
                    "Careful — I almost complimented you.",
                    "This one has aroma. Don't let it boil over.",
                    "I'm not smiling. This is my thinking face.",
                ], .playful)
            case .chefsKiss:
                return ([
                    "Fine. It's good. Don't make it weird.",
                    "I went back for thirds. Tell no one.",
                    "My review: I have no notes. First time for everything.",
                ], .playful)
            }

        case .actionCompleted:
            return ([
                "One down. Adjusting my expectations. Slightly.",
                "You did the thing you said you'd do. Rare.",
                "That's {count} done. Who ARE you today?",
            ], .playful)

        case .streakExtended:
            return ([
                "{days} days straight. Suspiciously consistent.",
                "A streak! I'd clap, but I'm holding a clipboard.",
                "{days} days. The kitchen stays hot.",
            ], .playful)

        case .planComplete:
            return ([
                "The whole plan. Finished. I need to sit down.",
                "No complaints. This is new for both of us.",
                "Full course, cleaned plate. Respect.",
            ], .playful)

        case .returnedAfterAbsence:
            return ([
                "Oh good, you remembered the app exists.",
                "{days} days. Your ideas kept asking about you. Awkward.",
                "Welcome back. Everything aged like milk.",
            ], .sassy)

        case .emptyKitchen:
            return ([
                "An empty kitchen. Bold minimalist concept.",
                "Record something. I can't roast air.",
            ], .neutral)

        case .plansIdle:
            return ([
                "That plan won't execute itself. Believe me, I checked.",
                "Step one is still step one. It's been days.",
            ], .sassy)

        case .randomJab:
            return ([
                "Just checking in. Judging, mostly.",
                "No notes today. Suspicious.",
                "I critique because I care. Mostly critique.",
                "Still here. Still skeptical.",
            ], .sassy)
        }
    }
}
