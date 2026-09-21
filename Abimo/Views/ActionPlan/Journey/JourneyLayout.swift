//
//  JourneyLayout.swift
//  Abimo
//
//  Single source of truth for journey-path geometry. Node placement and
//  route drawing read from here — no magic constants scattered across
//  views, so a spacing tweak can't silently misalign them.
//
//  Duolingo-style: big round nodes on a centred sine — centre, right,
//  centre, left — restarting centred at every chapter.
//

import SwiftUI

struct JourneyLayout {
    var nodeSize: CGFloat = 76
    var stride: CGFloat = 104        // node-center to node-center Y
    var iconSize: CGFloat = 42
    /// Room above the first node for the bobbing START pill.
    var topInset: CGFloat = 44
    var bottomInset: CGFloat = 16
    private let maxAmplitude: CGFloat = 76

    /// Lateral slot per index: 0 = centre, +1 = right, −1 = left.
    static let lateralPattern: [CGFloat] = [0, 1, 0, -1]

    func lateralSlot(_ index: Int) -> CGFloat {
        Self.lateralPattern[index % Self.lateralPattern.count]
    }

    /// How far the side slots sit from the centreline, clamped so nodes
    /// keep a margin on narrow devices.
    func amplitude(width: CGFloat) -> CGFloat {
        max(0, min(maxAmplitude, (width - nodeSize) / 2 - 20))
    }

    func xOffset(_ index: Int, width: CGFloat) -> CGFloat {
        lateralSlot(index) * amplitude(width: width)
    }

    func center(_ index: Int, width: CGFloat) -> CGPoint {
        CGPoint(
            x: width / 2 + xOffset(index, width: width),
            y: nodeSize / 2 + CGFloat(index) * stride
        )
    }

    /// Height of the node column alone (no insets).
    func contentHeight(count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count - 1) * stride + nodeSize + DuoTokens.Edge.node
    }

    /// Height of a chapter's path area including the pill room and tail.
    func sectionHeight(count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return topInset + contentHeight(count: count) + bottomInset
    }
}

// MARK: - Sticky header selection

/// Which chapter the sticky header should show: the last one (in display
/// order) whose inline header has scrolled up past `threshold`. Pure, so the
/// scroll math is unit-testable without a ScrollView.
enum JourneyStickyModel {
    static func currentChapterId(order: [String], tops: [String: CGFloat], threshold: CGFloat) -> String? {
        order.last { (tops[$0] ?? .infinity) <= threshold }
    }

    /// How far the sticky header is pushed up by the next chapter's inline
    /// header (Duolingo-style): 0 while the next header is still below the
    /// sticky, then it slides the sticky out as it arrives, until the two
    /// coincide and the next chapter takes over.
    /// `spacing` is the gap between inline sections — kept during the push so
    /// the two banners never touch (they don't anywhere else on the path).
    static func pushOffset(nextTop: CGFloat?, overlayTop: CGFloat, headerHeight: CGFloat, spacing: CGFloat = 0) -> CGFloat {
        guard let nextTop else { return 0 }
        return min(0, nextTop - (overlayTop + headerHeight + spacing))
    }
}

/// Dotted connector between two chapters: from the last node of one to the
/// first node of the next, passing under the chapter header. Drawn in the
/// next section's background with absolute points, so it starts above the
/// section's own frame (SwiftUI doesn't clip).
enum JourneyInterChapterStyle {
    static let stroke = StrokeStyle(lineWidth: 5, lineCap: .round, dash: [0.1, 11])
}

// MARK: - Trail

/// One stroke recipe for the faint route and the golden completed overlay —
/// a single definition so the two can never fall out of step.
enum JourneyTrailStyle {
    static let stroke = StrokeStyle(lineWidth: 5, lineCap: .round)
}

/// Draws the full route once, behind the nodes, as a faint solid connector.
/// Completed segments are painted gold by JourneyCompletedTrail on top, so
/// a fresh completion can draw itself on instead of hard-switching.
struct JourneyRouteCanvas: View {
    let layout: JourneyLayout
    let actions: [MicroAction]
    let width: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard actions.count > 1 else { return }

            let points = (0..<actions.count).map { layout.center($0, width: width) }
            for i in 0..<(points.count - 1) {
                let path = JourneySegmentShape(from: points[i], to: points[i + 1])
                    .path(in: .zero)
                context.stroke(path, with: .color(Color.textSec.opacity(0.18)), style: JourneyTrailStyle.stroke)
            }
        }
        .allowsHitTesting(false)
    }
}

/// One node-to-node curve of the route, as a Shape so it can be trimmed.
/// Control points at 45% of the Y gap; points are absolute in the path
/// area's coordinate space.
struct JourneySegmentShape: Shape {
    let from: CGPoint
    let to: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: from)
        let dy = (to.y - from.y) * 0.45
        path.addCurve(
            to: to,
            control1: CGPoint(x: from.x, y: from.y + dy),
            control2: CGPoint(x: to.x, y: to.y - dy)
        )
        return path
    }
}

/// Golden overlay for every completed segment. Segments that were already
/// complete render fully; the one belonging to the action that just
/// completed draws itself on top-to-bottom, timed to land between the
/// node's completion bounce and the next node's unlock pulse.
struct JourneyCompletedTrail: View {
    let layout: JourneyLayout
    let actions: [MicroAction]
    let width: CGFloat
    let justCompletedActionId: UUID?

    var body: some View {
        ForEach(Array(actions.enumerated().dropLast()), id: \.element.id) { index, action in
            if action.isCompleted {
                TrailSegment(
                    shape: JourneySegmentShape(
                        from: layout.center(index, width: width),
                        to: layout.center(index + 1, width: width)
                    ),
                    drawsOn: action.id == justCompletedActionId
                )
            }
        }
    }

    private struct TrailSegment: View {
        let shape: JourneySegmentShape
        let drawsOn: Bool
        @State private var progress: CGFloat

        init(shape: JourneySegmentShape, drawsOn: Bool) {
            self.shape = shape
            self.drawsOn = drawsOn
            _progress = State(initialValue: drawsOn && !AnimationPolicy.reduceMotion ? 0 : 1)
        }

        var body: some View {
            shape
                .trim(from: 0, to: progress)
                .stroke(Color.nodeDone, style: JourneyTrailStyle.stroke)
                .allowsHitTesting(false)
                .onAppear {
                    guard progress < 1 else { return }
                    withAnimation(.easeInOut(duration: 0.6).delay(0.15)) {
                        progress = 1
                    }
                }
        }
    }
}
