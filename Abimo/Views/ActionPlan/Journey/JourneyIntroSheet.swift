//
//  JourneyIntroSheet.swift
//  Abimo
//
//  The one place the horse talks about the roadmap — a closable half-sheet
//  shown once, ever, the first time a plan opens. Nothing inline, nothing
//  on the path; one line and a button.
//

import SwiftUI

struct JourneyIntroSheet: View {
    let onDismiss: () -> Void

    @State private var moment = MascotVoice.moment(for: .journeyIntro)

    var body: some View {
        VStack(spacing: 22) {
            MascotView(mood: moment.mood, size: 140, motion: .entrance)
                .padding(.top, 12)

            MascotCalloutLine(line: moment.line)
                .padding(.horizontal, 16)

            Text("One step is lit. Tap it, do it, come back. That's the whole game.")
                .font(.duoBody)
                .foregroundColor(.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button(action: onDismiss) {
                Text("Got it")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(Duo3DGradientButtonStyle(fill: .brand))
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .background(Color.appBg)
        .onAppear { HapticEngine.impact(style: .light) }
    }

    /// Persisted so the sheet never comes back.
    static let seenKey = "journey_intro_seen"
}
