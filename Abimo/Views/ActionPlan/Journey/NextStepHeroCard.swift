//
//  NextStepHeroCard.swift
//  Abimo
//
//  The one thing to do next, above the path: title, minutes, type, XP, a
//  line from the critic, and a Start button. "Pick another" opens the
//  picker — first-visit mode on an untouched plan so the founder learns
//  they can choose.
//

import SwiftUI

struct NextStepHeroCard: View {
    let action: MicroAction
    let xpPreview: Int
    let mascotLine: String
    let onStart: () -> Void
    let onPickAnother: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("YOUR NEXT \(action.timeEstimateMinutes) MINUTES")
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.textSec)

            HStack(alignment: .top, spacing: 12) {
                Text(ActionIconMapper.icon(for: action.actionType).emoji)
                    .font(.system(size: 32))
                VStack(alignment: .leading, spacing: 8) {
                    Text(action.text)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.textPri)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        chip("\(action.timeEstimateMinutes) min", tint: .textSec)
                        chip(ActionDeepLink.typeLabel(for: action), tint: .textSec)
                        chip("+\(xpPreview) XP", tint: .brandAmberDark, fill: Color.brandAmber.opacity(0.18))
                    }
                }
            }

            HStack(alignment: .center, spacing: 4) {
                MascotView(mood: .neutral, size: 52, motion: .talking, expression: .thumbsUp)
                MascotSpeechLine(line: mascotLine, arrowOffsetY: 22)
            }

            HStack(spacing: 12) {
                Button(action: onStart) {
                    HStack(spacing: 7) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Start this step")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                }
                .buttonStyle(Duo3DGradientButtonStyle(fill: .record))

                Button(action: onPickAnother) {
                    HStack(spacing: 3) {
                        Text("Pick another")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.textSec)
                    .padding(.horizontal, 6)
                    .frame(height: 46)
                }
                .buttonStyle(DuoPressStyle())
            }
        }
        .duoPanel()
    }

    private func chip(_ text: String, tint: Color, fill: Color = Color.black.opacity(0.05)) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(fill))
    }
}
