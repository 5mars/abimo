//
//  RootView.swift
//  Abimo
//

import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var coordinator = NavigationCoordinator()

    var body: some View {
        ZStack {
            if authViewModel.isLoading {
                LoadingView()
                    .transition(.opacity)
            } else if authViewModel.isAuthenticated {
                MainContentView()
                    .environmentObject(authViewModel)
                    .environmentObject(coordinator)
                    .transition(.opacity)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: authViewModel.isLoading)
        .animation(.easeInOut(duration: 0.4), value: authViewModel.isAuthenticated)
    }
}

// MARK: - Main Content View

struct MainContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var coordinator: NavigationCoordinator

    var body: some View {
        ZStack {
            // All views stay alive (preserving navigation state).
            // Opacity switches instantly — no animation to avoid flash/dark flicker.
            NavigationStack { NotesListView() }
                .opacity(coordinator.selectedTab == .ideas ? 1 : 0)
                .allowsHitTesting(coordinator.selectedTab == .ideas)
            NavigationStack { RecordingView() }
                .opacity(coordinator.selectedTab == .record ? 1 : 0)
                .allowsHitTesting(coordinator.selectedTab == .record)
            NavigationStack { ActionsTabView() }
                .opacity(coordinator.selectedTab == .actions ? 1 : 0)
                .allowsHitTesting(coordinator.selectedTab == .actions)
            ProfileView()
                .opacity(coordinator.selectedTab == .profile ? 1 : 0)
                .allowsHitTesting(coordinator.selectedTab == .profile)
        }
        .animation(nil, value: coordinator.selectedTab) // Disable animation on content — prevents flash
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selectedTab: $coordinator.selectedTab)
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        Spacer().frame(height: 8)

                        // Profile hero card
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient.brand)
                                    .frame(width: 80, height: 80)
                                Image(systemName: "person.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.white)
                            }

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
                        .heroCard(color: Color(hex: "F0FAFA"))
                        .padding(.horizontal, 16)

                        // Stats row
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: "note.text")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.accentBlue)
                                Text("—")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPri)
                                Text("ideas")
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSec)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tintedCard(color: .cardDarkBlue)

                            VStack(alignment: .leading, spacing: 10) {
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.accentTeal)
                                Text("—")
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.textPri)
                                Text("analyses")
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSec)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .tintedCard(color: .cardDarkTeal)
                        }
                        .padding(.horizontal, 16)

                        // Actions section
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
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbarBackground(Color.appBg, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
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
}

#Preview {
    RootView()
}
