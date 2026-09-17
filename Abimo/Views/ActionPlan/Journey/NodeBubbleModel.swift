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
    case start        // open the step sheet
    case pickAsNext   // make this the next step (open nodes only)
    case undo         // un-complete (done nodes only)
    case details      // open the sheet read-only-ish (done nodes)
}

enum NodeBubbleModel {
    static let maxWidth: CGFloat = 300
    static let margin: CGFloat = 16
    static let gap: CGFloat = 10

    static func actions(for state: NodeState) -> [NodeBubbleAction] {
        switch state {
        case .next: return [.start]
        case .open: return [.start, .pickAsNext]
        case .done: return [.undo, .details]
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
}

/// Node bounds, keyed by action id, so the bubble can anchor to the tapped
/// node from one overlay above every chapter section.
struct NodeAnchorKey: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] = [:]
    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue()) { $1 }
    }
}
