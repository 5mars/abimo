//
//  RootView.swift
//  Abimo
//

import SwiftUI

struct RootView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var coordinator = NavigationCoordinator()
    @AppStorage("hasSeenNotificationPermission") private var hasSeenPermission = false
    // Once-per-process: the fullscreen intro never replays (sign-out included).
    // In-app loading after launch is handled by each screen's own spinners.
    @State private var introFinished = false

    var body: some View {
        ZStack {
            if !introFinished {
                LaunchIntroView(isResolved: !authViewModel.isLoading) {
                    introFinished = true
                }
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
        .animation(.easeInOut(duration: 0.4), value: introFinished)
        .animation(.easeInOut(duration: 0.4), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.4), value: hasSeenPermission)
    }
}

// MARK: - Main Content View

struct MainContentView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var mascot = MascotDirector.shared
    @StateObject private var walkIn = WalkInDirector.shared
    // One plans/streak view model shared by the Actions tab and Profile —
    // both used to own separate instances that each refetched every plan.
    @StateObject private var actionsVM = ActionsTabViewModel()
    @State private var showMascotPaywall = false

    var body: some View {
        // Content and tab bar are stacked — pages physically END at the top
        // of the bar, so nothing can ever sit hidden behind it.
        VStack(spacing: 0) {
            ZStack {
                // All views stay alive (preserving navigation state).
                // The ZStack-level animation stays nil (dark-flash guard);
                // only each page's opacity cross-fades, per-page below.
                NavigationStack { NotesListView() }
                    .tabPage(.ideas, selected: coordinator.selectedTab)
                NavigationStack { RecordingView() }
                    .tabPage(.record, selected: coordinator.selectedTab)
                NavigationStack { ActionsTabView() }
                    .environmentObject(actionsVM)
                    .tabPage(.actions, selected: coordinator.selectedTab)
                ProfileView()
                    .environmentObject(actionsVM)
                    .tabPage(.profile, selected: coordinator.selectedTab)
            }
            .animation(nil, value: coordinator.selectedTab) // Disable animation on content — prevents flash
            CustomTabBar(selectedTab: $coordinator.selectedTab)
        }
        .walkInSpotlight(spotlightSpec)
        .overlay {
            // Walk-in beat 1: the first-ever welcome. The CTA deliberately
            // does NOT switch tabs — the Record tab starts glowing instead,
            // so the user learns the navigation themselves.
            if let moment = walkIn.welcomeMoment {
                MascotCenterPopup(
                    moment: moment,
                    onAction: { _ in walkIn.welcomeAcknowledged() },
                    onDismiss: { walkIn.skip() }
                )
                .transition(.opacity)
            }
            // Global mascot moment — a rare center-screen popup (max 1/session)
            else if let moment = mascot.currentMoment {
                MascotCenterPopup(
                    moment: moment,
                    onAction: { handleMascotIntent($0) },
                    onDismiss: { mascot.dismiss() }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: mascot.currentMoment)
        .animation(.easeOut(duration: 0.2), value: walkIn.welcomeMoment)
        .animation(.easeOut(duration: 0.2), value: walkIn.step)
        .task {
            await walkIn.evaluateOnLaunch()
            await mascot.evaluateStreakAtRisk()
        }
        .sheet(isPresented: $showMascotPaywall) {
            PaywallView(context: .ideaCap)
        }
    }

    /// The current spotlight beat for tour steps hosted at the root level.
    /// The taste-test beats live in SWOTAnalysisView — it's a sheet, so it
    /// hosts its own overlay above the presentation layer.
    private var spotlightSpec: SpotlightSpec? {
        switch walkIn.step {
        case .record where coordinator.selectedTab != .record:
            // Teach the navigation: the user taps the highlighted tab
            // themselves (tap-through), nothing switches for them.
            return SpotlightSpec(
                target: .recordTab,
                line: WalkInScript.tabHint,
                shape: .circle,
                tapThrough: true
            )
        case .record:
            // On the Record screen: dare the first pitch. Tapping the mic
            // through the cutout really starts recording; the anchor goes
            // inactive while recording, so the spotlight vanishes with it.
            return SpotlightSpec(
                target: .micButton,
                line: WalkInScript.pitchFallback,
                shape: .circle,
                cutoutPadding: 14,
                tapThrough: true
            )
        case .actionPlan where coordinator.selectedTab == .actions:
            return SpotlightSpec(
                target: .firstActionCard,
                line: WalkInScript.actionsNudge,
                primaryLabel: WalkInScript.actionsNudgeButton,
                primaryAction: { WalkInDirector.shared.finishFinalBeat() }
            )
        default:
            return nil
        }
    }

    private func handleMascotIntent(_ intent: MascotActionIntent) {
        mascot.dismiss()
        switch intent {
        case .goRecord:
            coordinator.selectedTab = .record
        case .openPlans:
            coordinator.selectedTab = .actions
        case .showPaywall:
            showMascotPaywall = true
        case .openNote:
            // No trigger produces this yet; land on the Kitchen as a safe default.
            coordinator.selectedTab = .ideas
        }
    }
}

// MARK: - Tab page visibility

private extension View {
    /// Kept-alive tab page: visible + tappable only when selected, with an
    /// opacity-only cross-fade. Geometry never animates, so the ZStack's
    /// nil-animation flash guard stays intact.
    func tabPage(_ tab: AppTab, selected: AppTab) -> some View {
        opacity(selected == tab ? 1 : 0)
            .allowsHitTesting(selected == tab)
            .animation(
                AnimationPolicy.reduceMotion ? nil : .easeOut(duration: 0.15),
                value: selected
            )
    }
}

#Preview {
    RootView()
}
