//
//  SettingsView.swift
//  Abimo
//

import SwiftUI

struct SettingsView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    Spacer().frame(height: 8)

                    // Notifications section (Phase 28 will wire toggles)
                    settingsSection(title: "Notifications") {
                        settingsRow(icon: "bell.fill", title: "Notification Preferences", color: .accentBlue)
                    }

                    // Data & Privacy section (Phase 29 will wire actions)
                    settingsSection(title: "Data & Privacy") {
                        settingsRow(icon: "trash", title: "Delete Account", color: .brandRed)
                        Divider().padding(.leading, 44)
                        settingsRow(icon: "arrow.clockwise", title: "Clear Local Data", color: .brandOrange)
                        Divider().padding(.leading, 44)
                        settingsRow(icon: "hand.raised", title: "Privacy Policy", color: .accentTeal)
                    }

                    // About section
                    settingsSection(title: "About") {
                        settingsRow(icon: "info.circle", title: "App Version", color: .textSec, detail: appVersion)
                    }

                    Spacer()
                }
            }
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
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSec)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.bottom, 8)

            VStack(spacing: 0) {
                content()
            }
            .background(Color.cardSurface)
            .cornerRadius(16)
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
}
