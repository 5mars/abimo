//
//  JourneyPathView.swift
//  Abimo
//
//  The plan as a path that READS: a header with the plan's purpose and
//  progress, the next step as a hero card, then chapters — each a colored
//  band of zigzag nodes with their titles and minutes beside them. Tapping
//  a node opens StepDetailSheet; completion runs after the sheet dismisses.
//

import SwiftUI

// MARK: - JourneyPathView

struct JourneyPathView: View {
    @ObservedObject var viewModel: ActionPlanViewModel

    @State private var selectedAction: MicroAction?
    @State private var pendingCompletion: (id: UUID, outcome: String, note: String?)?
    @State private var pendingPick: UUID?
    @State private var pendingUndo: UUID?
    @State private var heroLine = MascotVoice.moment(for: .nextStepNudge).line
    @Namespace private var riderNS

    private let layout = JourneyLayout()
    private let pathTopInset: CGFloat = 36   // room for the bobbing NEXT pill above the first node
    private let pathBottomInset: CGFloat = 12

    var body: some View {
        ScrollView(showsIndicators: false) {
            ScrollViewReader { proxy in
                VStack(spacing: 20) {
                    JourneyHeaderCard(
                        summary: viewModel.actionPlan?.summary ?? "",
                        completed: viewModel.completedCount,
                        total: viewModel.totalCount,
                        remainingMinutes: viewModel.remainingMinutes,
                        streak: viewModel.streak,
                        xpToday: viewModel.xpToday
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .cardEntrance(delay: 0.02)

                    if let next = viewModel.nextRecommendedAction {
                        NextStepHeroCard(
                            action: next,
                            xpPreview: viewModel.nextStepXP,
                            mascotLine: heroLine,
                            onStart: { selectedAction = next },
                            onPickAnother: {
                                let fresh = viewModel.userOrderedIds.isEmpty && viewModel.completedCount == 0
                                viewModel.presentPicker(fresh ? .firstVisit : .browse)
                            }
                        )
                        .padding(.horizontal, 16)
                        .cardEntrance(delay: 0.08)
                    }

                    ForEach(Array(viewModel.chapters.enumerated()), id: \.element.id) { chapterIndex, chapter in
                        VStack(spacing: 12) {
                            if chapter.kind != .steps {
                                ChapterBannerView(chapter: chapter, index: chapterIndex)
                                    .padding(.horizontal, 16)
                            }
                            chapterBand(chapter, proxy: proxy)
                        }
                        .cardEntrance(delay: 0.14 + Double(chapterIndex) * 0.06)
                    }
                }
                .padding(.bottom, 140)
                // The mascot rides to the new next node once the completed
                // node's bounce and trail draw-on have landed.
                .animation(
                    AnimationPolicy.reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.75).delay(0.75),
                    value: viewModel.nextRecommendedAction?.id
                )
                .task {
                    // Defer scroll to after first layout pass
                    try? await Task.sleep(nanoseconds: 80_000_000)
                    if let next = viewModel.nextRecommendedAction, viewModel.completedCount > 0 {
                        AnimationPolicy.animate(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(next.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .background(
            ZStack {
                Color.journeyBg
                DotGridBackground()
            }
            .ignoresSafeArea()
        )
        .sheet(item: $selectedAction, onDismiss: runPending) { action in
            StepDetailSheet(
                action: action,
                state: nodeState(for: action, nextId: viewModel.nextRecommendedAction?.id),
                chapter: viewModel.chapters.first { $0.actions.contains { $0.id == action.id } },
                xpPreview: viewModel.nextStepXP,
                onPickAsNext: { pendingPick = action.id },
                onComplete: { outcome, note in pendingCompletion = (action.id, outcome, note) },
                onUndo: { pendingUndo = action.id }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.journeyBg)
        }
    }

    /// Runs whatever the step sheet asked for — after it has fully dismissed,
    /// so the congrats sheet never fights it for the presentation slot.
    private func runPending() {
        if let p = pendingCompletion {
            pendingCompletion = nil
            Task { await viewModel.completeAction(id: p.id, outcome: p.outcome, note: p.note) }
        }
        if let id = pendingPick {
            pendingPick = nil
            viewModel.pickAction(id: id)
        }
        if let id = pendingUndo {
            pendingUndo = nil
            Task { await viewModel.toggleMicroAction(id: id, isCompleted: false) }
        }
    }

    // MARK: - Chapter band

    private func chapterBand(_ chapter: JourneyChapter, proxy: ScrollViewProxy) -> some View {
        let pathHeight = layout.contentHeight(count: chapter.actions.count)
        return GeometryReader { geo in
            pathArea(chapter, width: geo.size.width)
                .frame(width: geo.size.width, height: pathHeight, alignment: .topLeading)
                .offset(y: pathTopInset)
        }
        .frame(height: pathHeight + pathTopInset + pathBottomInset)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: DuoTokens.Radius.card, style: .continuous)
                .fill(chapter.kind.bandColor)
        )
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func pathArea(_ chapter: JourneyChapter, width: CGFloat) -> some View {
        let nextId = viewModel.nextRecommendedAction?.id

        ZStack(alignment: .topLeading) {
            JourneyRouteCanvas(layout: layout, actions: chapter.actions, width: width)

            JourneyCompletedTrail(
                layout: layout,
                actions: chapter.actions,
                width: width,
                justCompletedActionId: viewModel.justCompletedActionId
            )

            ForEach(Array(chapter.actions.enumerated()), id: \.element.id) { index, action in
                let state = nodeState(for: action, nextId: nextId)
                let label = layout.labelFrame(index, width: width)

                JourneyNodeLabel(
                    action: action,
                    state: state,
                    alignLeading: layout.isLeft(index),
                    xpPreview: state == .next ? viewModel.nextStepXP : nil
                )
                .frame(width: label.width, height: label.height)
                .position(x: label.midX, y: label.midY)

                JourneyNodeView(
                    action: action,
                    state: state,
                    onTap: { selectedAction = action },
                    justCompletedActionId: viewModel.justCompletedActionId,
                    nodeSize: layout.nodeSize,
                    celebrationState: viewModel.celebrationState,
                    celebratingActionId: viewModel.completingActionId
                )
                .position(layout.center(index, width: width))
                .id(action.id)
            }

            // The critic stands beside whatever's next — and walks there.
            if let nextIndex = chapter.actions.firstIndex(where: { $0.id == nextId }) {
                MascotView(mood: .neutral, size: layout.mascotSize, motion: .idle)
                    .matchedGeometryEffect(id: "rider", in: riderNS)
                    .position(layout.mascotCenter(nextIndex, width: width))
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Dot grid

/// Faint dot texture so the cream ground reads as a surface, not a void.
private struct DotGridBackground: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 22
            let dot = Path(ellipseIn: CGRect(x: 0, y: 0, width: 2, height: 2))
            var y: CGFloat = 8
            while y < size.height {
                var x: CGFloat = 8
                while x < size.width {
                    context.fill(dot.offsetBy(dx: x, dy: y), with: .color(Color.textSec.opacity(0.14)))
                    x += step
                }
                y += step
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Preview

#Preview {
    let viewModel = ActionPlanViewModel()

    return JourneyPathView(
        viewModel: viewModel
    )
}
