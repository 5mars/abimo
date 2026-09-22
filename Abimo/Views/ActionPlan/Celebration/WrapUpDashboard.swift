//
//  WrapUpDashboard.swift
//  Abimo
//
//  The little dashboard at the top of "What did we learn?": what the founder
//  actually did, in numbers and in their own words. Built only from data the
//  app already stores — no new calls.
//

import SwiftUI

struct WrapUpDashboard: View {
    let actions: [MicroAction]
    let completedMinutes: Int
    let daysToComplete: Int
    let streak: Int
    /// Score before → after when a re-taste exists (from score history or the
    /// re-taste just performed). Hidden when there is only one score.
    let scoreChange: (old: Int, new: Int)?

    private var completed: [MicroAction] { actions.filter(\.isCompleted) }
    private var didIt: Int { completed.filter { $0.completionOutcome != "didnt_work" }.count }
    private var didntWork: Int { completed.filter { $0.completionOutcome == "didnt_work" }.count }
    /// Flat per-action XP; day bonuses aren't stored per step, so this is the floor.
    private var xpEarned: Int { completed.count * XPEngine.actionXP }
    private var noted: [MicroAction] {
        completed.filter { !($0.completionNote ?? "").isEmpty }
    }
    private static let maxNotes = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Tiles
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                tile("checkmark.circle.fill", "\(completed.count)", completed.count == 1 ? "step done" : "steps done", .brandGreen,
                     sub: didntWork > 0 ? "\(didIt) worked · \(didntWork) didn't" : nil)
                tile("clock.fill", MinutesFormat.short(completedMinutes), "invested", .brandBlue,
                     sub: "\(daysToComplete) \(daysToComplete == 1 ? "day" : "days")")
                tile("flame.fill", "\(streak)", "day streak", .brandAmber, sub: nil)
                tile("bolt.fill", "\(xpEarned)", "XP earned", .brand, sub: nil)
            }

            if let scoreChange {
                scoreRow(scoreChange)
            }

            if !noted.isEmpty {
                Divider().overlay(Color.cardEdge)
                Text("IN YOUR WORDS")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.textSec)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(noted.prefix(Self.maxNotes)) { action in
                        noteRow(action)
                    }
                    if noted.count > Self.maxNotes {
                        Text("+\(noted.count - Self.maxNotes) more in the plan")
                            .font(.duoCaption)
                            .foregroundColor(.textTertiary)
                            .padding(.leading, 34)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel()
    }

    // MARK: - Bits

    private func tile(_ icon: String, _ value: String, _ label: String, _ tint: Color, sub: String?) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.duoCaption)
                    .foregroundColor(.textSec)
                if let sub {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: DuoTokens.Radius.inset, style: .continuous).fill(Color.insetBg))
    }

    private func scoreRow(_ change: (old: Int, new: Int)) -> some View {
        let delta = change.new - change.old
        let tint: Color = delta > 0 ? .brandGreen : delta < 0 ? .danger : .textSec
        return HStack(spacing: 10) {
            Image(systemName: delta > 0 ? "arrow.up.right" : delta < 0 ? "arrow.down.right" : "equal")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(tint.opacity(0.12)))
            Text("Score")
                .font(.duoLabel)
                .foregroundColor(.textSec)
            Spacer()
            HStack(spacing: 6) {
                Text("\(change.old)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.textSec)
                Image(systemName: "arrow.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.textTertiary)
                Text("\(change.new)")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(.textPri)
                if delta != 0 {
                    Text(delta > 0 ? "+\(delta)" : "\(delta)")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundColor(tint)
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: DuoTokens.Radius.inset, style: .continuous).fill(Color.insetBg))
    }

    private func noteRow(_ action: MicroAction) -> some View {
        let worked = action.completionOutcome != "didnt_work"
        let tint: Color = worked ? .brandGreen : .brandAmber
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: ActionIconMapper.icon(for: action.actionType).symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 24, height: 24)
                .background(Circle().fill(tint.opacity(0.12)))
            VStack(alignment: .leading, spacing: 1) {
                Text(action.completionNote ?? "")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textPri)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(action.text)
                    .font(.system(size: 11))
                    .foregroundColor(.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
