//
//  JourneyHeaderCard.swift
//  Abimo
//
//  What this plan is for (the AI's one-line summary — stored since day one,
//  rendered for the first time here), how far along it is, how many minutes
//  are left, and the momentum the founder brings to it today.
//

import SwiftUI

struct JourneyHeaderCard: View {
    let summary: String
    let completed: Int
    let total: Int
    let remainingMinutes: Int
    let streak: Int
    let xpToday: Int

    @AppStorage(DailyGoalTier.storageKey) private var dailyGoalXP = DailyGoalTier.fallback.rawValue

    private var progress: Double { total > 0 ? Double(completed) / Double(total) : 0 }
    private var isComplete: Bool { total > 0 && completed == total }

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 10) {
                Text(summary.isEmpty ? "Small steps toward a real answer." : summary)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.textPri)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.cardEdge)
                        Capsule()
                            .fill(isComplete ? Color.brandAmber : Color.brandGreen)
                            .frame(width: max(8, geo.size.width * progress))
                    }
                }
                .frame(height: 8)
                .animation(
                    AnimationPolicy.reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8),
                    value: progress
                )

                Text(progressLine)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSec)
                    .contentTransition(.numericText())
            }

            VStack(spacing: 6) {
                DailyGoalRing(xpToday: xpToday, goalXP: $dailyGoalXP)
                HStack(spacing: 3) {
                    Image(systemName: streak > 0 ? "flame.fill" : "flame")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(streak > 0 ? .brandAmber : .textSec)
                    Text("\(streak)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.textPri)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.brandAmber.opacity(streak > 0 ? 0.15 : 0.06)))
            }
        }
        .duoPanel()
    }

    private var progressLine: String {
        if isComplete { return "All \(total) done · plate cleaned" }
        return "\(completed) of \(total) · \(remainingMinutes) min left"
    }
}
