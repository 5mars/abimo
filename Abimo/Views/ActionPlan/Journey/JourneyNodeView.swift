//
//  JourneyNodeView.swift
//  Abimo
//

import SwiftUI
import Vortex

// MARK: - NodeState

enum NodeState {
    case locked
    case active
    case completed
}

// MARK: - State Helper

func nodeState(at index: Int, actions: [MicroAction]) -> NodeState {
    let action = actions[index]
    if action.isCompleted { return .completed }
    let firstIncompleteIndex = actions.firstIndex(where: { !$0.isCompleted })
    if firstIncompleteIndex == index { return .active }
    return .locked
}

// MARK: - JourneyNodeView

/// A single 3D path node. Positioning is the parent's job (JourneyLayout);
/// this view only renders the bubble-shaped node and its state animations.
struct JourneyNodeView: View {
    let action: MicroAction
    let state: NodeState
    let onTap: () -> Void
    let justCompletedActionId: UUID?
    let index: Int
    let actions: [MicroAction]
    var nodeSize: CGFloat = 70
    var celebrationState: CelebrationState = .idle

    @State private var completionBounceTrigger = 0
    @State private var unlockPulseTrigger = 0
    @State private var animatedFillColor: Color = .lockedFace
    @State private var animatedEdgeColor: Color = .lockedEdge
    @State private var startBob = false

    var body: some View {
        Button(action: onTap) {
            nodeContent
                .frame(width: nodeSize, height: nodeSize)
        }
        .buttonStyle(Duo3DCircleButtonStyle(fill: animatedFillColor, edge: animatedEdgeColor))
        .background {
            if state == .active {
                PulseRing(color: .brand)
                    .frame(width: nodeSize, height: nodeSize)
            }
        }
        .overlay(alignment: .top) {
            if state == .active {
                startPill
                    .offset(y: startBob ? -34 : -38)
                    .onAppear {
                        if !AnimationPolicy.reduceMotion {
                            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                                startBob = true
                            }
                        }
                    }
            }
        }
        // Completion bounce: pop to 1.2x and settle, one keyframe pass.
        .keyframeAnimator(initialValue: 1.0, trigger: completionBounceTrigger) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.2, duration: 0.15, spring: Spring(response: 0.15, dampingRatio: 0.4))
                SpringKeyframe(1.0, duration: 0.15, spring: Spring(response: 0.15, dampingRatio: 0.6))
            }
        }
        // Unlock pulse on the next node: swell to 1.15x, then relax.
        .keyframeAnimator(initialValue: 1.0, trigger: unlockPulseTrigger) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.15, duration: 0.3, spring: Spring(response: 0.3, dampingRatio: 0.6))
                SpringKeyframe(1.0, duration: 0.3, spring: Spring(response: 0.3, dampingRatio: 0.7))
            }
        }
        .overlay {
            if case .inlineConfetti(let actionId) = celebrationState,
               actionId == action.id {
                InlineConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            animatedFillColor = fillColor
            animatedEdgeColor = edgeColor
        }
        .onChange(of: state) { oldValue, newValue in
            if oldValue != .completed && newValue == .completed {
                // Bounce (keyframes) + color morph coral -> green together
                if !AnimationPolicy.reduceMotion { completionBounceTrigger += 1 }
                AnimationPolicy.animate(.spring(response: 0.15, dampingFraction: 0.4)) {
                    animatedFillColor = .brandGreen
                    animatedEdgeColor = .brandGreenDark
                }
            } else if oldValue != newValue {
                // Generic state change (e.g., active->locked on undo) — animate color
                AnimationPolicy.animate(.easeInOut(duration: 0.3)) {
                    animatedFillColor = fillColor
                    animatedEdgeColor = edgeColor
                }
            }
        }
        .onChange(of: justCompletedActionId) { _, completedId in
            guard let completedId = completedId,
                  let completedIndex = actions.firstIndex(where: { $0.id == completedId }),
                  index == completedIndex + 1 else { return }

            // Swell (keyframes) while the colors fade grey -> coral once the
            // pulse peaks — the delay replaces the old asyncAfter beat.
            if !AnimationPolicy.reduceMotion { unlockPulseTrigger += 1 }
            AnimationPolicy.animate(.easeInOut(duration: 0.3).delay(AnimationPolicy.reduceMotion ? 0 : 0.3)) {
                animatedFillColor = .brand
                animatedEdgeColor = .brandDark
            }
        }
    }

    // MARK: - Private Helpers

    private var fillColor: Color {
        switch state {
        case .locked:    return .lockedFace
        case .active:    return .brand
        case .completed: return .brandGreen
        }
    }

    private var edgeColor: Color {
        switch state {
        case .locked:    return .lockedEdge
        case .active:    return .brandDark
        case .completed: return .brandGreenDark
        }
    }

    private var startPill: some View {
        Text("START")
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(.brand)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().strokeBorder(Color.brand, lineWidth: 2))
            .fixedSize()
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private var nodeContent: some View {
        switch state {
        case .locked:
            Image(systemName: "lock.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.textSec.opacity(0.5))
        case .active:
            Text(ActionIconMapper.icon(for: action.actionType).emoji)
                .font(.system(size: 28))
        case .completed:
            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
                // Only the freshly completed node's checkmark pops — the
                // Bool stays false (no value change, no bounce) elsewhere.
                .symbolEffect(
                    .bounce,
                    value: !AnimationPolicy.reduceMotion && justCompletedActionId == action.id
                )
        }
    }
}

// MARK: - Preview

#Preview {
    let actions: [MicroAction] = [
        MicroAction(
            id: UUID(),
            actionPlanId: UUID(),
            text: "Send email",
            doneCriteria: "Email sent",
            timeEstimateMinutes: 5,
            priority: 1,
            quadrant: nil,
            template: nil,
            actionType: "email",
            deepLinkData: nil,
            isCompleted: true,
            completedAt: Date(),
            isCommitted: false,
            committedAt: nil,
            scheduledFor: nil,
            completionOutcome: nil,
            completionNote: nil,
            createdAt: Date()
        ),
        MicroAction(
            id: UUID(),
            actionPlanId: UUID(),
            text: "Search online",
            doneCriteria: "Found resources",
            timeEstimateMinutes: 10,
            priority: 2,
            quadrant: nil,
            template: nil,
            actionType: "search",
            deepLinkData: nil,
            isCompleted: false,
            completedAt: nil,
            isCommitted: false,
            committedAt: nil,
            scheduledFor: nil,
            completionOutcome: nil,
            completionNote: nil,
            createdAt: Date()
        ),
        MicroAction(
            id: UUID(),
            actionPlanId: UUID(),
            text: "Post update",
            doneCriteria: "Post published",
            timeEstimateMinutes: 15,
            priority: 3,
            quadrant: nil,
            template: nil,
            actionType: "post",
            deepLinkData: nil,
            isCompleted: false,
            completedAt: nil,
            isCommitted: false,
            committedAt: nil,
            scheduledFor: nil,
            completionOutcome: nil,
            completionNote: nil,
            createdAt: Date()
        ),
    ]

    VStack(spacing: 50) {
        JourneyNodeView(
            action: actions[0],
            state: .completed,
            onTap: {},
            justCompletedActionId: nil,
            index: 0,
            actions: actions
        )
        JourneyNodeView(
            action: actions[1],
            state: .active,
            onTap: {},
            justCompletedActionId: nil,
            index: 1,
            actions: actions
        )
        JourneyNodeView(
            action: actions[2],
            state: .locked,
            onTap: {},
            justCompletedActionId: nil,
            index: 2,
            actions: actions
        )
    }
    .padding(50)
    .background(Color.appBg)
}
