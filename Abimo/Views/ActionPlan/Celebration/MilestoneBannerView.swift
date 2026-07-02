//
//  MilestoneBannerView.swift
//  Abimo
//

import SwiftUI

struct MilestoneBannerView: View {
    let count: Int
    @State private var appeared = false
    @State private var moment: MascotMoment?

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Image((moment?.mood ?? .playful).assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                Text(moment?.line ?? "Keep going! \u{1F389}")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.brand)
            .cornerRadius(24)
            .shadow(color: Color.brand.opacity(0.4), radius: 8, y: 4)
            .padding(.top, 60)
            Spacer()
        }
        .offset(y: appeared ? 0 : -120)
        .onAppear {
            moment = MascotVoice.moment(for: .actionCompleted(count: count))
            AnimationPolicy.animate(.spring(response: 0.5, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}
