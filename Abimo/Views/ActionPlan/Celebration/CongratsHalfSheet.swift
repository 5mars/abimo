//
//  CongratsHalfSheet.swift
//  Abimo
//

import SwiftUI

// MARK: - CongratsHalfSheet

struct CongratsHalfSheet: View {
    @ObservedObject var viewModel: ActionPlanViewModel
    let onAdvance: () -> Void

    @State private var moment: MascotMoment?

    /// The horse acts out the biggest thing this step earned — the strip
    /// below lists it, he grudgingly hands it over. Plain steps fall back to
    /// the moment's own pose (a chapter gallop, or the XP horseshoe flip).
    private var pose: MascotExpression? {
        if moment?.trigger == .chapterComplete { return moment?.expression }
        guard let rewards = viewModel.lastRewards else { return moment?.expression }
        if rewards.badge != nil { return .medal }
        if rewards.streak != nil { return .flame }
        if rewards.goalHit != nil || rewards.milestone != nil { return .flex }
        return moment?.expression
    }

    var body: some View {
        VStack(spacing: 24) {
            // The mascot IS the celebration — big, with confetti behind it
            ZStack {
                InlineConfettiView()
                    .allowsHitTesting(false)
                MascotView(mood: moment?.mood ?? .playful, size: 160, motion: .entrance, expression: pose)
            }
            .frame(width: 200, height: 180)

            MascotCalloutLine(line: moment?.line ?? "Nice work! \u{2728}")
                .padding(.horizontal, 16)

            if let rewards = viewModel.lastRewards {
                RewardsStrip(rewards: rewards)
                    .padding(.horizontal, 8)
            }

            Button {
                onAdvance()
            } label: {
                Text("Back to the path")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(Duo3DGradientButtonStyle(fill: .brand))
        }
        .padding(.horizontal, 16)
        .background(Color.appBg)
        .onAppear {
            // Closing a whole chapter gets its own line; a plain step gets the usual one.
            let closedChapter = viewModel.chapters
                .first { $0.actions.contains { $0.id == viewModel.completingActionId } }?
                .isComplete ?? false
            moment = MascotVoice.moment(for: closedChapter ? .chapterComplete : .actionCompleted(count: viewModel.completedCount))
            HapticEngine.impact(style: .light)
        }
    }
}

// MARK: - PostCompletionSheetContent

struct PostCompletionSheetContent: View {
    @ObservedObject var viewModel: ActionPlanViewModel
    let completingActionId: UUID?

    var body: some View {
        // The path is linear: the next node is already lit behind this sheet,
        // so "back to the path" is the whole flow.
        CongratsHalfSheet(viewModel: viewModel, onAdvance: { viewModel.dismissPostCompletionSheet() })
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.appBg)
    }
}
