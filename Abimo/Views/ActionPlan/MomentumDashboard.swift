//
//  MomentumDashboard.swift
//  Abimo
//

import SwiftUI

struct MomentumDashboard: View {
    let streak: Int
    let weekActivity: [Bool] // 7 bools, Mon–Sun
    let totalCompletedThisWeek: Int
    let xpToday: Int
    @Binding var dailyGoalXP: Int

    var body: some View {
        VStack(spacing: 16) {
            // Streak + daily goal header
            HStack(alignment: .center) {
                // Streak
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: streak > 0 ? "flame.fill" : "flame")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(streak > 0 ? .brandAmber : .textSec)
                            .symbolEffect(.bounce, value: streak)
                        Text("\(streak)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.textPri)
                            .contentTransition(.numericText())
                    }
                    Text("day streak")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSec)
                }

                Spacer()

                DailyGoalRing(xpToday: xpToday, goalXP: $dailyGoalXP)
            }

            // Week view
            HStack {
                HStack(spacing: 6) {
                    ForEach(0..<7, id: \.self) { i in
                        Circle()
                            .fill(weekActivity[i] ? Color.brand : Color.brand.opacity(0.12))
                            .frame(width: 14, height: 14)
                    }
                }
                Spacer()
                Text("\(totalCompletedThisWeek) action\(totalCompletedThisWeek == 1 ? "" : "s") this week")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.textSec)
            }
        }
        .duoPanel()
    }
}
