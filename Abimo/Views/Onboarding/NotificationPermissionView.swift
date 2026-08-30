//
//  NotificationPermissionView.swift
//  Abimo
//

import SwiftUI

struct NotificationPermissionView: View {
    let onComplete: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.brand.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "bell.badge.fill")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(Color.brand)
                }

                VStack(spacing: 12) {
                    Text("Stay on track")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.textPri)

                    Text("I'll send you friendly nudges so your\nideas don't just sit there collecting dust")
                        .font(.system(size: 15))
                        .foregroundColor(.textSec)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                VStack(spacing: 14) {
                    GradientButton(title: "Turn on notifications") {
                        Task {
                            _ = await NotificationService.shared.requestPermission()
                            onComplete()
                        }
                    }
                    .padding(.horizontal, 32)

                    Button {
                        onComplete()
                    } label: {
                        Text("Maybe later")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.textSec)
                    }
                }

                Spacer().frame(height: 40)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.95)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
        }
    }
}

#Preview {
    NotificationPermissionView(onComplete: {})
}
