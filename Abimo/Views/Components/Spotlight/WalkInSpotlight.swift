//
//  WalkInSpotlight.swift
//  Abimo
//
//  Targeting infrastructure for the walk-in spotlight tour. Views tag their
//  tour targets with .walkInTarget(_:isActive:); a host view (see
//  WalkInSpotlightHost) reads the anchors and draws the scrim + cutout.
//

import SwiftUI

// MARK: - Target IDs

enum WalkInTargetID: Hashable {
    case recordTab
    case micButton
    case tasteScore
    case tasteVerdict
    case tastePlanCTA
    case firstActionCard
}

// MARK: - Anchor preference

struct WalkInTargetPreferenceKey: PreferenceKey {
    static var defaultValue: [WalkInTargetID: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [WalkInTargetID: Anchor<CGRect>],
        nextValue: () -> [WalkInTargetID: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Tags a view as a walk-in tour target. The `isActive` gate is mandatory
    /// for views inside kept-alive tabs: at opacity 0 they still lay out and
    /// would otherwise report anchors from invisible screens.
    func walkInTarget(_ id: WalkInTargetID, isActive: Bool = true) -> some View {
        anchorPreference(key: WalkInTargetPreferenceKey.self, value: .bounds) {
            isActive ? [id: $0] : [:]
        }
    }
}

// MARK: - Spec

/// Everything one spotlight beat needs: where to punch the hole, what the
/// mascot says, and how the user moves on.
struct SpotlightSpec {
    enum CutoutShape { case circle, roundedRect }

    /// What to render when the target anchor is missing or offscreen:
    /// `.card` shows a bottom coach card without a scrim (a beat can never
    /// dead-end behind an invisible overlay); `.none` renders nothing —
    /// for beats whose target absence means "not this moment" (e.g. the mic
    /// while a recording is already running).
    enum Fallback { case none, card }

    let target: WalkInTargetID
    let line: String
    var primaryLabel: String? = nil
    var primaryAction: (() -> Void)? = nil
    var shape: CutoutShape = .roundedRect
    /// Extra clear space around the target inside the cutout.
    var cutoutPadding: CGFloat = 10
    /// Whether taps inside the cutout reach the real control underneath.
    var tapThrough = false
    var fallback: Fallback = .none
}
