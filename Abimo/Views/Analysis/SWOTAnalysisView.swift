//
//  SWOTAnalysisView.swift
//  Abimo
//

import SwiftUI
import Charts

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
            .navigationTitle("Lab Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(.brand)
                        .fontWeight(.bold)
                        .buttonStyle(PlayfulButtonStyle())
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

        // 2. Quadrant Summary Grid
        QuadrantSummaryGrid(analysis: analysis)
            .cardEntrance(delay: 0.10)

        // 3. Category Overview Bar Chart
        CategoryOverviewChart(analysis: analysis)
            .cardEntrance(delay: 0.15)

        // 4. Market Intelligence
        if let insights = analysis.marketInsights {
            MarketIntelligenceSection(insights: insights, context: analysis.marketContext)
                .cardEntrance(delay: 0.20)
        }

        // 5. Item Score Details per quadrant
        QuadrantItemChart(
            title: "The Wins",
            items: analysis.resolvedStrengths,
            color: .brandGreen,
            gradient: .swotStrength,
            iconName: "checkmark.circle.fill"
        )
        .cardEntrance(delay: 0.26)

        QuadrantItemChart(
            title: "Opportunities",
            items: analysis.resolvedOpportunities,
            color: .brandBlue,
            gradient: .swotOpportunity,
            iconName: "arrow.up.circle.fill"
        )
        .cardEntrance(delay: 0.32)

        QuadrantItemChart(
            title: "Weaknesses",
            items: analysis.resolvedWeaknesses,
            color: .brandRed,
            gradient: .swotWeakness,
            iconName: "xmark.circle.fill"
        )
        .cardEntrance(delay: 0.38)

        QuadrantItemChart(
            title: "Watch Out",
            items: analysis.resolvedThreats,
            color: .brandOrange,
            gradient: .swotThreat,
            iconName: "exclamationmark.triangle.fill"
        )
        .cardEntrance(delay: 0.44)

        // 6. Action Plan CTA
        actionPlanCTA(analysis)
            .cardEntrance(delay: 0.50)

        Text("Cooked up \(analysis.createdAt, style: .relative) ago")
            .font(.system(size: 12))
            .foregroundColor(.textSec)
            .padding(.bottom, 8)
            .cardEntrance(delay: 0.56)
    }

    // MARK: - States

    private let cookingMessages: [String] = [
        "Cooking up insights...",
        "Turning up the heat...",
        "Taste-testing your idea...",
        "Simmering your strategy...",
        "Mixing the formula...",
        "Running the experiment...",
        "Prepping the ingredients...",
        "Almost chef's kiss ready...",
        "Adding a pinch of market data...",
        "Let it marinate for a sec...",
        "Stress-testing your thesis...",
        "Nearly plated up...",
    ]

    private var errorView: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 40)

            ZStack {
                Circle()
                    .fill(Color.brandOrange.opacity(0.1))
                    .frame(width: 90, height: 90)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.brandOrange)
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
                    colors: [.brandOrange, .brandAmber],
                    startPoint: .leading, endPoint: .trailing
                )
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
                // Capture all values before dismiss
                let capturedAnalysis = analysis
                let capturedTranscriptionText = transcription.text
                let capturedTitle = noteTitle

                // Signal loading state to Actions tab
                coordinator.pendingPlanGeneration = true
                // Navigate to Actions tab
                coordinator.selectedTab = .actions
                // Dismiss SWOT sheet
                dismiss()

                // Fire-and-forget: generate plan in background
                // Using AIAnalysisService directly (not viewModel) to survive sheet dismissal
                Task { @MainActor in
                    let service = AIAnalysisService()
                    do {
                        _ = try await service.generateAndSaveActionPlan(
                            analysis: capturedAnalysis,
                            transcriptionText: capturedTranscriptionText,
                            noteTitle: capturedTitle
                        )
                    } catch {
                        // Silent failure — plan won't appear; user can retry from NoteDetailView
                    }
                    coordinator.pendingPlanGeneration = false
                }
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
                .background(LinearGradient.record)
                .cornerRadius(18)
            }
            .buttonStyle(PlayfulButtonStyle())
        }
        .cardStyle()
    }

}

// MARK: - Viability Gauge

struct ViabilityGaugeView: View {
    let score: Int
    @State private var animatedScore: Double = 0

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

            Text(verdict.caption)
                .font(.system(size: 13))
                .foregroundColor(.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Text("Most fresh ideas score 20-45. The plan below is the recipe to raise it.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSec.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .heroCard(color: Color(hex: "F0FAFA"))
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

// MARK: - Category Overview Bar Chart

struct CategoryOverviewChart: View {
    let analysis: SWOTAnalysis
    @State private var selectedLabel: String?

    private struct BarData: Identifiable {
        let id: String   // label doubles as stable id
        let score: Double
        let color: Color
    }

    private var data: [BarData] {
        [
            BarData(id: "Strengths",     score: analysis.avgStrengthScore,    color: .brandGreen),
            BarData(id: "Opportunities", score: analysis.avgOpportunityScore, color: .brandBlue),
            BarData(id: "Weaknesses",    score: analysis.avgWeaknessScore,    color: .brandRed),
            BarData(id: "Threats",       score: analysis.avgThreatScore,      color: .brandOrange),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brand)
                Text("The Big Picture")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPri)
                Spacer()
                if selectedLabel != nil {
                    Text("Tap elsewhere to dismiss")
                        .font(.system(size: 10))
                        .foregroundColor(.textSec)
                }
            }

            Chart(data) { item in
                BarMark(
                    x: .value("Quadrant", item.id),
                    y: .value("Avg Score", item.score)
                )
                .foregroundStyle(
                    (selectedLabel == nil || selectedLabel == item.id)
                        ? AnyShapeStyle(item.color.gradient)
                        : AnyShapeStyle(item.color.opacity(0.25))
                )
                .cornerRadius(6)

                if selectedLabel == item.id {
                    RuleMark(x: .value("Selected", item.id))
                        .foregroundStyle(.clear)
                        .annotation(
                            position: .top,
                            alignment: .center,
                            spacing: 6,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            BarTooltip(label: item.id, score: item.score, color: item.color)
                        }
                }
            }
            .chartXSelection(value: $selectedLabel)
            .chartYScale(domain: 0...100)
            .chartYAxis {
                AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.black.opacity(0.06))
                    AxisValueLabel()
                        .foregroundStyle(Color.textSec)
                        .font(.system(size: 10))
                }
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel()
                        .foregroundStyle(Color.textSec)
                        .font(.system(size: 11, weight: .medium))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)  // extra height to accommodate tooltip above bar
        }
        .cardStyle()
    }
}

struct BarTooltip: View {
    let label: String
    let score: Double
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(score.rounded()))")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(color)
            Text("avg score")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.textSec)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.cardSurface)
        .cornerRadius(8)
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
        case "down": return .brandRed
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
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.brand)
                    Text("Market Intel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPri)
                    Spacer()
                    Label(insights.trendDirection?.capitalized ?? "Stable", systemImage: trendIcon)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(trendColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(trendColor.opacity(0.1))
                        .cornerRadius(20)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSec)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)
                }
            }
            .buttonStyle(.plain)

            if isExpanded {
                // 2×2 tile grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let size = insights.marketSize {
                        MarketInsightTile(icon: "chart.pie.fill", label: "Market Size", value: size, color: .brand, tileBackground: .cardDarkPurple)
                    }
                    if let rate = insights.growthRate {
                        MarketInsightTile(icon: "arrow.up.right.circle.fill", label: "Growth Rate", value: rate, color: .brandGreen, tileBackground: .cardDarkTeal)
                    }
                    if let competitors = insights.keyCompetitors, !competitors.isEmpty {
                        MarketInsightTile(icon: "person.3.fill", label: "Competitors", value: competitors.prefix(3).joined(separator: ", "), color: .brandOrange, tileBackground: .cardDarkOrange)
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
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.04))
                        .cornerRadius(10)
                }
            } else {
                // Collapsed summary row
                HStack(spacing: 16) {
                    if let size = insights.marketSize {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Market Size")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.textSec)
                            Text(size)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textPri)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let rate = insights.growthRate {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Growth")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.textSec)
                            Text(rate)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.textPri)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .cardStyle()
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
    let color: Color
    let gradient: LinearGradient
    let iconName: String

    @State private var isExpanded = false

    private var sortedItems: [SWOTItem] {
        items.sorted { $0.score > $1.score }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Tappable header
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: iconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.textPri)
                        Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundColor(.textSec)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSec)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isExpanded)
                }
            }
            .buttonStyle(.plain)

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
        .cardStyle()
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

// MARK: - Quadrant Summary Grid

struct QuadrantSummaryGrid: View {
    let analysis: SWOTAnalysis

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            QuadrantMiniCard(
                letter: "S",
                title: "The Wins",
                count: analysis.resolvedStrengths.count,
                avgScore: analysis.avgStrengthScore,
                color: .brandGreen,
                background: .cardDarkTeal
            )
            QuadrantMiniCard(
                letter: "O",
                title: "Opportunities",
                count: analysis.resolvedOpportunities.count,
                avgScore: analysis.avgOpportunityScore,
                color: .brandBlue,
                background: .cardDarkBlue
            )
            QuadrantMiniCard(
                letter: "W",
                title: "Weaknesses",
                count: analysis.resolvedWeaknesses.count,
                avgScore: analysis.avgWeaknessScore,
                color: .brandRed,
                background: .cardDarkRed
            )
            QuadrantMiniCard(
                letter: "T",
                title: "Watch Out",
                count: analysis.resolvedThreats.count,
                avgScore: analysis.avgThreatScore,
                color: .brandOrange,
                background: .cardDarkOrange
            )
        }
    }
}

struct QuadrantMiniCard: View {
    let letter: String
    let title: String
    let count: Int
    let avgScore: Double
    let color: Color
    let background: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(letter)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(color)
                Spacer()
                Text("\(count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSec)
                Text("items")
                    .font(.system(size: 11))
                    .foregroundColor(.textSec.opacity(0.6))
            }
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.textSec)
            // Score bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                        .frame(height: 4)
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: max(4, geo.size.width * CGFloat(avgScore / 100)), height: 4)
                }
            }
            .frame(height: 4)
        }
        .padding(16)
        .background(background)
        .cornerRadius(20)
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
