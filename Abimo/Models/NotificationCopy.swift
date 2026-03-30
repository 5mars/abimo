//
//  NotificationCopy.swift
//  Abimo
//

import Foundation

enum SassLevel {
    case playful    // 1 day inactive
    case sassy      // 3 days inactive
    case guiltTrip  // 7+ days inactive
}

enum NotificationTrigger {
    case inactivity
    case incompleteAction
    case unanalyzedIdea
    case streakAtRisk
    case streakMilestone(days: Int)
}

struct NotificationMessage {
    let title: String
    let body: String
    let mood: MascotMood
}

struct NotificationCopy {

    static func message(for trigger: NotificationTrigger, sass: SassLevel) -> NotificationMessage {
        let messages = variants(for: trigger, sass: sass)
        return messages.randomElement()!
    }

    static func message(for trigger: NotificationTrigger, sass: SassLevel, context: String) -> NotificationMessage {
        let msg = message(for: trigger, sass: sass)
        let title = msg.title.replacingOccurrences(of: "{context}", with: context)
        let body = msg.body.replacingOccurrences(of: "{context}", with: context)
        return NotificationMessage(title: title, body: body, mood: msg.mood)
    }

    // MARK: - Variants

    private static func variants(for trigger: NotificationTrigger, sass: SassLevel) -> [NotificationMessage] {
        switch trigger {
        case .inactivity:
            return inactivityMessages(sass: sass)
        case .incompleteAction:
            return incompleteActionMessages(sass: sass)
        case .unanalyzedIdea:
            return unanalyzedIdeaMessages(sass: sass)
        case .streakAtRisk:
            return streakAtRiskMessages(sass: sass)
        case .streakMilestone(let days):
            return streakMilestoneMessages(days: days)
        }
    }

    // MARK: - Inactivity

    private static func inactivityMessages(sass: SassLevel) -> [NotificationMessage] {
        switch sass {
        case .playful:
            return [
                NotificationMessage(title: "Hey stranger", body: "Abimo's been waiting for you. Your ideas miss their creator.", mood: .playful),
                NotificationMessage(title: "Remember me?", body: "It's Abimo. Just checking if you're still alive over there.", mood: .playful),
                NotificationMessage(title: "Quick hello", body: "Your ideas are getting lonely. Abimo thinks you should visit.", mood: .playful),
                NotificationMessage(title: "Knock knock", body: "It's Abimo. I've been keeping your ideas warm for you.", mood: .playful),
                NotificationMessage(title: "Missing you", body: "Abimo's just sitting here... with all your brilliant ideas... alone.", mood: .playful),
            ]
        case .sassy:
            return [
                NotificationMessage(title: "Oh, you're alive?", body: "Cool cool. Abimo was just here. Alone. With your abandoned ideas.", mood: .sassy),
                NotificationMessage(title: "No big deal", body: "Abimo's fine. Totally fine. It's not like your ideas needed you or anything.", mood: .sassy),
                NotificationMessage(title: "Just saying", body: "Other people check on their ideas. Just putting that out there. — Abimo", mood: .sassy),
                NotificationMessage(title: "Day 3. Still waiting.", body: "Abimo's starting to think this is a pattern.", mood: .sassy),
                NotificationMessage(title: "Interesting choice", body: "Ignoring your ideas. Bold strategy. — Abimo", mood: .sassy),
            ]
        case .guiltTrip:
            return [
                NotificationMessage(title: "It's been a while", body: "Abimo's given up hope. Just kidding. But seriously, your ideas are collecting dust.", mood: .grumpy),
                NotificationMessage(title: "I've been waiting. Again.", body: "Your ideas had so much potential. Abimo remembers, even if you don't.", mood: .grumpy),
                NotificationMessage(title: "Remember your ideas?", body: "They're still here. Abimo's been babysitting them for free.", mood: .grumpy),
                NotificationMessage(title: "Week without you", body: "Abimo's not mad. Just disappointed. Your ideas deserved better.", mood: .grumpy),
                NotificationMessage(title: "Ghosting your ideas?", body: "That's cold. Even for you. Abimo expected more.", mood: .grumpy),
            ]
        }
    }

    // MARK: - Incomplete Action

    private static func incompleteActionMessages(sass: SassLevel) -> [NotificationMessage] {
        switch sass {
        case .playful:
            return [
                NotificationMessage(title: "Quick reminder", body: "You committed to \"{context}\" — Abimo believes in you!", mood: .playful),
                NotificationMessage(title: "You got this", body: "That action isn't going to complete itself. Abimo's rooting for you.", mood: .playful),
                NotificationMessage(title: "Almost there", body: "One small step: \"{context}\". Abimo's counting on you.", mood: .playful),
                NotificationMessage(title: "Gentle nudge", body: "Remember \"{context}\"? Abimo does. Just saying.", mood: .playful),
                NotificationMessage(title: "Action pending", body: "Abimo noticed you haven't finished \"{context}\" yet. No pressure.", mood: .playful),
            ]
        case .sassy:
            return [
                NotificationMessage(title: "So about that...", body: "You said you'd do \"{context}\". Abimo's taking notes.", mood: .sassy),
                NotificationMessage(title: "Still waiting", body: "\"{context}\" isn't going to do itself. Abimo checked.", mood: .sassy),
                NotificationMessage(title: "Promises, promises", body: "You committed to \"{context}\". Abimo remembers everything.", mood: .sassy),
                NotificationMessage(title: "Any day now", body: "Abimo's been watching \"{context}\" sit there. Untouched. Lonely.", mood: .sassy),
                NotificationMessage(title: "Fun fact", body: "You have unfinished business. \"{context}\" is judging you. — Abimo", mood: .sassy),
            ]
        case .guiltTrip:
            return [
                NotificationMessage(title: "You promised", body: "\"{context}\" believed in you. Abimo believed in you. Don't let us down.", mood: .grumpy),
                NotificationMessage(title: "Gathering dust", body: "\"{context}\" has been waiting so long it forgot what hope feels like. — Abimo", mood: .grumpy),
                NotificationMessage(title: "Abimo's disappointed", body: "Not angry. Just disappointed. \"{context}\" deserved better.", mood: .grumpy),
                NotificationMessage(title: "Left behind", body: "Your action \"{context}\" is still there. Abandoned. Cold. Alone.", mood: .grumpy),
                NotificationMessage(title: "Remember this?", body: "\"{context}\". You made a commitment. Abimo doesn't forget.", mood: .grumpy),
            ]
        }
    }

    // MARK: - Unanalyzed Idea

    private static func unanalyzedIdeaMessages(sass: SassLevel) -> [NotificationMessage] {
        switch sass {
        case .playful:
            return [
                NotificationMessage(title: "Idea waiting", body: "\"{context}\" is ready for the lab. Abimo's got the beakers ready.", mood: .playful),
                NotificationMessage(title: "Lab time?", body: "Your idea \"{context}\" wants to be analyzed. Abimo can help.", mood: .playful),
                NotificationMessage(title: "Raw potential", body: "\"{context}\" is sitting there unanalyzed. Let Abimo work some magic.", mood: .playful),
                NotificationMessage(title: "Fresh idea alert", body: "You dropped \"{context}\" in the lab but never ran it. Abimo's curious.", mood: .playful),
                NotificationMessage(title: "Don't leave it raw", body: "\"{context}\" has potential. Let Abimo cook.", mood: .playful),
            ]
        case .sassy:
            return [
                NotificationMessage(title: "Just sitting there", body: "\"{context}\" is in the lab. Unanalyzed. Abimo's tapping its foot.", mood: .sassy),
                NotificationMessage(title: "Nice idea... I guess", body: "You had \"{context}\". Cool. Shame nobody analyzed it.", mood: .sassy),
                NotificationMessage(title: "Wasted potential", body: "\"{context}\" could've been something. But it's just sitting there. — Abimo", mood: .sassy),
                NotificationMessage(title: "You recorded it", body: "And then... nothing? \"{context}\" is wondering what it did wrong. — Abimo", mood: .sassy),
                NotificationMessage(title: "Ideas have feelings", body: "\"{context}\" feels ignored. Abimo can relate.", mood: .sassy),
            ]
        case .guiltTrip:
            return [
                NotificationMessage(title: "Forgotten idea", body: "\"{context}\" is still in the lab. Alone. In the dark. Abimo's with it, but still.", mood: .grumpy),
                NotificationMessage(title: "You had one job", body: "Record idea. Analyze idea. You got halfway. — Abimo", mood: .grumpy),
                NotificationMessage(title: "Abimo remembers", body: "Even if you forgot \"{context}\", Abimo didn't. Run. The. Analysis.", mood: .grumpy),
                NotificationMessage(title: "Collecting dust", body: "\"{context}\" had potential. Now it's just... there. Sad. — Abimo", mood: .grumpy),
                NotificationMessage(title: "Your idea misses you", body: "\"{context}\" has been waiting so long. Abimo's getting emotional.", mood: .grumpy),
            ]
        }
    }

    // MARK: - Streak At Risk

    private static func streakAtRiskMessages(sass: SassLevel) -> [NotificationMessage] {
        switch sass {
        case .playful:
            return [
                NotificationMessage(title: "Streak check", body: "You haven't completed an action today. Don't break the chain! — Abimo", mood: .playful),
                NotificationMessage(title: "Still time!", body: "Your streak is on the line. One quick action and you're golden. — Abimo", mood: .playful),
                NotificationMessage(title: "Evening nudge", body: "Day's almost over and your streak needs you. Abimo's worried.", mood: .playful),
                NotificationMessage(title: "Don't let it slip", body: "Your streak is counting on you tonight. Quick action? — Abimo", mood: .playful),
                NotificationMessage(title: "Streak alert", body: "Abimo's nervously watching your streak. One action saves it.", mood: .playful),
            ]
        case .sassy:
            return [
                NotificationMessage(title: "Tick tock", body: "Your streak is about to die. No pressure. — Abimo", mood: .sassy),
                NotificationMessage(title: "Going once...", body: "Your streak is on life support. Abimo's just the messenger.", mood: .sassy),
                NotificationMessage(title: "Last chance", body: "Complete one action or kiss your streak goodbye. — Abimo", mood: .sassy),
                NotificationMessage(title: "Streak dying", body: "Abimo tried to save it but Abimo can't do your actions for you.", mood: .sassy),
                NotificationMessage(title: "Hello?", body: "Your streak. Today. One action. That's it. — Abimo", mood: .sassy),
            ]
        case .guiltTrip:
            return [
                NotificationMessage(title: "RIP streak?", body: "After all that work. You're really going to let it die? — Abimo", mood: .grumpy),
                NotificationMessage(title: "Heartbreaking", body: "Abimo watched you build that streak. And now... nothing?", mood: .grumpy),
                NotificationMessage(title: "It's over", body: "Unless you act RIGHT NOW, your streak is gone. Abimo tried.", mood: .grumpy),
                NotificationMessage(title: "Streak obituary", body: "Here lies your streak. Cause of death: you. — Abimo", mood: .grumpy),
                NotificationMessage(title: "Was it worth it?", body: "Losing your whole streak because you couldn't do one small thing?", mood: .grumpy),
            ]
        }
    }

    // MARK: - Streak Milestone (celebratory — the ONE time Abimo is nice)

    private static func streakMilestoneMessages(days: Int) -> [NotificationMessage] {
        switch days {
        case 3:
            return [
                NotificationMessage(title: "3 days strong!", body: "Abimo's actually impressed. Keep this energy going!", mood: .playful),
                NotificationMessage(title: "Hat trick!", body: "3 days in a row. Abimo's starting to believe in you.", mood: .playful),
                NotificationMessage(title: "On a roll", body: "3-day streak! Abimo's doing a little dance for you.", mood: .playful),
            ]
        case 7:
            return [
                NotificationMessage(title: "One whole week!", body: "7 days! Abimo's genuinely proud. You're building something real.", mood: .playful),
                NotificationMessage(title: "Week warrior", body: "7-day streak! Abimo never doubted you. (Okay, maybe a little.)", mood: .playful),
                NotificationMessage(title: "Unstoppable", body: "A full week of action. Abimo's in awe. Seriously.", mood: .playful),
            ]
        case 14:
            return [
                NotificationMessage(title: "Two weeks!", body: "14 days! You're officially in the zone. Abimo's so proud.", mood: .playful),
                NotificationMessage(title: "Legend status", body: "14-day streak. Most people quit by now. Not you. — Abimo", mood: .playful),
                NotificationMessage(title: "Incredible", body: "Two full weeks of crushing it. Abimo's speechless (for once).", mood: .playful),
            ]
        default: // 30+
            return [
                NotificationMessage(title: "30 days!!!", body: "A MONTH of consistency. Abimo's crying happy tears. You're amazing.", mood: .playful),
                NotificationMessage(title: "Absolute beast", body: "30-day streak. Abimo officially works for YOU now.", mood: .playful),
                NotificationMessage(title: "Historic", body: "30 days. You turned your ideas into action for a whole month. Abimo bows.", mood: .playful),
            ]
        }
    }
}
