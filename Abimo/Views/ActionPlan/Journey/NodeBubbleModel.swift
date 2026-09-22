//
//  NodeBubbleModel.swift
//  Abimo
//
//  The pure half of the node bubble: which buttons a node offers in each
//  state, and where the bubble sits relative to its node. Testable without
//  a view.
//

import SwiftUI

enum NodeBubbleAction: Equatable {
    case start        // open the step sheet (the lit node only)
    case undo         // un-complete (done nodes only)
    case details      // open the sheet read-only-ish (done nodes)
}

enum NodeBubbleModel {
    static let maxWidth: CGFloat = 300
    static let margin: CGFloat = 16
    static let gap: CGFloat = 10

    static func actions(for state: NodeState) -> [NodeBubbleAction] {
        switch state {
        case .next:   return [.start]
        case .locked: return []            // the bubble just says what's coming
        case .done:   return [.undo, .details]
        }
    }

    /// Bubble frame below the node, clamped to the container's side margins.
    /// The START pill owns the space above a node, so bubbles always drop
    /// down; the path's bottom padding leaves room under the last node.
    static func frame(nodeRect: CGRect, containerWidth: CGFloat, height: CGFloat) -> CGRect {
        let width = min(maxWidth, containerWidth - margin * 2)
        var x = nodeRect.midX - width / 2
        x = max(margin, min(containerWidth - margin - width, x))
        return CGRect(x: x, y: nodeRect.maxY + gap, width: width, height: height)
    }

    /// Breathing room kept between the bubble/node and the edges of the
    /// visible window when the path auto-scrolls.
    static let autoScrollPadding: CGFloat = 12

    /// Where the node's top should land, in viewport coordinates (0 = the top
    /// of the visible window), so its bubble is fully on screen — or nil when
    /// nothing needs to move. All inputs are in one shared (global) space:
    /// `visibleTop`/`visibleBottom` bound the scroll viewport, `obstructedTop`
    /// is the first y not covered by the sticky chapter header (== visibleTop
    /// when there is none). When the bubble hangs below the fold the bubble
    /// wins, even if that tucks the node under the header.
    static func autoScrollNodeTop(
        nodeTop: CGFloat,
        bubbleBottom: CGFloat,
        visibleTop: CGFloat,
        visibleBottom: CGFloat,
        obstructedTop: CGFloat,
        padding: CGFloat = autoScrollPadding
    ) -> CGFloat? {
        let bubbleOverflow = bubbleBottom + padding - visibleBottom
        let topOverflow = obstructedTop + padding - nodeTop
        if bubbleOverflow <= 0 && topOverflow <= 0 { return nil }
        if bubbleOverflow > 0 {
            return (nodeTop - visibleTop) - bubbleOverflow
        }
        return (obstructedTop - visibleTop) + padding
    }

    /// `ScrollViewProxy.scrollTo(_:anchor:)` aligns the target's unit point
    /// with the viewport's; this solves for the y fraction that puts a node of
    /// `nodeSize` with its top at `nodeTop` (viewport coordinates).
    static func scrollAnchorY(nodeTop: CGFloat, nodeSize: CGFloat, viewportHeight: CGFloat) -> CGFloat {
        let span = viewportHeight - nodeSize
        guard span > 0 else { return 0.5 }
        return min(1, max(0, nodeTop / span))
    }
}

/// Node bounds, keyed by action id, so the bubble can anchor to the tapped
/// node from one overlay above every chapter section.
struct NodeAnchorKey: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] = [:]
    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}
