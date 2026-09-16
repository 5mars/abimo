//
//  RewardsStrip.swift
//  Abimo
//
//  The receipt for a completion: XP, then any milestone, streak, daily goal
//  and badge — rows staggering in. One soft chime when there's more than
//  the XP line, so a big day sounds like one.
//

import SwiftUI

struct RewardsStrip: View {
    let rewards: CompletionRewards

    private struct Row: Identifiable {
        let id: Int
        let icon: String
        let text: String
        let tint: Color
    }

    private var rows: [Row] {
        var out: [Row] = [
            Row(id: 0, icon: "star.fill",
                text: "+\(rewards.xp) XP" + (rewards.firstOfDay ? " · first of the day" : ""),
                tint: .brandAmber),
        ]
        if let m = rewards.milestone {
            out.append(Row(id: 1, icon: "checkmark.seal.fill", text: "\(m) steps done on this plan", tint: .brandGreen))
        }
        if let s = rewards.streak {
            out.append(Row(id: 2, icon: "flame.fill", text: "\(s)-day streak", tint: .brandAmber))
        }
        if let g = rewards.goalHit {
            out.append(Row(id: 3, icon: "target", text: "Daily goal hit · \(g) XP", tint: .brandGreen))
        }
        if let b = rewards.badge {
            out.append(Row(id: 4, icon: b.icon, text: "Badge unlocked: \(b.title)", tint: .brandAmber))
        }
        return out
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(row.tint.opacity(0.18))
                            .frame(width: 28, height: 28)
                        Image(systemName: row.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(row.tint)
                    }
                    Text(row.text)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.textPri)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: DuoTokens.Radius.inset, style: .continuous)
                        .fill(Color.white)
                )
                .cardEntrance(delay: 0.15 + Double(index) * 0.08)
            }
        }
        .onAppear {
            guard rewards.rowCount >= 2 else { return }
            let lastRow = 0.15 + Double(rewards.rowCount - 1) * 0.08
            DispatchQueue.main.asyncAfter(deadline: .now() + lastRow + 0.2) {
                HapticEngine.impact(style: .light)
                SoundEngine.chime()
            }
        }
    }
}
