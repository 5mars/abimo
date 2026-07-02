//
//  PlanCompletionView.swift
//  Abimo
//

import SwiftUI
import Lottie
import Vortex

struct PlanCompletionView: View {
    @ObservedObject var viewModel: ActionPlanViewModel
    let onDismiss: () -> Void

    @State private var playbackMode: LottiePlaybackMode = .paused
    @State private var appeared = false
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

                // Lottie trophy animation
                LottieView(animation: .named("trophy"))
                    .playbackMode(playbackMode)
                    .frame(width: 200, height: 200)

                // Champion message
                Text("\u{1F3C6} Champion! All \(viewModel.completedCount) actions done in \(viewModel.completedMinutes) min \u{1F525}")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
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

                // The critic's closing remarks
                HStack(alignment: .center, spacing: 6) {
                    Image((moment?.mood ?? .playful).assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                    MascotSpeechLine(line: moment?.line ?? "No complaints. This is new.", arrowOffsetY: 22)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

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
            if !AnimationPolicy.reduceMotion {
                playbackMode = .playing(.fromProgress(0, toProgress: 1, loopMode: .playOnce))
            }
        }
    }
}
