//
//  MascotView.swift
//  Abimo
//
//  The one way to render the mascot. Every surface that shows the critic
//  goes through here so idle life (breathing), entrances, and celebration
//  motion stay consistent — and so mood art drops in everywhere at once
//  when it lands (MascotMood.assetName already falls back to neutral).
//
//  Blinking is deliberately absent: the art is a flattened bitmap, so
//  synthetic eyelids can't register against the eyes across sizes. Revisit
//  when mood art ships as layered/vector sources.
//

import SwiftUI

struct MascotView: View {
    /// Motion presets, matching the app's existing animation vocabulary.
    enum Motion {
        /// Static image — banners and other tiny placements.
        case none
        /// Gentle breathing loop, anchored at the feet.
        case idle
        /// Pop in (scale + tilt spring), then settle into breathing.
        case entrance
        /// Continuous rocking — full-screen celebrations.
        case celebrating
        /// Small vertical bob, as if delivering its line.
        case talking
    }

    let mood: MascotMood
    var size: CGFloat
    var motion: Motion = .idle

    @State private var entered = false
    @State private var breathing = false
    @State private var rocking = false
    @State private var bobbing = false

    /// Tiny mascots read as jitter when animated; reduce motion means none.
    private var isStatic: Bool {
        motion == .none || size <= 60 || AnimationPolicy.reduceMotion
    }

    var body: some View {
        ZStack {
            Image(mood.assetName)
                .resizable()
                .scaledToFit()
                .transition(.opacity)
                .id(mood.assetName)
        }
        .animation(AnimationPolicy.reduceMotion ? nil : .easeInOut(duration: 0.25), value: mood)
        .frame(width: size, height: size)
        .scaleEffect(y: breathing ? 1.02 : 1.0, anchor: .bottom)
        .scaleEffect(entranceScale)
        .rotationEffect(.degrees(rotationDegrees))
        .offset(y: bobOffset)
        .onAppear(perform: start)
    }

    private var entranceScale: CGFloat {
        motion == .entrance && !isStatic && !entered ? 0.5 : 1
    }

    private var rotationDegrees: Double {
        switch motion {
        case .entrance where !isStatic && !entered: return -8
        case .celebrating where !isStatic:          return rocking ? 3 : -3
        default:                                    return 0
        }
    }

    private var bobOffset: CGFloat {
        motion == .talking && !isStatic ? (bobbing ? -2 : 2) : 0
    }

    private func start() {
        guard !isStatic else { return }
        let breathe = Animation.easeInOut(duration: 1.8).repeatForever(autoreverses: true)
        switch motion {
        case .none:
            break
        case .idle:
            withAnimation(breathe) { breathing = true }
        case .entrance:
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { entered = true }
            // Breathing starts once the pop has settled; the delay applies
            // only before the first repeat.
            withAnimation(breathe.delay(0.45)) { breathing = true }
        case .celebrating:
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                rocking = true
            }
        case .talking:
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                bobbing = true
            }
        }
    }
}

#Preview {
    VStack(spacing: 32) {
        MascotView(mood: .neutral, size: 140, motion: .idle)
        MascotView(mood: .playful, size: 160, motion: .entrance)
        MascotView(mood: .sassy, size: 72, motion: .talking)
        MascotView(mood: .grumpy, size: 40, motion: .none)
    }
    .padding()
    .background(Color.appBg)
}
