//
//  WalkInOverlays.swift
//  Abimo
//
//  Dumb views for the first-user walk-in tour. All state and analytics live
//  in WalkInDirector — these just render a line and forward taps.
//

import SwiftUI

// MARK: - WalkInHintBubble

/// Small in-context hint card. With `tailFraction` set it grows a
/// down-pointing tail (for sitting above the tab bar, aimed at a tab);
/// without it, it's a plain rounded banner (Actions tab).
struct WalkInHintBubble: View {
    let line: String
    var primaryLabel: String? = nil
    var onPrimary: (() -> Void)? = nil
    let onSkip: () -> Void
    /// Horizontal position of the tail tip as a fraction of bubble width.
    var tailFraction: CGFloat? = nil

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image("MascotNeutral")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)

                Text(line)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPri)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button(action: onSkip) {
                    Text("Not now")
                        .font(.duoLabel)
                        .foregroundColor(.textSec)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(DuoPressStyle())

                Spacer()

                if let primaryLabel, let onPrimary {
                    Button(action: onPrimary) {
                        Text(primaryLabel)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .frame(height: 36)
                    }
                    .buttonStyle(Duo3DButtonStyle(fill: .brand))
                }
            }
        }
        .padding(12)
        .padding(.bottom, tailFraction == nil ? 0 : 8)
        .background {
            GeometryReader { geo in
                bubbleShape(width: geo.size.width).fill(Color.white)
                bubbleShape(width: geo.size.width).stroke(Color.cardEdge, lineWidth: 2)
            }
        }
    }

    private func bubbleShape(width: CGFloat) -> AnyShape {
        if let tailFraction {
            AnyShape(BubbleShape(arrowOffset: width * tailFraction))
        } else {
            AnyShape(RoundedRectangle(cornerRadius: DuoTokens.Radius.card, style: .continuous))
        }
    }
}

// MARK: - WalkInBeatCard

/// Bottom-pinned card for the Taste Test walkthrough beats: mascot head,
/// one line, one advance button. Content behind stays fully interactive —
/// deliberately no dimming, no timers; the user sets the pace.
struct WalkInBeatCard: View {
    let mood: MascotMood
    let line: String
    var buttonLabel: String = "Next"
    let onNext: () -> Void
    let onSkip: () -> Void

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(mood.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 52, height: 52)

                Text(line)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPri)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button(action: onSkip) {
                    Text("Not now")
                        .font(.duoLabel)
                        .foregroundColor(.textSec)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(DuoPressStyle())

                Spacer()

                Button(action: onNext) {
                    Text(buttonLabel)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 40)
                }
                .buttonStyle(Duo3DButtonStyle(fill: .brand))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DuoTokens.Radius.card, style: .continuous)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DuoTokens.Radius.card, style: .continuous)
                .strokeBorder(Color.cardEdge, lineWidth: 2)
        )
        .padding(.horizontal, 16)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 24)
        .onAppear {
            AnimationPolicy.animate { appeared = true }
            HapticEngine.impact(style: .light)
        }
        // Re-run the entrance when the line changes (next beat).
        .id(line)
    }
}

// MARK: - Previews

#Preview("Hint above tab bar") {
    VStack {
        Spacer()
        WalkInHintBubble(
            line: WalkInScript.tabHint,
            onSkip: {},
            tailFraction: 0.375
        )
        .padding(.horizontal, 24)
    }
    .background(Color.appBg)
}

#Preview("Beat card") {
    VStack {
        Spacer()
        WalkInBeatCard(
            mood: .sassy,
            line: WalkInScript.tasteVerdict,
            onNext: {},
            onSkip: {}
        )
    }
    .background(Color.appBg)
}
