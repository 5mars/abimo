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
    var cutout: CGRect
    var cornerRadius: CGFloat

    /// Animatable origin + size + radius, so the hole morphs from one
    /// beat's target to the next instead of snapping.
    var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>
    > {
        get {
            AnimatablePair(
                AnimatablePair(cutout.origin.x, cutout.origin.y),
                AnimatablePair(AnimatablePair(cutout.size.width, cutout.size.height), cornerRadius)
            )
        }
        set {
            cutout.origin.x = newValue.first.first
            cutout.origin.y = newValue.first.second
            cutout.size.width = newValue.second.first.first
            cutout.size.height = newValue.second.first.second
            cornerRadius = newValue.second.second
        }
    }

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

    @State private var ringPulsing = false

    var body: some View {
        ZStack {
            CutoutPassthroughView(cutout: cutout, passthroughEnabled: spec.tapThrough)

            SpotlightScrimShape(cutout: cutout, cornerRadius: cornerRadius)
                .fill(Color.black.opacity(scrimOpacity), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

            pulseRing

            coachBubble
                // Beats keep the overlay alive (the cutout morphs between
                // them); the bubble itself fades out/in per line.
                .id(spec.line)
                .transition(.opacity)
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
        .onAppear {
            if !AnimationPolicy.reduceMotion {
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) {
                    ringPulsing = true
                }
            }
        }
    }

    /// Soft ring breathing outward from the cutout edge — draws the eye
    /// to the hole the way PulseRing does for the mic and active node.
    @ViewBuilder
    private var pulseRing: some View {
        if !AnimationPolicy.reduceMotion {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.white.opacity(ringPulsing ? 0 : 0.55), lineWidth: 2)
                .frame(width: cutout.width, height: cutout.height)
                .scaleEffect(ringPulsing ? 1.12 : 1.0)
                .position(x: cutout.midX, y: cutout.midY)
                .allowsHitTesting(false)
        }
    }

    // The onAppear haptic lives on the bubble (re-identified per line via
    // .id) so every beat taps, not just the overlay's first appearance.
    private var coachBubble: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 6) {
                // Points at the cutout without looking at it — obviously.
                MascotView(mood: .neutral, size: 72, motion: .talking, expression: .pointing)
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
        .onAppear { HapticEngine.impact(style: .light) }
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
