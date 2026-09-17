//
//  StatusPill.swift
//  Abimo
//
//  The one capsule badge recipe: tinted text on a 12% tint wash, optional
//  leading spinner. Use this instead of hand-rolling status capsules so
//  New/Cooking/Analyzed (and future badges) can't drift apart.
//

import SwiftUI

struct StatusPill: View {
    let text: String
    let tint: Color
    var showsSpinner = false

    var body: some View {
        HStack(spacing: 6) {
            if showsSpinner {
                ProgressView()
                    .scaleEffect(0.65)
                    .tint(tint)
            }
            Text(text)
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.12))
        .clipShape(Capsule())
    }
}

#Preview {
    HStack(spacing: 12) {
        StatusPill(text: "New", tint: .brand)
        StatusPill(text: "Cooking", tint: .brandAmber, showsSpinner: true)
        StatusPill(text: "Analyzed", tint: .brandGreen)
    }
    .padding()
    .background(Color.appBg)
}
