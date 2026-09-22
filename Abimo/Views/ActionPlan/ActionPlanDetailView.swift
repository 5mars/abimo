//
//  ActionPlanDetailView.swift
//  Abimo
//

import SwiftUI

struct ActionPlanDetailView: View {
    let planId: UUID
    let analysisId: UUID

    @StateObject private var viewModel = ActionPlanViewModel()
    @AppStorage(JourneyIntroSheet.seenKey) private var introSeen = false
    @State private var showIntro = false

    /// The plan-level progress the old header card used to show.
    private var progressSubtitle: String {
        guard viewModel.totalCount > 0 else { return "" }
        return "\(viewModel.completedCount) of \(viewModel.totalCount) · \(viewModel.remainingMinutes) min left"
    }

    var body: some View {
        ZStack {
            Color.journeyBg.ignoresSafeArea()

            if viewModel.isLoading {
                LoadingView(text: "Loading your plan...")
            } else if viewModel.actionPlan != nil {
                JourneyPathView(
                    viewModel: viewModel
                )
            }

            // Error toast (e.g. completion rollback after a failed save)
            if let error = viewModel.errorMessage {
                VStack {
                    Spacer()
                    Text(error)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(Color.danger.opacity(0.92))
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                        .onTapGesture { viewModel.errorMessage = nil }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }

            // Milestone / streak / goal / badge no longer stack banners here —
            // they land as one RewardsStrip inside the congrats sheet.

            // Plan completion overlay
            if viewModel.celebrationState == .planComplete {
                // The overlay paints its own full-bleed background; the content
                // itself must respect the safe area, and the nav bar goes away so
                // "What did we learn?" isn't hidden under the inline title.
                PlanCompletionView(viewModel: viewModel, onDismiss: {
                    viewModel.celebrationState = .idle
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .toolbar(viewModel.celebrationState == .planComplete ? .hidden : .visible, for: .navigationBar)
        .animation(.easeInOut(duration: 0.3), value: viewModel.celebrationState)
        .animation(.easeInOut(duration: 0.25), value: viewModel.errorMessage)
        .navigationTitle(viewModel.actionPlan?.title ?? "")
        .navigationSubtitleIfAvailable(progressSubtitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.journeyBg, for: .navigationBar)
        .sheet(isPresented: $showIntro, onDismiss: { introSeen = true }) {
            JourneyIntroSheet(onDismiss: { showIntro = false })
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $viewModel.postCompletionSheet) { sheet in
            switch sheet {
            case .congrats:
                PostCompletionSheetContent(
                    viewModel: viewModel,
                    completingActionId: viewModel.completingActionId
                )
            case .chapterBrief(let chapter):
                ChapterBriefSheet(viewModel: viewModel, chapter: chapter) {
                    viewModel.postCompletionSheet = nil
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.journeyBg)
            }
        }
        .task {
            SoundEngine.prepare()
            await viewModel.loadActionPlan(analysisId: analysisId)
            // First plan ever: one closable line from the horse, then never again.
            if !introSeen, viewModel.totalCount > 0 {
                try? await Task.sleep(nanoseconds: 400_000_000)
                showIntro = true
            }
        }
    }

}
