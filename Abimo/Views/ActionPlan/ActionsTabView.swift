//
//  ActionsTabView.swift
//  Abimo
//

import SwiftUI

struct ActionsTabView: View {
    @StateObject private var viewModel = ActionsTabViewModel()
    @EnvironmentObject var coordinator: NavigationCoordinator
    @State private var expandedCommitmentPlanId: UUID? = nil

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 4)

                    if viewModel.isLoading {
                        MascotLoadingView(mode: .inline, text: "Loading your actions...")
                    } else if viewModel.plans.isEmpty && viewModel.errorMessage != nil {
                        loadErrorState
                            .cardEntrance(delay: 0.1)
                    } else if viewModel.plans.isEmpty {
                        if coordinator.pendingPlanGeneration || coordinator.planGenerationRetry != nil {
                            topBanner
                        } else {
                            emptyState
                                .cardEntrance(delay: 0.1)
                        }
                    } else {
                        // Momentum Dashboard
                        if !viewModel.allCompletionDates.isEmpty {
                            MomentumDashboard(
                                streak: viewModel.currentStreak,
                                weekActivity: viewModel.weekActivity,
                                totalCompletedThisWeek: viewModel.totalCompletedThisWeek
                            )
                            .padding(.horizontal, 16)
                            .cardEntrance(delay: 0)
                        }

                        topBanner

                        ForEach(Array(viewModel.plans.enumerated()), id: \.element.id) { index, plan in
                            ideaCard(plan)
                                .padding(.horizontal, 16)
                                .cardEntrance(delay: Double(index) * 0.08 + 0.06)
                        }
                    }

                    Spacer().frame(height: 100)
                }
            }
        }
        .navigationTitle("Actions")
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

    // MARK: - Top Banner (budget: at most ONE message surface)

    /// Priority: generation failed > plan cooking > mascot nudge.
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
                    Text(committedAction != nil ? "Continue your plan" : "Choose your first step")
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
        VStack(spacing: 28) {
            HStack(alignment: .center, spacing: 2) {
                Image("MascotNeutral")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 130, height: 130)
                MascotSpeechLine(
                    line: MascotVoice.moment(for: .emptyKitchen).line,
                    arrowOffsetY: 24
                )
            }
            .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Text("Your action plans will live here")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)

                Text("Here's how it works")
                    .font(.system(size: 14))
                    .foregroundColor(.textSec)
            }

            VStack(alignment: .leading, spacing: 16) {
                stepRow(number: 1, icon: "mic.fill", text: "Record an idea")
                stepRow(number: 2, icon: "fork.knife", text: "Let the critic taste it")
                stepRow(number: 3, icon: "bolt.fill", text: "Get your action plan")
            }
            .padding(.horizontal, 32)

            GradientButton(title: "Record an idea") {
                coordinator.selectedTab = .record
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
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
