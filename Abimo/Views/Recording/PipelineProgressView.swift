//
//  PipelineProgressView.swift
//  Abimo
//

import SwiftUI

/// Full-screen staged progress shown from stop-recording to results.
/// Each row maps to a real pipeline stage — no fake progress.
struct PipelineProgressView: View {
    @ObservedObject var pipeline: IdeaPipelineService
    let onFinished: () -> Void
    let onBackground: () -> Void
    let onDiscard: () -> Void
    let onRetry: () -> Void

    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(stageMood.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)

                Spacer().frame(height: 28)

                VStack(spacing: 14) {
                    ForEach(IdeaPipelineService.Step.allCases, id: \.rawValue) { step in
                        stageRow(step)
                    }
                }
                .duoPanel()
                .padding(.horizontal, 24)

                if case .failed(_, let message) = pipeline.stage {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.brand)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 16)
                }

                Spacer()

                controls
                    .padding(.horizontal, 32)
                    .padding(.bottom, 32)
            }
        }
        .onChange(of: pipeline.stage) { _, newStage in
            if newStage == .done {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    onFinished()
                }
            }
        }
        .interactiveDismissDisabled()
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .ideaCap)
        }
    }

    private var stageMood: MascotMood {
        switch pipeline.stage {
        case .idle, .running(.saving), .running(.transcribing),
             .running(.scouting):                               return .neutral
        case .running(.analyzing):                              return .sassy
        case .running(.planning), .done:                        return .playful
        case .failed:                                           return .grumpy
        }
    }

    @ViewBuilder
    private func stageRow(_ step: IdeaPipelineService.Step) -> some View {
        let state = rowState(for: step)

        // Single state encoding: the leading circle carries the whole story;
        // trailing shows only the live spinner.
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(leadingFill(for: state))
                    .frame(width: 38, height: 38)
                Image(systemName: leadingGlyph(for: state, step: step))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(leadingTint(for: state))
            }

            Text(step.title)
                .font(.system(size: 15, weight: state == .active ? .bold : .medium, design: .rounded))
                .foregroundColor(state == .pending ? .textSec.opacity(0.5) : .textPri)

            Spacer()

            if state == .active {
                ProgressView().tint(.brand)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state)
    }

    private func leadingFill(for state: RowState) -> Color {
        switch state {
        case .completed: return .brandGreen
        case .active:    return Color.brand.opacity(0.12)
        case .failed:    return .brand
        case .pending:   return .lockedFace
        }
    }

    private func leadingGlyph(for state: RowState, step: IdeaPipelineService.Step) -> String {
        switch state {
        case .completed: return "checkmark"
        case .failed:    return "exclamationmark"
        default:         return step.icon
        }
    }

    private func leadingTint(for state: RowState) -> Color {
        switch state {
        case .completed, .failed: return .white
        case .active:             return .brand
        case .pending:            return .textSec.opacity(0.5)
        }
    }

    private enum RowState: Equatable { case pending, active, completed, failed }

    private func rowState(for step: IdeaPipelineService.Step) -> RowState {
        switch pipeline.stage {
        case .idle:
            return step == .saving ? .active : .pending
        case .running(let current):
            if step.rawValue < current.rawValue { return .completed }
            if step == current { return .active }
            return .pending
        case .failed(let failedStep, _):
            if step.rawValue < failedStep.rawValue { return .completed }
            if step == failedStep { return .failed }
            return .pending
        case .done:
            return .completed
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch pipeline.stage {
        case .failed(let step, _):
            VStack(spacing: 12) {
                if pipeline.capHit {
                    // Cap block: the recording is retained — retry re-enters
                    // at .saving once the user upgrades or frees a slot.
                    GradientButton(title: "Unlock Abimo Plus") { showPaywall = true }
                    secondaryButton("I freed a slot — retry", tint: .brand) { onRetry() }
                    secondaryButton("Discard recording", tint: .textSec) { onDiscard() }
                } else {
                    GradientButton(title: "Try again") { onRetry() }
                    if step == .saving {
                        secondaryButton("Discard recording", tint: .brand) { onDiscard() }
                    } else {
                        secondaryButton("I'll come back later", tint: .textSec) { onBackground() }
                    }
                }
            }
        case .running(let step) where step != .saving:
            secondaryButton("Finish in background", tint: .textSec) { onBackground() }
        default:
            EmptyView()
        }
    }

    private func secondaryButton(_ label: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.duoLabel)
                .foregroundColor(tint)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
        }
        .buttonStyle(Duo3DSecondaryButtonStyle())
    }

}
