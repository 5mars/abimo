//
//  ScoreCardView.swift
//  Abimo
//
//  The shareable score card — a fixed 1080x1350 canvas (4:5, the format
//  every feed accepts) rendered offscreen by ScoreCardRenderer. Not a live
//  view: no animation, plain Image for the mascot, absolute sizes.
//

import SwiftUI

struct ScoreCardView: View {
    let title: String
    let score: Int
    let dimensions: DimensionScores?

    static let size = CGSize(width: 1080, height: 1350)

    /// App Store / landing link printed in the footer. Leave nil until one
    /// exists — a fake URL on a shared card is worse than none.
    static let landingURL: String? = nil

    private var verdict: ScoreVerdict { ScoreVerdict(score: score) }

    private var expression: MascotExpression {
        switch verdict {
        case .burnt, .halfBaked:      return .grumpy
        case .needsSeasoning:         return .thumbsUp
        case .simmering, .chefsKiss:  return .waving
        }
    }

    var body: some View {
        ZStack {
            Color.journeyBg

            VStack(spacing: 0) {
                Text("MY IDEA SURVIVED THE CRITIC")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(.textSec)
                    .tracking(2)
                    .padding(.top, 90)

                Text(title)
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, 90)
                    .padding(.top, 24)

                HStack(alignment: .center, spacing: 40) {
                    Image(expression.assetName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)

                    VStack(spacing: 8) {
                        Text("\(score)")
                            .font(.system(size: 220, weight: .heavy, design: .rounded))
                            .foregroundColor(verdict.color)
                        Text("\(verdict.emoji) \(verdict.label)")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(verdict.color)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(verdict.color.opacity(0.15)))
                    }
                }
                .padding(.top, 40)

                if let dimensions {
                    VStack(spacing: 22) {
                        ForEach(DimensionKey.allCases) { key in
                            HStack(spacing: 24) {
                                Text(key.label)
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                                    .foregroundColor(.textSec)
                                    .frame(width: 200, alignment: .leading)
                                ZStack(alignment: .leading) {
                                    Capsule().fill(Color.black.opacity(0.07))
                                    Capsule()
                                        .fill(verdict.color)
                                        .frame(width: max(24, 560 * CGFloat(dimensions.value(for: key)) / 10))
                                }
                                .frame(width: 560, height: 22)
                                Text("\(dimensions.value(for: key))/10")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundColor(verdict.color)
                                    .frame(width: 110, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.top, 70)
                    .padding(.horizontal, 90)
                }

                Spacer(minLength: 0)

                HStack(spacing: 14) {
                    Image("MascotNeutral")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                    Text("abimo — the critic for your ideas")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.textPri)
                    if let url = Self.landingURL {
                        Text("· \(url)")
                            .font(.system(size: 26, weight: .medium, design: .rounded))
                            .foregroundColor(.textSec)
                    }
                }
                .padding(.bottom, 70)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
    }
}

/// Renders the card to a UIImage on the main actor.
enum ScoreCardRenderer {
    @MainActor
    static func render(title: String, score: Int, dimensions: DimensionScores?) -> UIImage? {
        let renderer = ImageRenderer(content: ScoreCardView(title: title, score: score, dimensions: dimensions))
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(ScoreCardView.size)
        return renderer.uiImage
    }
}

#Preview {
    ScoreCardView(
        title: "Pool-route scheduler for solo techs",
        score: 71,
        dimensions: DimensionScores(problemSeverity: 8, demandEvidence: 6, marketQuality: 6, feasibility: 6, differentiation: 6)
    )
    .scaleEffect(0.3)
    .frame(width: 324, height: 405)
}
