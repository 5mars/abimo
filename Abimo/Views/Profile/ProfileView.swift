//
//  ProfileView.swift
//  Abimo
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var actionsViewModel = ActionsTabViewModel()
    @State private var showSignOutAlert = false
    @State private var ideaCount: Int?
    @State private var analysisCount: Int?
    @State private var scoresByAnalysisId: [UUID: Int] = [:]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 8)

                        heroCard
                            .padding(.horizontal, 16)

                        // Momentum (streak + week) — same dashboard as the Actions tab
                        if !actionsViewModel.allCompletionDates.isEmpty {
                            MomentumDashboard(
                                streak: actionsViewModel.currentStreak,
                                weekActivity: actionsViewModel.weekActivity,
                                totalCompletedThisWeek: actionsViewModel.totalCompletedThisWeek
                            )
                            .padding(.horizontal, 16)
                        }

                        statsRow
                            .padding(.horizontal, 16)

                        AchievementGridView(context: achievementContext)
                            .padding(.horizontal, 16)

                        actionsSection
                            .padding(.horizontal, 16)

                        Spacer().frame(height: 24)
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbarBackground(Color.appBg, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.textSec)
                    }
                }
            }
            .task { await loadStats() }
            .onChange(of: coordinator.selectedTab) { _, newTab in
                if newTab == .profile { Task { await loadStats() } }
            }
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Sign Out", role: .destructive) {
                Task { await authViewModel.signOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }

    // MARK: - Sections

    private var heroCard: some View {
        VStack(spacing: 16) {
            Image(MascotMood.playful.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 84)

            VStack(spacing: 6) {
                Text("My Account")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                if let email = authViewModel.currentUser?.email {
                    Text(email)
                        .font(.system(size: 14))
                        .foregroundColor(.textSec)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .heroCard(color: .cardDarkMint)
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statCard(
                icon: "note.text", color: .accentBlue, background: .cardDarkBlue,
                value: "\(ideaCount ?? 0)", label: "ideas"
            )
            statCard(
                icon: "checkmark.seal.fill", color: .brandGreen, background: .cardDarkTeal,
                value: "\(completedActionCount)", label: "actions done"
            )
            statCard(
                icon: "gauge.with.needle", color: .brandAmber, background: .cardDarkOrange,
                value: bestScore.map { "\($0)" } ?? "—", label: "best score"
            )
        }
    }

    private func statCard(icon: String, color: Color, background: Color, value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(.textPri)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.textSec)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tintedCard(color: background)
    }

    private var actionsSection: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Actions")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSec)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.bottom, 8)

            Button {
                showSignOutAlert = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(.brandRed)
                        .frame(width: 28)
                    Text("Sign Out")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.brandRed)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .disabled(authViewModel.isLoading)
            .background(Color.cardSurface)
            .cornerRadius(16)
        }
    }

    // MARK: - Derived data

    private var completedActionCount: Int {
        actionsViewModel.microActionsByPlan.values.flatMap { $0 }.filter(\.isCompleted).count
    }

    private var completedPlanCount: Int {
        actionsViewModel.plans.filter { plan in
            let actions = actionsViewModel.microActionsByPlan[plan.id] ?? []
            return !actions.isEmpty && actions.allSatisfy(\.isCompleted)
        }.count
    }

    private var bestScore: Int? {
        scoresByAnalysisId.values.max()
    }

    private var achievementContext: AchievementContext {
        var completedByAnalysis: [UUID: Int] = [:]
        for plan in actionsViewModel.plans {
            let completed = actionsViewModel.microActionsByPlan[plan.id]?.filter(\.isCompleted).count ?? 0
            completedByAnalysis[plan.analysisId, default: 0] += completed
        }
        return AchievementContext(
            ideaCount: ideaCount ?? 0,
            analysisCount: analysisCount ?? 0,
            completedActionCount: completedActionCount,
            completedPlanCount: completedPlanCount,
            currentStreak: actionsViewModel.currentStreak,
            bestScore: bestScore,
            completedActionsByAnalysisId: completedByAnalysis,
            scoresByAnalysisId: scoresByAnalysisId
        )
    }

    private func loadStats() async {
        ideaCount = try? await SupabaseService.shared.countVoiceNotes()
        analysisCount = try? await SupabaseService.shared.countAnalyses()
        scoresByAnalysisId = (try? await SupabaseService.shared.fetchViabilityScores()) ?? [:]
        await actionsViewModel.loadAllPlans()
    }
}
