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
    @State private var moment: MascotMoment?

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image((moment?.mood ?? .playful).assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                Image(systemName: "flame.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .scaleEffect(appeared ? 1 : 0.4)
                Text(moment?.line ?? "\(days)-day streak!")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.brandAmber)
            .cornerRadius(24)
            .shadow(color: Color.brandAmber.opacity(0.4), radius: 8, y: 4)
            .padding(.top, 60)
            Spacer()
        }
        .offset(y: appeared ? 0 : -120)
        .onAppear {
            moment = MascotVoice.moment(for: .streakExtended(days: days))
            AnimationPolicy.animate(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

#Preview {
    StreakBannerView(days: 3)
}
