//
//  ActionPlanDetailView.swift
//  Abimo
//

import SwiftUI

struct ActionPlanDetailView: View {
    let planId: UUID
    let analysisId: UUID

    @StateObject private var viewModel = ActionPlanViewModel()
    @State private var pickerMode: PickerMode = .browse

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

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
                        .background(Color.brandRed.opacity(0.92))
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                        .onTapGesture { viewModel.errorMessage = nil }
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(3)
            }

            // Milestone banner
            if case .milestone(let count) = viewModel.celebrationState {
                MilestoneBannerView(count: count)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }

            // Streak-extended banner (first completion of the day)
            if case .streakExtended(let days) = viewModel.celebrationState {
                StreakBannerView(days: days)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
            }

            // Plan completion overlay
            if viewModel.celebrationState == .planComplete {
                PlanCompletionView(viewModel: viewModel, onDismiss: {
                    viewModel.celebrationState = .idle
                })
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
                .ignoresSafeArea()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.celebrationState)
        .animation(.easeInOut(duration: 0.25), value: viewModel.errorMessage)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBg, for: .navigationBar)
        .sheet(isPresented: $viewModel.showActionPicker) {
            ActionPickerSheet(viewModel: viewModel, mode: pickerMode)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.appBg)
        }
        .sheet(item: $viewModel.postCompletionSheet) { _ in
            PostCompletionSheetContent(
                viewModel: viewModel,
                completingActionId: viewModel.completingActionId
            )
        }
        .task {
            SoundEngine.prepare()
            await viewModel.loadActionPlan(analysisId: analysisId)
            pickerMode = viewModel.userOrderedIds.isEmpty ? .firstVisit : .browse
        }
    }

}
