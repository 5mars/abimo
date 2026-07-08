//
//  LockedContentOverlay.swift
//  Abimo
//
//  The "visible but locked" treatment for Plus-gated content: the real
//  content stays underneath, blurred just enough to tease, with a lock
//  badge and an unlock CTA on top. Tapping anywhere routes to the paywall.
//

import SwiftUI

private struct PlusLockedModifier: ViewModifier {
    let locked: Bool
    let message: String
    let onUnlock: () -> Void

    func body(content: Content) -> some View {
        if locked {
            content
                .blur(radius: 5)
                .opacity(0.55)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .overlay {
                    Button {
                        HapticEngine.impact(style: .light)
                        onUnlock()
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle()
                                    .fill(Color.lockedFace)
                                    .frame(width: 44, height: 44)
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.textSec)
                            }
                            Text(message)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: DuoTokens.Radius.button, style: .continuous)
                                        .fill(Color.brand)
                                )
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(DuoPressStyle())
                    .accessibilityLabel(message)
                }
        } else {
            content
        }
    }
}

extension View {
    /// Blurs + dims the content and overlays a lock badge with an unlock CTA
    /// when `locked` is true; passthrough otherwise.
    func plusLocked(_ locked: Bool,
                    message: String = "Unlock the full tasting notes",
                    onUnlock: @escaping () -> Void) -> some View {
        modifier(PlusLockedModifier(locked: locked, message: message, onUnlock: onUnlock))
    }
}

#Preview {
    VStack(spacing: 20) {
        VStack(alignment: .leading, spacing: 8) {
            Text("Secret sauce ingredient #1")
            Text("Secret sauce ingredient #2")
            Text("Secret sauce ingredient #3")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel()
        .plusLocked(true) {}

        Text("Unlocked content")
            .frame(maxWidth: .infinity, alignment: .leading)
            .duoPanel()
            .plusLocked(false) {}
    }
    .padding()
    .background(Color.appBg)
}
