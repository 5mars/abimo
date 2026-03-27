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
        .toolbarBackground(.visible, for: .navigationBar)
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
                    Text(committedAction != nil ? "See all actions" : "Pick an action")
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
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.brand)
            }

            VStack(spacing: 8) {
                Text("No action plans yet")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                Text("Record an idea, run the analysis,\nthen generate your action plan")
                    .font(.system(size: 15))
                    .foregroundColor(.textSec)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
