//
//  AboutView.swift
//  Abimo
//

import SwiftUI

struct AboutView: View {
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image("MascotNeutral")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)

                VStack(spacing: 8) {
                    Text("Abimo")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.textPri)

                    Text("Turn your ideas into action")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.textSec)
                }

                Text(appVersion)
                    .font(.system(size: 14))
                    .foregroundColor(.textSec)

                Spacer()

                VStack(spacing: 4) {
                    Text("Made with love")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.textSec)
                }
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBg, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}
