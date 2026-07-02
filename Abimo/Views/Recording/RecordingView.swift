//
//  RecordingView.swift
//  Abimo
//
//  One giant irresistible mic. The mascot prompts you, you talk, the
//  pipeline does the rest.
//

import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = RecordingViewModel()
    @StateObject private var pipeline = IdeaPipelineService()
    @State private var showPipeline = false
    @State private var prompt = MascotVoice.moment(for: .recordPrompt).line

    private var saveFailed: Bool {
        viewModel.recordingFileURL != nil && !viewModel.isRecording
            && !viewModel.isSaving && viewModel.errorMessage != nil
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

    // MARK: - Top zone (mascot prompt / live recording readout / failure)

    @ViewBuilder
    private var topZone: some View {
        if viewModel.micDenied {
            mascotSays(
                "No mic, no magic. Let me hear you.",
                mood: .grumpy
            )
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
            mascotSays(
                "That one slipped off the counter. Try again?",
                mood: .grumpy
            )
        } else {
            mascotSays(prompt, mood: .neutral)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }

    private func mascotSays(_ line: String, mood: MascotMood) -> some View {
        HStack(alignment: .center, spacing: 4) {
            Image(mood.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
            MascotSpeechLine(line: line, arrowOffsetY: 26)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
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
                    } else {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 56, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 140, height: 140)
            }
            .buttonStyle(Duo3DCircleButtonStyle(
                fill: saveFailed ? .lockedFace : .brand,
                edge: saveFailed ? .lockedEdge : .brandDark,
                edgeHeight: 8
            ))
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
        prompt = MascotVoice.moment(for: .recordPrompt).line
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
