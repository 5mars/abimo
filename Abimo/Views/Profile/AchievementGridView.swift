//
//  AchievementGridView.swift
//  Abimo
//

import SwiftUI

/// 2-column badge grid. Unlocks persist in UserDefaults so streak-based
/// badges never re-lock when a streak lapses; newly earned badges get a
/// confetti burst on the profile visit that detects them.
struct AchievementGridView: View {
    let context: AchievementContext

    @AppStorage("unlocked_achievements") private var unlockedStore = ""
    @State private var justUnlocked: Achievement?

    private var unlockedSet: Set<Achievement> {
        Set(unlockedStore.split(separator: ",").compactMap { Achievement(rawValue: String($0)) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kitchen Badges")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSec)
                    .textCase(.uppercase)
                Spacer()
                Text("\(unlockedSet.count)/\(Achievement.allCases.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.textSec.opacity(0.7))
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Achievement.allCases) { achievement in
                    badge(achievement, unlocked: unlockedSet.contains(achievement))
                }
            }
        }
        .onAppear { detectNewUnlocks() }
        .onChange(of: context.completedActionCount) { _, _ in detectNewUnlocks() }
        .overlay {
            if justUnlocked != nil {
                InlineConfettiView()
                    .allowsHitTesting(false)
            }
        }
    }

    private func badge(_ achievement: Achievement, unlocked: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(unlocked ? Color.brandAmber.opacity(0.18) : Color.black.opacity(0.05))
                    .frame(width: 40, height: 40)
                Image(systemName: achievement.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(unlocked ? .brandAmber : .textSec.opacity(0.4))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.title)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(unlocked ? .textPri : .textSec.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(achievement.subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.textSec.opacity(unlocked ? 1 : 0.5))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(Color.cardSurface)
        .cornerRadius(14)
        .opacity(unlocked ? 1 : 0.55)
        .scaleEffect(justUnlocked == achievement ? 1.06 : 1)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: justUnlocked)
    }

    private func detectNewUnlocks() {
        let computed = Achievement.unlocked(in: context)
        let previously = unlockedSet
        let fresh = computed.subtracting(previously)
        guard !fresh.isEmpty else { return }

        unlockedStore = previously.union(fresh).map(\.rawValue).sorted().joined(separator: ",")
        justUnlocked = fresh.first
        HapticEngine.success()
        SoundEngine.chime()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            justUnlocked = nil
        }
    }
}
