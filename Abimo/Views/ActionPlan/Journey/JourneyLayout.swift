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
    var nodeSize: CGFloat = 70
    var stride: CGFloat = 120        // node-center to node-center Y
    private let maxAmplitude: CGFloat = 70

    /// Zigzag ±x from the centerline, clamped so nodes keep a margin on
    /// narrow devices.
    func amplitude(width: CGFloat) -> CGFloat {
        min(maxAmplitude, (width - nodeSize) / 2 - 16)
    }

    func xOffset(_ index: Int, width: CGFloat) -> CGFloat {
        let a = amplitude(width: width)
        return index.isMultiple(of: 2) ? -a : a
    }

    func center(_ index: Int, width: CGFloat) -> CGPoint {
        CGPoint(
            x: width / 2 + xOffset(index, width: width),
            y: nodeSize / 2 + CGFloat(index) * stride
        )
    }

    func contentHeight(count: Int) -> CGFloat {
        guard count > 0 else { return 0 }
        return CGFloat(count - 1) * stride + nodeSize + DuoTokens.Edge.node
    }
}

// MARK: - JourneyRouteCanvas

/// Draws the whole route once, behind the nodes: solid muted grey for the
/// full path, re-stroked in green over the completed prefix.
struct JourneyRouteCanvas: View {
    let layout: JourneyLayout
    let actions: [MicroAction]
    let width: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard actions.count > 1 else { return }

            let points = (0..<actions.count).map { layout.center($0, width: width) }

            func segment(from a: CGPoint, to b: CGPoint) -> Path {
                var path = Path()
                path.move(to: a)
                let dy = (b.y - a.y) * 0.45
                path.addCurve(
                    to: b,
                    control1: CGPoint(x: a.x, y: a.y + dy),
                    control2: CGPoint(x: b.x, y: b.y - dy)
                )
                return path
            }

            let baseStyle = StrokeStyle(lineWidth: 7, lineCap: .round)

            for i in 0..<(points.count - 1) {
                let path = segment(from: points[i], to: points[i + 1])
                context.stroke(path, with: .color(Color.textSec.opacity(0.22)), style: baseStyle)
                if actions[i].isCompleted {
                    context.stroke(path, with: .color(.brandGreen), style: baseStyle)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
