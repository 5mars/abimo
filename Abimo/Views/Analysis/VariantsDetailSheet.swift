//
//  VariantsDetailSheet.swift
//  Abimo
//
//  "Remix the Recipe" — 2-3 variations of the founder's idea, each changing
//  one axis, with what it keeps/changes vs the original and a re-taste
//  action that re-runs the analysis pivoted to that remix. Plus-only.
//

import SwiftUI

struct VariantsDetailSheet: View {
    let variants: [IdeaVariant]
    /// Called when the user chooses to re-run the analysis as this remix.
    /// The presenter owns the confirm step and the actual re-generation.
    var onRetaste: ((IdeaVariant) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Same core ingredient, different plating. Each remix changes one thing — re-taste the one you could serve first.")
                        .font(.system(size: 14))
                        .foregroundColor(.textSec)
                        .lineSpacing(4)
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
        VStack(alignment: .leading, spacing: 12) {
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
                .font(.system(size: 15))
                .foregroundColor(.textPri)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 10) {
                if let keeps = variant.keeps, !keeps.isEmpty {
                    remixRow(icon: "checkmark.circle.fill", tint: .brandGreen,
                             label: "Keeps", text: keeps)
                }
                if let changes = variant.changes, !changes.isEmpty {
                    remixRow(icon: "arrow.triangle.2.circlepath", tint: .brandBlue,
                             label: "Changes", text: changes)
                }
                remixRow(icon: "star.fill", tint: .brandAmber,
                         label: "Why it wins", text: variant.differentiator)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .duoInset(padding: 14)

            if let onRetaste {
                Button {
                    onRetaste(variant)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .bold))
                        Text("Re-taste this remix")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 46)
                }
                .buttonStyle(Duo3DButtonStyle(fill: .brand))
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel(padding: 16)
    }

    /// One labeled remix line: icon + bold label + body text.
    private func remixRow(icon: String, tint: Color, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 18)
                .padding(.top, 2)
            (Text("\(label): ").bold().foregroundColor(.textPri) + Text(text).foregroundColor(.textSec))
                .font(.system(size: 14))
                .lineSpacing(4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    VariantsDetailSheet(
        variants: [
            IdeaVariant(
                title: "Invoice Nagger for Design Studios",
                pitch: "The same polite-reminder engine, sold to 3-10 person studios instead of solo freelancers.",
                differentiator: "Studios lose more money to late invoices and already pay for tools — higher price, same build.",
                keeps: "The automated polite-reminder engine.",
                changes: "Audience shifts from solo freelancers to small studios at $29/mo."
            ),
            IdeaVariant(
                title: "Done-For-You Chasing Service",
                pitch: "A productized service: you send the overdue invoice, a human+bot combo does the chasing.",
                differentiator: "Zero software to build first — validates willingness to pay this week.",
                keeps: "The core promise: overdue invoices get chased for you.",
                changes: "Software becomes a service — no code before the first paying customer."
            ),
        ],
        onRetaste: { _ in }
    )
}
