//
//  QuadrantDetailSheet.swift
//  Abimo
//
//  One course, served in full: every item of a single SWOT quadrant with
//  scores and deep-dive details. Free tier gets the top item; the rest
//  stays visible-but-blurred behind the Plus lock.
//

import SwiftUI

struct QuadrantDetailSheet: View {
    let course: SWOTCourse
    /// Fires the same flow as the main "Get your action plan" CTA.
    var onGetActionPlan: (() -> Void)? = nil

    @ObservedObject private var entitlements = EntitlementService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if course.items.isEmpty {
                        Text(course.kind.emptyLine)
                            .font(.duoBody)
                            .foregroundColor(.textSec)
                            .italic()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .duoPanel()
                    } else {
                        // Top item — the free taste, always in full
                        SWOTItemRow(item: course.items[0], color: course.kind.color)
                            .duoPanel(padding: 16)

                        if course.items.count > 1 {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(course.items.dropFirst()) { item in
                                    SWOTItemRow(item: item, color: course.kind.color)
                                        .duoInset(padding: 14)
                                }
                                CategoryPillsRow(
                                    categories: Array(Set(course.items.map(\.category))).sorted(),
                                    color: course.kind.color
                                )
                            }
                            .duoPanel(padding: 16)
                            .plusLocked(!entitlements.isPremium) {
                                showPaywall = true
                            }
                        }
                    }

                    if let onGetActionPlan, !course.items.isEmpty {
                        Button {
                            onGetActionPlan()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14))
                                Text("Get your action plan")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                        }
                        .buttonStyle(Duo3DGradientButtonStyle(fill: .record))
                        .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color.appBg, ignoresSafeAreaEdges: .all)
            .navigationTitle(course.kind.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBg, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(.brand)
                        .fontWeight(.bold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: .fullAnalysis)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(course.kind.color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: course.kind.iconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(course.kind.color)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(course.kind.courseLabel)
                    .font(.duoCaption)
                    .foregroundColor(.textSec)
                Text("\(course.items.count) item\(course.items.count == 1 ? "" : "s") on the plate")
                    .font(.system(size: 13))
                    .foregroundColor(.textSec)
            }
            Spacer()
            if !course.items.isEmpty {
                Text("avg \(Int(course.avgScore.rounded()))")
                    .font(.duoCaption)
                    .foregroundColor(course.kind.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(course.kind.color.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Shared item rendering

/// Always-expanded item row: point, score capsule, and deep-dive detail
/// when the analysis has one. Shared by the quadrant detail sheet.
struct SWOTItemRow: View {
    let item: SWOTItem
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Text(item.point)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.textPri)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("\(item.score)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.12))
                    .clipShape(Capsule())
            }

            if let detail = item.detail {
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundColor(.textSec)
                    .lineSpacing(4)
            }
        }
    }
}

struct CategoryPillsRow: View {
    let categories: [String]
    let color: Color

    var body: some View {
        if !categories.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(categories, id: \.self) { cat in
                        Text(cat)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(color)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(color.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.top, 2)
        }
    }
}

#Preview {
    QuadrantDetailSheet(course: SWOTCourse(
        kind: .weaknesses,
        items: [
            SWOTItem(point: "No clear moat against incumbents", score: 62, category: "Competition"),
            SWOTItem(point: "Unproven distribution channel", score: 48, category: "Go-to-market"),
            SWOTItem(point: "High onboarding friction", score: 41, category: "Product"),
        ],
        avgScore: 50.3
    ))
}
