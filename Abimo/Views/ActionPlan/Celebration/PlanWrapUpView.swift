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
import Supabase

struct PlanWrapUpView: View {
    @ObservedObject var viewModel: ActionPlanViewModel
    let onDismiss: () -> Void

    @ObservedObject private var entitlements = EntitlementService.shared
    @EnvironmentObject private var coordinator: NavigationCoordinator
    @State private var paywallContext: PaywallView.Context?
    @State private var shareImage: Image?
    @State private var scoreBand = "unknown"
    // Loaded once for the share card; reused by re-taste.
    @State private var note: VoiceNote?
    @State private var analysis: SWOTAnalysis?
    @State private var isRetasting = false
    @State private var retasteResult: (old: Int, new: Int)?
    @State private var doorError: String?

    private let aiService = AIAnalysisService()

    private var actions: [MicroAction] { viewModel.microActions }
    /// Before → after: the re-taste just performed wins; otherwise the stored history.
    private var scoreChange: (old: Int, new: Int)? {
        if let retasteResult { return retasteResult }
        if let analysis, let previous = analysis.previousScore, let current = analysis.viabilityScore, previous != current {
            return (previous, current)
        }
        return nil
    }
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

                // Recap dashboard — numbers + the founder's own notes
                WrapUpDashboard(
                    actions: actions,
                    completedMinutes: viewModel.completedMinutes,
                    daysToComplete: daysToComplete,
                    streak: viewModel.streak,
                    scoreChange: scoreChange
                )

                // Doors
                VStack(spacing: 10) {
                    if viewModel.isExtending {
                        busyRow("Writing chapter \(viewModel.partCount + 1)…")
                    } else {
                        door("Next chapter", "5-7 more steps, built from what you learned",
                             icon: "book.pages.fill", plus: true) {
                            if entitlements.isPremium {
                                Task { await extendPlan() }
                            } else {
                                AnalyticsService.shared.log(.gateHit(gate: "next_chapter", source: "wrap_up"))
                                paywallContext = .nextChapter
                            }
                        }
                    }
                    if let retasteResult {
                        retasteRow(retasteResult)
                    } else if isRetasting {
                        busyRow("The critic is tasting again…")
                    } else {
                        door("Re-taste your idea", "Re-score after the work. Watch the number move.",
                             icon: "arrow.clockwise", plus: true) {
                            if entitlements.isPremium {
                                Task { await retaste() }
                            } else {
                                AnalyticsService.shared.log(.gateHit(gate: "retaste", source: "wrap_up"))
                                paywallContext = .retaste
                            }
                        }
                    }
                    if let doorError {
                        Text(doorError)
                            .font(.system(size: 12))
                            .foregroundColor(.brand)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
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
                    Text("Back to the stable")
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

    private func busyRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            ProgressView().tint(.brand)
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.textSec)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .duoCard()
    }

    /// The re-taste verdict, in place of the door: "46 → 58".
    private func retasteRow(_ result: (old: Int, new: Int)) -> some View {
        let delta = result.new - result.old
        let tint: Color = delta > 0 ? .brandGreen : delta < 0 ? .danger : .textSec
        return HStack(spacing: 12) {
            Image(systemName: delta > 0 ? "arrow.up.right" : delta < 0 ? "arrow.down.right" : "equal")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 30, height: 30)
                .background(Circle().fill(tint.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(result.old) → \(result.new)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                Text(delta == 0
                     ? "The critic tasted no difference. The work didn't change the evidence."
                     : delta > 0
                        ? "Up \(delta). The work counted as evidence — keep going."
                        : "Down \(-delta). You learned something the first score didn't know.")
                    .font(.system(size: 12))
                    .foregroundColor(.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .duoCard()
    }

    // MARK: - Doors (Plus)

    private func extendPlan() async {
        doorError = nil
        do {
            try await viewModel.requestNextChapter()
            onDismiss()   // back to the journey, first new step already marked NEXT
        } catch {
            doorError = Self.friendly(error, fallback: "The next chapter didn't saddle up. Try again in a moment.")
        }
    }

    private func retaste() async {
        guard let note, let analysis else {
            doorError = "Couldn't find the tasting behind this plan."
            return
        }
        doorError = nil
        isRetasting = true
        defer { isRetasting = false }
        let old = analysis.viabilityScore ?? 0
        AnalyticsService.shared.log(.retasteRequested(previousScore: old))
        do {
            guard let transcription = try await SupabaseService.shared.fetchTranscription(noteId: note.id) else {
                doorError = "This idea has no transcript to re-taste."
                return
            }
            let updated = try await aiService.retasteAnalysis(
                analysis,
                transcriptionText: transcription.text,
                completedActions: viewModel.microActions
            )
            self.analysis = updated
            let new = updated.viabilityScore ?? old
            retasteResult = (old, new)
            AnalyticsService.shared.log(.retasteCompleted(previousScore: old, newScore: new))
            HapticEngine.success()
            await loadShareCard()   // the card should carry the new number
        } catch {
            doorError = Self.friendly(error, fallback: "The critic choked mid-taste. Try again in a moment.")
        }
    }

    /// Server-side tier and budget answers read as kitchen talk, not HTTP.
    private static func friendly(_ error: Error, fallback: String) -> String {
        if case FunctionsError.httpError(let code, _) = error {
            switch code {
            case 403: return "That paddock is Plus-only. If you just subscribed, give the stable a minute to catch up."
            case 409: return "This plan has reached its final chapter. Re-taste it — or ship."
            case 429: return "Even Plus stallions rest. Back in the saddle tomorrow."
            default: break
            }
        }
        return fallback
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
        self.note = note
        self.analysis = analysis
        scoreBand = score >= 70 ? "high" : score >= 40 ? "mid" : "low"
        if let ui = ScoreCardRenderer.render(title: note.title, score: score, dimensions: analysis.dimensionScores) {
            shareImage = Image(uiImage: ui)
        }
    }
}

extension PaywallView.Context: Identifiable {
    var id: String { analyticsName }
}
