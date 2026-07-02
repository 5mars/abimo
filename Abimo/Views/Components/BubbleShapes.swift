//
//  BubbleShapes.swift
//  Abimo
//
//  Shared speech-bubble shapes (moved out of NodeBubbleView so the mascot
//  speech bubble can use them too).
//

import SwiftUI

// MARK: - BubbleShape (arrow at bottom — pointing down)

/// Rounded rectangle with a downward-pointing triangle arrow at bottom center.
struct BubbleShape: Shape {
    var arrowOffset: CGFloat

    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 12
        let arrowWidth: CGFloat = 12
        let arrowHeight: CGFloat = 8

        let bodyRect = CGRect(
            x: rect.minX, y: rect.minY,
            width: rect.width, height: rect.height - arrowHeight
        )

        var path = Path()
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        let arrowTipX = max(arrowWidth / 2 + cornerRadius, min(rect.width - arrowWidth / 2 - cornerRadius, arrowOffset))
        path.move(to: CGPoint(x: arrowTipX - arrowWidth / 2, y: bodyRect.maxY))
        path.addLine(to: CGPoint(x: arrowTipX + arrowWidth / 2, y: bodyRect.maxY))
        path.addLine(to: CGPoint(x: arrowTipX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

// MARK: - TopArrowBubbleShape (arrow at top — pointing up)

/// Rounded rectangle with an upward-pointing triangle arrow at top center.
struct TopArrowBubbleShape: Shape {
    var arrowOffset: CGFloat

    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 12
        let arrowWidth: CGFloat = 12
        let arrowHeight: CGFloat = 8

        let bodyRect = CGRect(
            x: rect.minX, y: rect.minY + arrowHeight,
            width: rect.width, height: rect.height - arrowHeight
        )

        var path = Path()
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        let arrowTipX = max(arrowWidth / 2 + cornerRadius, min(rect.width - arrowWidth / 2 - cornerRadius, arrowOffset))
        path.move(to: CGPoint(x: arrowTipX - arrowWidth / 2, y: bodyRect.minY))
        path.addLine(to: CGPoint(x: arrowTipX + arrowWidth / 2, y: bodyRect.minY))
        path.addLine(to: CGPoint(x: arrowTipX, y: rect.minY))
        path.closeSubpath()

        return path
    }
}

// MARK: - SideArrowBubbleShape (arrow on the leading edge — pointing left)

/// Rounded rectangle with a leftward-pointing triangle tail on the leading
/// edge, for speech bubbles sitting to the right of the speaker.
struct SideArrowBubbleShape: Shape {
    /// Vertical position of the tail tip, from the top of the bubble.
    var arrowOffsetY: CGFloat

    func path(in rect: CGRect) -> Path {
        let cornerRadius: CGFloat = 14
        let arrowWidth: CGFloat = 8
        let arrowHeight: CGFloat = 12

        let bodyRect = CGRect(
            x: rect.minX + arrowWidth, y: rect.minY,
            width: rect.width - arrowWidth, height: rect.height
        )

        var path = Path()
        path.addRoundedRect(in: bodyRect, cornerSize: CGSize(width: cornerRadius, height: cornerRadius))

        let tipY = max(arrowHeight / 2 + cornerRadius, min(rect.height - arrowHeight / 2 - cornerRadius, arrowOffsetY))
        path.move(to: CGPoint(x: bodyRect.minX, y: tipY - arrowHeight / 2))
        path.addLine(to: CGPoint(x: bodyRect.minX, y: tipY + arrowHeight / 2))
        path.addLine(to: CGPoint(x: rect.minX, y: tipY))
        path.closeSubpath()

        return path
    }
}
