//
//  SparkCard.swift
//  Abimo
//
//  The daily loop's "do this today" card for every state that ISN'T a live
//  plan: a raw idea waiting to be tasted, an analyzed idea missing its
//  plan, every plan finished, or nothing recorded yet. One line from the
//  critic, one button.
//

import SwiftUI

struct SparkCard: View {
    enum Kind: String {
        case recordIdea      // nothing on the stove
        case tasteIdea       // a raw recording
        case buildPlan       // analyzed, no plan
        case whatsNext       // all plans done
    }

    let kind: Kind
    let title: String
    let line: String
    let buttonTitle: String
    let onTap: () -> Void
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil

    private var expression: MascotExpression {
        switch kind {
        case .recordIdea: return .listening  // arms crossed, waiting for the pitch
        case .tasteIdea:  return .tasting    // spoon's out, the dish isn't
        case .buildPlan:  return .writing    // notepad ready for the plan
        case .whatsNext:  return .dare       // "I bet you won't do another"
        }
    }

    private var icon: String {
        switch kind {
        case .recordIdea: return "mic.fill"
        case .tasteIdea:  return "fork.knife"
        case .buildPlan:  return "bolt.fill"
        case .whatsNext:  return "sparkles"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                Text("TODAY")
                    .font(.system(size: 12, weight: .black, design: .rounded))
            }
            .foregroundColor(.brand)

            Text(title)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.textPri)
                .fixedSize(horizontal: false, vertical: true)

            HStack(alignment: .center, spacing: 4) {
                MascotView(mood: .neutral, size: 52, motion: .talking, expression: expression)
                MascotSpeechLine(line: line, arrowOffsetY: 22)
            }

            HStack(spacing: 12) {
                Button(action: onTap) {
                    Text(buttonTitle)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                }
                .buttonStyle(Duo3DGradientButtonStyle(fill: .record))

                if let secondaryTitle, let onSecondary {
                    Button(action: onSecondary) {
                        Text(secondaryTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSec)
                            .padding(.horizontal, 6)
                            .frame(height: 46)
                    }
                    .buttonStyle(DuoPressStyle())
                }
            }
        }
        .duoPanel()
        .onAppear { AnalyticsService.shared.log(.sparkShown(kind: kind.rawValue)) }
    }
}
