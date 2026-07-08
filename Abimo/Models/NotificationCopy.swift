//
//  NotificationCopy.swift
//  Abimo
//
//  Push/local notification copy — the critic, but passive-aggressive.
//  First person, dry, guilt with a smile. Same tone rule as MascotVoice:
//  roast the idea or the situation, never the founder.
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
                NotificationMessage(title: "The kitchen's suspiciously quiet", body: "One day without an idea. I'm sure that means you're 'thinking'.", mood: .playful),
                NotificationMessage(title: "Everything okay over there?", body: "No new ideas since yesterday. I've started alphabetizing the spice rack.", mood: .playful),
                NotificationMessage(title: "Not to alarm you", body: "But your last idea is starting to look like your best idea. Fix that.", mood: .playful),
                NotificationMessage(title: "I had a thought today", body: "Just one though. Your move.", mood: .playful),
                NotificationMessage(title: "Quick question", body: "Do geniuses take days off? Asking for a food critic who's bored.", mood: .playful),
            ]
        case .sassy:
            return [
                NotificationMessage(title: "Day 3. I've stopped setting the table.", body: "The stove's still warm. Barely. — Abimo", mood: .sassy),
                NotificationMessage(title: "Oh don't mind me", body: "I'll just keep polishing the same three ideas. Living the dream.", mood: .sassy),
                NotificationMessage(title: "I made a reservation for your ideas", body: "Party of none, apparently. — Abimo", mood: .sassy),
                NotificationMessage(title: "Fun fact", body: "Ideas don't age like wine. They age like milk. Yours are on day 3.", mood: .sassy),
                NotificationMessage(title: "No pressure", body: "It's not like inspiration is perishable or anything. Oh wait. — Abimo", mood: .sassy),
            ]
        case .guiltTrip:
            return [
                NotificationMessage(title: "A week. I counted.", body: "I don't do feelings, but the empty kitchen is starting to echo. — Abimo", mood: .grumpy),
                NotificationMessage(title: "I'm not saying you quit", body: "I'm just saying the kitchen lights are on a timer now. To save money.", mood: .grumpy),
                NotificationMessage(title: "Your ideas asked about you", body: "I said you were 'busy'. We both know I lied for you. — Abimo", mood: .grumpy),
                NotificationMessage(title: "Seven days", body: "I've reviewed restaurants that opened AND closed in less time. — Abimo", mood: .grumpy),
                NotificationMessage(title: "Still here. Unfortunately.", body: "Me, your ideas, and a week of silence. Cozy. — Abimo", mood: .grumpy),
            ]
        }
    }

    // MARK: - Incomplete Action

    private static func incompleteActionMessages(sass: SassLevel) -> [NotificationMessage] {
        switch sass {
        case .playful:
            return [
                NotificationMessage(title: "About \"{context}\"", body: "It's still on the counter. I covered it with foil. You're welcome.", mood: .playful),
                NotificationMessage(title: "Tiny reminder", body: "\"{context}\" takes less time than reading this notification. Probably.", mood: .playful),
                NotificationMessage(title: "One small step", body: "\"{context}\". That's it. That's the whole ask.", mood: .playful),
                NotificationMessage(title: "I checked the list", body: "\"{context}\" is still unchecked. The list and I are exchanging looks.", mood: .playful),
                NotificationMessage(title: "No rush", body: "\"{context}\" has only been waiting since yesterday. It's very patient. Unlike me.", mood: .playful),
            ]
        case .sassy:
            return [
                NotificationMessage(title: "Bold of you", body: "Committing to \"{context}\" and then... this silence. Inspired. — Abimo", mood: .sassy),
                NotificationMessage(title: "Status update on \"{context}\"", body: "There is no status. That's the update. — Abimo", mood: .sassy),
                NotificationMessage(title: "I told the other actions", body: "That \"{context}\" would get done today. Don't make me a liar twice.", mood: .sassy),
                NotificationMessage(title: "Quick math", body: "\"{context}\": 10 minutes. Time elapsed: significantly more. — Abimo", mood: .sassy),
                NotificationMessage(title: "Interesting strategy", body: "Planning the work and skipping the work. Revolutionary. — Abimo", mood: .sassy),
            ]
        case .guiltTrip:
            return [
                NotificationMessage(title: "\"{context}\" again", body: "At this point I've memorized it. I recite it at night. Do the thing.", mood: .grumpy),
                NotificationMessage(title: "I'm keeping a ledger", body: "\"{context}\" has its own page now. The page is getting full. — Abimo", mood: .grumpy),
                NotificationMessage(title: "Not mad. Cataloguing.", body: "\"{context}\" — promised, postponed, preserved for the record. — Abimo", mood: .grumpy),
                NotificationMessage(title: "The plan called", body: "It wants to know if \"{context}\" was ever real to you.", mood: .grumpy),
                NotificationMessage(title: "One item stands between you", body: "and me shutting up about it. \"{context}\". Your call. — Abimo", mood: .grumpy),
            ]
        }
    }

    // MARK: - Unanalyzed Idea

    private static func unanalyzedIdeaMessages(sass: SassLevel) -> [NotificationMessage] {
        switch sass {
        case .playful:
            return [
                NotificationMessage(title: "\"{context}\" is sitting raw", body: "You brought me ingredients and left. Shall I cook or compost?", mood: .playful),
                NotificationMessage(title: "Taste test pending", body: "\"{context}\" awaits judgment. I've sharpened my opinions.", mood: .playful),
                NotificationMessage(title: "The critic is seated", body: "Napkin on. Fork ready. \"{context}\" still hasn't been served.", mood: .playful),
                NotificationMessage(title: "You recorded \"{context}\"", body: "And then vanished like a chef who saw the health inspector. Come back.", mood: .playful),
                NotificationMessage(title: "Free professional opinion", body: "\"{context}\" qualifies. My schedule is suspiciously open.", mood: .playful),
            ]
        case .sassy:
            return [
                NotificationMessage(title: "\"{context}\" — untasted", body: "Recording it was the appetizer. There was supposed to be a main course. — Abimo", mood: .sassy),
                NotificationMessage(title: "I don't review raw ideas", body: "Oh wait, I literally do. \"{context}\". Send it. — Abimo", mood: .sassy),
                NotificationMessage(title: "Half a workflow", body: "Record ✓. Analyze... we'll circle back? \"{context}\" deserves closure.", mood: .sassy),
                NotificationMessage(title: "The suspense is fake", body: "You already know \"{context}\" needs a taste test. So do it. — Abimo", mood: .sassy),
                NotificationMessage(title: "\"{context}\" update", body: "Still brilliant, still unverified. One of those is fixable. — Abimo", mood: .sassy),
            ]
        case .guiltTrip:
            return [
                NotificationMessage(title: "\"{context}\" is in the fridge", body: "Behind the leftovers. Next to the other maybes. It remembers daylight. — Abimo", mood: .grumpy),
                NotificationMessage(title: "I did everything but taste it", body: "Because that part needs YOU to tap one button. \"{context}\". — Abimo", mood: .grumpy),
                NotificationMessage(title: "Some ideas get analyzed", body: "Others get \"{context}\"'d. Don't let that become a verb. — Abimo", mood: .grumpy),
                NotificationMessage(title: "A moment of honesty", body: "\"{context}\" might be great. We'll never know. Unless — imagine — you run it.", mood: .grumpy),
                NotificationMessage(title: "The kitchen keeps receipts", body: "\"{context}\", recorded and abandoned. Exhibit A. — Abimo", mood: .grumpy),
            ]
        }
    }

    // MARK: - Streak At Risk

    private static func streakAtRiskMessages(sass: SassLevel) -> [NotificationMessage] {
        switch sass {
        case .playful:
            return [
                NotificationMessage(title: "Your streak called", body: "It sounded worried. One small action calms it right down.", mood: .playful),
                NotificationMessage(title: "The flame is flickering", body: "Not to be dramatic, but midnight is coming and your streak knows it.", mood: .playful),
                NotificationMessage(title: "Evening check", body: "Nothing done today. The streak is pacing. I'm pretending not to watch.", mood: .playful),
                NotificationMessage(title: "One action", body: "That's the price of keeping the flame. Cheapest thing on the menu.", mood: .playful),
                NotificationMessage(title: "Streak forecast", body: "Cloudy with a chance of zero. Still reversible. — Abimo", mood: .playful),
            ]
        case .sassy:
            return [
                NotificationMessage(title: "Tick tock", body: "The streak dies at midnight and I'm not doing CPR. — Abimo", mood: .sassy),
                NotificationMessage(title: "Going once, going twice", body: "Your streak is on the auction block. Bid: one tiny action. — Abimo", mood: .sassy),
                NotificationMessage(title: "Days of work", body: "One evening of scrolling. I've seen this recipe before. It ends badly.", mood: .sassy),
                NotificationMessage(title: "The streak or the couch", body: "Choose wisely. The couch will still be there after. — Abimo", mood: .sassy),
                NotificationMessage(title: "I prepared a eulogy", body: "For your streak. I'd rather not read it. One action cancels the funeral.", mood: .sassy),
            ]
        case .guiltTrip:
            return [
                NotificationMessage(title: "So this is how it ends", body: "All those days, undone by one quiet evening. Poetic. Preventable. — Abimo", mood: .grumpy),
                NotificationMessage(title: "Here lies your streak", body: "Cause of death: 'I'll do it tomorrow.' Time of death: midnight. Unless. — Abimo", mood: .grumpy),
                NotificationMessage(title: "I watched you build it", body: "Day by day. And now I'm watching this. One action, and I saw nothing.", mood: .grumpy),
                NotificationMessage(title: "The flame doesn't beg", body: "But I do. Reluctantly. One action before midnight. — Abimo", mood: .grumpy),
                NotificationMessage(title: "Tomorrow-you is watching", body: "They'd like to wake up with the streak intact. Don't rob them. — Abimo", mood: .grumpy),
            ]
        }
    }

    // MARK: - Streak Milestone (celebratory — the critic compliments through gritted teeth)

    private static func streakMilestoneMessages(days: Int) -> [NotificationMessage] {
        switch days {
        case 3:
            return [
                NotificationMessage(title: "3 days straight", body: "I'm not impressed. I'm... adjacent to impressed. Keep going.", mood: .playful),
                NotificationMessage(title: "A hat trick", body: "Three days in a row. Fine. FINE. That's consistency. — Abimo", mood: .playful),
                NotificationMessage(title: "Day 3, still cooking", body: "Statistically this is where people quit. Statistically. — Abimo", mood: .playful),
            ]
        case 7:
            return [
                NotificationMessage(title: "A full week", body: "7 days. I checked the math twice because I didn't believe it either.", mood: .playful),
                NotificationMessage(title: "Week one, done", body: "The kitchen ran hot for 7 straight days. I have no complaints. Write that down.", mood: .playful),
                NotificationMessage(title: "7 days", body: "I'd say I never doubted you, but we both keep records. — Abimo", mood: .playful),
            ]
        case 14:
            return [
                NotificationMessage(title: "Two weeks", body: "14 days. I've started telling other critics about you. Anonymously.", mood: .playful),
                NotificationMessage(title: "14 days straight", body: "Most streaks don't survive one rainy Tuesday. Yours ate two of them. — Abimo", mood: .playful),
                NotificationMessage(title: "Fortnight of fire", body: "Two weeks without missing. My skepticism is filing a complaint.", mood: .playful),
            ]
        default: // 30+
            return [
                NotificationMessage(title: "30 days", body: "A month. Of consistency. From you. I need to sit down. — Abimo", mood: .playful),
                NotificationMessage(title: "One month streak", body: "I came to roast and I have nothing. This is the worst day of my career.", mood: .playful),
                NotificationMessage(title: "30 days of action", body: "Chef's kiss. Don't quote me. I'll deny it in the reviews. — Abimo", mood: .playful),
            ]
        }
    }
}
