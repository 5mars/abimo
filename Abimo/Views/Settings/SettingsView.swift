//
//  SettingsView.swift
//  Abimo
//

import SwiftUI
import StoreKit

struct SettingsView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    @AppStorage("notif_inactivity") private var inactivityEnabled = true
    @AppStorage("notif_action_nudge") private var actionNudgeEnabled = true
    @AppStorage("notif_idea_nudge") private var ideaNudgeEnabled = true
    @AppStorage("notif_streak") private var streakEnabled = true
    @AppStorage("sound_enabled") private var soundEnabled = true

    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject var authViewModel: AuthViewModel

    @State private var showDeleteAlert = false
    @State private var showClearDataAlert = false
    @State private var showClearDataConfirmation = false

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 8)

                    // Notifications section
                    settingsSection(title: "Notifications") {
                        notificationToggle(icon: "moon.zzz", title: "Inactivity Reminders", color: .brand, isOn: $inactivityEnabled)
                        Divider().overlay(Color.cardEdge)
                        notificationToggle(icon: "checkmark.circle", title: "Action Nudges", color: .brand, isOn: $actionNudgeEnabled)
                        Divider().overlay(Color.cardEdge)
                        notificationToggle(icon: "lightbulb", title: "Idea Nudges", color: .brand, isOn: $ideaNudgeEnabled)
                        Divider().overlay(Color.cardEdge)
                        notificationToggle(icon: "flame", title: "Streak Alerts", color: .brand, isOn: $streakEnabled)
                    }

                    // Sounds section
                    settingsSection(title: "Sounds") {
                        notificationToggle(icon: "speaker.wave.2", title: "Celebration Sounds", color: .brandGreen, isOn: $soundEnabled)
                    }

                    // Subscription section — reviewers expect Restore outside the paywall too
                    settingsSection(title: "Subscription") {
                        Button {
                            Task { await EntitlementService.shared.restore() }
                        } label: {
                            settingsRow(icon: "arrow.triangle.2.circlepath", title: "Restore Purchases", color: .brandBlue)
                        }
                        Divider().overlay(Color.cardEdge)
                        Link(destination: URL(string: "https://apps.apple.com/account/subscriptions")!) {
                            settingsRow(icon: "creditcard", title: "Manage Subscription", color: .brandGreen)
                        }
                    }

                    // Data & Privacy section
                    settingsSection(title: "Data & Privacy") {
                        Button {
                            showDeleteAlert = true
                        } label: {
                            settingsRow(icon: "trash", title: "Delete Account", color: .brand)
                        }
                        Divider().overlay(Color.cardEdge)
                        Button {
                            showClearDataAlert = true
                        } label: {
                            settingsRow(icon: "arrow.clockwise", title: "Clear Local Data", color: .brandAmber)
                        }
                        Divider().overlay(Color.cardEdge)
                        Link(destination: URL(string: "https://abimo.app/privacy")!) {
                            settingsRow(icon: "hand.raised", title: "Privacy Policy", color: .brandGreen)
                        }
                        Divider().overlay(Color.cardEdge)
                        Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                            settingsRow(icon: "doc.text", title: "Terms of Use", color: .brandBlue)
                        }
                    }

                    // About section
                    settingsSection(title: "About") {
                        settingsRow(icon: "info.circle", title: "App Version", color: .textSec, detail: appVersion)
                        Divider().overlay(Color.cardEdge)
                        Button {
                            requestReview()
                        } label: {
                            settingsRow(icon: "star", title: "Rate the App", color: .brandAmber)
                        }
                        Divider().overlay(Color.cardEdge)
                        Button {
                            if let url = URL(string: "mailto:feedback@abimo.app?subject=Abimo%20Feedback") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            settingsRow(icon: "envelope", title: "Send Feedback", color: .brandBlue)
                        }
                    }

                    Spacer()
                }
            }
        }
        .onChange(of: inactivityEnabled) { _, enabled in
            if !enabled { NotificationService.shared.cancelNotifications(withPrefix: "inactivity-") }
        }
        .onChange(of: actionNudgeEnabled) { _, enabled in
            if !enabled { NotificationService.shared.cancelNotifications(withPrefix: "action-nudge-") }
        }
        .onChange(of: ideaNudgeEnabled) { _, enabled in
            if !enabled { NotificationService.shared.cancelNotifications(withPrefix: "idea-nudge-") }
        }
        .onChange(of: streakEnabled) { _, enabled in
            if !enabled { NotificationService.shared.cancelNotifications(withPrefix: "streak-") }
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) {
                Task { await authViewModel.deleteAccountAndSignOut() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete your account and all your data. This action cannot be undone.")
        }
        .alert("Clear Local Data", isPresented: $showClearDataAlert) {
            Button("Clear", role: .destructive) {
                authViewModel.clearLocalData()
                showClearDataConfirmation = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all local preferences and cached data. Your account and cloud data will not be affected.")
        }
        .alert("Data Cleared", isPresented: $showClearDataConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Local data has been cleared. Notification preferences have been reset to defaults.")
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBg, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }

    // MARK: - Section Builder

    @ViewBuilder
    private func settingsSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.duoLabel)
                    .foregroundColor(.textPri)
                Spacer()
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .duoPanel(padding: 0)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Row Builder

    @ViewBuilder
    private func settingsRow(icon: String, title: String, color: Color, detail: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.textPri)

            Spacer()

            if let detail = detail {
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundColor(.textSec)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSec.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - Toggle Row Builder

    @ViewBuilder
    private func notificationToggle(icon: String, title: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(color)
                .frame(width: 28, height: 28)

            Toggle(title, isOn: isOn)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.textPri)
                .tint(.brand)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
