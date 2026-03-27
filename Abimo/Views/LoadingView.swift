//
//  LoadingView.swift
//  Abimo
//
//  Created by Jeremy Cinq-Mars on 2026-03-16.
//

import SwiftUI

enum LoadingDisplayMode {
    case fullscreen  // Brand background, white text, ignores safe area — for app launch
    case inline      // Transparent background, textPri text — for sheets and tab content
}

struct MascotLoadingView: View {
    var mode: LoadingDisplayMode = .fullscreen
    var text: String = "abimo"
    var rotatingMessages: [String] = []
    var subtitle: String? = nil

    @State private var appeared = false
    @State private var spinning = false
    @State private var messageIndex = 0
    @State private var messageTimer: Timer?

    private var displayText: String {
        if !rotatingMessages.isEmpty {
            return rotatingMessages[messageIndex % rotatingMessages.count]
        }
        return text
    }

    private var textColor: Color {
        mode == .fullscreen ? .white : .textPri
    }

    private var subtitleColor: Color {
        mode == .fullscreen ? .white.opacity(0.7) : .textSec
    }

    private var spinnerColor: Color {
        mode == .fullscreen ? .white : .brand
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Spinner
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(spinnerColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .frame(width: 32, height: 32)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(.linear(duration: 0.8).repeatForever(autoreverses: false), value: spinning)

            // Mascot
            Image("MascotNeutral")
                .resizable()
                .scaledToFit()
                .frame(width: 180, height: 180)

            // Text
            VStack(spacing: 8) {
                Text(displayText)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.center)
                    .id(messageIndex)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(subtitleColor)
                }
            }

            Spacer()
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared ? 1 : 0.92)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundView)
        .onAppear {
            spinning = true
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
            if !rotatingMessages.isEmpty {
                messageTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: true) { _ in
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        messageIndex += 1
                    }
                }
            }
        }
        .onDisappear {
            messageTimer?.invalidate()
            messageTimer = nil
        }
    }

    @ViewBuilder
    private var backgroundView: some View {
        if mode == .fullscreen {
            Color.brand.ignoresSafeArea()
        } else {
            Color.clear
        }
    }
}

// Backward-compatible alias
typealias LoadingView = MascotLoadingView

#Preview {
    MascotLoadingView()
}

#Preview("Inline") {
    MascotLoadingView(
        mode: .inline,
        rotatingMessages: ["Cooking up insights...", "Turning up the heat...", "Taste-testing your idea..."],
        subtitle: "This might take 15–30 seconds"
    )
}
