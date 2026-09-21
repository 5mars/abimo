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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: state == .locked ? "lock.fill" : "flag.checkered")
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

            Text("Ready to actually build on it?")
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
                        Text(isPlus ? "Get more actions" : "Unlock with Plus")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                }
                .buttonStyle(Duo3DGradientButtonStyle(fill: .brand))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel(fill: state == .locked ? .insetBg : .white)
        .opacity(state == .locked ? 0.85 : 1)
        .accessibilityElement(children: .combine)
    }

    /// No number here: the path's inline headers count quadrant chapters, and
    /// a numbered "chapter 2" under a visible "chapter 3" reads as a bug.
    private var eyebrow: String {
        state == .locked ? "NEXT CHAPTER · LOCKED" : "NEXT CHAPTER · UNLOCKED"
    }

    private var detail: String {
        switch state {
        case .locked:
            return "Finish the path above and the critic writes the next chapter: real people, real asks, something you can actually ship."
        case .generating:
            return "The critic is turning what you learned into the next set of steps."
        case .ready:
            return isPlus
                ? "The micro-steps are done. Next chapter: bigger, more concrete actions that start the real thing."
                : "The free chapter is done. Plus writes the next one — bigger, more concrete actions that start the real thing."
        }
    }
}
