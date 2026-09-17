//
//  SkeletonCard.swift
//  Abimo
//
//  Pulsing placeholder card shaped like an idea row — shown while The
//  Kitchen loads for the first time, so the wait reads as "cards incoming"
//  instead of a spinner swap.
//

import SwiftUI

struct SkeletonCardRow: View {
    @State private var pulsing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.insetBg)
                    .frame(height: 16)
                    .frame(maxWidth: 190, alignment: .leading)
                Spacer()
                Capsule()
                    .fill(Color.insetBg)
                    .frame(width: 68, height: 22)
            }
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.insetBg)
                .frame(width: 130, height: 12)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .duoCard(padding: 0)
        .opacity(pulsing ? 0.55 : 1)
        .onAppear {
            guard !AnimationPolicy.reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        SkeletonCardRow()
        SkeletonCardRow()
        SkeletonCardRow()
    }
    .padding(16)
    .background(Color.appBg)
}
