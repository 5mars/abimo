//
//  MascotSpeechBubble.swift
//  Abimo
//
//  Inline mascot speech lines. The global popup lives in MascotCenterPopup;
//  these are the static bubbles rendered next to an existing mascot image.
//

import SwiftUI

/// Static inline variant for empty states — no popup mechanics, just the
/// mascot's line next to wherever the mascot image already is.
struct MascotSpeechLine: View {
    let line: String
    var arrowOffsetY: CGFloat = 24

    var body: some View {
        Text(line)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundColor(.textPri)
            .multilineTextAlignment(.leading)
            .padding(.vertical, 10)
            .padding(.leading, 18)
            .padding(.trailing, 12)
            .background(
                SideArrowBubbleShape(arrowOffsetY: arrowOffsetY)
                    .fill(Color.white)
            )
            .overlay(
                SideArrowBubbleShape(arrowOffsetY: arrowOffsetY)
                    .stroke(Color.cardEdge, lineWidth: 2)
            )
    }
}

/// Centered variant with a top tail — for when the mascot sits ABOVE the
/// line (celebration sheets, hero layouts).
struct MascotCalloutLine: View {
    let line: String

    var body: some View {
        Text(line)
            .font(.system(size: 16, weight: .bold, design: .rounded))
            .foregroundColor(.textPri)
            .multilineTextAlignment(.center)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity)
            .background {
                GeometryReader { geo in
                    TopArrowBubbleShape(arrowOffset: geo.size.width / 2)
                        .fill(Color.white)
                    TopArrowBubbleShape(arrowOffset: geo.size.width / 2)
                        .stroke(Color.cardEdge, lineWidth: 2)
                }
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        Spacer()
        MascotSpeechLine(line: "Record something. I can't roast air.")
        MascotCalloutLine(line: "Fine. It's good. Don't make it weird.")
            .padding(16)
    }
    .background(Color.appBg)
}
