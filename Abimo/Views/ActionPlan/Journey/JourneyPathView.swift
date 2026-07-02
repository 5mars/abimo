//
//  JourneyPathView.swift
//  Abimo
//

import SwiftUI

// MARK: - JourneyPathView

struct JourneyPathView: View {
    @ObservedObject var viewModel: ActionPlanViewModel

    @State private var activeBubbleId: UUID? = nil
    private let layout = JourneyLayout()

    var body: some View {
        ScrollView(showsIndicators: false) {
            ScrollViewReader { proxy in
                VStack(spacing: 28) {
                    unitHeader
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    // The path — header lives OUTSIDE the coordinate space,
                    // so node/bubble math can't drift when the title wraps.
                    GeometryReader { geo in
                        pathArea(width: geo.size.width, proxy: proxy)
                    }
                    .frame(height: layout.contentHeight(count: viewModel.orderedActions.count))
                }
                .padding(.bottom, 140)
                .task {
                    // Defer scroll to after first layout pass
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    if let activeAction = viewModel.orderedActions.first(where: { !$0.isCompleted }) {
                        AnimationPolicy.animate(.easeInOut(duration: 0.5)) {
                            proxy.scrollTo(activeAction.id, anchor: .center)
                        }
                    }
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 10).onChanged { _ in
                if activeBubbleId != nil {
                    AnimationPolicy.animate(.easeOut(duration: 0.2)) {
                        activeBubbleId = nil
                    }
                }
            }
        )
        .onTapGesture {
            if activeBubbleId != nil {
                AnimationPolicy.animate(.easeOut(duration: 0.2)) {
                    activeBubbleId = nil
                }
            }
        }
    }

    // MARK: - Unit Header

    private var unitHeader: some View {
        let completed = viewModel.completedCount
        let total = viewModel.totalCount
        let shape = RoundedRectangle(cornerRadius: DuoTokens.Radius.card, style: .continuous)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(completed == total && total > 0
                         ? "PLAN COMPLETE"
                         : "STEP \(min(completed + 1, max(total, 1))) OF \(total)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                    Text(viewModel.actionPlan?.title ?? "Your plan")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Button {
                    viewModel.showActionPicker = true
                } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(DuoPressStyle())
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.25))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: max(8, geo.size.width * viewModel.progress))
                }
            }
            .frame(height: 8)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: viewModel.progress)
        }
        .padding(20)
        .background(shape.fill(Color.brand))
        .background(shape.fill(Color.brandDark).offset(y: DuoTokens.Edge.card))
        .padding(.bottom, DuoTokens.Edge.card)
    }

    // MARK: - Path Area

    @ViewBuilder
    private func pathArea(width: CGFloat, proxy: ScrollViewProxy) -> some View {
        ZStack(alignment: .topLeading) {
            JourneyRouteCanvas(
                layout: layout,
                actions: viewModel.orderedActions,
                width: width
            )

            ForEach(Array(viewModel.orderedActions.enumerated()), id: \.element.id) { index, action in
                JourneyNodeView(
                    action: action,
                    state: nodeState(at: index, actions: viewModel.orderedActions),
                    onTap: {
                        let isOpening = activeBubbleId != action.id
                        AnimationPolicy.animate(.spring(response: 0.3, dampingFraction: 0.6)) {
                            activeBubbleId = isOpening ? action.id : nil
                        }
                        if isOpening {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    proxy.scrollTo(action.id, anchor: .top)
                                }
                            }
                        }
                    },
                    justCompletedActionId: viewModel.justCompletedActionId,
                    index: index,
                    actions: viewModel.orderedActions,
                    nodeSize: layout.nodeSize,
                    celebrationState: viewModel.celebrationState
                )
                .position(layout.center(index, width: width))
                .id(action.id)
                .cardEntrance(delay: Double(index) * 0.05)
            }

            bubbleView(width: width)
        }
    }

    // MARK: - Bubble

    @ViewBuilder
    private func bubbleView(width: CGFloat) -> some View {
        if let id = activeBubbleId,
           let index = viewModel.orderedActions.firstIndex(where: { $0.id == id }) {
            let action = viewModel.orderedActions[index]
            let state = nodeState(at: index, actions: viewModel.orderedActions)

            let center = layout.center(index, width: width)
            let bubbleWidth = min(width - 48, 340)
            let yPos = center.y + layout.nodeSize / 2 + DuoTokens.Edge.node + 6
            let rawX = center.x - bubbleWidth / 2
            let xPos = max(8, min(width - bubbleWidth - 8, rawX))
            let arrowOffset = center.x - xPos

            NodeBubbleView(
                action: action,
                state: state,
                arrowOffset: arrowOffset,
                onComplete: {
                    activeBubbleId = nil
                    Task { await viewModel.toggleMicroAction(id: action.id, isCompleted: true) }
                },
                onDismiss: {
                    activeBubbleId = nil
                }
            )
            .frame(width: bubbleWidth)
            .offset(x: xPos, y: yPos)
            .transition(.scale(scale: 0.01, anchor: .top).combined(with: .opacity))
            .zIndex(10)
            .id("bubble-\(id)")
        }
    }
}

// MARK: - Preview

#Preview {
    let viewModel = ActionPlanViewModel()

    return JourneyPathView(
        viewModel: viewModel
    )
    .background(Color.appBg)
}
