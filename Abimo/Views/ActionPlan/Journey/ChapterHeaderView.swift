//
//  ChapterHeaderView.swift
//  Abimo
//
//  The colored banner that opens each chapter of the path (Duolingo's unit
//  header), with its own progress ring. The same view renders inline at the
//  top of the chapter and as the sticky bar that takes over once the inline
//  one scrolls away.
//

import SwiftUI

struct ChapterHeaderView: View {
    enum Style { case inline, sticky }

    let chapter: JourneyChapter
    let index: Int
    var style: Style = .inline

    /// Fixed by construction (system fonts at fixed sizes), so the sticky
    /// threshold can be computed without measuring.
    static let inlineHeight: CGFloat = 66

    private var progress: Double {
        chapter.actions.isEmpty ? 0 : Double(chapter.completedCount) / Double(chapter.actions.count)
    }

    private var minutesLeft: Int {
        chapter.actions.filter { !$0.isCompleted }.reduce(0) { $0 + $1.timeEstimateMinutes }
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
                HStack(spacing: 6) {
                    Image(systemName: chapter.icon)
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
            .frame(width: 28, height: 28)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(height: Self.inlineHeight - DuoTokens.Edge.card)
        .background(shape.fill(chapter.faceColor))
        .background(shape.fill(chapter.edgeColor).offset(y: DuoTokens.Edge.card))
        .padding(.bottom, DuoTokens.Edge.card)
        // Closing a chapter gets its own beat: the ring fills and the
        // device gives one sharp tap — once, from the inline copy only.
        .onChange(of: chapter.isComplete) { _, done in
            if done && style == .inline { HapticEngine.impact(style: .rigid) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Chapter \(index + 1), \(chapter.title), \(chapter.completedCount) of \(chapter.actions.count) done")
    }

    /// Chapter 1 counts its quadrant beats ("CHAPTER 1/2/3"); a Plus chapter
    /// is one beat and names its rung ("CHAPTER 2 · BUILD").
    private var eyebrow: String {
        let label = chapter.rung.map { "CHAPTER \($0.number) · \($0.eyebrowTag)" } ?? "CHAPTER \(index + 1)"
        if chapter.isComplete { return "\(label) · DONE" }
        return "\(label) · \(chapter.completedCount)/\(chapter.actions.count) DONE · \(MinutesFormat.eyebrow(minutesLeft)) LEFT"
    }
}
