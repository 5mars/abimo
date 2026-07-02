//
//  StreakBannerView.swift
//  Abimo
//

import SwiftUI

/// Drops from the top on the first completion of the day, mirroring
/// MilestoneBannerView but themed around the streak flame.
struct StreakBannerView: View {
    let days: Int
    @State private var appeared = false

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(appeared ? 1 : 0.4)
                Text("\(days)-day streak — the kitchen stays hot!")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.brandOrange)
            .cornerRadius(24)
            .shadow(color: Color.brandOrange.opacity(0.4), radius: 8, y: 4)
            .padding(.top, 60)
            Spacer()
        }
        .offset(y: appeared ? 0 : -120)
        .onAppear {
            AnimationPolicy.animate(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

#Preview {
    StreakBannerView(days: 3)
}
