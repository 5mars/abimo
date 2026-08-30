//
//  DailyGoalRing.swift
//  Abimo
//
//  The daily-goal progress ring (repurposed from the retired
//  ProgressRingView). Green while filling, gold once the goal is hit.
//  Tapping opens a tier menu so the goal is adjustable right where it
//  lives — the same picker also exists in Settings.
//

import SwiftUI

struct DailyGoalRing: View {
    let xpToday: Int
    /// Backed by @AppStorage(DailyGoalTier.storageKey) at the call site.
    @Binding var goalXP: Int

    private var goal: DailyGoalTier { DailyGoalTier(storedXP: goalXP) }
    private var progress: Double { min(1, Double(xpToday) / Double(max(goalXP, 1))) }
    private var goalHit: Bool { xpToday >= goalXP }
    private var ringColor: Color { goalHit ? .brandAmber : .brandGreen }

    var body: some View {
        Menu {
            ForEach(DailyGoalTier.allCases) { tier in
                Button {
                    guard goalXP != tier.rawValue else { return }
                    goalXP = tier.rawValue
                    HapticEngine.selection()
                    AnalyticsService.shared.log(.goalTierChanged(tier: tier.analyticsName))
                } label: {
                    if tier.rawValue == goalXP {
                        Label("\(tier.title) \u{2014} \(tier.subtitle)", systemImage: "checkmark")
                    } else {
                        Text("\(tier.title) \u{2014} \(tier.subtitle)")
                    }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .stroke(ringColor.opacity(0.15), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(
                        AnimationPolicy.reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8),
                        value: progress
                    )

                VStack(spacing: 0) {
                    Text("\(xpToday)")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(goalHit ? .brandAmber : .textPri)
                        .contentTransition(.numericText())
                    Text("/ \(goalXP) XP")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.textSec)
                }
            }
            .frame(width: 68, height: 68)
        }
        .accessibilityLabel("Daily goal: \(xpToday) of \(goalXP) XP. Tap to change the goal.")
    }
}

#Preview {
    HStack(spacing: 24) {
        DailyGoalRing(xpToday: 0, goalXP: .constant(25))
        DailyGoalRing(xpToday: 15, goalXP: .constant(25))
        DailyGoalRing(xpToday: 25, goalXP: .constant(25))
    }
    .padding()
    .background(Color.appBg)
}
