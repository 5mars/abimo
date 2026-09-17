//
//  DuoDisclosureHeader.swift
//  Abimo
//
//  The one collapse idiom: icon circle + title (+ subtitle) + optional
//  trailing accessory + rotating chevron. Used by What You Said, Market
//  Intel, and the SWOT quadrant cards.
//

import SwiftUI

struct DuoDisclosureHeader<Trailing: View>: View {
    let icon: String
    var tint: Color = .brand
    let title: String
    var subtitle: String? = nil
    @Binding var isExpanded: Bool
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(tint)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.duoCardTitle)
                        .foregroundColor(.textPri)
                    if let subtitle {
                        Text(subtitle)
                            .font(.duoCaption)
                            .foregroundColor(.textSec)
                    }
                }

                Spacer()

                trailing()

                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.textSec)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)
            }
        }
        .buttonStyle(.plain)
    }
}

extension DuoDisclosureHeader where Trailing == EmptyView {
    init(icon: String, tint: Color = .brand, title: String, subtitle: String? = nil, isExpanded: Binding<Bool>) {
        self.icon = icon
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self._isExpanded = isExpanded
        self.trailing = { EmptyView() }
    }
}
