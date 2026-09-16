//
//  ActionPlanDetailView.swift
//  Abimo
//

import SwiftUI

struct ActionPlanDetailView: View {
    let planId: UUID
    let analysisId: UUID

    @StateObject private var viewModel = ActionPlanViewModel()

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
                        .background(Color.brand.opacity(0.92))
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
        .navigationTitle(viewModel.actionPlan?.title ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.journeyBg, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.presentPicker(.browse)
                } label: {
                    Label("All steps", systemImage: "list.bullet")
                        .font(.system(size: 14, weight: .semibold))
                }
                .tint(.brand)
            }
        }
        .sheet(isPresented: $viewModel.showActionPicker) {
            ActionPickerSheet(viewModel: viewModel, mode: viewModel.pickerMode)
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
        }
    }

}
