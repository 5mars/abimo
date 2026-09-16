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
    @ObservedObject private var walkIn = WalkInDirector.shared
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var coordinator: NavigationCoordinator

    @State private var walkInBeat = 0
    @State private var activeCourse: SWOTCourse?
    @State private var showMarketSheet = false
    @State private var showVariantsSheet = false
    @State private var showPaywall = false
    @State private var showReceipt = false
    @State private var pendingRetaste: IdeaVariant?

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
            // Walk-in tour: three spotlight beats over the first analysis.
            // Hosted here (not at the root) because this view is a sheet —
            // dismissing it mid-beats resumes next open.
            .walkInSpotlight(spotlightSpec)
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
                if let analysis = viewModel.analysis, let score = analysis.viabilityScore {
                    let band = score >= 70 ? "high" : score >= 40 ? "mid" : "low"
                    AnalyticsService.shared.log(.analysisViewed(
                        scoreBand: band,
                        scoringVersion: analysis.scoringVersion ?? 1
                    ))
                }
            }
            .sheet(item: $activeCourse) { course in
                QuadrantDetailSheet(course: course, onGetActionPlan: {
                    guard let analysis = viewModel.analysis else { return }
                    activeCourse = nil
                    startActionPlan(analysis)
                })
            }
            .sheet(isPresented: $showMarketSheet) {
                if let analysis = viewModel.analysis, let insights = analysis.marketInsights {
                    MarketIntelDetailSheet(insights: insights, context: analysis.marketContext)
                }
            }
            .sheet(isPresented: $showVariantsSheet) {
                if let variants = viewModel.analysis?.ideaVariants, !variants.isEmpty {
                    VariantsDetailSheet(variants: variants, onRetaste: { variant in
                        showVariantsSheet = false
                        pendingRetaste = variant
                    })
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: .fullAnalysis)
            }
            .sheet(isPresented: $showReceipt) {
                if let analysis = viewModel.analysis {
                    EvidenceReceiptSheet(analysis: analysis)
                }
            }
            .alert("Re-taste as \"\(pendingRetaste?.title ?? "")\"?", isPresented: Binding(
                get: { pendingRetaste != nil },
                set: { if !$0 { pendingRetaste = nil } }
            )) {
                Button("Re-taste", role: .destructive) {
                    if let variant = pendingRetaste {
                        pendingRetaste = nil
                        Task {
                            await viewModel.generateAnalysis(
                                transcription: transcription,
                                noteTitle: noteTitle,
                                pivot: variant
                            )
                        }
                    }
                }
                Button("Keep current", role: .cancel) { pendingRetaste = nil }
            } message: {
                Text("The critic re-judges your idea as this remix. Your current score, analysis, and action plan get replaced.")
            }
            .alert("Kitchen incident", isPresented: Binding(
                get: { viewModel.errorMessage != nil && viewModel.analysis != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )) {
                Button("OK") { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    // MARK: - Walk-in beats

    /// Spotlight spec for the current taste-test beat: score gauge, then the
    /// verdict card, then the action-plan CTA. Each falls back to a bottom
    /// card when its target is offscreen (the CTA usually is — no forced
    /// scrolling, the mascot just tells the user where to look).
    private var spotlightSpec: SpotlightSpec? {
        guard walkIn.step == .tasteTest, viewModel.analysis != nil, !viewModel.isLoading else {
            return nil
        }
        switch walkInBeat {
        case 0:
            return SpotlightSpec(
                target: .tasteScore,
                line: WalkInScript.tasteScore,
                primaryLabel: "Next",
                primaryAction: { AnimationPolicy.animate { walkInBeat = 1 } },
                tapThrough: true,
                fallback: .card
            )
        case 1:
            return SpotlightSpec(
                target: .tasteVerdict,
                line: WalkInScript.tasteVerdict,
                primaryLabel: "Next",
                primaryAction: { AnimationPolicy.animate { walkInBeat = 2 } },
                tapThrough: true,
                fallback: .card
            )
        default:
            return SpotlightSpec(
                target: .tastePlanCTA,
                line: WalkInScript.tastePlan,
                primaryLabel: WalkInScript.tastePlanButton,
                primaryAction: { walkIn.tasteTestFinished() },
                tapThrough: true,
                fallback: .card
            )
        }
    }

    /// Shared "turn this into action" behavior — used by the bottom CTA and
    /// the quadrant sheets' action button.
    private func startActionPlan(_ analysis: SWOTAnalysis) {
        coordinator.startPlanGeneration(
            analysis: analysis,
            transcriptionText: transcription.text,
            noteTitle: noteTitle
        )
        coordinator.selectedTab = .actions
        dismiss()
    }

    // MARK: - Analysis Content

    @ViewBuilder
    private func analysisContent(_ analysis: SWOTAnalysis) -> some View {
        // 1. The tasting — score, verdict, critic quip, dimension breakdown
        ViabilityGaugeView(
            score: analysis.viabilityScore ?? 0,
            dimensions: analysis.dimensionScores,
            rationale: analysis.scoreRationale,
            evidence: analysis.dimensionEvidence,
            meta: analysis.scoreMeta,
            evidenceStrength: analysis.evidenceStrength,
            fatalFlaw: analysis.fatalFlaw ?? false,
            fatalFlawReason: analysis.fatalFlawReason,
            isLegacyScoring: analysis.isLegacyScoring,
            receiptLocked: !entitlements.isPremium,
            onShowReceipt: {
                if entitlements.isPremium {
                    showReceipt = true
                } else {
                    AnalyticsService.shared.log(.gateHit(gate: "swot_lock"))
                    showPaywall = true
                }
            }
        )
        .walkInTarget(.tasteScore)
        .cardEntrance(delay: 0.05)

        // 2. The TL;DR
        CriticsVerdictCard(
            summary: analysis.summary,
            verdict: ScoreVerdict(score: analysis.viabilityScore ?? 0)
        )
        .walkInTarget(.tasteVerdict)
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
            .walkInTarget(.tastePlanCTA)
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
                    AnalyticsService.shared.log(.gateHit(gate: "swot_lock"))
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
                        AnalyticsService.shared.log(.gateHit(gate: "swot_lock"))
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
                startActionPlan(analysis)
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
    // Scoring v2 receipt (all nil/false for rows scored with the old recipe)
    var evidence: DimensionEvidence? = nil
    var meta: ScoreMeta? = nil
    var evidenceStrength: String? = nil
    var fatalFlaw: Bool = false
    var fatalFlawReason: String? = nil
    var isLegacyScoring: Bool = false
    var receiptLocked: Bool = true
    var onShowReceipt: (() -> Void)? = nil
    @State private var animatedScore: Double = 0

    private var verdict: ScoreVerdict { ScoreVerdict(score: score) }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "gauge.with.needle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brand)
                    .symbolEffect(.pulse, options: .nonRepeating, isActive: !AnimationPolicy.reduceMotion)
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

                // Center label — digits roll up on the same 1.2s clock as
                // the arc sweep instead of snapping to the final value.
                VStack(spacing: 4) {
                    Text("\(Int(animatedScore.rounded()))")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(verdict.color)
                        .contentTransition(.numericText(value: animatedScore))
                    Text(verdict.label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textSec)
                }
            }
            .frame(height: 150)
            .padding(.horizontal, 32)
            .onAppear {
                if AnimationPolicy.reduceMotion {
                    animatedScore = Double(score)
                } else {
                    withAnimation(.easeOut(duration: 1.2)) {
                        animatedScore = Double(score)
                    }
                }
                let hapticDelay = AnimationPolicy.reduceMotion ? 0.0 : 1.2
                DispatchQueue.main.asyncAfter(deadline: .now() + hapticDelay) {
                    switch verdict {
                    case .burnt, .halfBaked: HapticEngine.impact(style: .rigid)
                    case .simmering, .chefsKiss: HapticEngine.success()
                    case .needsSeasoning: HapticEngine.impact(style: .soft)
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
                .padding(.horizontal, 8)

            // The single most memorable thing the critic can say — it caps
            // the score at 20 server-side, so it had better be on screen.
            if fatalFlaw {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Fatal flaw, as described")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.brand)
                        if let fatalFlawReason, !fatalFlawReason.isEmpty {
                            Text(fatalFlawReason)
                                .font(.system(size: 12))
                                .foregroundColor(.textPri)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: DuoTokens.Radius.inset, style: .continuous)
                        .fill(Color.brand.opacity(0.10))
                )
            }

            // The receipt behind the number — free for everyone, because a
            // harsh score without a "why" just feels arbitrary.
            if let dimensions {
                ScoreBreakdownView(
                    dimensions: dimensions,
                    rationale: rationale,
                    color: verdict.color,
                    evidence: evidence,
                    meta: meta,
                    evidenceStrength: evidenceStrength,
                    isLegacy: isLegacyScoring
                )
                .padding(.horizontal, 4)
            }

            if isLegacyScoring {
                Text("Scored with the critic's old recipe. Re-taste for the evidence-backed number — it will probably move.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textSec.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            } else {
                if let onShowReceipt {
                    Button(action: onShowReceipt) {
                        Label(
                            receiptLocked ? "Evidence receipt · Plus" : "See the evidence receipt",
                            systemImage: receiptLocked ? "lock.fill" : "doc.text.magnifyingglass"
                        )
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.brandBlue)
                    }
                    .buttonStyle(DuoPressStyle())
                }
                Text("Scores run the full range — the plan below is the recipe to raise yours.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.textSec.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .duoPanel(fill: .cardDarkMint, padding: 24)
    }
}

// MARK: - Score Breakdown

/// Five labeled bars showing the sub-scores behind the viability number.
/// With scoring v2 each row also carries its weight, any evidence cap, and
/// expands on tap to the critic's evidence sentence plus "what would raise
/// this" — the reasons are free; the sources live in the Evidence Receipt.
struct ScoreBreakdownView: View {
    let dimensions: DimensionScores
    let rationale: String?
    let color: Color
    var evidence: DimensionEvidence? = nil
    var meta: ScoreMeta? = nil
    var evidenceStrength: String? = nil
    var isLegacy: Bool = false

    @State private var expanded: DimensionKey? = nil

    private var canExpand: Bool { !isLegacy && (evidence != nil || meta != nil) }

    var body: some View {
        VStack(spacing: 9) {
            if !isLegacy, let pill = DimensionRubric.evidenceStrengthCopy(evidenceStrength) {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: pill.icon)
                        .font(.system(size: 11, weight: .semibold))
                    Text(pill.text)
                        .font(.system(size: 11, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .foregroundColor(evidenceStrength == "none" || evidenceStrength == "thin" ? .brandAmberDark : .brandGreenDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: DuoTokens.Radius.chip, style: .continuous)
                        .fill((evidenceStrength == "none" || evidenceStrength == "thin" ? Color.brandAmber : Color.brandGreen).opacity(0.12))
                )
                .padding(.bottom, 2)
            }

            ForEach(DimensionKey.allCases) { key in
                row(for: key)
            }

            if meta?.hedged == true {
                HStack(spacing: 6) {
                    Image(systemName: "scale.3d")
                        .font(.system(size: 11, weight: .semibold))
                    Text("The critic hedged — every dimension sat in 4-6, so the number was docked 4.")
                        .font(.system(size: 11, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .foregroundColor(.textSec)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
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

    @ViewBuilder
    private func row(for key: DimensionKey) -> some View {
        let value = dimensions.value(for: key)
        let cap = meta?.cap(for: key)
        let isOpen = expanded == key

        VStack(spacing: 6) {
            Button {
                guard canExpand else { return }
                HapticEngine.selection()
                AnimationPolicy.animate(.spring(response: 0.3, dampingFraction: 0.75)) {
                    expanded = isOpen ? nil : key
                }
            } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(key.label)
                            .font(.duoCaption)
                            .foregroundColor(.textSec)
                        if let w = DimensionRubric.weightLabel(meta?.weight(for: key)) {
                            Text(w)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.textSec.opacity(0.6))
                        }
                    }
                    .frame(width: 74, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.06))
                            Capsule()
                                .fill(color)
                                .frame(width: max(8, geo.size.width * CGFloat(value) / 10))
                            if let cap {
                                // Ghost of what the model said before the cap
                                Capsule()
                                    .strokeBorder(color.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                    .frame(width: max(8, geo.size.width * CGFloat(cap.from) / 10))
                            }
                        }
                    }
                    .frame(height: 8)

                    HStack(spacing: 3) {
                        if cap != nil {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.textSec.opacity(0.7))
                        }
                        Text("\(value)/10")
                            .font(.duoCaption)
                            .foregroundColor(color)
                    }
                    .frame(width: 44, alignment: .trailing)

                    if canExpand {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.textSec.opacity(0.5))
                            .rotationEffect(.degrees(isOpen ? 180 : 0))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canExpand)

            if isOpen {
                VStack(alignment: .leading, spacing: 6) {
                    if let text = evidence?.text(for: key), !text.isEmpty {
                        Text(text)
                            .font(.system(size: 12))
                            .foregroundColor(.textPri)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let cap {
                        Label {
                            Text("Capped at \(cap.to) (the critic said \(cap.from)): \(cap.reason)")
                                .fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "lock.fill")
                        }
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.brandAmberDark)
                    }
                    Label {
                        Text(DimensionRubric.nextStep(for: key, score: value))
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "arrow.up.right.circle.fill")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.brandGreenDark)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: DuoTokens.Radius.inset, style: .continuous)
                        .fill(Color.white.opacity(0.7))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
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
