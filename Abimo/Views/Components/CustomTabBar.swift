//
//  CustomTabBar.swift
//  Abimo
//

import SwiftUI

// MARK: - CustomTabBar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    action: {
                        guard selectedTab != tab else { return }
                        HapticEngine.impact(style: .medium)
                        AnimationPolicy.animate(.spring(response: 0.35, dampingFraction: 0.6)) {
                            selectedTab = tab
                        }
                    }
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Color.white)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.black.opacity(0.06))
                .frame(height: 0.5)
        }
    }
}

// MARK: - TabBarButton

private struct TabBarButton: View {
    let tab: AppTab
    let isSelected: Bool
    let action: () -> Void

    @State private var bounceScale: CGFloat = 1.0
    @State private var bounceRotation: Double = 0.0

    var body: some View {
        Button(action: {
            action()
            if !AnimationPolicy.reduceMotion {
                triggerBounce()
            }
        }) {
            ZStack {
                // Rounded-square highlight behind selected icon
                if isSelected {
                    RoundedRectangle(cornerRadius: DuoTokens.Radius.inset, style: .continuous)
                        .fill(Color.brand.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: DuoTokens.Radius.inset, style: .continuous)
                                .strokeBorder(Color.brand.opacity(0.25), lineWidth: 1.5)
                        )
                        .frame(width: 52, height: 40)
                }

                Image(systemName: isSelected ? tab.selectedIconName : tab.iconName)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(isSelected ? .brand : .gray)
                    .scaleEffect(bounceScale)
                    .rotationEffect(.degrees(bounceRotation))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .buttonStyle(.plain)
    }

    private func triggerBounce() {
        // Phase 1: scale up + rotate left
        withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
            bounceScale = 1.25
            bounceRotation = -8
        }
        // Phase 2: rotate right
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) {
                bounceRotation = 6
            }
        }
        // Phase 3: return to rest
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36) {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                bounceScale = 1.0
                bounceRotation = 0
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var selectedTab: AppTab = .ideas
    VStack {
        Spacer()
        CustomTabBar(selectedTab: $selectedTab)
    }
}
