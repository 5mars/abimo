//
//  GenerateCTACard.swift
//  Abimo
//
//  The one "do the next thing" card: icon circle, title, subtitle, big
//  button. Replaces the three near-identical hand-rolled variants in
//  NoteDetailView (transcribing, taste-test CTA, action-plan CTA).
//

import SwiftUI

struct GenerateCTACard: View {
    let icon: String
    let title: String
    let subtitle: String
    var buttonTitle: String? = nil
    var isLoading: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.1))
                    .frame(width: 64, height: 64)
                if isLoading {
                    ProgressView()
                        .tint(.brand)
                        .scaleEffect(1.2)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.brand)
                        .symbolEffect(.pulse)
                }
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                Text(subtitle)
                    .font(.duoBody)
                    .foregroundColor(.textSec)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            if let buttonTitle, let action {
                GradientButton(title: buttonTitle, action: action)
            }
        }
        .frame(maxWidth: .infinity)
        .duoPanel()
    }
}
