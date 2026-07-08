//
//  RecordingView.swift
//  Abimo
//
//  One giant irresistible mic. You talk, the pipeline does the rest.
//  No mascot here — status lines only when something needs saying.
//

import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = RecordingViewModel()
    @StateObject private var pipeline = IdeaPipelineService()
    @ObservedObject private var entitlements = EntitlementService.shared
    @State private var showPipeline = false
    @State private var showPaywall = false
    @State private var capLine = MascotVoice.moment(for: .ideaCapReached).line

    private var saveFailed: Bool {
        viewModel.recordingFileURL != nil && !viewModel.isRecording
            && !viewModel.isSaving && viewModel.errorMessage != nil
    }

    /// Free cap reached — the mic becomes the door to the paywall. Never
    /// blocks an in-flight recording or a failed save awaiting retry.
    private var capBlocked: Bool {
        viewModel.isAtFreeCap && !viewModel.isRecording && !saveFailed
    }

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                topZone
                    .frame(height: 190)

                Spacer().frame(height: 44)

                micButton

                Spacer().frame(height: 32)

                bottomControls
                    .frame(minHeight: 60)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .navigationTitle("Drop an Idea")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: viewModel.isRecording)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: saveFailed)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: capBlocked)
        .task { await viewModel.refreshIdeaCount() }
        .onChange(of: coordinator.selectedTab) { _, newTab in
            // Kept-alive tabs never refire onAppear — refresh the quota here
            if newTab == .record {
                Task { await viewModel.refreshIdeaCount() }
            }
        }
        .sheet(isPresented: $showPaywall, onDismiss: {
            // A purchase or a deletion may have freed the gate
            Task { await viewModel.refreshIdeaCount() }
        }) {
            PaywallView(context: .ideaCap)
        }
        .fullScreenCover(isPresented: $showPipeline) {
            PipelineProgressView(
                pipeline: pipeline,
                onFinished: {
                    showPipeline = false
                    if let note = pipeline.note {
                        coordinator.pendingShowAnalysis = true
                        coordinator.navigateToNote(note)
                    }
                },
                onBackground: {
                    // Pipeline keeps running; artifacts persist and the note
                    // shows current progress when opened from The Kitchen.
                    showPipeline = false
                },
                onDiscard: {
                    viewModel.cancelRecording()
                    showPipeline = false
                },
                onRetry: {
                    pipeline.retry(recordingVM: viewModel, coordinator: coordinator)
                }
            )
        }
    }

    // MARK: - Top zone (live recording readout / status lines)

    @ViewBuilder
    private var topZone: some View {
        if viewModel.micDenied {
            statusLine("No mic, no magic. Enable the microphone in Settings.")
        } else if viewModel.isRecording {
            VStack(spacing: 20) {
                Text(formatDuration(viewModel.recordingDuration))
                    .font(.system(size: 52, weight: .semibold, design: .monospaced))
                    .foregroundColor(.brand)
                    .contentTransition(.numericText())
                WaveformBarsView(level: viewModel.audioLevel)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
        } else if saveFailed {
            statusLine("That one slipped off the counter. Try again?")
        } else if capBlocked {
            statusLine(capLine)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        } else {
            // Idle: the mic speaks for itself.
            Color.clear
        }
    }

    private func statusLine(_ line: String) -> some View {
        VStack {
            Spacer()
            Text(line)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.textSec)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
    }

    // MARK: - The giant mic

    private var micButton: some View {
        ZStack {
            if viewModel.isRecording {
                PulseRing(color: .brand)
                    .frame(width: 150, height: 150)
            }

            Button {
                if viewModel.isRecording {
                    stopAndSave()
                } else if capBlocked {
                    showPaywall = true
                } else if !saveFailed {
                    Task { await viewModel.startRecording() }
                }
            } label: {
                Group {
                    if viewModel.isSaving {
                        ProgressView().tint(.white).scaleEffect(1.4)
                    } else if viewModel.isRecording {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white)
                            .frame(width: 44, height: 44)
                    } else if capBlocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 50, weight: .semibold))
                            .foregroundColor(.textSec)
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 140, height: 140)
            }
            .buttonStyle(Duo3DCircleButtonStyle(
                fill: (saveFailed || capBlocked) ? .lockedFace : .brand,
                edge: (saveFailed || capBlocked) ? .lockedEdge : .brandDark,
                edgeHeight: 8
            ))
            // capBlocked stays pressable — the press opens the paywall
            .disabled(viewModel.isSaving || viewModel.micDenied || saveFailed)
        }
    }

    // MARK: - Bottom controls

    @ViewBuilder
    private var bottomControls: some View {
        if viewModel.micDenied {
            GradientButton(title: "Open Settings", size: .compact) {
                viewModel.openSettings()
            }
            .frame(width: 220)
        } else if saveFailed {
            VStack(spacing: 12) {
                GradientButton(title: "Try saving again", isLoading: viewModel.isSaving) {
                    saveAndNavigate()
                }
                .padding(.horizontal, 16)
                discardButton
            }
        } else if viewModel.isRecording {
            discardButton
        } else if capBlocked {
            VStack(spacing: 10) {
                GradientButton(title: "Unlock unlimited ideas", size: .compact) {
                    showPaywall = true
                }
                .frame(width: 240)
                Text("or delete an idea in The Kitchen")
                    .font(.system(size: 13))
                    .foregroundColor(.textSec)
            }
        }
    }

    private var discardButton: some View {
        Button {
            viewModel.cancelRecording()
        } label: {
            Text("Discard")
                .font(.duoLabel)
                .foregroundColor(.brand)
                .frame(width: 160)
                .frame(height: 40)
        }
        .buttonStyle(Duo3DSecondaryButtonStyle())
        .disabled(viewModel.isSaving)
    }

    // MARK: - Actions

    /// Stop → full pipeline (save, transcribe, analyze, plan) with a staged
    /// progress cover. Zero taps between stopping and seeing results.
    private func stopAndSave() {
        viewModel.stopRecording()
        showPipeline = true
        pipeline.start(recordingVM: viewModel, coordinator: coordinator)
    }

    private func saveAndNavigate() {
        showPipeline = true
        pipeline.retry(recordingVM: viewModel, coordinator: coordinator)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    NavigationStack {
        RecordingView()
    }
    .environmentObject(NavigationCoordinator())
}
