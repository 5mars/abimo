//
//  SpotlightOverlay.swift
//  Abimo
//
//  The walk-in tour's spotlight: a dark scrim with a punched-out cutout on
//  the current target, the mascot explaining beside it, and an always-visible
//  "Skip tour". Taps land only inside the cutout (when the beat allows
//  tap-through) — everywhere else the scrim absorbs them.
//

import SwiftUI

// MARK: - Scrim shape (even-odd punch-out)

struct SpotlightScrimShape: Shape {
    let cutout: CGRect
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addRect(rect)
        p.addRoundedRect(
            in: cutout,
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius),
            style: .continuous
        )
        return p
    }
}

// MARK: - Cutout passthrough hit-testing

/// SwiftUI hit-testing can't honor an even-odd shape, so a UIKit view does
/// it: touches inside the cutout fall through to the real control behind the
/// scrim; touches anywhere else are absorbed by this view.
private struct CutoutPassthroughView: UIViewRepresentable {
    let cutout: CGRect
    let passthroughEnabled: Bool

    final class PassthroughUIView: UIView {
        var cutout: CGRect = .zero
        var passthroughEnabled = false

        override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
            if passthroughEnabled, cutout.contains(point) { return false }
            return true
        }
    }

    func makeUIView(context: Context) -> PassthroughUIView {
        let view = PassthroughUIView()
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: PassthroughUIView, context: Context) {
        view.cutout = cutout
        view.passthroughEnabled = passthroughEnabled
    }
}

// MARK: - SpotlightOverlay

struct SpotlightOverlay: View {
    let spec: SpotlightSpec
    /// Cutout rect (already padded), in the host's full-screen space.
    let cutout: CGRect
    let container: CGSize

    private var cornerRadius: CGFloat {
        spec.shape == .circle ? min(cutout.width, cutout.height) / 2 : DuoTokens.Radius.card
    }

    private var scrimOpacity: Double {
        UIAccessibility.isReduceTransparencyEnabled ? 0.78 : 0.6
    }

    /// Bubble goes on whichever side of the cutout has more room.
    private var bubbleBelowCutout: Bool { cutout.midY < container.height / 2 }

    /// Skip moves out of the way when the cutout sits near the bottom
    /// (e.g. the Record tab).
    private var skipAtTop: Bool { cutout.maxY > container.height - 220 }

    var body: some View {
        ZStack {
            CutoutPassthroughView(cutout: cutout, passthroughEnabled: spec.tapThrough)

            SpotlightScrimShape(cutout: cutout, cornerRadius: cornerRadius)
                .fill(Color.black.opacity(scrimOpacity), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

            coachBubble
                .frame(
                    maxWidth: .infinity, maxHeight: .infinity,
                    alignment: bubbleBelowCutout ? .top : .bottom
                )
                .padding(.top, bubbleBelowCutout ? cutout.maxY + 18 : 0)
                .padding(.bottom, bubbleBelowCutout ? 0 : max(0, container.height - cutout.minY + 18))

            skipButton
                .frame(
                    maxWidth: .infinity, maxHeight: .infinity,
                    alignment: skipAtTop ? .topTrailing : .bottom
                )
                .padding(.top, skipAtTop ? 64 : 0)
                .padding(.trailing, skipAtTop ? 20 : 0)
                .padding(.bottom, skipAtTop ? 0 : 44)
        }
        .onAppear { HapticEngine.impact(style: .light) }
    }

    private var coachBubble: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 6) {
                MascotView(mood: .neutral, size: 72, motion: .talking)
                MascotSpeechLine(line: spec.line, arrowOffsetY: 30)
            }

            if let label = spec.primaryLabel, let action = spec.primaryAction {
                Button(action: action) {
                    Text(label)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .frame(height: 40)
                }
                .buttonStyle(Duo3DButtonStyle(fill: .brand))
            }
        }
        .padding(.horizontal, 24)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var skipButton: some View {
        Button {
            WalkInDirector.shared.skip()
        } label: {
            Text("Skip tour")
                .font(.duoLabel)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.white.opacity(0.18)))
        }
        .buttonStyle(DuoPressStyle())
    }
}

// MARK: - Fallback coach card

/// Bottom card shown when a beat's target isn't on screen (async content,
/// scrolled away): the mascot still explains, no scrim, content behind stays
/// fully interactive — the pre-spotlight tour behavior.
struct SpotlightFallbackCard: View {
    let spec: SpotlightSpec

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                MascotView(mood: .neutral, size: 52, motion: .none)

                Text(spec.line)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPri)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 12) {
                Button {
                    WalkInDirector.shared.skip()
                } label: {
                    Text("Skip tour")
                        .font(.duoLabel)
                        .foregroundColor(.textSec)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(DuoPressStyle())

                Spacer()

                if let label = spec.primaryLabel, let action = spec.primaryAction {
                    Button(action: action) {
                        Text(label)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .frame(height: 40)
                    }
                    .buttonStyle(Duo3DButtonStyle(fill: .brand))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DuoTokens.Radius.card, style: .continuous)
                .fill(Color.white)
                .duoShadow()
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
        .id(spec.line)
    }
}
