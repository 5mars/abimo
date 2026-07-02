//
//  RecordingView.swift
//  Abimo
//

import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = RecordingViewModel()
    @StateObject private var pipeline = IdeaPipelineService()
    @State private var showPipeline = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Status pill
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusDotColor)
                        .frame(width: 8, height: 8)
                        .shadow(color: statusDotColor.opacity(0.6), radius: 4, x: 0, y: 0)
                    Text(statusLabel)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.textPri)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.cardSurface)
                .clipShape(Capsule())
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
                .animation(.easeInOut(duration: 0.3), value: viewModel.recordingFileURL != nil)

                Spacer()

                // Visualization area
                ZStack {
                    if viewModel.isRecording {
                        WaveformBarsView(level: viewModel.audioLevel)
                            .transition(.opacity.combined(with: .scale(scale: 0.8)))
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.brand.opacity(0.07))
                                .frame(width: 180, height: 180)

                            Circle()
                                .fill(Color.brand.opacity(0.05))
                                .frame(width: 130, height: 130)

                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 72))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.brand.opacity(0.4), Color.brandLight.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.isRecording)
                .frame(height: 160)

                Spacer().frame(height: 32)

                // Timer
                Text(formatDuration(viewModel.recordingDuration))
                    .font(.system(size: 52, weight: .light, design: .monospaced))
                    .foregroundStyle(
                        viewModel.isRecording
                        ? AnyShapeStyle(LinearGradient.record)
                        : AnyShapeStyle(Color.textSec)
                    )
                    .animation(.easeInOut(duration: 0.3), value: viewModel.isRecording)
                    .contentTransition(.numericText())

                Spacer()

                // Record button section
                ZStack {
                    if viewModel.isRecording {
                        // Pulse rings behind stop button
                        PulseRing(color: .brand, delay: 0)
                            .frame(width: 96, height: 96)
                        PulseRing(color: .brand, delay: 0.6)
                            .frame(width: 96, height: 96)

                        // Stop button — saves and navigates immediately, no naming step
                        Button {
                            stopAndSave()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient.record)
                                    .frame(width: 88, height: 88)
                                    .shadow(color: Color.brand.opacity(0.5), radius: 20, x: 0, y: 8)

                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white)
                                    .frame(width: 28, height: 28)
                            }
                        }
                    } else if viewModel.recordingFileURL != nil {
                        // Saving (or save failed — retry button shows below)
                        Circle()
                            .fill(Color.brand.opacity(0.12))
                            .frame(width: 96, height: 96)

                        ZStack {
                            Circle()
                                .fill(LinearGradient.brand)
                                .frame(width: 88, height: 88)
                                .shadow(color: Color.brand.opacity(0.4), radius: 18, x: 0, y: 6)

                            if viewModel.isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 30, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    } else {
                        // Idle record button
                        Button {
                            Task { await viewModel.startRecording() }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient.brand)
                                    .frame(width: 88, height: 88)

                                Image(systemName: "mic.fill")
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(PlayfulButtonStyle())
                        .disabled(viewModel.isSaving)
                    }
                }
                .frame(height: 120)
                .animation(.spring(response: 0.45, dampingFraction: 0.65), value: viewModel.isRecording)
                .animation(.spring(response: 0.45, dampingFraction: 0.65), value: viewModel.recordingFileURL != nil)

                Spacer().frame(height: 24)

                // Action controls below button
                VStack(spacing: 14) {
                    // Retry CTA: only when an auto-save failed and the file is still local
                    if viewModel.recordingFileURL != nil && !viewModel.isRecording
                        && !viewModel.isSaving && viewModel.errorMessage != nil {
                        GradientButton(
                            title: "Try saving again",
                            isLoading: viewModel.isSaving
                        ) {
                            saveAndNavigate()
                        }
                        .padding(.horizontal, 32)
                    }

                    // Discard pill: visible whenever any recording state is active (D-06/D-07/D-08)
                    if viewModel.isRecording || viewModel.recordingFileURL != nil {
                        Button {
                            viewModel.cancelRecording()
                        } label: {
                            Text("Discard")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.brandRed)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.brandRed.opacity(0.08))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(PlayfulButtonStyle())
                        .disabled(viewModel.isSaving)
                        .frame(minHeight: 44)
                    }

                    // Idle hint
                    if !viewModel.isRecording && viewModel.recordingFileURL == nil {
                        Text("Tap the mic, start talking")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color.textSec.opacity(0.6))
                    }
                }
                .frame(minHeight: 60)

                if viewModel.micDenied {
                    micDeniedCard
                } else if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.brandRed)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                if viewModel.isSaving {
                    HStack(spacing: 8) {
                        ProgressView().tint(.brand).scaleEffect(0.8)
                        Text("Locking it in...")
                            .font(.system(size: 14))
                            .foregroundColor(.textSec)
                    }
                }

                Spacer().frame(height: 48)
            }
        }
        .navigationTitle("Drop an Idea")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
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

    private var micDeniedCard: some View {
        VStack(spacing: 10) {
            Text("Abimo needs your mic to catch ideas")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.textPri)
            Text("Turn on microphone access in Settings and come back.")
                .font(.system(size: 12))
                .foregroundColor(.textSec)
                .multilineTextAlignment(.center)
            Button {
                viewModel.openSettings()
            } label: {
                Text("Open Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(LinearGradient.brand)
                    .clipShape(Capsule())
            }
            .buttonStyle(PlayfulButtonStyle())
        }
        .padding(16)
        .background(Color.cardSurface)
        .cornerRadius(16)
        .padding(.horizontal, 32)
        .padding(.top, 4)
    }

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

    private var statusLabel: String {
        if viewModel.isRecording { return "Catching your thoughts..." }
        if viewModel.isSaving { return "Locking it in..." }
        if viewModel.recordingFileURL != nil { return "Hmm, that didn't save" }
        return "Mic check"
    }

    private var statusDotColor: Color {
        if viewModel.isRecording { return .brand }
        if viewModel.recordingFileURL != nil { return .brand }
        return .textSec
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
