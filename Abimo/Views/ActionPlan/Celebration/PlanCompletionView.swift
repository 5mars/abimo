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
    @State private var mascotBounce = false
    @State private var moment: MascotMoment?

    var body: some View {
        ZStack {
            // Background
            Color.appBg.ignoresSafeArea()

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
                Image((moment?.mood ?? .playful).assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(mascotBounce ? 3 : -3))
                    .onAppear {
                        if !AnimationPolicy.reduceMotion {
                            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                                mascotBounce = true
                            }
                        }
                    }

                // The critic's closing remarks
                MascotCalloutLine(line: moment?.line ?? "No complaints. This is new.")
                    .padding(.horizontal, 32)

                // Champion message
                Text("\u{1F3C6} All \(viewModel.completedCount) actions done in \(viewModel.completedMinutes) min \u{1F525}")
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

                // Done button
                GradientButton(title: "Done") {
                    onDismiss()
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
