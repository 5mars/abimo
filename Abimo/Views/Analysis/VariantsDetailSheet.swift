//
//  VariantsDetailSheet.swift
//  Abimo
//
//  "Remix the Recipe" — 2-3 variations of the founder's idea, each changing
//  one axis (audience, model, channel, or wedge) with a differentiator.
//  Plus-only; free users hit the lock on the course card.
//

import SwiftUI

struct VariantsDetailSheet: View {
    let variants: [IdeaVariant]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Same core ingredient, different plating. Each remix changes one thing — pick the one you could serve first.")
                        .font(.system(size: 13))
                        .foregroundColor(.textSec)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    ForEach(variants) { variant in
                        variantCard(variant)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color.appBg, ignoresSafeAreaEdges: .all)
            .navigationTitle("Remix the Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(.brand)
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func variantCard(_ variant: IdeaVariant) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.brandGreen.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "fork.knife")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.brandGreen)
                }
                Text(variant.title)
                    .font(.duoCardTitle)
                    .foregroundColor(.textPri)
                Spacer()
            }

            Text(variant.pitch)
                .font(.duoBody)
                .foregroundColor(.textPri)
                .lineSpacing(3)

            (Text("Why it wins: ").bold() + Text(variant.differentiator))
                .font(.system(size: 13))
                .foregroundColor(.textSec)
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .duoInset()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel(padding: 16)
    }
}

#Preview {
    VariantsDetailSheet(variants: [
        IdeaVariant(
            title: "Invoice Nagger for Design Studios",
            pitch: "The same polite-reminder engine, sold to 3-10 person studios instead of solo freelancers.",
            differentiator: "Studios lose more money to late invoices and already pay for tools — higher price, same build."
        ),
        IdeaVariant(
            title: "Done-For-You Chasing Service",
            pitch: "A productized service: you send the overdue invoice, a human+bot combo does the chasing.",
            differentiator: "Zero software to build first — validates willingness to pay this week."
        ),
    ])
}
