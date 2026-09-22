//
//  NextChapterGateCard.swift
//  Abimo
//
//  The card at the bottom of the path: "Ready to actually build on it?"
//  Locked while steps above are open; once the path is done it becomes the
//  door to the next chapter — Plus generates it in place, free sees the
//  paywall. Chapters are capped server-side (extend-action-plan), so the
//  card disappears after the last one.
//

import SwiftUI

struct NextChapterGateCard: View {
    enum State { case locked, ready, generating }

    let state: State
    let nextChapter: Int
    let isPlus: Bool
    let onUnlock: () -> Void

    private var rung: ChapterLadder.Rung? { ChapterLadder.rung(nextChapter) }
    private var ctaColor: Color { rung?.face ?? .brand }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: state == .locked ? "lock.fill" : (rung?.icon ?? "flag.checkered"))
                    .font(.system(size: 12, weight: .bold))
                Text(eyebrow)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                Spacer()
                if !isPlus {
                    Text("PLUS")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.brandAmber))
                }
            }
            .foregroundColor(.textSec)

            Text(rung?.title ?? "Ready to actually build on it?")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.textPri)

            Text(detail)
                .font(.system(size: 13))
                .foregroundColor(.textSec)
                .fixedSize(horizontal: false, vertical: true)

            switch state {
            case .locked:
                EmptyView()
            case .generating:
                HStack(spacing: 10) {
                    ProgressView().tint(.brand)
                    Text("Writing the next chapter…")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.textSec)
                }
                .frame(height: 46)
            case .ready:
                Button(action: onUnlock) {
                    HStack(spacing: 8) {
                        Image(systemName: isPlus ? "plus.circle.fill" : "lock.open.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(isPlus ? "Write chapter \(nextChapter)" : "Unlock with Plus")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                }
                .buttonStyle(Duo3DGradientButtonStyle(
                    fill: LinearGradient(colors: [ctaColor, ctaColor], startPoint: .top, endPoint: .bottom),
                    edge: rung?.edge ?? .brandDark
                ))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel(fill: state == .locked ? .insetBg : .white)
        .opacity(state == .locked ? 0.85 : 1)
        .accessibilityElement(children: .combine)
    }

    /// Plus chapters carry their ladder number; the free plan's inline headers
    /// count quadrant beats, so the number here is the plan chapter, not those.
    private var eyebrow: String {
        let name = "CHAPTER \(nextChapter) OF \(ChapterLadder.maxChapters)"
        return state == .locked ? "\(name) · LOCKED" : "\(name) · UNLOCKED"
    }

    private var detail: String {
        switch state {
        case .locked:
            return "Finish the path above and the critic writes chapter \(nextChapter): \(rung?.subtitle.lowercased() ?? "real people, real asks, something you can actually ship.")"
        case .generating:
            return "The critic is turning what you learned into the next set of steps."
        case .ready:
            let what = rung?.subtitle ?? "Bigger, more concrete actions that start the real thing."
            let lowered = what.prefix(1).lowercased() + String(what.dropFirst())
            return isPlus
                ? "\(what) Four quick questions first, so the steps fit you."
                : "The free chapter is done. Plus writes the next one: \(lowered)"
        }
    }
}
