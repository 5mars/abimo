//
//  ActionsTabView.swift
//  Abimo
//

import SwiftUI

struct ActionsTabView: View {
    @StateObject private var viewModel = ActionsTabViewModel()
    @EnvironmentObject var coordinator: NavigationCoordinator
    @State private var expandedCommitmentPlanId: UUID? = nil
    @AppStorage("hasSeenActionsOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 4)

                    if viewModel.isLoading {
                        MascotLoadingView(mode: .inline, text: "Loading your actions...")
                    } else if viewModel.plans.isEmpty && !coordinator.pendingPlanGeneration {
                        emptyState
                            .cardEntrance(delay: 0.1)
                    } else if viewModel.plans.isEmpty && coordinator.pendingPlanGeneration {
                        // First plan being generated
                        VStack(spacing: 16) {
                            Spacer().frame(height: 40)
                            ProgressView()
                                .tint(.brand)
                                .scaleEffect(1.2)
                            Text("Cooking up your action plan...")
                                .font(.system(size: 17, weight: .medium, design: .rounded))
                                .foregroundColor(.textSec)
                            Spacer().frame(height: 40)
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

                        if !hasSeenOnboarding {
                            onboardingCard
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        if coordinator.pendingPlanGeneration {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .tint(.brand)
                                Text("Cooking up your action plan...")
                                    .font(.system(size: 15, weight: .medium, design: .rounded))
                                    .foregroundColor(.textSec)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.brand.opacity(0.06))
                            .cornerRadius(16)
                            .padding(.horizontal, 16)
                        }

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

            // Committed action (highlighted)
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
                    .cornerRadius(16)
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
            .buttonStyle(PlayfulButtonStyle())
        }
        .cardStyle()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 28) {
            Image("MascotNeutral")
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)

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
                stepRow(number: 2, icon: "flask.fill", text: "Run it through the lab")
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

    // MARK: - Onboarding Card

    private var onboardingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.brand)
                Text("What are actions?")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        hasSeenOnboarding = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSec)
                        .padding(6)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Circle())
                }
            }
            Text("Actions are small, concrete steps generated from your ideas. Complete them one by one to turn your thoughts into real progress.")
                .font(.system(size: 14))
                .foregroundColor(.textSec)
                .lineSpacing(3)
        }
        .padding(16)
        .background(Color.brand.opacity(0.06))
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }
}
