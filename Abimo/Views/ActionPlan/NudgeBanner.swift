//
//  NudgeBanner.swift
//  Abimo
//

import SwiftUI

/// In-app nudge banner with the mascot doing the nudging. Dismissal is
/// persisted per nudge type per day, so it stays gone after a swipe away
/// but can return tomorrow if the situation hasn't improved.
struct NudgeBanner: View {
    let nudge: NudgeMessage
    @State private var isVisible: Bool

    init(nudge: NudgeMessage) {
        self.nudge = nudge
        _isVisible = State(initialValue: !Self.isDismissedToday(type: nudge.type))
    }

    private var tintColor: Color {
        switch nudge.type {
        case .inactivity:    return .brandAmber
        case .commitmentDue: return .brandBlue
        case .milestone:     return .brandGreen
        case .nextAction:    return .brand
        }
    }

    private var bgColor: Color {
        switch nudge.type {
        case .inactivity:    return .cardDarkOrange
        case .commitmentDue: return .cardDarkRed
        case .milestone:     return .cardDarkTeal
        case .nextAction:    return .cardDarkBlue
        }
    }

    private var mood: MascotMood {
        switch nudge.type {
        case .inactivity, .commitmentDue: return .sassy
        case .milestone:                  return .playful
        case .nextAction:                 return .neutral
        }
    }

    var body: some View {
        if isVisible {
            HStack(spacing: 10) {
                Image(mood.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    Text(nudge.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.textPri)
                    Text(nudge.body)
                        .font(.system(size: 13))
                        .foregroundColor(.textSec)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    Self.markDismissedToday(type: nudge.type)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isVisible = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.textSec)
                        .padding(6)
                }
            }
            .duoPanel(fill: bgColor, padding: 14)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Daily dismissal persistence

    private static func dismissKey(type: NudgeType) -> String {
        let day = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970
        return "nudge_dismissed_\(type.rawValue)_\(Int(day))"
    }

    static func isDismissedToday(type: NudgeType) -> Bool {
        UserDefaults.standard.bool(forKey: dismissKey(type: type))
    }

    static func markDismissedToday(type: NudgeType) {
        UserDefaults.standard.set(true, forKey: dismissKey(type: type))
    }
}
