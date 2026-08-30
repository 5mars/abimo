//
//  AchievementBannerView.swift
//  Abimo
//
//  Drops from the top when a badge is earned mid-session, so the unlock is
//  celebrated where it happens instead of waiting for a Profile visit.
//  Amber like the badge grid's unlocked tint; streak stays the flame banner.
//

import SwiftUI

struct AchievementBannerView: View {
    let achievement: Achievement
    @State private var appeared = false

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: achievement.icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(appeared ? 1 : 0.4)
                    .symbolEffect(.bounce, value: !AnimationPolicy.reduceMotion && appeared)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Badge unlocked")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                        .textCase(.uppercase)
                    Text(achievement.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.brandAmber)
            .cornerRadius(24)
            .duoShadow()
            .padding(.top, 60)
            Spacer()
        }
        .offset(y: appeared ? 0 : -120)
        .onAppear {
            AnimationPolicy.animate(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

#Preview {
    AchievementBannerView(achievement: .lineCook)
}
