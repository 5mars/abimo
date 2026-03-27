//
//  NoteDetailView.swift
//  Abimo
//

import SwiftUI
import AVFoundation

struct NoteDetailView: View {
    let note: VoiceNote

    @StateObject private var transcriptionService = TranscriptionService()
    @StateObject private var audioPlayer = AudioPlayerService()
    @State private var transcription: Transcription?
    @State private var isLoadingTranscription = false
    @State private var showingSWOTAnalysis = false
    @State private var errorMessage: String?
    @State private var editedTranscriptionText = ""
    @State private var isEditingTranscript = false
    @State private var hasUnsavedChanges = false
    @State private var swotAnalysis: SWOTAnalysis?
    @State private var isLoadingSWOT = false
    @State private var noteTitle: String
    @State private var editedTitle = ""
    @State private var isEditingTitle = false
    @State private var actionPlan: ActionPlan?
    @State private var actionPlanProgress: (completed: Int, total: Int)?
    @State private var isGeneratingPlan = false
    @State private var isTranscriptionExpanded = false

    private let supabase = SupabaseService.shared

    init(note: VoiceNote) {
        self.note = note
        _noteTitle = State(initialValue: note.title)
    }

    /// Testable logic for whether the transcribing placeholder card should be visible.
    static func shouldShowTranscribingPlaceholder(
        isLoadingTranscription: Bool,
        transcription: Transcription?
    ) -> Bool {
        isLoadingTranscription && transcription == nil
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {

                    // Note header card
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(LinearGradient.brand)
                                .frame(width: 60, height: 60)
                            Image(systemName: "waveform.circle.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        if isEditingTitle {
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Idea name", text: $editedTitle)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.textPri)
                                    .tint(.brand)
                                    .submitLabel(.done)
                                    .onSubmit { Task { await saveTitleEdit() } }

                                HStack {
                                    Button("Cancel") {
                                        isEditingTitle = false
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.textSec)

                                    Spacer()

                                    Button {
                                        Task { await saveTitleEdit() }
                                    } label: {
                                        Text("Save")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 6)
                                            .background(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty ? Color.gray.opacity(0.3) : Color.brand)
                                            .cornerRadius(10)
                                    }
                                    .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                                }
                            }
                            Spacer()
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(noteTitle)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.textPri)
                                    .lineLimit(2)

                                HStack(spacing: 12) {
                                    Label(formatDuration(note.duration), systemImage: "clock")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.brand.opacity(0.8))

                                    Text(note.createdAt, style: .date)
                                        .font(.system(size: 13))
                                        .foregroundColor(.textSec)
                                }
                            }
                            Spacer()

                            Button {
                                editedTitle = noteTitle
                                isEditingTitle = true
                            } label: {
                                Image(systemName: "pencil")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.brand)
                                    .padding(8)
                                    .background(Color.brand.opacity(0.08))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .heroCard(color: Color(hex: "F0FAFA"))
                    .cardEntrance(delay: 0.0)

                    // What You Said — collapsible card with audio player + transcription
                    VStack(alignment: .leading, spacing: 16) {
                        // Header with collapse toggle
                        Button {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                                isTranscriptionExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(Color.brand.opacity(0.1))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: "text.bubble.fill")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.brand)
                                }
                                Text("What You Said")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.textPri)

                                Spacer()

                                if transcription != nil && !isEditingTranscript && isTranscriptionExpanded {
                                    Button {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                            isEditingTranscript = true
                                            editedTranscriptionText = transcription?.text ?? ""
                                        }
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.brand)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.brand.opacity(0.08))
                                            .cornerRadius(20)
                                    }
                                    .buttonStyle(PlayfulButtonStyle())
                                }

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.textSec)
                                    .rotationEffect(.degrees(isTranscriptionExpanded ? 180 : 0))
                                    .animation(.spring(response: 0.35, dampingFraction: 0.7), value: isTranscriptionExpanded)
                            }
                        }
                        .buttonStyle(.plain)

                        if isTranscriptionExpanded {
                            // Audio player
                            HStack(spacing: 16) {
                                Button {
                                    Task { await togglePlayback() }
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(LinearGradient.brand)
                                            .frame(width: 48, height: 48)

                                        if audioPlayer.isLoading {
                                            ProgressView().tint(.white).scaleEffect(0.8)
                                        } else {
                                            Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.white)
                                                .offset(x: audioPlayer.isPlaying ? 0 : 2)
                                                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: audioPlayer.isPlaying)
                                        }
                                    }
                                }
                                .buttonStyle(PlayfulButtonStyle())
                                .disabled(audioPlayer.isLoading)

                                VStack(spacing: 8) {
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(Color.black.opacity(0.08))
                                                .frame(height: 5)

                                            Capsule()
                                                .fill(LinearGradient.brand)
                                                .frame(
                                                    width: max(5, geo.size.width * CGFloat(audioPlayer.progress)),
                                                    height: 5
                                                )
                                                .animation(.linear(duration: 0.5), value: audioPlayer.progress)
                                        }
                                    }
                                    .frame(height: 5)

                                    HStack {
                                        Text(formatDuration(audioPlayer.currentTime))
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundColor(.textSec)
                                            .contentTransition(.numericText())

                                        Spacer()

                                        Text(formatDuration(note.duration))
                                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                                            .foregroundColor(.textSec)
                                    }
                                }
                            }

                            // Transcription content
                            if isLoadingTranscription {
                                HStack(spacing: 10) {
                                    ProgressView().tint(.brand).scaleEffect(0.9)
                                    Text("Catching every word...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.textSec)
                                }
                                .padding(.vertical, 8)
                            } else if let transcription = transcription {
                                if isEditingTranscript {
                                    TextEditor(text: $editedTranscriptionText)
                                        .frame(minHeight: 150)
                                        .padding(12)
                                        .background(Color.black.opacity(0.04))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.brand.opacity(0.35), lineWidth: 1.5)
                                        )
                                        .font(.system(size: 15))
                                        .tint(.brand)
                                        .onChange(of: editedTranscriptionText) { oldValue, newValue in
                                            hasUnsavedChanges = newValue != transcription.text
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))

                                    HStack {
                                        Button("Cancel") {
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                                isEditingTranscript = false
                                                hasUnsavedChanges = false
                                                editedTranscriptionText = transcription.text
                                            }
                                        }
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundColor(.textSec)
                                        .buttonStyle(PlayfulButtonStyle())

                                        Spacer()

                                        Button {
                                            Task { await saveTranscriptionEdit() }
                                        } label: {
                                            Text("Save Changes")
                                                .font(.system(size: 15, weight: .semibold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 9)
                                                .background(hasUnsavedChanges ? Color.brand : Color.gray.opacity(0.3))
                                                .cornerRadius(12)
                                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasUnsavedChanges)
                                        }
                                        .buttonStyle(PlayfulButtonStyle())
                                        .disabled(!hasUnsavedChanges)
                                    }
                                } else {
                                    Text(transcription.text)
                                        .font(.system(size: 15))
                                        .foregroundColor(.textPri)
                                        .lineSpacing(4)
                                        .padding(14)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.black.opacity(0.04))
                                        .cornerRadius(12)
                                        .transition(.opacity)
                                }
                            } else {
                                VStack(spacing: 14) {
                                    Text("Still raw audio")
                                        .font(.system(size: 15))
                                        .foregroundColor(.textSec)
                                        .italic()

                                    GradientButton(title: "Turn it into text") {
                                        Task { await loadTranscription() }
                                    }
                                }
                            }
                        }
                    }
                    .cardStyle()
                    .cardEntrance(delay: 0.09)
                    .animation(.spring(response: 0.38, dampingFraction: 0.75), value: isTranscriptionExpanded)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isEditingTranscript)

                    // Transcription loading placeholder — visible when transcribing and no content yet
                    if Self.shouldShowTranscribingPlaceholder(isLoadingTranscription: isLoadingTranscription, transcription: transcription) {
                        transcribingPlaceholderCard
                            .transition(.opacity)
                    } else if transcription != nil && !isEditingTranscript {
                        // Action plan card — top priority
                        if swotAnalysis != nil {
                            actionPlanCard
                                .transition(.opacity)
                        }
                        // Lab Results card
                        analysisActionCard
                            .transition(.opacity)
                    }

                    if let error = errorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 13))
                            Text(error)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.brandRed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isLoadingTranscription)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.appBg)
        .navigationTitle("The Pitch")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBg, for: .navigationBar)
        .sheet(isPresented: $showingSWOTAnalysis, onDismiss: {
            // Refresh analysis state — user may have generated a new SWOT
            if let t = transcription {
                Task {
                    await loadSWOTAnalysis(transcriptionId: t.id)
                    if let analysis = swotAnalysis {
                        await loadActionPlan(analysisId: analysis.id)
                    }
                }
            }
        }) {
            if let transcription = transcription {
                SWOTAnalysisView(transcription: transcription, preloadedAnalysis: swotAnalysis, noteTitle: noteTitle)
            }
        }
        .task {
            await loadTranscription()
            if let t = transcription {
                await loadSWOTAnalysis(transcriptionId: t.id)
                if let analysis = swotAnalysis {
                    await loadActionPlan(analysisId: analysis.id)
                }
            }
        }
        .onDisappear { audioPlayer.stop() }
    }

    // MARK: - Transcribing Placeholder Card

    @ViewBuilder
    private var transcribingPlaceholderCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.1))
                    .frame(width: 64, height: 64)
                ProgressView()
                    .tint(.brand)
                    .scaleEffect(1.2)
            }

            VStack(spacing: 6) {
                Text("Transcribing your idea...")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                Text("We're turning your recording\ninto text right now")
                    .font(.system(size: 14))
                    .foregroundColor(.textSec)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    // MARK: - Analysis Action Card

    @ViewBuilder
    private var analysisActionCard: some View {
        if isLoadingSWOT {
            HStack(spacing: 12) {
                ProgressView().tint(.brand)
                Text("Loading analysis...")
                    .font(.system(size: 14))
                    .foregroundColor(.textSec)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 20)
        } else if let analysis = swotAnalysis {
            // Analysis exists — prominent CTA card
            VStack(spacing: 20) {
                // Header row
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.brand.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.brand)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lab Results")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.textPri)
                        Text("Your idea's been stress-tested")
                            .font(.system(size: 12))
                            .foregroundColor(.textSec)
                    }
                    Spacer()
                    if let score = analysis.viabilityScore {
                        VStack(spacing: 0) {
                            Text("\(score)")
                                .font(.system(size: 28, weight: .black, design: .rounded))
                                .foregroundColor(viabilityColor(score))
                                .contentTransition(.numericText())
                            Text("/ 100")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.textSec)
                        }
                    }
                }

                // TL;DR summary
                if let summary = analysis.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.system(size: 14))
                        .foregroundColor(.textSec)
                        .lineSpacing(3)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.04))
                        .cornerRadius(12)
                }

                // S W O T count pills
                HStack(spacing: 8) {
                    quadrantPill("S", count: analysis.resolvedStrengths.count, color: .brandGreen)
                    quadrantPill("W", count: analysis.resolvedWeaknesses.count, color: .brandRed)
                    quadrantPill("O", count: analysis.resolvedOpportunities.count, color: .brandBlue)
                    quadrantPill("T", count: analysis.resolvedThreats.count, color: .brandOrange)
                }

                // Big CTA button
                Button {
                    showingSWOTAnalysis = true
                } label: {
                    HStack(spacing: 10) {
                        Text("See the full breakdown")
                            .font(.system(size: 17, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .background(LinearGradient.brand)
                    .cornerRadius(20)
                }
                .buttonStyle(PlayfulButtonStyle())
            }
            .cardStyle()
        } else {
            // No analysis yet — playful generate CTA
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(Color.brand.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Image(systemName: "sparkles")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.brand)
                        .symbolEffect(.pulse)
                }

                VStack(spacing: 6) {
                    Text("Put it to the test")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.textPri)
                    Text("Drop it in The Lab and we'll\nbreak it down for you")
                        .font(.system(size: 14))
                        .foregroundColor(.textSec)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                }

                GradientButton(title: "🔬  Run it through The Lab") {
                    showingSWOTAnalysis = true
                }
            }
            .frame(maxWidth: .infinity)
            .cardStyle()
        }
    }

    private func quadrantPill(_ letter: String, count: Int, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundColor(color)
                .contentTransition(.numericText())
            Text(letter)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(color.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.1))
        .cornerRadius(16)
    }

    private func viabilityColor(_ score: Int) -> Color {
        switch score {
        case 0..<40:  return .brandRed
        case 40..<60: return .brandOrange
        case 60..<80: return .brandAmber
        default:      return .brandGreen
        }
    }

    // MARK: - Action Plan Card

    @ViewBuilder
    private var actionPlanCard: some View {
        if isGeneratingPlan {
            HStack(spacing: 12) {
                ProgressView().tint(.brand)
                Text("Cooking up your action plan...")
                    .font(.system(size: 14))
                    .foregroundColor(.textSec)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 20)
        } else if let plan = actionPlan, let progress = actionPlanProgress {
            // Existing plan — show progress
            VStack(spacing: 14) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .stroke(Color.brand.opacity(0.15), lineWidth: 3.5)
                            .frame(width: 40, height: 40)
                        Circle()
                            .trim(from: 0, to: progress.total > 0 ? Double(progress.completed) / Double(progress.total) : 0)
                            .stroke(Color.brand, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                            .frame(width: 40, height: 40)
                            .rotationEffect(.degrees(-90))
                        Text("\(progress.completed)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.brand)
                            .contentTransition(.numericText())
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(plan.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.textPri)
                            .lineLimit(1)
                        Text("\(progress.completed)/\(progress.total) actions done")
                            .font(.system(size: 13))
                            .foregroundColor(.textSec)
                            .contentTransition(.numericText())
                    }
                    Spacer()
                }

                NavigationLink {
                    ActionPlanDetailView(planId: plan.id, analysisId: plan.analysisId)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 13))
                        Text("Continue")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(LinearGradient.record)
                    .cornerRadius(16)
                }
                .buttonStyle(PlayfulButtonStyle())
            }
            .cardStyle()
        } else {
            // No plan yet — generate CTA
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready to act?")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.textPri)
                        Text("Get a step-by-step plan you can start right now")
                            .font(.system(size: 13))
                            .foregroundColor(.textSec)
                    }
                    Spacer()
                }

                GradientButton(title: "Get your action plan", gradient: .record) {
                    Task { await generateActionPlan() }
                }
            }
            .cardStyle()
        }
    }

    // MARK: - Private Methods

    private func generateActionPlan() async {
        guard let analysis = swotAnalysis, let transcription = transcription else { return }

        isGeneratingPlan = true
        defer { isGeneratingPlan = false }

        do {
            let aiService = AIAnalysisService()
            let (plan, actions) = try await aiService.generateAndSaveActionPlan(
                analysis: analysis,
                transcriptionText: transcription.text
            )
            actionPlan = plan
            actionPlanProgress = (completed: 0, total: actions.count)
        } catch {
            errorMessage = "Failed to generate plan: \(error.localizedDescription)"
        }
    }

    private func loadActionPlan(analysisId: UUID) async {
        if let plan = try? await supabase.fetchActionPlan(analysisId: analysisId) {
            let actions = (try? await supabase.fetchMicroActions(actionPlanId: plan.id)) ?? []
            actionPlan = plan
            actionPlanProgress = (completed: actions.filter(\.isCompleted).count, total: actions.count)
        }
    }

    private func togglePlayback() async {
        if audioPlayer.isPlaying {
            audioPlayer.pause()
        } else {
            if audioPlayer.audioURL == nil {
                do {
                    let localURL = try await supabase.downloadAudioFile(filePath: note.audioFileURL)
                    try await audioPlayer.prepare(url: localURL)
                    audioPlayer.play()
                } catch {
                    errorMessage = "Failed to load audio: \(error.localizedDescription)"
                }
            } else {
                audioPlayer.play()
            }
        }
    }

    private func loadTranscription() async {
        isLoadingTranscription = true
        errorMessage = nil
        defer { isLoadingTranscription = false }

        do {
            if let existing = try await supabase.fetchTranscription(noteId: note.id) {
                transcription = existing
                editedTranscriptionText = existing.text
                return
            }

            let signedURL = try await supabase.getSignedAudioURL(filePath: note.audioFileURL, expiresIn: 3600)
            let transcriptionText = try await transcriptionService.transcribeWithWhisper(storageURL: signedURL)

            let newTranscription = Transcription(
                id: UUID(),
                noteId: note.id,
                text: transcriptionText,
                language: "en",
                confidence: nil,
                createdAt: Date()
            )

            try await supabase.createTranscription(newTranscription)
            transcription = newTranscription
            editedTranscriptionText = transcriptionText
        } catch {
            errorMessage = "Failed to transcribe: \(error.localizedDescription)"
        }
    }

    private func loadSWOTAnalysis(transcriptionId: UUID) async {
        isLoadingSWOT = true
        let result = try? await supabase.fetchSWOTAnalysis(transcriptionId: transcriptionId)
        swotAnalysis = result
        isLoadingSWOT = false
    }

    private func saveTitleEdit() async {
        let trimmed = editedTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        do {
            try await supabase.updateVoiceNoteTitle(id: note.id, title: trimmed)
            noteTitle = trimmed
            isEditingTitle = false
        } catch {
            errorMessage = "Failed to save title: \(error.localizedDescription)"
        }
    }

    private func saveTranscriptionEdit() async {
        guard let transcription = transcription else { return }

        do {
            let updatedTranscription = Transcription(
                id: transcription.id,
                noteId: transcription.noteId,
                text: editedTranscriptionText,
                language: transcription.language,
                confidence: transcription.confidence,
                createdAt: transcription.createdAt
            )
            try await supabase.updateTranscription(updatedTranscription)
            self.transcription = updatedTranscription
            isEditingTranscript = false
            hasUnsavedChanges = false
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


#Preview {
    NavigationStack {
        NoteDetailView(note: VoiceNote(
            id: UUID(),
            userId: UUID(),
            title: "Sample Recording",
            audioFileURL: "https://example.com/audio.m4a",
            duration: 125.5,
            createdAt: Date(),
            updatedAt: Date(),
            transcriptionId: nil,
            analysisId: nil
        ))
    }
}
