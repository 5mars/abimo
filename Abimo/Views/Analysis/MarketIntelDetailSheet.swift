//
//  MarketIntelDetailSheet.swift
//  Abimo
//
//  Market Intelligence served as its own course: the 2×2 insight tile grid
//  plus the market context paragraph. Plus-only — free users hit the lock
//  on the course card before ever opening this sheet.
//

import SwiftUI

struct MarketIntelDetailSheet: View {
    let insights: MarketInsights
    let context: String?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 16) {
                        MarketInsightGrid(insights: insights)

                        if let context, !context.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 8) {
                                    Image(systemName: "map.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.brandBlue)
                                    Text("The lay of the land")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .foregroundColor(.textPri)
                                }
                                Text(context)
                                    .font(.system(size: 14))
                                    .foregroundColor(.textSec)
                                    .lineSpacing(5)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .duoInset(padding: 14)
                        }
                    }
                    .duoPanel()

                    if let comparables = insights.comparables, !comparables.isEmpty {
                        comparablesPanel(comparables)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color.appBg, ignoresSafeAreaEdges: .all)
            .navigationTitle("Market Intel")
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

    /// Real small businesses found by live web research — framed as proof
    /// the dish sells at a small table, not as intimidating competition.
    private func comparablesPanel(_ comparables: [MarketComparable]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Image(systemName: "storefront.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.brandGreen)
                    Text("Small players already cooking")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPri)
                    Spacer()
                }
                Text("Proof this dish sells at a small table.")
                    .font(.duoCaption)
                    .foregroundColor(.textSec)
            }

            ForEach(comparables) { comp in
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Text(comp.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.textPri)
                        if !comp.status.isEmpty {
                            Text(comp.status)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.brandGreen)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.brandGreen.opacity(0.12))
                                .clipShape(Capsule())
                                .lineLimit(1)
                        }
                        Spacer()
                        if !comp.pricing.isEmpty && comp.pricing.lowercased() != "unknown" {
                            Text(comp.pricing)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.textSec)
                        }
                    }

                    Text(comp.what)
                        .font(.system(size: 14))
                        .foregroundColor(.textSec)
                        .lineSpacing(4)

                    if let overlap = comp.overlap, !overlap.isEmpty {
                        comparisonRow(icon: "equal.circle.fill", tint: .textSec,
                                      label: "Same dish", text: overlap)
                    }
                    if let edge = comp.edge, !edge.isEmpty {
                        comparisonRow(icon: "bolt.fill", tint: .brandGreen,
                                      label: "Your edge", text: edge)
                    }

                    if let url = comp.url, !url.isEmpty, let link = URL(string: url) {
                        Link(destination: link) {
                            HStack(spacing: 6) {
                                Image(systemName: "safari.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Visit site")
                                    .font(.duoLabel)
                            }
                            .foregroundColor(.brand)
                            .frame(maxWidth: .infinity)
                            .frame(height: 36)
                        }
                        .buttonStyle(Duo3DSecondaryButtonStyle())
                        .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .duoInset(padding: 14)
            }
        }
        .duoPanel()
    }

    /// One labeled comparison line: icon circle + bold label + body text.
    private func comparisonRow(icon: String, tint: Color, label: String, text: String) -> some View {
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

// MARK: - Shared pieces

enum MarketTrendStyle {
    static func icon(for direction: String?) -> String {
        switch direction {
        case "up":   return "arrow.up.right"
        case "down": return "arrow.down.right"
        default:     return "arrow.right"
        }
    }

    static func color(for direction: String?) -> Color {
        switch direction {
        case "up":   return .brandGreen
        case "down": return .brand
        default:     return .brandAmber
        }
    }

    static func background(for direction: String?) -> Color {
        switch direction {
        case "up":   return .cardDarkTeal
        case "down": return .cardDarkRed
        default:     return .cardDarkOrange
        }
    }
}

/// The 2×2 insight tile grid — also rendered miniature (blurred) on the
/// locked Market Intel course card.
struct MarketInsightGrid: View {
    let insights: MarketInsights

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            if let size = insights.marketSize {
                MarketInsightTile(icon: "chart.pie.fill", label: "Niche Size", value: size, color: .brand, tileBackground: .cardDarkRed)
            }
            if let rate = insights.growthRate {
                MarketInsightTile(icon: "arrow.up.right.circle.fill", label: "Demand", value: rate, color: .brandGreen, tileBackground: .cardDarkTeal)
            }
            if let competitors = insights.keyCompetitors, !competitors.isEmpty {
                MarketInsightTile(icon: "person.3.fill", label: "Small Players", value: competitors.prefix(3).joined(separator: ", "), color: .brandAmber, tileBackground: .cardDarkOrange)
            }
            if let dir = insights.trendDirection {
                MarketInsightTile(icon: "waveform.path.ecg", label: "Market Trend", value: dir.capitalized,
                                  color: MarketTrendStyle.color(for: dir),
                                  tileBackground: MarketTrendStyle.background(for: dir))
            }
        }
    }
}

struct MarketInsightTile: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    var tileBackground: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.textSec)
            }
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.textPri)
                .lineSpacing(3)
                .lineLimit(4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tileBackground ?? color.opacity(0.06))
        .cornerRadius(12)
    }
}

#Preview {
    MarketIntelDetailSheet(
        insights: MarketInsights(
            marketSize: "Tens of thousands of freelance designers who invoice clients directly — 50 of them at $8/mo is a real side income.",
            growthRate: "More freelancers ditch heavy invoicing suites every year.",
            trendDirection: "up",
            keyCompetitors: ["Bonsai", "Indy", "Harvest"],
            comparables: [
                MarketComparable(name: "LateChaser", what: "Automated polite payment reminders for freelancers.", pricing: "$9/mo", status: "solo dev", url: "https://example.com"),
                MarketComparable(name: "InvoiceOwl", what: "Simple invoicing with follow-up nudges.", pricing: "$7/mo", status: "small team", url: ""),
            ]
        ),
        context: "First 100 customers: freelance designers in invoice-frustration threads on Reddit and X. Small tools already charge and get paid here."
    )
}
