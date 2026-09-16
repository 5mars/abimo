//
//  PlanWrapUpView.swift
//  Abimo
//
//  The second beat after a plan is finished — what used to be a bare
//  "Done". A recap built from data the app already stores and never showed
//  (outcomes, notes, minutes), then four doors: next chapter (Plus),
//  re-taste (Plus), share the score, start a new idea.
//

import SwiftUI

struct PlanWrapUpView: View {
    @ObservedObject var viewModel: ActionPlanViewModel
    let onDismiss: () -> Void

    @ObservedObject private var entitlements = EntitlementService.shared
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var paywallContext: PaywallView.Context?
    @State private var shareImage: Image?
    @State private var scoreBand = "unknown"

    private var actions: [MicroAction] { viewModel.microActions }
    private var didIt: Int { actions.filter { $0.completionOutcome != "didnt_work" }.count }
    private var didntWork: Int { actions.filter { $0.completionOutcome == "didnt_work" }.count }
    private var notes: [String] { actions.compactMap(\.completionNote).filter { !$0.isEmpty } }
    private var daysToComplete: Int {
        guard let first = viewModel.actionPlan?.createdAt,
              let last = actions.compactMap(\.completedAt).max() else { return 0 }
        return max(1, (Calendar.current.dateComponents([.day], from: first, to: last).day ?? 0) + 1)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("WHAT DID WE LEARN?")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(.textSec)

                // Recap
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 18) {
                        stat("\(didIt)", "did it", .brandGreen)
                        stat("\(didntWork)", "didn't work", .brandAmber)
                        stat("\(viewModel.completedMinutes)", "minutes", .brandBlue)
                        stat("\(daysToComplete)", daysToComplete == 1 ? "day" : "days", .brand)
                    }
                    if !notes.isEmpty {
                        Divider().overlay(Color.cardEdge)
                        Text("KITCHEN NOTES")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.textSec)
                        ForEach(notes.prefix(5), id: \.self) { note in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "quote.opening")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.textSec)
                                    .padding(.top, 3)
                                Text(note)
                                    .font(.system(size: 13))
                                    .italic()
                                    .foregroundColor(.textPri)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .duoPanel()

                // Doors
                VStack(spacing: 10) {
                    door("Next chapter", "5-7 more steps, built from what you learned",
                         icon: "book.pages.fill", plus: true) {
                        if entitlements.isPremium {
                            // Generation lands with the server work in the next release.
                            paywallContext = nil
                        } else {
                            AnalyticsService.shared.log(.gateHit(gate: "next_chapter", source: "wrap_up"))
                            paywallContext = .nextChapter
                        }
                    }
                    door("Re-taste your idea", "Re-score after the work. Watch the number move.",
                         icon: "arrow.clockwise", plus: true) {
                        if !entitlements.isPremium {
                            AnalyticsService.shared.log(.gateHit(gate: "retaste", source: "wrap_up"))
                        }
                        paywallContext = .retaste
                    }
                    if let shareImage {
                        ShareLink(
                            item: shareImage,
                            preview: SharePreview(viewModel.actionPlan?.title ?? "My idea", image: shareImage)
                        ) {
                            doorLabel("Share your score", "A card for the group chat", icon: "square.and.arrow.up", plus: false)
                        }
                        .buttonStyle(DuoCardButtonStyle(padding: 14))
                        .simultaneousGesture(TapGesture().onEnded {
                            AnalyticsService.shared.log(.shareInitiated(surface: "wrap_up", scoreBand: scoreBand))
                        })
                    }
                    door("Start a new idea", "Sixty seconds. One idea.", icon: "mic.fill", plus: false) {
                        onDismiss()
                        coordinator.selectedTab = .record
                    }
                }

                Button(action: onDismiss) {
                    Text("Back to the kitchen")
                        .font(.duoLabel)
                        .foregroundColor(.textSec)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(DuoPressStyle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color.journeyBg.ignoresSafeArea())
        .sheet(item: $paywallContext) { context in
            PaywallView(context: context)
        }
        .task {
            AnalyticsService.shared.log(.planCompleted(actions: actions.count, daysToComplete: daysToComplete))
            await loadShareCard()
        }
    }

    // MARK: - Bits

    private func stat(_ value: String, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(tint)
            Text(label)
                .font(.duoCaption)
                .foregroundColor(.textSec)
        }
        .frame(maxWidth: .infinity)
    }

    private func door(_ title: String, _ detail: String, icon: String, plus: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            doorLabel(title, detail, icon: icon, plus: plus)
        }
        .buttonStyle(DuoCardButtonStyle(padding: 14))
    }

    private func doorLabel(_ title: String, _ detail: String, icon: String, plus: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.brand)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.brand.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.textPri)
                    if plus && !entitlements.isPremium {
                        Text("PLUS")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.brandAmber))
                    }
                }
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The share card needs the analysis behind this plan: note → transcription → analysis.
    private func loadShareCard() async {
        guard let plan = viewModel.actionPlan else { return }
        let supabase = SupabaseService.shared
        guard let notes = try? await supabase.fetchVoiceNotes(),
              let note = notes.first(where: { $0.analysisId == plan.analysisId }),
              let transcriptionId = note.transcriptionId,
              let analysis = try? await supabase.fetchSWOTAnalysis(transcriptionId: transcriptionId),
              let score = analysis.viabilityScore else { return }
        scoreBand = score >= 70 ? "high" : score >= 40 ? "mid" : "low"
        if let ui = ScoreCardRenderer.render(title: note.title, score: score, dimensions: analysis.dimensionScores) {
            shareImage = Image(uiImage: ui)
        }
    }
}

extension PaywallView.Context: Identifiable {
    var id: String { analyticsName }
}
