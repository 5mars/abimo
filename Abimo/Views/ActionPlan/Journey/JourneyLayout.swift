//
//  JourneyLayout.swift
//  Abimo
//
//  Single source of truth for journey-path geometry. Node placement, route
//  drawing, and bubble anchoring all read from here — no magic constants
//  scattered across views, so a spacing tweak can't silently misalign them.
//

import SwiftUI

struct JourneyLayout {
    var nodeSize: CGFloat = 64
    var stride: CGFloat = 112        // node-center to node-center Y
    var mascotSize: CGFloat = 56
    private let maxAmplitude: CGFloat = 56
    private let labelGutter: CGFloat = 12
    private let edgeInset: CGFloat = 8

    /// Zigzag ±x from the centerline, clamped so nodes keep a margin on
    /// narrow devices.
    func amplitude(width: CGFloat) -> CGFloat {
        min(maxAmplitude, (width - nodeSize) / 2 - 16)
    }

    func xOffset(_ index: Int, width: CGFloat) -> CGFloat {
        let a = amplitude(width: width)
        return index.isMultiple(of: 2) ? -a : a
    }

    /// Even nodes sit left of center, odd nodes right.
    func isLeft(_ index: Int) -> Bool { index.isMultiple(of: 2) }

    func center(_ index: Int, width: CGFloat) -> CGPoint {
        CGPoint(
            x: width / 2 + xOffset(index, width: width),
            y: nodeSize / 2 + CGFloat(index) * stride
        )
    }

    /// Where a node's title/meta label goes: the inner side of the zigzag,
    /// from the node's edge to the opposite margin, one stride tall.
    func labelFrame(_ index: Int, width: CGFloat) -> CGRect {
        let c = center(index, width: width)
        let nodeEdge = nodeSize / 2 + labelGutter
        let minX = isLeft(index) ? c.x + nodeEdge : edgeInset
        let maxX = isLeft(index) ? width - edgeInset : c.x - nodeEdge
        return CGRect(x: minX, y: c.y - stride / 2, width: max(0, maxX - minX), height: stride)
    }

    /// Where the mascot stands: the outer side of the node, feet on its centerline.
    func mascotCenter(_ index: Int, width: CGFloat) -> CGPoint {
        let c = center(index, width: width)
        let dx = nodeSize / 2 + 6 + mascotSize / 2
        return CGPoint(x: isLeft(index) ? c.x - dx : c.x + dx, y: c.y)
    }

    func contentHeight(count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count - 1) * stride + nodeSize + DuoTokens.Edge.node
    }
}

/// The dash recipe shared by the grey base trail and the green overlay —
/// one definition so the two can never fall out of step.
enum JourneyTrailStyle {
    static let stroke = StrokeStyle(lineWidth: 6, lineCap: .round, dash: [10, 14])
}

// MARK: - JourneyRouteCanvas

/// Draws the full route once, behind the nodes, in muted grey. Completed
/// segments are painted green by JourneyCompletedTrail overlaid on top,
/// so a fresh completion can draw itself on instead of hard-switching.
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
                context.stroke(path, with: .color(Color.textSec.opacity(0.25)), style: JourneyTrailStyle.stroke)
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - JourneySegmentShape

/// One node-to-node curve of the route, as a Shape so it can be trimmed.
/// Same cubic as the Canvas trail (control points at 45% of the Y gap);
/// points are absolute in the path area's coordinate space.
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

// MARK: - JourneyCompletedTrail

/// Green overlay for every completed segment. Segments that were already
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
                .stroke(Color.brandGreen, style: JourneyTrailStyle.stroke)
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
