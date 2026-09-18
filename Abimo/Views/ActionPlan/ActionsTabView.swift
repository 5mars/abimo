//
//  ActionsTabView.swift
//  Abimo
//

import SwiftUI

struct ActionsTabView: View {
    @EnvironmentObject var viewModel: ActionsTabViewModel
    @EnvironmentObject var coordinator: NavigationCoordinator
    @State private var expandedCommitmentPlanId: UUID? = nil
    @AppStorage(DailyGoalTier.storageKey) private var dailyGoalXP = DailyGoalTier.fallback.rawValue
    @AppStorage(DareEngine.latchStorageKey) private var dareLatchStore = ""
    @AppStorage(DareEngine.replayLatchKey) private var replayLatch = ""
    @ObservedObject private var pipeline = IdeaPipelineService.shared

    /// Today's XP for the goal ring: action completions plus latched dares.
    private var xpToday: Int {
        let latched = DareEngine.decodeLatch(dareLatchStore, for: Date())
        return XPEngine.xpToday(completionDates: viewModel.allCompletionDates)
            + DareEngine.xp(latchedCount: latched.count)
    }

    private var dareContext: DareContext {
        DareContext(
            ideasRecordedToday: viewModel.notes.filter { Calendar.current.isDateInToday($0.createdAt) }.count,
            replayedPitchToday: replayLatch == DareEngine.dayKey(for: Date())
        )
    }

    /// What today is about — decided by one pure function.
    private var loopState: DailyLoopState {
        DailyLoopState.resolve(
            notes: viewModel.notes,
            plans: viewModel.plans,
            actionsByPlan: viewModel.microActionsByPlan,
            pipelineCooking: pipeline.isRunning,
            planGenerationPending: coordinator.pendingPlanGeneration,
            planGenerationFailed: coordinator.planGenerationRetry != nil
        )
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Hand-drawn title, like the Kitchen — the system large
                    // title ignores the palette.
                    Text("Actions")
                        .font(.duoScreenTitle)
                        .foregroundColor(.textPri)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    if viewModel.isLoading && !viewModel.hasLoadedOnce {
                        MascotLoadingView(mode: .inline, text: "Loading your actions...")
                    } else if viewModel.plans.isEmpty && viewModel.errorMessage != nil {
                        loadErrorState
                            .cardEntrance(delay: 0.1)
                    } else if loopState == .noIdeas {
                        // First run belongs to the walk-in tour.
                        emptyState
                            .cardEntrance(delay: 0.1)
                    } else {
                        // The daily surface shows for anyone with at least one
                        // idea — a founder with no plan (or every plan finished)
                        // still has a streak to keep and dares to clear.
                        MomentumDashboard(
                            streak: viewModel.currentStreak,
                            weekActivity: viewModel.weekActivity,
                            totalCompletedThisWeek: viewModel.totalCompletedThisWeek,
                            xpToday: xpToday,
                            dailyGoalXP: $dailyGoalXP
                        )
                        .padding(.horizontal, 16)
                        .cardEntrance(delay: 0)

                        DailyDaresCard(
                            actionsByPlan: viewModel.microActionsByPlan,
                            streak: viewModel.currentStreak,
                            committedActionId: viewModel.activeCommitment?.microActionId,
                            context: dareContext
                        )
                        .padding(.horizontal, 16)
                        .cardEntrance(delay: 0.06)

                        topBanner

                        sparkCard
                            .padding(.horizontal, 16)
                            .cardEntrance(delay: 0.1)

                        ForEach(Array(viewModel.plans.enumerated()), id: \.element.id) { index, plan in
                            ideaCard(plan)
                                .padding(.horizontal, 16)
                                // Final walk-in beat spotlights the first card.
                                .walkInTarget(
                                    .firstActionCard,
                                    isActive: index == 0 && coordinator.selectedTab == .actions
                                )
                                .cardEntrance(delay: Double(index) * 0.08 + 0.12)
                        }
                    }

                    Spacer().frame(height: 100)
                }
            }
        }
        // A notification deep-linked to a plan pushes it directly.
        .navigationDestination(isPresented: Binding(
            get: { coordinator.pendingPlan != nil },
            set: { if !$0 { coordinator.pendingPlan = nil } }
        )) {
            if let pending = coordinator.pendingPlan {
                ActionPlanDetailView(planId: pending.planId, analysisId: pending.analysisId)
            }
        }
        .navigationTitle("")
        .toolbarBackground(Color.appBg, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
        .task {
            await viewModel.loadAllPlans()
        }
        .onChange(of: coordinator.selectedTab) { _, newTab in
            if newTab == .actions {
                Task { await viewModel.loadAllPlans() }
            }
        }
        .onChange(of: coordinator.pendingPlanGeneration) { _, isPending in
            if !isPending {
                Task { await viewModel.loadAllPlans() }
            }
        }
    }

    // MARK: - Spark card (the day's one non-plan prompt)

    @ViewBuilder
    private var sparkCard: some View {
        switch loopState {
        case .ideaUntasted(let noteId, let title):
            SparkCard(
                kind: .tasteIdea,
                title: "\u{201C}\(title)\u{201D} is sitting raw.",
                line: MascotVoice.moment(for: .recordPrompt).line,
                buttonTitle: "Taste it",
                onTap: {
                    AnalyticsService.shared.log(.sparkTapped(kind: SparkCard.Kind.tasteIdea.rawValue))
                    if let note = viewModel.notes.first(where: { $0.id == noteId }) {
                        coordinator.pendingShowAnalysis = true
                        coordinator.navigateToNote(note)
                    }
                }
            )
        case .planMissing(let noteId, let title, _):
            SparkCard(
                kind: .buildPlan,
                title: "\u{201C}\(title)\u{201D} is tasted but has no plan.",
                line: "Critics talk, cooks do. Let's write the recipe.",
                buttonTitle: "Get the action plan",
                onTap: {
                    AnalyticsService.shared.log(.sparkTapped(kind: SparkCard.Kind.buildPlan.rawValue))
                    if let note = viewModel.notes.first(where: { $0.id == noteId }) {
                        coordinator.navigateToNote(note)
                    }
                }
            )
        case .allChaptersDone:
            SparkCard(
                kind: .whatsNext,
                title: "Every plan on the stove is done.",
                line: MascotVoice.moment(for: .planComplete).line,
                buttonTitle: "Record a new idea",
                onTap: {
                    AnalyticsService.shared.log(.sparkTapped(kind: SparkCard.Kind.whatsNext.rawValue))
                    coordinator.selectedTab = .record
                }
            )
        case .activePlan, .planCooking, .planFailed, .noIdeas:
            EmptyView()
        }
    }

    // MARK: - Top Banner (budget: at most ONE message surface)

    /// Priority: generation failed > plan cooking > mascot nudge.
    /// (The final walk-in beat is a root-level spotlight on the first card.)
    @ViewBuilder
    private var topBanner: some View {
        if let retry = coordinator.planGenerationRetry {
            planRetryCard(retry)
                .padding(.horizontal, 16)
        } else if coordinator.pendingPlanGeneration {
            planCookingRow
                .padding(.horizontal, 16)
        } else if let nudge = viewModel.nudges.first,
                  !NudgeBanner.isDismissedToday(type: nudge.type) {
            NudgeBanner(nudge: nudge)
                .padding(.horizontal, 16)
                .cardEntrance(delay: 0.04)
        }
    }

    private var planCookingRow: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.brand)
            Text("Cooking up your action plan...")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.textPri)
            Spacer()
        }
        .duoPanel(fill: .cardDarkRed, padding: 16)
    }

    // MARK: - Idea Card

    private func ideaCard(_ plan: ActionPlan) -> some View {
        let completed = viewModel.completedCount(for: plan.id)
        let total = viewModel.totalCount(for: plan.id)
        let committedAction = viewModel.committedMicroAction(for: plan.id)

        return VStack(alignment: .leading, spacing: 18) {
            // Idea title + progress
            HStack {
                Text(plan.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)

                Spacer()

                Text("\(completed) of \(total)")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.textSec)
                    .contentTransition(.numericText())
            }

            // Committed action — inset inside the card, not a card-in-card
            if let action = committedAction {
                let isExpanded = expandedCommitmentPlanId == plan.id

                Button {
                    AnimationPolicy.animate(.spring(response: 0.3, dampingFraction: 0.8)) {
                        expandedCommitmentPlanId = isExpanded ? nil : plan.id
                    }
                } label: {
                    VStack(alignment: .leading, spacing: isExpanded ? 10 : 0) {
                        HStack(spacing: 10) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.brand)

                            Text(action.text)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.textPri)
                                .lineLimit(isExpanded ? nil : 2)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.textSec.opacity(0.5))
                                .rotationEffect(.degrees(isExpanded ? -180 : 0))
                        }

                        if isExpanded {
                            Text(action.doneCriteria)
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(.textSec)
                                .multilineTextAlignment(.leading)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cardDarkTeal)
                    .cornerRadius(DuoTokens.Radius.inset)
                }
                .buttonStyle(.plain)
            }

            // See all actions
            NavigationLink {
                ActionPlanDetailView(planId: plan.id, analysisId: plan.analysisId)
            } label: {
                HStack(spacing: 6) {
                    Text(ActionPlanViewModel.journeyCTA(completed: completed, committed: committedAction != nil))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.brand)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.brand)
                }
            }
            .buttonStyle(DuoPressStyle())
        }
        .duoCard()
    }

    // MARK: - Error States

    private func planRetryCard(_ retry: PlanGenerationRetryContext) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.brandAmber)
                Text("The kitchen hiccuped")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                Spacer()
            }
            Text("Your action plan for \"\(retry.noteTitle.isEmpty ? "your idea" : retry.noteTitle)\" didn't come out. Fire it up again?")
                .font(.system(size: 13))
                .foregroundColor(.textSec)
                .frame(maxWidth: .infinity, alignment: .leading)
            GradientButton(title: "Try again", size: .compact) {
                coordinator.startPlanGeneration(
                    analysis: retry.analysis,
                    transcriptionText: retry.transcriptionText,
                    noteTitle: retry.noteTitle
                )
            }
        }
        .duoPanel(fill: .cardDarkOrange, padding: 16)
    }

    private var loadErrorState: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 36))
                .foregroundColor(.brandAmber)
            Text("Couldn't load your plans")
                .font(.duoCardTitle)
                .foregroundColor(.textPri)
            Text("Check your connection and give it another go.")
                .font(.system(size: 13))
                .foregroundColor(.textSec)
            GradientButton(title: "Retry", size: .compact) {
                Task { await viewModel.loadAllPlans() }
            }
            .frame(width: 160)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        MascotEmptyStateView(
            line: MascotVoice.moment(for: .emptyKitchen).line,
            title: "Your action plans will live here",
            subtitle: "Here's how it works",
            ctaTitle: "Record an idea",
            ctaAction: { coordinator.selectedTab = .record }
        ) {
            VStack(alignment: .leading, spacing: 16) {
                stepRow(number: 1, icon: "mic.fill", text: "Record an idea")
                stepRow(number: 2, icon: "fork.knife", text: "Let the critic taste it")
                stepRow(number: 3, icon: "bolt.fill", text: "Get your action plan")
            }
            .padding(.horizontal, 32)
        }
        .padding(.top, 40)
    }

    private func stepRow(number: Int, icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brand)
            }
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.textPri)
        }
    }
}
