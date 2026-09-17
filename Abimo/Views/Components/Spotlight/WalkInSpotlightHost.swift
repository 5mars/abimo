//
//  WalkInSpotlightHost.swift
//  Abimo
//
//  Renders the walk-in spotlight for the current beat. Installed in two
//  places whose steps are disjoint (they never render at once):
//   - MainContentView's root VStack — Record-tab, mic and first-action beats
//   - SWOTAnalysisView — the three taste-test beats (it's a sheet; a root
//     overlay can't dim above its presentation layer)
//
//  Rule: never show a scrim without a resolved cutout. A missing/offscreen
//  anchor renders the beat's fallback (bottom card or nothing) instead.
//

import SwiftUI

extension View {
    /// Draws the spotlight for `spec` over this view (pass nil for no beat).
    /// Targets are tagged with `.walkInTarget(_:isActive:)` anywhere inside.
    func walkInSpotlight(_ spec: SpotlightSpec?) -> some View {
        modifier(WalkInSpotlightHostModifier(spec: spec))
    }
}

struct WalkInSpotlightHostModifier: ViewModifier {
    let spec: SpotlightSpec?

    func body(content: Content) -> some View {
        content.overlayPreferenceValue(WalkInTargetPreferenceKey.self) { anchors in
            GeometryReader { proxy in
                ZStack {
                    if let spec {
                        beat(spec, anchors: anchors, proxy: proxy)
                    }
                }
                .animation(
                    AnimationPolicy.reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.75),
                    value: spec?.target
                )
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func beat(
        _ spec: SpotlightSpec,
        anchors: [WalkInTargetID: Anchor<CGRect>],
        proxy: GeometryProxy
    ) -> some View {
        let container = proxy.size
        if let anchor = anchors[spec.target],
           let cutout = usableCutout(for: proxy[anchor], spec: spec, in: container) {
            SpotlightOverlay(spec: spec, cutout: cutout, container: container)
                .transition(.opacity)
        } else if spec.fallback == .card {
            VStack {
                Spacer()
                SpotlightFallbackCard(spec: spec)
                    .padding(.bottom, 44)
            }
            .transition(.opacity)
        }
    }

    /// Pads the target bounds into a cutout rect; returns nil when the target
    /// is mostly offscreen (e.g. scrolled away) so the beat falls back.
    private func usableCutout(
        for target: CGRect,
        spec: SpotlightSpec,
        in container: CGSize
    ) -> CGRect? {
        let cutout: CGRect
        switch spec.shape {
        case .circle:
            // Circle hugs the smaller side — a target wider than tall (a tab
            // column) gets a focused ring on its centered icon.
            let side = min(target.width, target.height) + spec.cutoutPadding * 2
            cutout = CGRect(
                x: target.midX - side / 2,
                y: target.midY - side / 2,
                width: side,
                height: side
            )
        case .roundedRect:
            cutout = target.insetBy(dx: -spec.cutoutPadding, dy: -spec.cutoutPadding)
        }

        let visible = CGRect(origin: .zero, size: container).intersection(cutout)
        guard visible.width >= cutout.width * 0.7,
              visible.height >= cutout.height * 0.7 else { return nil }
        return cutout
    }
}
