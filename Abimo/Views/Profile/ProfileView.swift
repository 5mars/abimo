//
//  ProfileView.swift
//  Abimo
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var actionsViewModel = ActionsTabViewModel()
    @ObservedObject private var entitlements = EntitlementService.shared
    @State private var showSignOutAlert = false
    @State private var showPaywall = false
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

                        plusSection
                            .padding(.horizontal, 16)

                        AchievementGridView(context: achievementContext)
                            .padding(.horizontal, 16)

                        signOutButton
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

    /// One panel: mascot + email + inline stats (ideas / actions / streak).
    private var heroCard: some View {
        VStack(spacing: 16) {
            Image(MascotMood.playful.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)

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

            Divider().overlay(Color.cardEdge)

            HStack(spacing: 0) {
                inlineStat(value: "\(ideaCount ?? 0)", label: "ideas", color: .brandBlue)
                Divider().overlay(Color.cardEdge).frame(height: 36)
                inlineStat(value: "\(completedActionCount)", label: "actions done", color: .brandGreen)
                Divider().overlay(Color.cardEdge).frame(height: 36)
                inlineStat(
                    value: "\(actionsViewModel.currentStreak)",
                    label: "day streak",
                    color: .brandAmber,
                    icon: actionsViewModel.currentStreak > 0 ? "flame.fill" : nil
                )
            }
        }
        .frame(maxWidth: .infinity)
        .duoPanel(fill: .cardDarkMint, padding: 24)
    }

    private func inlineStat(value: String, label: String, color: Color, icon: String? = nil) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(color)
                }
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                    .contentTransition(.numericText())
            }
            Text(label)
                .font(.duoCaption)
                .foregroundColor(.textSec)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var plusSection: some View {
        if entitlements.isPremium {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.brandGreen)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Abimo Plus — active")
                        .font(.duoCardTitle)
                        .foregroundColor(.textPri)
                    Text("Unlimited idea slots")
                        .font(.system(size: 13))
                        .foregroundColor(.textSec)
                }
                Spacer()
                Link("Manage", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                    .font(.duoLabel)
                    .foregroundColor(.brandBlue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .duoPanel(fill: .cardDarkTeal)
        } else {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.brandAmber)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Go Plus")
                            .font(.duoCardTitle)
                            .foregroundColor(.textPri)
                        Text("Unlimited idea slots for the serious cooks")
                            .font(.system(size: 13))
                            .foregroundColor(.textSec)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSec.opacity(0.5))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(DuoCardButtonStyle(padding: 18))
            .sheet(isPresented: $showPaywall) {
                PaywallView(context: .general)
            }
        }
    }

    private var signOutButton: some View {
        Button {
            showSignOutAlert = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 14, weight: .semibold))
                Text("Sign Out")
                    .font(.duoLabel)
            }
            .foregroundColor(.brand)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(Duo3DSecondaryButtonStyle())
        .disabled(authViewModel.isLoading)
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
