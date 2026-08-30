//
//  DailyGoalBannerView.swift
//  Abimo
//
//  Drops from the top when today's XP crosses the daily goal — the green
//  sibling of StreakBannerView (amber stays the streak's color).
//

import SwiftUI

struct DailyGoalBannerView: View {
    let goalXP: Int
    @State private var appeared = false
    @State private var moment: MascotMoment?

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                MascotView(mood: moment?.mood ?? .playful, size: 40, motion: .none)
                Image(systemName: "target")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .symbolEffect(.bounce, value: !AnimationPolicy.reduceMotion && appeared)
                Text(moment?.line ?? "Daily goal hit! \(goalXP) XP")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.brandGreen)
            .cornerRadius(24)
            .duoShadow()
            .padding(.top, 60)
            Spacer()
        }
        .offset(y: appeared ? 0 : -120)
        .onAppear {
            moment = MascotVoice.moment(for: .dailyGoalHit)
            AnimationPolicy.animate(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

#Preview {
    DailyGoalBannerView(goalXP: 25)
}
