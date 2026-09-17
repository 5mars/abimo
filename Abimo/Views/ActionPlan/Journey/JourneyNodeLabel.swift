//
//  JourneyNodeLabel.swift
//  Abimo
//
//  The text beside each node — what the step is, how long it takes, and
//  (once done) when and how it went. The path has to read without a tap.
//

import SwiftUI

struct JourneyNodeLabel: View {
    let action: MicroAction
    let state: NodeState
    /// Text hugs the node: leading-aligned when the node is on the left.
    let alignLeading: Bool
    /// "+10 XP" preview, shown on the `next` step only.
    var xpPreview: Int? = nil

    private var alignment: HorizontalAlignment { alignLeading ? .leading : .trailing }
    private var frameAlignment: Alignment { alignLeading ? .leading : .trailing }

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(action.text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(state == .done ? .textSec : .textPri)
                .lineLimit(3)
                .multilineTextAlignment(alignLeading ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)

            if state == .done {
                Text(doneLine)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.brandGreen)
                if let note = action.completionNote, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 11))
                        .italic()
                        .foregroundColor(.textSec)
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 6) {
                    Text("\(action.timeEstimateMinutes) min · \(ActionDeepLink.typeLabel(for: action))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSec)
                    if state == .next, let xpPreview {
                        Text("+\(xpPreview) XP")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.brandAmberDark)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.brandAmber.opacity(0.18)))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
        .allowsHitTesting(false)
    }

    private var doneLine: String {
        var parts: [String] = []
        if let date = action.completedAt {
            parts.append("Done \(Self.dayLabel(for: date))")
        } else {
            parts.append("Done")
        }
        switch action.completionOutcome {
        case "didnt_work": parts.append("Didn't work")
        case "did_it":     parts.append("Did it")
        default:           break
        }
        return parts.joined(separator: " · ")
    }

    static func dayLabel(for date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}
