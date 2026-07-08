//
//  SWOTAnalysisView.swift
//  Abimo
//

import SwiftUI

struct SWOTAnalysisView: View {
    let transcription: Transcription
    let noteTitle: String

    @StateObject private var viewModel: AnalysisViewModel
    @ObservedObject private var entitlements = EntitlementService.shared
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var coordinator: NavigationCoordinator

    @State private var activeCourse: SWOTCourse?
    @State private var showMarketSheet = false
    @State private var showVariantsSheet = false
    @State private var showPaywall = false

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
            .sheet(item: $activeCourse) { course in
                QuadrantDetailSheet(course: course)
            }
            .sheet(isPresented: $showMarketSheet) {
                if let analysis = viewModel.analysis, let insights = analysis.marketInsights {
                    MarketIntelDetailSheet(insights: insights, context: analysis.marketContext)
                }
            }
            .sheet(isPresented: $showVariantsSheet) {
                if let variants = viewModel.analysis?.ideaVariants, !variants.isEmpty {
                    VariantsDetailSheet(variants: variants)
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: .fullAnalysis)
            }
        }
    }

    // MARK: - Analysis Content

    @ViewBuilder
    private func analysisContent(_ analysis: SWOTAnalysis) -> some View {
        // 1. The tasting — score, verdict, critic quip, dimension breakdown
        ViabilityGaugeView(
            score: analysis.viabilityScore ?? 0,
            dimensions: analysis.dimensionScores,
            rationale: analysis.scoreRationale
        )
        .cardEntrance(delay: 0.05)

        // 2. The TL;DR
        CriticsVerdictCard(
            summary: analysis.summary,
            verdict: ScoreVerdict(score: analysis.viabilityScore ?? 0)
        )
        .cardEntrance(delay: 0.12)

        // 3. The courses — one compact card per quadrant, tap for the full plate
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(Array(analysis.courses.enumerated()), id: \.element.id) { index, course in
                CourseCard(course: course) {
                    activeCourse = course
                }
                .cardEntrance(delay: 0.18 + Double(index) * 0.04)
            }
        }

        // 4. Remix the Recipe (fully Plus)
        if let variants = analysis.ideaVariants, !variants.isEmpty {
            remixCard(variants)
                .cardEntrance(delay: 0.34)
        }

        // 5. Market Intel course (Plus)
        if let insights = analysis.marketInsights {
            marketIntelCard(insights)
                .cardEntrance(delay: 0.38)
        }

        // 5. Action Plan CTA
        actionPlanCTA(analysis)
            .cardEntrance(delay: 0.42)

        Text("Cooked up \(analysis.createdAt, style: .relative) ago")
            .font(.system(size: 12))
            .foregroundColor(.textSec)
            .padding(.bottom, 8)
            .cardEntrance(delay: 0.48)
    }

    // MARK: - Remix the Recipe card (fully Plus)

    @ViewBuilder
    private func remixCard(_ variants: [IdeaVariant]) -> some View {
        if entitlements.isPremium {
            Button {
                showVariantsSheet = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.brandGreen.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.brandGreen)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Remix the Recipe")
                            .font(.duoCardTitle)
                            .foregroundColor(.textPri)
                        Text("\(variants.count) variation\(variants.count == 1 ? "" : "s") cooked")
                            .font(.system(size: 13))
                            .foregroundColor(.textSec)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSec)
                }
            }
            .buttonStyle(DuoCardButtonStyle(padding: 16))
        } else {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.brandGreen)
                    Text("Remix the Recipe")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPri)
                    Spacer()
                    Text("\(variants.count) cooked")
                        .font(.duoCaption)
                        .foregroundColor(.brandGreen)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.brandGreen.opacity(0.12))
                        .clipShape(Capsule())
                }
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(variants) { variant in
                        Text(variant.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.textPri)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .plusLocked(true, message: "Unlock the remixes") {
                    showPaywall = true
                }
            }
            .duoPanel()
        }
    }

    // MARK: - Market Intel course card

    @ViewBuilder
    private func marketIntelCard(_ insights: MarketInsights) -> some View {
        if entitlements.isPremium {
            // Plus: compact tap-through card into the full sheet
            Button {
                showMarketSheet = true
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.brandBlue.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.brandBlue)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Market Intel")
                            .font(.duoCardTitle)
                            .foregroundColor(.textPri)
                        Text(insights.marketSize ?? insights.growthRate ?? "The lay of the land")
                            .font(.system(size: 13))
                            .foregroundColor(.textSec)
                            .lineLimit(1)
                    }
                    Spacer()
                    Label(insights.trendDirection?.capitalized ?? "Stable",
                          systemImage: MarketTrendStyle.icon(for: insights.trendDirection))
                        .font(.duoCaption)
                        .foregroundColor(MarketTrendStyle.color(for: insights.trendDirection))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(MarketTrendStyle.color(for: insights.trendDirection).opacity(0.1))
                        .cornerRadius(20)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.textSec)
                }
            }
            .buttonStyle(DuoCardButtonStyle(padding: 16))
        } else {
            // Free: the intel is right there — just out of focus
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.brandBlue)
                    Text("Market Intel")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.textPri)
                    Spacer()
                }
                MarketInsightGrid(insights: insights)
                    .plusLocked(true, message: "Unlock Market Intel") {
                        showPaywall = true
                    }
            }
            .duoPanel()
        }
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
    var dimensions: DimensionScores? = nil
    var rationale: String? = nil
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

            // The receipt behind the number — free for everyone, because a
            // harsh score without a "why" just feels arbitrary.
            if let dimensions {
                ScoreBreakdownView(dimensions: dimensions, rationale: rationale, color: verdict.color)
                    .padding(.horizontal, 4)
            }

            Text("Scores run the full range — the plan below is the recipe to raise yours.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.textSec.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .duoPanel(fill: .cardDarkMint, padding: 24)
    }
}

// MARK: - Score Breakdown

/// Five labeled bars showing the sub-scores behind the viability number,
/// plus the critic's one-line rationale for the weakest link.
struct ScoreBreakdownView: View {
    let dimensions: DimensionScores
    let rationale: String?
    let color: Color

    private var rows: [(label: String, value: Int)] {
        [
            ("Problem",   dimensions.problemSeverity),
            ("Demand",    dimensions.demandEvidence),
            ("Market",    dimensions.marketQuality),
            ("Buildable", dimensions.feasibility),
            ("Different", dimensions.differentiation),
        ]
    }

    var body: some View {
        VStack(spacing: 9) {
            ForEach(rows, id: \.label) { row in
                HStack(spacing: 10) {
                    Text(row.label)
                        .font(.duoCaption)
                        .foregroundColor(.textSec)
                        .frame(width: 74, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.06))
                            Capsule()
                                .fill(color)
                                .frame(width: max(8, geo.size.width * CGFloat(row.value) / 10))
                        }
                    }
                    .frame(height: 8)

                    Text("\(row.value)/10")
                        .font(.duoCaption)
                        .foregroundColor(color)
                        .frame(width: 36, alignment: .trailing)
                }
            }

            if let rationale, !rationale.isEmpty {
                Text(rationale)
                    .font(.system(size: 12))
                    .italic()
                    .foregroundColor(.textSec)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .padding(.top, 4)
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
