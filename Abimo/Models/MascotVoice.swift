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
    // Popup triggers — the ONLY ones that go through MascotDirector.
    // Popups are rare by design: max one per session, each with an action.
    case firstWelcome                    // first session ever after sign-in
    case returnedAfterAbsence(days: Int)
    case streakAtRisk(days: Int)         // streak from yesterday, nothing today
    // Static line sources (consumed via .line only, never popups)
    case emptyKitchen
    case recordPrompt
    case launching
    case ideaCapReached

    /// Stable key for per-trigger throttle timestamps.
    var throttleKey: String {
        switch self {
        case .scoreRevealed:        return "scoreRevealed"
        case .actionCompleted:      return "actionCompleted"
        case .streakExtended:       return "streakExtended"
        case .planComplete:         return "planComplete"
        case .firstWelcome:         return "firstWelcome"
        case .returnedAfterAbsence: return "returnedAfterAbsence"
        case .streakAtRisk:         return "streakAtRisk"
        case .emptyKitchen:         return "emptyKitchen"
        case .recordPrompt:         return "recordPrompt"
        case .launching:            return "launching"
        case .ideaCapReached:       return "ideaCapReached"
        }
    }
}

/// Where a mascot popup's action button routes. Lives in the Models layer —
/// the popup host maps intents to tabs/sheets, never the other way around.
enum MascotActionIntent: Equatable {
    case goRecord
    case openPlans
    case showPaywall
    case openNote(UUID)   // plumbed for future triggers; no producer yet
}

struct MascotAction: Equatable {
    let label: String
    let intent: MascotActionIntent
}

struct MascotMoment: Identifiable, Equatable {
    let id = UUID()
    let trigger: MascotMomentTrigger
    let line: String
    let mood: MascotMood
    var action: MascotAction? = nil
}

enum MascotVoice {

    static func moment(for trigger: MascotMomentTrigger) -> MascotMoment {
        let (lines, mood) = pool(for: trigger)
        var line = lines.randomElement() ?? ""
        switch trigger {
        case .actionCompleted(let count):
            line = line.replacingOccurrences(of: "{count}", with: "\(count)")
        case .streakExtended(let days), .returnedAfterAbsence(let days),
             .streakAtRisk(let days):
            line = line.replacingOccurrences(of: "{days}", with: "\(days)")
        default:
            break
        }
        var moment = MascotMoment(trigger: trigger, line: line, mood: mood)
        moment.action = defaultAction(for: trigger)
        return moment
    }

    /// Every popup trigger carries an action — that's the point of a popup.
    /// Static line consumers only read `.line`, so nothing else gets one.
    private static func defaultAction(for trigger: MascotMomentTrigger) -> MascotAction? {
        switch trigger {
        case .firstWelcome:
            return MascotAction(label: "Record an idea", intent: .goRecord)
        case .returnedAfterAbsence:
            return MascotAction(label: "Drop an idea", intent: .goRecord)
        case .streakAtRisk:
            return MascotAction(label: "Save the streak", intent: .openPlans)
        case .scoreRevealed, .actionCompleted, .streakExtended, .planComplete,
             .emptyKitchen, .recordPrompt, .launching, .ideaCapReached:
            return nil
        }
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

        case .firstWelcome:
            return ([
                "New in my kitchen? Bring me an idea. I'll tell you if it's edible.",
                "Welcome. I judge ideas for a living. Yours are safe-ish with me.",
                "First day. Low expectations. Surprise me with an idea.",
            ], .playful)

        case .streakAtRisk:
            return ([
                "{days} days of momentum, about to expire at midnight. One tiny action.",
                "Your {days}-day streak is on the counter getting cold. Do something.",
                "I don't do sentimental, but losing a {days}-day streak? Even I'd flinch.",
            ], .sassy)

        case .recordPrompt:
            return ([
                "Got an idea? Spill it.",
                "Talk to me. I'm listening. Reluctantly.",
                "The kitchen's open. What are we making?",
                "One tap. One idea. Go.",
            ], .neutral)

        case .launching:
            return ([
                "Warming up the judgment.",
                "Preheating opinions to 450°.",
                "Reviewing your life choices. One sec.",
                "Sharpening the red pen.",
                "Polishing the tasting spoon.",
            ], .neutral)

        case .ideaCapReached:
            return ([
                "Three ideas on the stove already. I'm one critic, not a brigade.",
                "Free menu's full. Clear a plate or buy the whole kitchen.",
                "I only have two hands and three of your ideas.",
                "The counter's full. Toss a dish or go pro.",
            ], .sassy)
        }
    }
}
