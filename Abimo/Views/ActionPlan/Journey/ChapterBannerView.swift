//
//  ChapterBannerView.swift
//  Abimo
//
//  The colored banner that opens each chapter of the path, with its own
//  progress ring — the per-section progress the v1.0 spec asked for.
//

import SwiftUI

struct ChapterBannerView: View {
    let chapter: JourneyChapter
    let index: Int

    private var progress: Double {
        chapter.actions.isEmpty ? 0 : Double(chapter.completedCount) / Double(chapter.actions.count)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                HStack(spacing: 6) {
                    Image(systemName: chapter.kind.icon)
                        .font(.system(size: 14, weight: .bold))
                    Text(chapter.title)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundColor(.white)
            }
            Spacer(minLength: 8)
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(
                        AnimationPolicy.reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.8),
                        value: progress
                    )
                if chapter.isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white)
                } else {
                    Text("\(chapter.completedCount)/\(chapter.actions.count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(shape.fill(chapter.kind.color))
        .background(shape.fill(chapter.kind.edgeColor).offset(y: DuoTokens.Edge.card))
        .padding(.bottom, DuoTokens.Edge.card)
        // Closing a chapter gets its own beat: the ring fills and the
        // device gives one sharp tap.
        .onChange(of: chapter.isComplete) { _, done in
            if done { HapticEngine.impact(style: .rigid) }
        }
    }

    private var eyebrow: String {
        let steps = chapter.actions.count
        return "CHAPTER \(index + 1) · \(steps) STEP\(steps == 1 ? "" : "S") · \(chapter.totalMinutes) MIN"
    }
}
