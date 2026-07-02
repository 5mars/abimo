//
//  RootView.swift
//  Abimo
//

import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var coordinator = NavigationCoordinator()
    @AppStorage("hasSeenNotificationPermission") private var hasSeenPermission = false

    var body: some View {
        ZStack {
            if authViewModel.isLoading {
                MascotLoadingView(mode: .fullscreen, text: "abimo")
                    .transition(.opacity)
            } else if authViewModel.isAuthenticated && !hasSeenPermission {
                NotificationPermissionView {
                    hasSeenPermission = true
                }
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
        .animation(.easeInOut(duration: 0.4), value: hasSeenPermission)
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

#Preview {
    RootView()
}
