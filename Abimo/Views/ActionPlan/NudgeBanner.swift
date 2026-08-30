//
//  NudgeBanner.swift
//  Abimo
//

import SwiftUI

/// In-app nudge banner with a tinted icon per nudge type. Dismissal is
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

    private var iconName: String {
        switch nudge.type {
        case .inactivity:    return "flame.fill"
        case .commitmentDue: return "alarm.fill"
        case .milestone:     return "trophy.fill"
        case .nextAction:    return "bolt.fill"
        }
    }

    var body: some View {
        if isVisible {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tintColor.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: iconName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(tintColor)
                }

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
