//
//  JourneyNodeView.swift
//  Abimo
//
//  One big round 3D node on the path, Duolingo-style: a kawaii icon on a
//  fat-edged circle. Three honest states — done, next, open — nothing is
//  ever "locked": any open step can be started or promoted.
//

import SwiftUI

// MARK: - NodeState

enum NodeState {
    case done
    case next   // the recommended step — the one lit node on the path
    case open   // any other unfinished step; tappable
}

/// Which state an action renders in, given the recommended next id.
func nodeState(for action: MicroAction, nextId: UUID?) -> NodeState {
    if action.isCompleted { return .done }
    return action.id == nextId ? .next : .open
}

// MARK: - JourneyNodeView

/// Positioning is the parent's job (JourneyLayout); this view only renders
/// the circle, its icon and its state animations.
struct JourneyNodeView: View {
    let action: MicroAction
    let state: NodeState
    let chapterKind: JourneyChapterKind
    let iconName: String
    let onTap: () -> Void
    let justCompletedActionId: UUID?
    var nodeSize: CGFloat = 76
    var iconSize: CGFloat = 42
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
    @State private var animatedFillColor: Color = .nodeOpenFace
    @State private var animatedEdgeColor: Color = .nodeOpenEdge
    @State private var startBob = false

    var body: some View {
        Button(action: onTap) {
            nodeContent
                .frame(width: nodeSize, height: nodeSize)
        }
        .buttonStyle(Duo3DCircleButtonStyle(fill: animatedFillColor, edge: animatedEdgeColor))
        .background {
            if state == .next {
                PulseRing(color: chapterKind.color)
                    .frame(width: nodeSize, height: nodeSize)
            }
        }
        .overlay(alignment: .top) {
            if state == .next {
                startPill
                    .offset(y: startBob ? -(nodeSize / 2) + 4 : -(nodeSize / 2))
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
        .anchorPreference(key: NodeAnchorKey.self, value: .bounds) { [action.id: $0] }
        .accessibilityLabel(action.text)
        .accessibilityValue(accessibilityState)
        .accessibilityHint("Shows step options")
        .onAppear {
            animatedFillColor = fillColor
            animatedEdgeColor = edgeColor
        }
        .onChange(of: state) { oldValue, newValue in
            if oldValue != .done && newValue == .done {
                // Bounce (keyframes) + color morph to gold together
                if !AnimationPolicy.reduceMotion { completionBounceTrigger += 1 }
                AnimationPolicy.animate(.spring(response: 0.15, dampingFraction: 0.4)) {
                    animatedFillColor = .nodeDone
                    animatedEdgeColor = .nodeDoneEdge
                }
            } else if newValue == .next && oldValue != .next {
                // The path moved on to this step: swell while the colors turn
                // to the chapter's once the pulse peaks. Works across chapters —
                // it keys on state, not on array position.
                if !AnimationPolicy.reduceMotion { unlockPulseTrigger += 1 }
                AnimationPolicy.animate(.easeInOut(duration: 0.3).delay(AnimationPolicy.reduceMotion ? 0 : 0.3)) {
                    animatedFillColor = chapterKind.color
                    animatedEdgeColor = chapterKind.edgeColor
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
        case .open: return .nodeOpenFace
        case .next: return chapterKind.color
        case .done: return .nodeDone
        }
    }

    private var edgeColor: Color {
        switch state {
        case .open: return .nodeOpenEdge
        case .next: return chapterKind.edgeColor
        case .done: return .nodeDoneEdge
        }
    }

    private var accessibilityState: String {
        switch state {
        case .done: return "Done"
        case .next: return "Next step"
        case .open: return "Open"
        }
    }

    private var startPill: some View {
        Text("START")
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundColor(chapterKind.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.white))
            .overlay(Capsule().strokeBorder(chapterKind.color, lineWidth: 2))
            .fixedSize()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var icon: some View {
        Image(iconName)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
    }

    @ViewBuilder
    private var nodeContent: some View {
        switch state {
        case .open:
            icon
                .saturation(0.25)
                .opacity(0.7)
        case .next:
            icon
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.9), lineWidth: 3)
                        .frame(width: nodeSize - 8, height: nodeSize - 8)
                )
        case .done:
            icon
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle().fill(Color.white)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.nodeDoneEdge)
                            // Only the freshly completed node's checkmark pops — the
                            // Bool stays false (no value change, no bounce) elsewhere.
                            .symbolEffect(
                                .bounce,
                                value: !AnimationPolicy.reduceMotion && justCompletedActionId == action.id
                            )
                    }
                    .frame(width: 22, height: 22)
                    .offset(x: 10, y: 8)
                }
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
        JourneyNodeView(action: make("email", true), state: .done, chapterKind: .fixWeakSpot, iconName: "IconHammer", onTap: {}, justCompletedActionId: nil)
        JourneyNodeView(action: make("search", false), state: .next, chapterKind: .proveDemand, iconName: "IconTarget", onTap: {}, justCompletedActionId: nil)
        JourneyNodeView(action: make("post", false), state: .open, chapterKind: .playYourEdge, iconName: "IconStar", onTap: {}, justCompletedActionId: nil)
    }
    .padding(60)
    .background(Color.journeyBg)
}
