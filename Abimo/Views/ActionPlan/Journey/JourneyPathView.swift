//
//  JourneyPathView.swift
//  Abimo
//
//  The plan as a Duolingo path: chapters open with a colored header, then
//  big round nodes on a centred sine. The path is linear — exactly one node
//  is lit (START), everything after it is locked; tap any node for a bubble
//  with its title; Start opens StepDetailSheet; completion runs after the
//  sheet dismisses. A sticky copy of the current chapter's header takes
//  over as you scroll, and the path ends on the next-chapter gate.
//

import SwiftUI

// MARK: - JourneyPathView

struct JourneyPathView: View {
    @ObservedObject var viewModel: ActionPlanViewModel

    @State private var selectedAction: MicroAction?
    @State private var pendingCompletion: (id: UUID, outcome: String, note: String?)?
    @State private var pendingUndo: UUID?
    @State private var bubbleActionId: UUID?
    @State private var paywallContext: PaywallView.Context?
    @State private var gateError: String?
    @ObservedObject private var entitlements = EntitlementService.shared
    @State private var chapterTops: [String: CGFloat] = [:]
    @State private var overlayTop: CGFloat = 0
    @State private var pathWidth: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    /// The open bubble's frame in global space (same space as `overlayTop`),
    /// so the path can scroll it fully into view.
    @State private var bubbleGlobalFrame: CGRect?
    /// The tapped node's top edge in the same global space.
    @State private var bubbleNodeGlobalTop: CGFloat?
    /// True while the path is scrolling on the bubble's behalf — that scroll
    /// must not dismiss the very bubble it is revealing.
    @State private var autoScrolling = false

    private let layout = JourneyLayout()
    private let sideMargin: CGFloat = 16
    private let sectionSpacing: CGFloat = 8

    /// The chapter whose inline header has reached (or passed) the top, and
    /// how far the following header has pushed it up.
    private var stickyChapter: (chapter: JourneyChapter, index: Int, offset: CGFloat)? {
        let chapters = viewModel.chapters
        let id = JourneyStickyModel.currentChapterId(
            order: chapters.map(\.id),
            tops: chapterTops,
            threshold: overlayTop + 0.5
        )
        guard let id, let index = chapters.firstIndex(where: { $0.id == id }) else { return nil }
        let nextTop = index + 1 < chapters.count ? chapterTops[chapters[index + 1].id] : nil
        let offset = JourneyStickyModel.pushOffset(
            nextTop: nextTop, overlayTop: overlayTop,
            headerHeight: ChapterHeaderView.inlineHeight, spacing: sectionSpacing
        )
        return (chapters[index], index, offset)
    }

    /// Enough room under the last section for its header to reach the top,
    /// so the sticky handoff never rests half-pushed at the end of the scroll.
    private var bottomPadding: CGFloat {
        guard let last = viewModel.chapters.last else { return 140 }
        let tail = layout.sectionHeight(count: last.actions.count) + 12 + 190
        return max(140, viewportHeight - tail)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            ScrollViewReader { proxy in
                VStack(spacing: sectionSpacing) {
                    ForEach(Array(viewModel.chapters.enumerated()), id: \.element.id) { chapterIndex, chapter in
                        chapterSection(chapter, index: chapterIndex)
                            // Global space on purpose: the sticky overlay is not a
                            // descendant of the ScrollView, so a named space would
                            // resolve differently on each side.
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.frame(in: .global).minY
                            } action: { top in
                                chapterTops[chapter.id] = top
                            }
                    }
                    if viewModel.isFinalChapterDone {
                        finalChapterRow
                            .padding(.horizontal, sideMargin)
                            .padding(.top, 12)
                    } else if viewModel.partCount < ActionPlanViewModel.maxChapters, !viewModel.microActions.isEmpty {
                        NextChapterGateCard(
                            state: viewModel.isExtending ? .generating : (viewModel.nextRecommendedAction == nil ? .ready : .locked),
                            nextChapter: viewModel.partCount + 1,
                            isPlus: entitlements.isPremium,
                            onUnlock: unlockNextChapter
                        )
                        .padding(.horizontal, sideMargin)
                        .padding(.top, 12)
                        if let gateError {
                            Text(gateError)
                                .font(.system(size: 12))
                                .foregroundColor(.danger)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, sideMargin)
                        }
                    }
                }
                .padding(.bottom, bottomPadding)
                .overlayPreferenceValue(NodeAnchorKey.self) { anchors in
                    bubbleOverlay(anchors)
                }
                .onChange(of: bubbleActionId) { _, id in
                    guard let id else { bubbleGlobalFrame = nil; bubbleNodeGlobalTop = nil; return }
                    Task { await revealBubble(for: id, proxy: proxy) }
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
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            pathWidth = size.width
            viewportHeight = size.height
        }
        .onScrollPhaseChange { _, phase in
            // A programmatic reveal scroll is ours; only the user's scroll dismisses.
            if autoScrolling {
                if phase == .idle { autoScrolling = false }
                return
            }
            if phase != .idle, bubbleActionId != nil { bubbleActionId = nil }
        }
        .overlay(alignment: .top) {
            // Sticky chapter header: takes over the moment the inline header
            // reaches the top (they coincide, so nothing jumps), then the next
            // chapter's header pushes it out. No backing — the pushed banner
            // alone slides up and is clipped at the top edge; with the push,
            // banners never overlap, so there is nothing to hide.
            ZStack(alignment: .top) {
                Color.clear.frame(height: 1)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { overlayTop = $0 }
                if let sticky = stickyChapter {
                    ChapterHeaderView(chapter: sticky.chapter, index: sticky.index, style: .sticky)
                        .padding(.horizontal, sideMargin)
                        .offset(y: sticky.offset)
                        .frame(maxWidth: .infinity)
                        .frame(height: ChapterHeaderView.inlineHeight, alignment: .top)
                        .clipped()
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
        .sheet(item: $paywallContext) { context in
            PaywallView(context: context)
        }
        .sheet(item: $selectedAction, onDismiss: runPending) { action in
            StepDetailSheet(
                action: action,
                state: nodeState(for: action, nextId: viewModel.nextRecommendedAction?.id),
                chapter: viewModel.chapters.first { $0.actions.contains { $0.id == action.id } },
                iconName: NodeIconCatalog.icon(for: action, in: viewModel.chapters),
                xpPreview: viewModel.nextStepXP,
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
        if let id = pendingUndo {
            pendingUndo = nil
            Task { await viewModel.toggleMicroAction(id: id, isCompleted: false) }
        }
    }

    // MARK: - Next chapter gate

    private func unlockNextChapter() {
        gateError = nil
        guard entitlements.isPremium else {
            AnalyticsService.shared.log(.gateHit(gate: "next_chapter", source: "path"))
            paywallContext = .nextChapter
            return
        }
        Task {
            do {
                try await viewModel.requestNextChapter()
            } catch {
                gateError = ChapterError.from(error).message
            }
        }
    }

    /// After chapter five there is nothing left to unlock — say so instead of
    /// letting the card silently vanish.
    private var finalChapterRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "flag.checkered")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.brand)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.brand.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text("Five chapters, cooked.")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                Text("That's the whole ladder. Re-taste the idea to see the number move — or ship it.")
                    .font(.system(size: 12))
                    .foregroundColor(.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel(fill: .insetBg)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Chapter section

    private var sectionWidth: CGFloat { max(0, pathWidth - sideMargin * 2) }

    private func chapterSection(_ chapter: JourneyChapter, index: Int) -> some View {
        VStack(spacing: 0) {
            ChapterHeaderView(chapter: chapter, index: index)
            pathArea(chapter, width: sectionWidth)
                .background {
                    // Plus chapters stand on different ground: a soft band in the
                    // rung's colour behind the path, so "chapter 3" feels like a
                    // new place, not more of chapter 1.
                    if let rung = chapter.rung {
                        RoundedRectangle(cornerRadius: DuoTokens.Radius.card, style: .continuous)
                            .fill(rung.band)
                            .overlay(
                                RoundedRectangle(cornerRadius: DuoTokens.Radius.card, style: .continuous)
                                    .strokeBorder(rung.face.opacity(0.18), lineWidth: 1.5)
                            )
                            .padding(.top, layout.topInset - 12)
                            .padding(.bottom, -4)
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: sectionWidth, height: layout.sectionHeight(count: chapter.actions.count), alignment: .topLeading)
        }
        .background(alignment: .topLeading) {
            // One long road: a dotted link from the previous chapter's last
            // node, under this header, to this chapter's first node.
            if index > 0 {
                interChapterConnector(from: viewModel.chapters[index - 1], to: chapter)
            }
        }
        .padding(.horizontal, sideMargin)
    }

    private func interChapterConnector(from previous: JourneyChapter, to chapter: JourneyChapter) -> some View {
        let width = sectionWidth
        let lastPrev = layout.center(previous.actions.count - 1, width: width)
        // The previous node sits (bottomInset + section spacing) above this
        // section's top, half a node above its own area's bottom edge.
        let from = CGPoint(x: lastPrev.x, y: -(sectionSpacing + layout.bottomInset + layout.nodeSize / 2 + DuoTokens.Edge.node))
        let first = layout.center(0, width: width)
        let to = CGPoint(x: first.x, y: ChapterHeaderView.inlineHeight + layout.topInset + first.y)
        return JourneySegmentShape(from: from, to: to)
            .stroke(Color.textSec.opacity(0.4), style: JourneyInterChapterStyle.stroke)
            .frame(width: width, height: 1, alignment: .topLeading)
            .allowsHitTesting(false)
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
                    accent: chapter.rung.map { ($0.face, $0.edge) },
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

    /// Scrolls just enough that the bubble (and, when possible, its node)
    /// sits inside the visible window — under the sticky header, above the
    /// bottom edge. Waits one layout pass so the bubble has a measured frame.
    private func revealBubble(for id: UUID, proxy: ScrollViewProxy) async {
        try? await Task.sleep(nanoseconds: 60_000_000)
        guard bubbleActionId == id, let bubble = bubbleGlobalFrame, let nodeTop = bubbleNodeGlobalTop, viewportHeight > 0 else { return }
        let obstructed = overlayTop + (stickyChapter != nil ? ChapterHeaderView.inlineHeight : 0)
        guard let targetTop = NodeBubbleModel.autoScrollNodeTop(
            nodeTop: nodeTop,
            bubbleBottom: bubble.maxY,
            visibleTop: overlayTop,
            visibleBottom: overlayTop + viewportHeight,
            obstructedTop: obstructed
        ) else { return }
        let y = NodeBubbleModel.scrollAnchorY(nodeTop: targetTop, nodeSize: layout.nodeSize, viewportHeight: viewportHeight)
        autoScrolling = true
        AnimationPolicy.animate(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: y))
        }
        // If nothing actually moved, no phase change arrives — don't leave the guard armed.
        try? await Task.sleep(nanoseconds: 700_000_000)
        autoScrolling = false
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
                // The overlay spans the whole scroll content; its global origin
                // turns content-space rects into the space `overlayTop` lives in.
                let overlayOrigin = geo.frame(in: .global).origin

                ZStack(alignment: .topLeading) {
                    // Outside tap closes the bubble (and eats the tap, like Duolingo).
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { toggleBubble(id) }

                    NodeBubbleView(
                        action: action,
                        state: state,
                        chapterKind: chapter.kind,
                        accent: chapter.rung.map { ($0.face, $0.edge) },
                        xpPreview: viewModel.nextStepXP,
                        tailX: node.midX - frame.minX,
                        onAction: { handleBubble($0, action: action) }
                    )
                    .frame(width: frame.width)
                    .offset(x: frame.minX, y: frame.minY)
                    // `.offset` is a transform — a frame read here would ignore it,
                    // so the global rect is rebuilt from the anchor instead. Only the
                    // bubble's height is measured.
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height in
                        bubbleGlobalFrame = CGRect(
                            x: frame.minX + overlayOrigin.x, y: frame.minY + overlayOrigin.y,
                            width: frame.width, height: height
                        )
                        bubbleNodeGlobalTop = node.minY + overlayOrigin.y
                    }
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
