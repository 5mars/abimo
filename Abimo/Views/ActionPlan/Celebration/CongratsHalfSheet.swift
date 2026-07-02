//
//  CongratsHalfSheet.swift
//  Abimo
//

import SwiftUI

// MARK: - SheetPhase

enum SheetPhase {
    case congrats
    case picker
}

// MARK: - CongratsHalfSheet

struct CongratsHalfSheet: View {
    @ObservedObject var viewModel: ActionPlanViewModel
    let onAdvance: () -> Void

    @State private var moment: MascotMoment?
    @State private var mascotAppeared = false

    var body: some View {
        VStack(spacing: 24) {
            // The mascot IS the celebration — big, with confetti behind it
            ZStack {
                InlineConfettiView()
                    .allowsHitTesting(false)
                Image((moment?.mood ?? .playful).assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)
                    .scaleEffect(mascotAppeared ? 1 : 0.5)
                    .rotationEffect(.degrees(mascotAppeared ? 0 : -8))
            }
            .frame(width: 200, height: 180)

            MascotCalloutLine(line: moment?.line ?? "Nice work! \u{2728}")
                .padding(.horizontal, 16)

            Button {
                onAdvance()
            } label: {
                Text("Keep the momentum?")
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
            moment = MascotVoice.moment(for: .actionCompleted(count: viewModel.completedCount))
            HapticEngine.impact(style: .light)
            AnimationPolicy.animate(.spring(response: 0.4, dampingFraction: 0.6)) {
                mascotAppeared = true
            }
        }
    }
}

// MARK: - PostCompletionSheetContent

struct PostCompletionSheetContent: View {
    @ObservedObject var viewModel: ActionPlanViewModel
    let completingActionId: UUID?

    @State private var sheetPhase: SheetPhase = .congrats
    @State private var selectedDetent: PresentationDetent = .medium

    var body: some View {
        Group {
            if sheetPhase == .congrats {
                CongratsHalfSheet(viewModel: viewModel, onAdvance: advance)
                    .transition(.opacity)
            } else {
                ActionPickerSheet(
                    viewModel: viewModel,
                    mode: .postCompletion,
                    excludedActionId: completingActionId
                )
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sheetPhase)
        .presentationDetents([.medium, .large], selection: $selectedDetent)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.appBg)
    }

    private func advance() {
        // 0.3s delay lets PlayfulButtonStyle scale animation complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Set detent first — SwiftUI animates it automatically
            selectedDetent = .large
            // Stagger content swap by 0.05s to avoid jank
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                AnimationPolicy.animate(.easeInOut(duration: 0.25)) {
                    sheetPhase = .picker
                }
            }
        }
    }
}
