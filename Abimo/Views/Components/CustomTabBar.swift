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
        .background(
            // Extend under the home indicator so scrolled content can't
            // peek through beneath the bar
            Color.white.ignoresSafeArea(edges: .bottom)
        )
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

    @State private var bounceTrigger = 0

    /// The icon's 3-beat bounce, expressed as keyframe tracks: scale pops
    /// and holds while the rotation wags left, right, then settles.
    private struct BounceValues {
        var scale: CGFloat = 1.0
        var rotation: Double = 0.0
    }

    var body: some View {
        Button(action: {
            action()
            if !AnimationPolicy.reduceMotion {
                bounceTrigger += 1
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
                    .foregroundColor(isSelected ? .brand : .textSec)
                    .keyframeAnimator(
                        initialValue: BounceValues(),
                        trigger: bounceTrigger
                    ) { content, values in
                        content
                            .scaleEffect(values.scale)
                            .rotationEffect(.degrees(values.rotation))
                    } keyframes: { _ in
                        KeyframeTrack(\.scale) {
                            SpringKeyframe(1.25, duration: 0.18, spring: Spring(response: 0.18, dampingRatio: 0.5))
                            LinearKeyframe(1.25, duration: 0.18)
                            SpringKeyframe(1.0, duration: 0.25, spring: Spring(response: 0.25, dampingRatio: 0.7))
                        }
                        KeyframeTrack(\.rotation) {
                            SpringKeyframe(-8, duration: 0.18, spring: Spring(response: 0.18, dampingRatio: 0.5))
                            SpringKeyframe(6, duration: 0.18, spring: Spring(response: 0.18, dampingRatio: 0.5))
                            SpringKeyframe(0, duration: 0.25, spring: Spring(response: 0.25, dampingRatio: 0.7))
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            // Spotlight tour target: the circle cutout hugs the 44pt icon
            // area, not the full tab column.
            .walkInTarget(.recordTab, isActive: tab == .record)
        }
        .buttonStyle(.plain)
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
