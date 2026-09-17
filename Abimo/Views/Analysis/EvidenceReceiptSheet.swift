//
//  EvidenceReceiptSheet.swift
//  Abimo
//
//  Plus-only "Evidence Receipt": the sources and arithmetic behind the
//  critic's score. The REASONS (evidence sentences, caps, weights, next
//  steps) are free in the breakdown; this sheet adds the SOURCES — the
//  comparables table with prices, every signal with its link, the queries
//  the scout ran — and the raw → mapped → adjusted math.
//

import SwiftUI

struct EvidenceReceiptSheet: View {
    let analysis: SWOTAnalysis
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var meta: ScoreMeta? { analysis.scoreMeta }
    private var digest: ResearchDigest? { analysis.researchDigest }
    private var verdict: ScoreVerdict { ScoreVerdict(score: analysis.viabilityScore ?? 0) }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if let meta, meta.version >= 2 {
                        arithmeticPanel
                            .cardEntrance(delay: 0.05)
                    }
                    if let market = digest?.market {
                        marketPanel(market)
                            .cardEntrance(delay: 0.10)
                    }
                    if let comparables = digest?.comparables, !comparables.isEmpty {
                        comparablesPanel(comparables)
                            .cardEntrance(delay: 0.15)
                    }
                    if let signals = digest?.signals, !signals.isEmpty {
                        signalsPanel(signals)
                            .cardEntrance(delay: 0.20)
                    }
                    if let queries = digest?.market?.queriesRun, !queries.isEmpty {
                        queriesPanel(queries)
                            .cardEntrance(delay: 0.25)
                    }
                    if digest == nil && meta == nil {
                        Text("This idea was scored with the critic's old recipe — no receipt was kept. Re-taste it to get one.")
                            .font(.duoBody)
                            .foregroundColor(.textSec)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .duoPanel()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color.appBg, ignoresSafeAreaEdges: .all)
            .navigationTitle("Evidence Receipt")
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

    // MARK: - Panels

    private var arithmeticPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("How the number was cooked", icon: "function")
            if let meta {
                receiptRow("Weighted mean", value: fmt(meta.wm), note: "P .20 · D .25 · M .20 · F .10 · X .25")
                if let gate = meta.gate, gate < 1 {
                    receiptRow("Weakest-link gate", value: "×\(fmt(gate))", note: "a dimension sits at 0-2")
                }
                if let df = meta.demandFactor, df < 1 {
                    receiptRow("Demand factor", value: "×\(fmt(df))", note: "demand evidence is thin")
                }
                receiptRow("Raw", value: fmt(meta.raw), note: "0-10 scale")
                receiptRow("Mapped", value: fmt(meta.mapped), note: "calibrated curve → 0-100")
                ForEach(meta.adjustments ?? [], id: \.self) { adj in
                    if let delta = adj.delta {
                        receiptRow(adj.kind.replacingOccurrences(of: "_", with: " ").capitalized,
                                   value: delta > 0 ? "+\(delta)" : "\(delta)", note: adj.reason)
                    } else if let cap = adj.cap {
                        receiptRow(adj.kind.replacingOccurrences(of: "_", with: " ").capitalized,
                                   value: "≤\(cap)", note: adj.reason)
                    }
                }
                Divider().overlay(Color.cardEdge)
                HStack {
                    Text("Critic's Score")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.textPri)
                    Spacer()
                    Text("\(analysis.viabilityScore ?? 0)")
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundColor(verdict.color)
                }
                if let band = meta.verdictBand, meta.bandMismatch == true {
                    Text("The critic's gut said \(band.replacingOccurrences(of: "_", with: " ")); the evidence said \(meta.computedBand?.replacingOccurrences(of: "_", with: " ") ?? "otherwise"). The evidence wins.")
                        .font(.system(size: 12))
                        .italic()
                        .foregroundColor(.textSec)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel()
    }

    private func marketPanel(_ market: ResearchMarket) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("What the scout found", icon: "binoculars.fill")
            factRow("Paid comparables", "\(market.paidComparablesFound ?? 0)")
            factRow("Saturation", (market.saturation ?? "unknown").capitalized)
            factRow("Small players making money", (market.smallPlayersMakingMoney ?? "unknown").capitalized)
            factRow("Free alternatives dominate", (market.freeAlternativesDominate ?? "unknown").capitalized)
            if market.giantBlocksNiche == "yes" {
                factRow("Giant blocking the niche", market.giantName?.isEmpty == false ? market.giantName! : "Yes")
            }
            if let lo = market.typicalPriceLow, let hi = market.typicalPriceHigh, hi > 0 {
                factRow("Typical pricing", lo == hi ? money(lo, market.priceCurrency) : "\(money(lo, market.priceCurrency)) – \(money(hi, market.priceCurrency))")
            }
            factRow("Search quality", (market.searchQuality ?? "unknown").capitalized)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel()
    }

    private func comparablesPanel(_ comparables: [MarketComparable]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Comparables, with numbers", icon: "storefront.fill")
            ForEach(comparables) { c in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(c.name)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.textPri)
                        Spacer()
                        Text(priceLabel(c))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(c.chargesMoney == "yes" ? .brandGreen : .textSec)
                    }
                    Text(c.what)
                        .font(.system(size: 13))
                        .foregroundColor(.textSec)
                    HStack(spacing: 8) {
                        if let size = c.size, size != "unknown" { chip(size.replacingOccurrences(of: "_", with: " ")) }
                        if let users = c.userCountHint, users > 0 { chip("~\(Int(users).formatted()) users") }
                        if let active = c.lastActive, active != "unknown" { chip("active \(active.replacingOccurrences(of: "_", with: " "))") }
                        Spacer()
                        if let url = c.url, let link = URL(string: url), !url.isEmpty {
                            Button { openURL(link) } label: {
                                Label("Visit", systemImage: "arrow.up.right")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .tint(.brandBlue)
                        }
                    }
                }
                .padding(12)
                .duoInset(padding: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel()
    }

    private func signalsPanel(_ signals: [ResearchSignal]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Demand signals", icon: "waveform.path.ecg")
            ForEach(signals) { s in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: s.direction == "negative" ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
                        .foregroundColor(s.direction == "negative" ? .danger : .brandGreen)
                        .font(.system(size: 16))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(s.text)
                            .font(.system(size: 13))
                            .foregroundColor(.textPri)
                        HStack(spacing: 6) {
                            if let strength = s.strength { chip(strength) }
                            if let source = s.sourceType { chip(source.replacingOccurrences(of: "_", with: " ")) }
                            if let count = s.countHint, count > 0 { chip("\(Int(count).formatted())") }
                            if let url = s.url, let link = URL(string: url), !url.isEmpty {
                                Button { openURL(link) } label: {
                                    Image(systemName: "link").font(.system(size: 11, weight: .semibold))
                                }
                                .tint(.brandBlue)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel()
    }

    private func queriesPanel(_ queries: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Searches the scout ran", icon: "magnifyingglass")
            ForEach(queries, id: \.self) { q in
                Text("“\(q)”")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.textSec)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel()
    }

    // MARK: - Bits

    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.brand)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.textPri)
        }
    }

    private func receiptRow(_ label: String, value: String, note: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 13, weight: .semibold)).foregroundColor(.textPri)
                Text(note).font(.system(size: 11)).foregroundColor(.textSec)
            }
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.textPri)
        }
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(.textSec)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(.textPri)
        }
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.textSec)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.black.opacity(0.05)))
    }

    private func fmt(_ v: Double?) -> String {
        guard let v else { return "–" }
        return String(format: "%.2f", v)
    }

    private func money(_ v: Double, _ currency: String?) -> String {
        let symbol = (currency == nil || currency == "" || currency == "USD") ? "$" : (currency == "EUR" ? "€" : (currency == "GBP" ? "£" : "\(currency!) "))
        return v == v.rounded() ? "\(symbol)\(Int(v))" : "\(symbol)\(String(format: "%.2f", v))"
    }

    private func priceLabel(_ c: MarketComparable) -> String {
        if c.chargesMoney == "no" || c.pricePeriod == "free" { return "Free" }
        guard let amount = c.priceAmount, amount > 0 else { return c.pricing }
        let base = money(amount, c.priceCurrency)
        switch c.pricePeriod {
        case "month":    return "\(base)/mo"
        case "year":     return "\(base)/yr"
        case "one_time": return "\(base) once"
        default:         return base
        }
    }
}
