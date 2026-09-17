//
//  DailyDaresCard.swift
//  Abimo
//
//  Three rotating daily micro-quests under the momentum dashboard. Dares
//  latch when satisfied (undoing an action doesn't un-check them) and pay
//  XP into the daily goal ring; clearing all three opens the chest bonus.
//  A dashboard element, not a banner — it never competes with topBanner.
//

import SwiftUI

struct DailyDaresCard: View {
    let actionsByPlan: [UUID: [MicroAction]]
    let streak: Int
    let committedActionId: UUID?
    var context: DareContext = DareContext()

    @AppStorage(DareEngine.latchStorageKey) private var latchStore = ""
    @State private var clearedMoment: MascotMoment?
    @State private var burstTrigger = 0

    private var today: Date { Date() }
    private var hasOpenActions: Bool {
        actionsByPlan.values.flatMap { $0 }.contains { !$0.isCompleted }
    }
    private var dares: [Dare] { DareEngine.dares(for: today, hasOpenActions: hasOpenActions) }
    private var latched: Set<Dare> { DareEngine.decodeLatch(latchStore, for: today) }
    private var allCleared: Bool { dares.allSatisfy(latched.contains) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Daily Dares")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSec)
                    .textCase(.uppercase)
                Spacer()
                Text(allCleared
                     ? "+\(DareEngine.xp(latchedCount: 3)) XP"
                     : "+\(XPEngine.dareXP) XP each")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(allCleared ? .brandAmber : .textSec.opacity(0.7))
                    .contentTransition(.numericText())
            }

            if allCleared {
                HStack(spacing: 10) {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.brandAmber)
                        .symbolEffect(.bounce, value: !AnimationPolicy.reduceMotion && allCleared)
                    Text(clearedMoment?.line ?? "All three dares. Show-off.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.textPri)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94)))
            } else {
                VStack(spacing: 10) {
                    ForEach(dares) { dare in
                        dareRow(dare, done: latched.contains(dare))
                    }
                }
            }
        }
        .duoPanel()
        .overlay {
            if burstTrigger > 0 && !AnimationPolicy.reduceMotion {
                InlineConfettiView()
                    .allowsHitTesting(false)
                    .id(burstTrigger)
            }
        }
        .animation(
            AnimationPolicy.reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75),
            value: allCleared
        )
        .onAppear(perform: evaluate)
        .onChange(of: completionFingerprint) { _, _ in evaluate() }
    }

    private func dareRow(_ dare: Dare, done: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: dare.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(done ? .brandGreen : .textSec.opacity(0.6))
                .frame(width: 24)
            Text(dare.title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(done ? .textSec : .textPri)
                .strikethrough(done, color: .textSec)
            Spacer()
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(done ? .brandGreen : .textSec.opacity(0.3))
                .symbolEffect(.bounce, value: !AnimationPolicy.reduceMotion && done)
        }
    }

    /// Cheap change signal: re-evaluate whenever today's completion count
    /// or the committed action changes.
    private var completionFingerprint: Int {
        let all = actionsByPlan.values.flatMap { $0 }
        return all.filter(\.isCompleted).count &* 31
            &+ (committedActionId?.hashValue ?? 0)
            &+ context.ideasRecordedToday &* 7
            &+ (context.replayedPitchToday ? 1 : 0)
    }

    private func evaluate() {
        let wasCleared = allCleared
        var current = latched
        var newly: [Dare] = []

        for dare in dares where !current.contains(dare) {
            if DareEngine.isSatisfied(
                dare,
                actionsByPlan: actionsByPlan,
                streak: streak,
                committedActionId: committedActionId,
                context: context
            ) {
                current.insert(dare)
                newly.append(dare)
            }
        }
        guard !newly.isEmpty else { return }

        latchStore = DareEngine.encodeLatch(current, for: today)
        for dare in newly {
            AnalyticsService.shared.log(.dareCompleted(kind: dare.rawValue))
        }
        HapticEngine.selection()

        if !wasCleared && dares.allSatisfy(current.contains) {
            clearedMoment = MascotVoice.moment(for: .daresCleared)
            AnalyticsService.shared.log(.daresCleared)
            HapticEngine.success()
            SoundEngine.chime()
            burstTrigger += 1
        }
    }
}

#Preview {
    DailyDaresCard(actionsByPlan: [:], streak: 0, committedActionId: nil)
        .padding()
        .background(Color.appBg)
}
