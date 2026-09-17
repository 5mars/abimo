//
//  LaunchIntroView.swift
//  Abimo
//
//  Animated launch intro shown while the session restores. Frame one is
//  pixel-identical to the native launch screen (mascot at intrinsic size,
//  dead center, on brand coral) so the native → SwiftUI handoff is
//  invisible; then the mascot wakes up, the wordmark staggers in, and —
//  slow launches only — the critic starts muttering.
//
//  Interruptible by design: the moment auth resolves, onFinished fires
//  after at most a 0.7s grace (just enough for the bounce to land).
//  It never waits for the full animation.
//

import SwiftUI

struct LaunchIntroView: View {
    /// Flipped by RootView when auth state resolves.
    let isResolved: Bool
    /// Called when the intro is willing to be dismissed.
    let onFinished: () -> Void

    @State private var hopped = false
    @State private var wordmarkShown = false
    @State private var showQuips = false
    @State private var quip = MascotVoice.moment(for: .launching).line
    @State private var quipTimer: Timer?
    @State private var spinning = false
    @State private var startedAt = Date()
    @State private var finishTask: Task<Void, Never>?

    private let minDisplay: TimeInterval = 0.7
    private let letters = Array("abimo")

    /// The native launch screen renders MascotNeutral at its intrinsic point
    /// size, centered — matching it exactly is what makes the handoff seamless.
    private var mascotSize: CGSize {
        UIImage(named: "MascotNeutral")?.size ?? CGSize(width: 260, height: 260)
    }

    var body: some View {
        ZStack {
            Color.brand.ignoresSafeArea()

            // Mascot stays pinned at screen center for its whole life — the
            // wordmark and quips hang below it so nothing ever shifts.
            Image("MascotNeutral")
                .resizable()
                .scaledToFit()
                .frame(width: mascotSize.width, height: mascotSize.height)
                .scaleEffect(x: hopped ? 0.97 : 1.0, y: hopped ? 1.05 : 1.0)
                .offset(y: hopped ? -14 : 0)

            wordmark
                .offset(y: mascotSize.height / 2 + 44)

            VStack(spacing: 18) {
                Text(quip)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .id(quip)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))

                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(spinning ? 360 : 0))
                    .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: spinning)
            }
            .offset(y: mascotSize.height / 2 + 116)
            .opacity(showQuips ? 1 : 0)
        }
        .onAppear {
            spinning = true
            runIntro()
            maybeFinish()
        }
        .onChange(of: isResolved) { _, _ in
            maybeFinish()
        }
        .onDisappear {
            quipTimer?.invalidate()
            quipTimer = nil
            finishTask?.cancel()
        }
    }

    private var wordmark: some View {
        HStack(spacing: 2) {
            ForEach(Array(letters.enumerated()), id: \.offset) { index, letter in
                Text(String(letter))
                    .font(.system(size: 34, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(wordmarkShown ? 1 : 0)
                    .offset(y: wordmarkShown ? 0 : 14)
                    .scaleEffect(wordmarkShown ? 1 : 0.6)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.6)
                            .delay(Double(index) * 0.05),
                        value: wordmarkShown
                    )
            }
        }
    }

    // MARK: - Choreography

    private func runIntro() {
        Task {
            // Hold frame one briefly — it's the native launch screen's twin.
            try? await Task.sleep(nanoseconds: 60_000_000)
            withAnimation(.spring(response: 0.38, dampingFraction: 0.55)) { hopped = true }
            try? await Task.sleep(nanoseconds: 240_000_000)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) { hopped = false }
            wordmarkShown = true

            // Quips are for the slow path only — fast launches never see them.
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled, quipTimer == nil else { return }
            withAnimation(.easeIn(duration: 0.4)) { showQuips = true }
            quipTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: true) { _ in
                Task { @MainActor in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        quip = MascotVoice.moment(for: .launching).line
                    }
                }
            }
        }
    }

    /// Exit as soon as auth is resolved AND the minimum grace has passed —
    /// whichever is later. Never waits for the animation to complete.
    private func maybeFinish() {
        guard isResolved else { return }
        finishTask?.cancel()
        let remaining = max(0, minDisplay - Date().timeIntervalSince(startedAt))
        finishTask = Task {
            if remaining > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            onFinished()
        }
    }
}

#Preview {
    LaunchIntroView(isResolved: false) {}
}
