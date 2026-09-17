//
//  MascotEmptyStateView.swift
//  Abimo
//
//  The one empty-state layout: mascot + speech line on top, title, subtitle,
//  optional screen-specific content, and a gradient CTA. The Kitchen and
//  Actions both use it so their empty states can't drift apart.
//

import SwiftUI

struct MascotEmptyStateView<Extra: View>: View {
    let line: String
    let title: String
    let subtitle: String
    let ctaTitle: String
    let ctaAction: () -> Void
    @ViewBuilder let extra: () -> Extra

    var body: some View {
        VStack(spacing: 24) {
            HStack(alignment: .center, spacing: 2) {
                // Bored on the floor — "I can't roast air."
                MascotView(mood: .neutral, size: 140, expression: .sitting)
                MascotSpeechLine(line: line, arrowOffsetY: 25)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(.textSec)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            extra()

            GradientButton(title: ctaTitle, action: ctaAction)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
    }
}

extension MascotEmptyStateView where Extra == EmptyView {
    init(
        line: String,
        title: String,
        subtitle: String,
        ctaTitle: String,
        ctaAction: @escaping () -> Void
    ) {
        self.init(
            line: line,
            title: title,
            subtitle: subtitle,
            ctaTitle: ctaTitle,
            ctaAction: ctaAction,
            extra: { EmptyView() }
        )
    }
}

#Preview {
    MascotEmptyStateView(
        line: "Record something. I can't roast air.",
        title: "Welcome to The Kitchen",
        subtitle: "Record an idea and we'll turn it\ninto a real action plan",
        ctaTitle: "Record your first idea",
        ctaAction: {}
    )
    .padding(.horizontal, 32)
    .background(Color.appBg)
}
