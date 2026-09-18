//
//  JourneyPathView.swift
//  Abimo
//
//  The plan as a Duolingo path: chapters open with a colored header, then
//  big round nodes on a centred sine. Exactly one node is lit (START); tap
//  any node for a bubble with its title and what you can do; Start opens
//  StepDetailSheet; completion runs after the sheet dismisses. A sticky
//  copy of the current chapter's header takes over as you scroll.
//

import SwiftUI

// MARK: - JourneyPathView

struct JourneyPathView: View {
    @ObservedObject var viewModel: ActionPlanViewModel

    @State private var selectedAction: MicroAction?
    @State private var pendingCompletion: (id: UUID, outcome: String, note: String?)?
    @State private var pendingPick: UUID?
    @State private var pendingUndo: UUID?
    @State private var bubbleActionId: UUID?
    @State private var chapterTops: [String: CGFloat] = [:]
    @State private var overlayTop: CGFloat = 0
    @State private var pathWidth: CGFloat = 0

    private let layout = JourneyLayout()
    private let sideMargin: CGFloat = 16

    private var stickyChapter: (chapter: JourneyChapter, index: Int)? {
        let chapters = viewModel.chapters
        let id = JourneyStickyModel.currentChapterId(
            order: chapters.map(\.id),
            tops: chapterTops,
            threshold: overlayTop - (ChapterHeaderView.inlineHeight - 8)
        )
        guard let id, let index = chapters.firstIndex(where: { $0.id == id }) else { return nil }
        return (chapters[index], index)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            ScrollViewReader { proxy in
                VStack(spacing: 8) {
                    ForEach(Array(viewModel.chapters.enumerated()), id: \.element.id) { chapterIndex, chapter in
                        chapterSection(chapter, index: chapterIndex)
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.frame(in: .named("journey")).minY
                            } action: { top in
                                chapterTops[chapter.id] = top
                            }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 140)
                .overlayPreferenceValue(NodeAnchorKey.self) { anchors in
                    bubbleOverlay(anchors)
                }
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
        .coordinateSpace(.named("journey"))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { pathWidth = $0 }
        .onScrollPhaseChange { _, phase in
            if phase != .idle, bubbleActionId != nil { bubbleActionId = nil }
        }
        .overlay(alignment: .top) {
            // Sticky chapter header: fades in once the inline one has left.
            ZStack(alignment: .top) {
                Color.clear.frame(height: 1)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("journey")).minY } action: { overlayTop = $0 }
                if let sticky = stickyChapter {
                    ChapterHeaderView(chapter: sticky.chapter, index: sticky.index, style: .sticky)
                        .padding(.horizontal, sideMargin)
                        .padding(.top, 4)
                        .id(sticky.chapter.id)
                        .transition(.opacity)
                }
            }
            .animation(AnimationPolicy.reduceMotion ? nil : .easeInOut(duration: 0.2), value: stickyChapter?.chapter.id)
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
                iconName: NodeIconCatalog.icon(for: action, in: viewModel.chapters),
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

    // MARK: - Chapter section

    private var sectionWidth: CGFloat { max(0, pathWidth - sideMargin * 2) }

    private func chapterSection(_ chapter: JourneyChapter, index: Int) -> some View {
        VStack(spacing: 0) {
            ChapterHeaderView(chapter: chapter, index: index)
            pathArea(chapter, width: sectionWidth)
                .frame(width: sectionWidth, height: layout.sectionHeight(count: chapter.actions.count), alignment: .topLeading)
        }
        .padding(.horizontal, sideMargin)
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
                JourneyNodeView(
                    action: action,
                    state: nodeState(for: action, nextId: nextId),
                    chapterKind: chapter.kind,
                    iconName: NodeIconCatalog.icon(
                        for: chapter.kind,
                        indexInChapter: index,
                        isLastInChapter: index == chapter.actions.count - 1
                    ),
                    onTap: { toggleBubble(action.id) },
                    justCompletedActionId: viewModel.justCompletedActionId,
                    nodeSize: layout.nodeSize,
                    iconSize: layout.iconSize,
                    celebrationState: viewModel.celebrationState,
                    celebratingActionId: viewModel.completingActionId
                )
                .position(layout.center(index, width: width))
                .id(action.id)
            }
        }
        .offset(y: layout.topInset)
    }

    private func toggleBubble(_ id: UUID) {
        AnimationPolicy.animate(.spring(response: 0.3, dampingFraction: 0.75)) {
            bubbleActionId = bubbleActionId == id ? nil : id
        }
    }

    // MARK: - Bubble

    @ViewBuilder
    private func bubbleOverlay(_ anchors: [UUID: Anchor<CGRect>]) -> some View {
        GeometryReader { geo in
            if let id = bubbleActionId,
               let anchor = anchors[id],
               let action = viewModel.orderedActions.first(where: { $0.id == id }),
               let chapter = viewModel.chapters.first(where: { $0.actions.contains { $0.id == id } }) {
                let node = geo[anchor]
                let frame = NodeBubbleModel.frame(nodeRect: node, containerWidth: geo.size.width, height: 0)
                let state = nodeState(for: action, nextId: viewModel.nextRecommendedAction?.id)

                ZStack(alignment: .topLeading) {
                    // Outside tap closes the bubble (and eats the tap, like Duolingo).
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { toggleBubble(id) }

                    NodeBubbleView(
                        action: action,
                        state: state,
                        chapterKind: chapter.kind,
                        xpPreview: viewModel.nextStepXP,
                        tailX: node.midX - frame.minX,
                        onAction: { handleBubble($0, action: action) }
                    )
                    .frame(width: frame.width)
                    .offset(x: frame.minX, y: frame.minY)
                    .transition(
                        AnimationPolicy.reduceMotion
                            ? .opacity
                            : .scale(scale: 0.85, anchor: .top).combined(with: .opacity)
                    )
                }
            }
        }
    }

    private func handleBubble(_ item: NodeBubbleAction, action: MicroAction) {
        switch item {
        case .start, .details:
            bubbleActionId = nil
            selectedAction = action
        case .pickAsNext:
            // Immediate: the node turns `next` under the open bubble, which
            // re-renders as "Start" — the feedback is the point.
            viewModel.pickAction(id: action.id)
        case .undo:
            bubbleActionId = nil
            Task { await viewModel.toggleMicroAction(id: action.id, isCompleted: false) }
        }
    }
}

// MARK: - Dot grid

/// Faint dot texture so the beige ground reads as a surface, not a void.
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
