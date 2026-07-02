//
//  MascotSpeechBubble.swift
//  Abimo
//
//  The mascot pops up and says a line. Hosted globally as a bottom overlay
//  above the tab bar (see MainContentView) and reusable inline.
//

import SwiftUI

struct MascotSpeechBubble: View {
    let moment: MascotMoment
    var onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            Image(moment.mood.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 72, height: 72)

            Text(moment.line)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.textPri)
                .multilineTextAlignment(.leading)
                .padding(.vertical, 12)
                .padding(.leading, 20)
                .padding(.trailing, 14)
                .background(
                    SideArrowBubbleShape(arrowOffsetY: 60)
                        .fill(Color.white)
                        .shadow(color: Color.textPri.opacity(0.10), radius: 10, y: 4)
                )
                .overlay(
                    SideArrowBubbleShape(arrowOffsetY: 60)
                        .stroke(Color.cardEdge, lineWidth: 2)
                )

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
        .onTapGesture { onDismiss() }
        .offset(y: appeared ? 0 : 24)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            AnimationPolicy.animate(.spring(response: 0.4, dampingFraction: 0.72)) {
                appeared = true
            }
            SoundEngine.pop()
            HapticEngine.impact(style: .light)
        }
    }
}

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

#Preview {
    VStack {
        Spacer()
        MascotSpeechBubble(
            moment: MascotVoice.moment(for: .randomJab),
            onDismiss: {}
        )
        .padding(16)
    }
    .background(Color.appBg)
}
