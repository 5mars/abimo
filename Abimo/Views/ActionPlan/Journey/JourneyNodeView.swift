//
//  JourneyNodeView.swift
//  Abimo
//

import SwiftUI
import Vortex

// MARK: - NodeState

/// Honest states. Micro-actions are independent by construction (the plan
/// prompt has no dependency concept), so nothing is "locked": exactly one
/// step is the recommended `next`, everything else undone is `open` and can
/// be done — or promoted to next — at will.
enum NodeState {
    case done
    case next
    case open
}

// MARK: - State Helper

func nodeState(for action: MicroAction, nextId: UUID?) -> NodeState {
    if action.isCompleted { return .done }
    return action.id == nextId ? .next : .open
}

// MARK: - JourneyNodeView

/// A single 3D path node. Positioning is the parent's job (JourneyLayout);
/// this view only renders the circle and its state animations.
struct JourneyNodeView: View {
    let action: MicroAction
    let state: NodeState
    let onTap: () -> Void
    let justCompletedActionId: UUID?
    var nodeSize: CGFloat = 64
    var celebrationState: CelebrationState = .idle
    /// The action whose completion is being celebrated — a milestone plays
    /// its (heavier) confetti on that node instead of a top banner.
    var celebratingActionId: UUID? = nil

    private var showsConfetti: Bool {
        switch celebrationState {
        case .inlineConfetti(let id): return id == action.id
        case .milestone:              return celebratingActionId == action.id
        default:                      return false
        }
    }

    @State private var completionBounceTrigger = 0
    @State private var unlockPulseTrigger = 0
    @State private var animatedFillColor: Color = .white
    @State private var animatedEdgeColor: Color = .cardEdge
    @State private var nextBob = false

    var body: some View {
        Button(action: onTap) {
            nodeContent
                .frame(width: nodeSize, height: nodeSize)
        }
        .buttonStyle(Duo3DCircleButtonStyle(fill: animatedFillColor, edge: animatedEdgeColor))
        .background {
            if state == .next {
                PulseRing(color: .brand)
                    .frame(width: nodeSize, height: nodeSize)
            }
        }
        .overlay(alignment: .top) {
            if state == .next {
                nextPill
                    .offset(y: nextBob ? -32 : -36)
                    .onAppear {
                        if !AnimationPolicy.reduceMotion {
                            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                                nextBob = true
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
        // Becoming `next`: swell to 1.15x, then relax.
        .keyframeAnimator(initialValue: 1.0, trigger: unlockPulseTrigger) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(1.15, duration: 0.3, spring: Spring(response: 0.3, dampingRatio: 0.6))
                SpringKeyframe(1.0, duration: 0.3, spring: Spring(response: 0.3, dampingRatio: 0.7))
            }
        }
        .overlay {
            if showsConfetti {
                InlineConfettiView()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            animatedFillColor = fillColor
            animatedEdgeColor = edgeColor
        }
        .onChange(of: state) { oldValue, newValue in
            if oldValue != .done && newValue == .done {
                // Bounce (keyframes) + color morph to green together
                if !AnimationPolicy.reduceMotion { completionBounceTrigger += 1 }
                AnimationPolicy.animate(.spring(response: 0.15, dampingFraction: 0.4)) {
                    animatedFillColor = .brandGreen
                    animatedEdgeColor = .brandGreenDark
                }
            } else if newValue == .next && oldValue != .next {
                // The path moved on to this step: swell while the colors turn
                // coral once the pulse peaks. Works across chapters — it keys
                // on state, not on array position.
                if !AnimationPolicy.reduceMotion { unlockPulseTrigger += 1 }
                AnimationPolicy.animate(.easeInOut(duration: 0.3).delay(AnimationPolicy.reduceMotion ? 0 : 0.3)) {
                    animatedFillColor = .brand
                    animatedEdgeColor = .brandDark
                }
            } else if oldValue != newValue {
                AnimationPolicy.animate(.easeInOut(duration: 0.3)) {
                    animatedFillColor = fillColor
                    animatedEdgeColor = edgeColor
                }
            }
        }
    }

    // MARK: - Private Helpers

    private var fillColor: Color {
        switch state {
        case .open: return .white
        case .next: return .brand
        case .done: return .brandGreen
        }
    }

    private var edgeColor: Color {
        switch state {
        case .open: return .cardEdge
        case .next: return .brandDark
        case .done: return .brandGreenDark
        }
    }

    private var nextPill: some View {
        Text("NEXT")
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
        case .open:
            Text(ActionIconMapper.icon(for: action.actionType).emoji)
                .font(.system(size: 26))
                .opacity(0.7)
        case .next:
            Text(ActionIconMapper.icon(for: action.actionType).emoji)
                .font(.system(size: 26))
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 22, weight: .bold))
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
    let make: (String, Bool) -> MicroAction = { type, done in
        MicroAction(
            id: UUID(), actionPlanId: UUID(), text: "Step", doneCriteria: "Done",
            timeEstimateMinutes: 10, priority: 1, quadrant: nil, template: nil,
            actionType: type, deepLinkData: nil, isCompleted: done,
            completedAt: done ? Date() : nil, isCommitted: false, committedAt: nil,
            scheduledFor: nil, completionOutcome: nil, completionNote: nil, createdAt: Date()
        )
    }
    HStack(spacing: 40) {
        JourneyNodeView(action: make("email", true), state: .done, onTap: {}, justCompletedActionId: nil)
        JourneyNodeView(action: make("search", false), state: .next, onTap: {}, justCompletedActionId: nil)
        JourneyNodeView(action: make("post", false), state: .open, onTap: {}, justCompletedActionId: nil)
    }
    .padding(60)
    .background(Color.journeyBg)
}
