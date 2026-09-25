//
//  PlanCompletionView.swift
//  Abimo
//

import SwiftUI
import Vortex

struct PlanCompletionView: View {
    @ObservedObject var viewModel: ActionPlanViewModel
    let onDismiss: () -> Void

    @State private var appeared = false
    @State private var moment: MascotMoment?
    @State private var showWrapUp = false

    var body: some View {
        ZStack {
            // Background
            Color.appBg.ignoresSafeArea()

            if showWrapUp {
                PlanWrapUpView(viewModel: viewModel, onDismiss: onDismiss)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                    .zIndex(1)
            } else {
                celebration
                    .transition(.opacity)
            }
        }
        .animation(AnimationPolicy.reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85), value: showWrapUp)
    }

    private var celebration: some View {
        ZStack {

            // Confetti behind everything
            if !AnimationPolicy.reduceMotion {
                VortexViewReader { proxy in
                    VortexView(.confetti) {
                        Rectangle().fill(Color.brand).frame(width: 10, height: 10).tag("square")
                        Circle().fill(Color.brandGreen).frame(width: 10).tag("circle")
                        Rectangle().fill(Color.brandAmber).frame(width: 10, height: 10).tag("square2")
                    }
                    .onAppear { proxy.burst() }
                    .allowsHitTesting(false)
                }
            }

            // Content
            VStack(spacing: 24) {
                Spacer()

                // The mascot takes the podium
                MascotView(mood: moment?.mood ?? .cool, size: 220, motion: .celebrating, expression: .trophy)

                // The critic's closing remarks
                MascotCalloutLine(line: moment?.line ?? "No complaints. This is new.")
                    .padding(.horizontal, 32)

                // The horse holds the trophy now — just the tally.
                Text("All \(viewModel.completedCount) actions done in \(MinutesFormat.short(viewModel.completedMinutes)) \u{1F525}")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Plan title
                if let plan = viewModel.actionPlan {
                    Text(plan.title)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.textSec)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                if let rewards = viewModel.lastRewards {
                    RewardsStrip(rewards: rewards)
                        .padding(.horizontal, 32)
                }

                // Second beat: recap + what's next (was a dead-end "Done")
                GradientButton(title: "What did we learn?") {
                    showWrapUp = true
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.8)
        }
        .onAppear {
            moment = MascotVoice.moment(for: .planComplete)
            AnimationPolicy.animate(.spring(response: 0.6, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }
}
