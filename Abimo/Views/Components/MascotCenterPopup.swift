//
//  MascotCenterPopup.swift
//  Abimo
//
//  Duolingo-style center-screen mascot moment: dimmed backdrop, big mascot,
//  one line, one action. Rare by design (MascotDirector caps these at one
//  per session) and never auto-dismisses — the user acts or waves it off.
//

import SwiftUI

struct MascotCenterPopup: View {
    let moment: MascotMoment
    var onAction: (MascotActionIntent) -> Void
    var onDismiss: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(appeared ? 0.45 : 0)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 16) {
                Image(moment.mood.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)

                Text(moment.line)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let action = moment.action {
                    Button {
                        onAction(action.intent)
                    } label: {
                        Text(action.label)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(Duo3DButtonStyle(fill: .brand))
                    .padding(.top, 4)
                }

                Button {
                    onDismiss()
                } label: {
                    Text("Not now")
                        .font(.duoLabel)
                        .foregroundColor(.textSec)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DuoPressStyle())
            }
            .padding(24)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: DuoTokens.Radius.card, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DuoTokens.Radius.card, style: .continuous)
                    .strokeBorder(Color.cardEdge, lineWidth: 2)
            )
            .padding(.horizontal, 32)
            .scaleEffect(appeared ? 1 : 0.85)
            .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            AnimationPolicy.animate(.spring(response: 0.38, dampingFraction: 0.72)) {
                appeared = true
            }
            SoundEngine.pop()
            HapticEngine.impact(style: .light)
        }
    }
}

#Preview {
    MascotCenterPopup(
        moment: MascotVoice.moment(for: .streakAtRisk(days: 5)),
        onAction: { _ in },
        onDismiss: {}
    )
    .background(Color.appBg)
}
