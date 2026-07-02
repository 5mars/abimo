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

    @State private var tastingMessageIndex = 0
    @State private var tastingTimer: Timer?

    private let tastingMessages = [
        "Simmering your strategy…",
        "Adding a pinch of market data…",
        "Checking what the competition plated…",
    ]

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(stageMood.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 140, height: 140)

                Spacer().frame(height: 12)

                Text(headline)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Spacer().frame(height: 28)

                VStack(spacing: 14) {
                    ForEach(IdeaPipelineService.Step.allCases, id: \.rawValue) { step in
                        stageRow(step)
                    }
                }
                .padding(20)
                .background(Color.cardSurface)
                .cornerRadius(24)
                .padding(.horizontal, 24)

                if case .failed(_, let message) = pipeline.stage {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundColor(.brandRed)
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
            syncTastingTimer(for: newStage)
        }
        .onAppear { syncTastingTimer(for: pipeline.stage) }
        .onDisappear {
            tastingTimer?.invalidate()
            tastingTimer = nil
        }
        .interactiveDismissDisabled()
    }

    private var stageMood: MascotMood {
        switch pipeline.stage {
        case .idle, .running(.saving), .running(.transcribing): return .neutral
        case .running(.analyzing):                              return .sassy
        case .running(.planning), .done:                        return .playful
        case .failed:                                           return .grumpy
        }
    }

    private var headline: String {
        switch pipeline.stage {
        case .idle, .running(.saving):    return "Got it — kitchen's on it"
        case .running(.transcribing):     return "Got it — kitchen's on it"
        case .running(.analyzing):        return tastingMessages[tastingMessageIndex % tastingMessages.count]
        case .running(.planning), .done:  return "Order up!"
        case .failed:                     return "Small kitchen fire"
        }
    }

    @ViewBuilder
    private func stageRow(_ step: IdeaPipelineService.Step) -> some View {
        let state = rowState(for: step)

        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(state == .completed ? Color.brandGreen.opacity(0.15) : Color.brand.opacity(state == .active ? 0.12 : 0.05))
                    .frame(width: 38, height: 38)
                Image(systemName: step.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(state == .completed ? .brandGreen : (state == .pending ? .textSec.opacity(0.4) : .brand))
            }

            Text(step.title)
                .font(.system(size: 15, weight: state == .active ? .semibold : .medium))
                .foregroundColor(state == .pending ? .textSec.opacity(0.5) : .textPri)

            Spacer()

            switch state {
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.brandGreen)
            case .active:
                ProgressView().tint(.brand)
            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.brandRed)
            case .pending:
                Circle()
                    .strokeBorder(Color.textSec.opacity(0.25), lineWidth: 1.5)
                    .frame(width: 16, height: 16)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state)
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
                GradientButton(title: "Try again") { onRetry() }
                if step == .saving {
                    Button {
                        onDiscard()
                    } label: {
                        Text("Discard recording")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.brandRed)
                    }
                    .frame(minHeight: 44)
                } else {
                    finishInBackgroundButton(label: "I'll come back later")
                }
            }
        case .running(let step) where step != .saving:
            finishInBackgroundButton(label: "Finish in background")
        default:
            EmptyView()
        }
    }

    private func finishInBackgroundButton(label: String) -> some View {
        Button {
            onBackground()
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.textSec)
        }
        .frame(minHeight: 44)
    }

    private func syncTastingTimer(for stage: IdeaPipelineService.Stage) {
        if case .running(.analyzing) = stage {
            guard tastingTimer == nil else { return }
            tastingTimer = Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
                Task { @MainActor in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        tastingMessageIndex += 1
                    }
                }
            }
        } else {
            tastingTimer?.invalidate()
            tastingTimer = nil
        }
    }
}
