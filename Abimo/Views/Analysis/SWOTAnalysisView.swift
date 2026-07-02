//
//  SWOTAnalysisView.swift
//  Abimo
//

import SwiftUI

struct SWOTAnalysisView: View {
    let transcription: Transcription
    let noteTitle: String

    @StateObject private var viewModel: AnalysisViewModel
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var coordinator: NavigationCoordinator

    init(transcription: Transcription, preloadedAnalysis: SWOTAnalysis? = nil, noteTitle: String = "") {
        self.transcription = transcription
        self.noteTitle = noteTitle
        if let existing = preloadedAnalysis {
            _viewModel = StateObject(wrappedValue: AnalysisViewModel(preloadedAnalysis: existing))
        } else {
            _viewModel = StateObject(wrappedValue: AnalysisViewModel())
        }
    }

    /// Returns true when SWOT generation should start automatically on appear.
    /// Auto-generates only when there is no existing analysis and no prior error.
    static func shouldAutoGenerate(analysis: SWOTAnalysis?, errorMessage: String?) -> Bool {
        return analysis == nil && errorMessage == nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    MascotLoadingView(
                        mode: .inline,
                        rotatingMessages: cookingMessages,
                        subtitle: "This might take 15–30 seconds"
                    )
                } else {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 20) {
                            if let analysis = viewModel.analysis {
                                analysisContent(analysis)
                            } else if viewModel.errorMessage != nil {
                                errorView
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                    }
                }
            }
            .background(Color.appBg, ignoresSafeAreaEdges: .all)
            .navigationTitle("The Taste Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(.brand)
                        .fontWeight(.bold)
                }
            }
            .task {
                await viewModel.loadAnalysis(transcriptionId: transcription.id)
                if Self.shouldAutoGenerate(analysis: viewModel.analysis, errorMessage: viewModel.errorMessage) {
                    await viewModel.generateAnalysis(transcription: transcription, noteTitle: noteTitle)
                }
            }
        }
    }

    // MARK: - Analysis Content

    @ViewBuilder
    private func analysisContent(_ analysis: SWOTAnalysis) -> some View {
        // 1. Viability Score
        ViabilityGaugeView(score: analysis.viabilityScore ?? 0)
            .cardEntrance(delay: 0.05)

        // 2. Market Intelligence
        if let insights = analysis.marketInsights {
            MarketIntelligenceSection(insights: insights, context: analysis.marketContext)
                .cardEntrance(delay: 0.12)
        }

        // 3. The four quadrants (avg score lives in each header now)
        QuadrantItemChart(
            title: "The Wins",
            items: analysis.resolvedStrengths,
            avgScore: analysis.avgStrengthScore,
            color: .brandGreen,
            iconName: "checkmark.circle.fill"
        )
        .cardEntrance(delay: 0.18)

        QuadrantItemChart(
            title: "Opportunities",
            items: analysis.resolvedOpportunities,
            avgScore: analysis.avgOpportunityScore,
            color: .brandBlue,
            iconName: "arrow.up.circle.fill"
        )
        .cardEntrance(delay: 0.24)

        QuadrantItemChart(
            title: "Weaknesses",
            items: analysis.resolvedWeaknesses,
            avgScore: analysis.avgWeaknessScore,
            color: .brand,
            iconName: "xmark.circle.fill"
        )
        .cardEntrance(delay: 0.30)

        QuadrantItemChart(
            title: "Watch Out",
            items: analysis.resolvedThreats,
            avgScore: analysis.avgThreatScore,
            color: .brandAmber,
            iconName: "exclamationmark.triangle.fill"
        )
        .cardEntrance(delay: 0.36)

        // 4. Action Plan CTA
        actionPlanCTA(analysis)
            .cardEntrance(delay: 0.42)

        Text("Cooked up \(analysis.createdAt, style: .relative) ago")
            .font(.system(size: 12))
            .foregroundColor(.textSec)
            .padding(.bottom, 8)
            .cardEntrance(delay: 0.48)
    }

    // MARK: - States

    private let cookingMessages: [String] = [
        "Cooking up insights...",
        "Turning up the heat...",
        "Taste-testing your idea...",
        "Simmering your strategy...",
        "Mixing the formula...",
        "The critic is tasting...",
        "Prepping the ingredients...",
        "Almost chef's kiss ready...",
        "Adding a pinch of market data...",
        "Let it marinate for a sec...",
        "Checking the competition's menu...",
        "Nearly plated up...",
    ]

    private var errorView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.brandAmber.opacity(0.1))
                    .frame(width: 90, height: 90)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.brandAmber)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 15))
                    .foregroundColor(.textSec)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            GradientButton(
                title: "One more time",
                gradient: LinearGradient(
                    colors: [.brandAmber, .brandAmber],
                    startPoint: .leading, endPoint: .trailing
                ),
                edge: .brandAmberDark
            ) {
                Task { await viewModel.generateAnalysis(transcription: transcription, noteTitle: noteTitle) }
            }
            .padding(.horizontal, 40)

            Spacer().frame(height: 40)
        }
    }

    private func actionPlanCTA(_ analysis: SWOTAnalysis) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.brand.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.brand)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Turn this into action")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.textPri)
                    Text("Get a micro-action plan you can start right now")
                        .font(.system(size: 13))
                        .foregroundColor(.textSec)
                }
                Spacer()
            }

            Button {
                coordinator.startPlanGeneration(
                    analysis: analysis,
                    transcriptionText: transcription.text,
                    noteTitle: noteTitle
                )
                coordinator.selectedTab = .actions
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14))
                    Text("Get your action plan")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
            }
            .buttonStyle(Duo3DGradientButtonStyle(fill: .record))
        }
        .duoPanel()
    }

}

// MARK: - Viability Gauge

struct ViabilityGaugeView: View {
    let score: Int
    @State private var animatedScore: Double = 0
    @State private var criticLine: String?

    private var verdict: ScoreVerdict { ScoreVerdict(score: score) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.needle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brand)
                Text("Critic's Score")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPri)
                Spacer()
            }

            ZStack {
                // Track arc
                GaugeArc(progress: 1.0)
                    .stroke(Color.black.opacity(0.08), style: StrokeStyle(lineWidth: 14, lineCap: .round))

                // Value arc
                GaugeArc(progress: animatedScore / 100)
                    .stroke(verdict.color, style: StrokeStyle(lineWidth: 14, lineCap: .round))

                // Center label
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(verdict.color)
                    Text(verdict.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSec)
                }
            }
            .frame(height: 150)
            .padding(.horizontal, 32)
            .onAppear {
                withAnimation(.easeOut(duration: 1.2)) {
                    animatedScore = Double(score)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    switch verdict {
                    case .burnt, .halfBaked: HapticEngine.impact(style: .rigid)
                    case .simmering, .chefsKiss: HapticEngine.success()
                    case .needsSeasoning: break
                    }
                    AnimationPolicy.animate(.spring(response: 0.42, dampingFraction: 0.72)) {
                        criticLine = MascotVoice.moment(for: .scoreRevealed(verdict: verdict)).line
                    }
                }
            }

            // Verdict pill badge
            Text("\(verdict.emoji) \(verdict.label)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(verdict.color)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(verdict.color.opacity(0.15))
                .clipShape(Capsule())

            // The critic delivers the verdict in person, ~a beat after the gauge lands
            HStack(alignment: .center, spacing: 6) {
                Image(MascotMood.forVerdict(verdict).assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 54, height: 54)
                if let criticLine {
                    MascotSpeechLine(line: criticLine, arrowOffsetY: 20)
                        .transition(.scale(scale: 0.85, anchor: .leading).combined(with: .opacity))
                } else {
                    Text(verdict.caption)
                        .font(.system(size: 13))
                        .foregroundColor(.textSec)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)

            Text("Most fresh ideas score 20-45. The plan below is the recipe to raise it.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSec.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .duoPanel(fill: .cardDarkMint, padding: 24)
    }
}

// 240° arc shape starting at 150° (bottom-left), sweeping clockwise to 30° (bottom-right)
struct GaugeArc: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY + 20)
        let radius = min(rect.width, rect.height) * 0.42
        let startAngle = Angle(degrees: 150)
        let endAngle = Angle(degrees: 150 + 240 * progress)
        var path = Path()
        path.addArc(center: center, radius: radius,
                    startAngle: startAngle, endAngle: endAngle, clockwise: false)
        return path
    }
}

// MARK: - Market Intelligence

struct MarketIntelligenceSection: View {
    let insights: MarketInsights
    let context: String?

    private var trendIcon: String {
        switch insights.trendDirection {
        case "up":     return "arrow.up.right"
        case "down":   return "arrow.down.right"
        default:       return "arrow.right"
        }
    }

    private var trendColor: Color {
        switch insights.trendDirection {
        case "up":   return .brandGreen
        case "down": return .brand
        default:     return .brandAmber
        }
    }

    private var trendBg: Color {
        switch insights.trendDirection {
        case "up":   return .cardDarkTeal
        case "down": return .cardDarkRed
        default:     return .cardDarkOrange
        }
    }

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DuoDisclosureHeader(
                icon: "globe.americas.fill",
                title: "Market Intel",
                isExpanded: $isExpanded
            ) {
                Label(insights.trendDirection?.capitalized ?? "Stable", systemImage: trendIcon)
                    .font(.duoCaption)
                    .foregroundColor(trendColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(trendColor.opacity(0.1))
                    .cornerRadius(20)
            }

            if isExpanded {
                // 2×2 tile grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let size = insights.marketSize {
                        MarketInsightTile(icon: "chart.pie.fill", label: "Market Size", value: size, color: .brand, tileBackground: .cardDarkRed)
                    }
                    if let rate = insights.growthRate {
                        MarketInsightTile(icon: "arrow.up.right.circle.fill", label: "Growth Rate", value: rate, color: .brandGreen, tileBackground: .cardDarkTeal)
                    }
                    if let competitors = insights.keyCompetitors, !competitors.isEmpty {
                        MarketInsightTile(icon: "person.3.fill", label: "Competitors", value: competitors.prefix(3).joined(separator: ", "), color: .brandAmber, tileBackground: .cardDarkOrange)
                    }
                    if let dir = insights.trendDirection {
                        MarketInsightTile(icon: "waveform.path.ecg", label: "Market Trend", value: dir.capitalized, color: trendColor, tileBackground: trendBg)
                    }
                }

                if let context = context, !context.isEmpty {
                    Text(context)
                        .font(.system(size: 13))
                        .foregroundColor(.textSec)
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .duoInset()
                }
            }
        }
        .duoPanel()
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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.textPri)
                .lineLimit(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tileBackground ?? color.opacity(0.06))
        .cornerRadius(12)
    }
}

// MARK: - Quadrant Item Chart

struct QuadrantItemChart: View {
    let title: String
    let items: [SWOTItem]
    let avgScore: Double
    let color: Color
    let iconName: String

    @State private var isExpanded = false

    private var sortedItems: [SWOTItem] {
        items.sorted { $0.score > $1.score }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DuoDisclosureHeader(
                icon: iconName,
                tint: color,
                title: title,
                subtitle: "\(items.count) item\(items.count == 1 ? "" : "s")",
                isExpanded: $isExpanded
            ) {
                if !items.isEmpty {
                    Text("avg \(Int(avgScore.rounded()))")
                        .font(.duoCaption)
                        .foregroundColor(color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(color.opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            if sortedItems.isEmpty {
                Text("Nothing here — that's a good sign")
                    .font(.system(size: 14))
                    .foregroundColor(.textSec)
                    .italic()
                    .padding(.vertical, 4)
            } else {
                // Always show top item
                itemRow(sortedItems[0])

                if isExpanded {
                    ForEach(sortedItems.dropFirst()) { item in
                        itemRow(item)
                    }

                    // Category pills
                    let categories = Array(Set(sortedItems.map(\.category))).sorted()
                    if !categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(categories, id: \.self) { cat in
                                    Text(cat)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(color)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(color.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.top, 2)
                    }
                } else if sortedItems.count > 1 {
                    Text("+\(sortedItems.count - 1) more")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(color.opacity(0.7))
                }
            }
        }
        .duoPanel()
    }

    private func itemRow(_ item: SWOTItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Text(item.point)
                    .font(.system(size: 14))
                    .foregroundColor(.textPri)
                    .lineLimit(isExpanded ? nil : 2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(item.score)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }

            if isExpanded, let detail = item.detail {
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(.textSec)
                    .lineSpacing(3)
                    .padding(.top, 2)
            }
        }
    }
}

#Preview {
    SWOTAnalysisView(transcription: Transcription(
        id: UUID(),
        noteId: UUID(),
        text: "Sample transcription text",
        language: "en",
        confidence: 0.95,
        createdAt: Date()
    ))
}
