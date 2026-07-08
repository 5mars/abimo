//
//  NotesListView.swift
//  Abimo
//

import SwiftUI

struct NotesListView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = NotesViewModel()
    @ObservedObject private var entitlements = EntitlementService.shared
    @ObservedObject private var pipeline = IdeaPipelineService.shared
    @State private var confirmingDeleteNote: VoiceNote? = nil
    @State private var showPaywall = false

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            Group {
                if viewModel.isLoading && viewModel.notes.isEmpty {
                    labLoadingView
                } else if viewModel.notes.isEmpty {
                    labEmptyView
                } else {
                    ideaList
                }
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { coordinator.pendingNote != nil },
            set: { if !$0 { coordinator.pendingNote = nil } }
        )) {
            if let note = coordinator.pendingNote {
                NoteDetailView(note: note)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.appBg, for: .navigationBar)
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage { Text(error) }
        }
        .task { await viewModel.fetchNotes() }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                context: viewModel.notes.count >= EntitlementService.freeIdeaLimit ? .ideaCap : .general
            )
        }
        .onChange(of: coordinator.selectedTab) { _, newTab in
            if newTab == .ideas {
                Task { await viewModel.fetchNotes() }
            }
        }
        .onChange(of: pipeline.stage) { _, newStage in
            // A finished cook flips the card from "Cooking" to "Analyzed"
            if newStage == .done {
                Task { await viewModel.fetchNotes() }
            }
        }
        .alert("Delete Idea?", isPresented: Binding(
            get: { confirmingDeleteNote != nil },
            set: { if !$0 { confirmingDeleteNote = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let note = confirmingDeleteNote {
                    Task { await viewModel.deleteNote(note) }
                    confirmingDeleteNote = nil
                }
            }
            Button("Cancel", role: .cancel) {
                confirmingDeleteNote = nil
            }
        } message: {
            if let note = confirmingDeleteNote {
                Text("\"\(note.title)\" will be permanently deleted.")
            }
        }
    }

    // MARK: - Loading

    private var labLoadingView: some View {
        MascotLoadingView(mode: .inline, text: "Firing up the kitchen...")
    }

    // MARK: - Empty State

    private var labEmptyView: some View {
        VStack(spacing: 24) {
            HStack(alignment: .center, spacing: 2) {
                Image("MascotNeutral")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                MascotSpeechLine(
                    line: MascotVoice.moment(for: .emptyKitchen).line,
                    arrowOffsetY: 26
                )
            }
            .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Text("Welcome to The Kitchen")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)

                Text("Record an idea and we'll turn it\ninto a real action plan")
                    .font(.system(size: 15))
                    .foregroundColor(.textSec)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            GradientButton(title: "Record your first idea") {
                coordinator.selectedTab = .record
            }
            .padding(.horizontal, 40)
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Idea List

    private var ideaList: some View {
        List {
            // Lab header
            Section {
                LabHeaderView(count: viewModel.notes.count, isPremium: entitlements.isPremium) {
                    showPaywall = true
                }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .cardEntrance(delay: 0.0)
            }

            // Ideas — cards are self-evident, no section header needed
            Section {
                ForEach(viewModel.notes) { note in
                    let isCooking = pipeline.isCooking(noteId: note.id)
                    NavigationLink(destination: NoteDetailView(note: note)) {
                        IdeaCardView(
                            note: note,
                            viewModel: viewModel,
                            cookingStepTitle: isCooking ? pipeline.currentStepTitle : nil
                        )
                    }
                    .disabled(isCooking)   // no peeking while the kitchen works
                    .listRowBackground(Color.appBg)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            confirmingDeleteNote = note
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable { await viewModel.fetchNotes() }
    }
}

// MARK: - Lab Header

struct LabHeaderView: View {
    let count: Int
    var isPremium: Bool = false
    var onSlotsTap: () -> Void = {}

    private var tagline: String {
        let ideas = "\(count) idea\(count == 1 ? "" : "s") · "
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return ideas + "morning grind, let's get it" }
        if hour < 17 { return ideas + "ideas don't cook themselves" }
        return ideas + "late night cooking hits different"
    }

    private var atCap: Bool { count >= EntitlementService.freeIdeaLimit }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The Kitchen")
                .font(.duoScreenTitle)
                .foregroundColor(.textPri)
            Text(tagline)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSec)
            slotPill
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var slotPill: some View {
        if isPremium {
            pillLabel("Plus · unlimited slots", icon: "infinity",
                      fg: .brandGreen, bg: Color.brandGreen.opacity(0.12))
        } else {
            Button(action: onSlotsTap) {
                pillLabel(
                    "\(min(count, EntitlementService.freeIdeaLimit)) of \(EntitlementService.freeIdeaLimit) idea slots used",
                    icon: atCap ? "lock.fill" : "tray.full",
                    fg: atCap ? .white : .brand,
                    bg: atCap ? Color.brand : Color.brand.opacity(0.12)
                )
            }
            .buttonStyle(DuoPressStyle())
        }
    }

    private func pillLabel(_ text: String, icon: String, fg: Color, bg: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(text)
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundColor(fg)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(bg))
    }
}

// MARK: - Idea Card

struct IdeaCardView: View {
    let note: VoiceNote
    let viewModel: NotesViewModel
    /// Non-nil while the pipeline is actively cooking this note — the card
    /// shows live progress and NotesListView disables navigation into it.
    var cookingStepTitle: String? = nil

    private var isAnalyzed: Bool { note.analysisId != nil }
    private var isCooking: Bool { cookingStepTitle != nil }

    private func timeAgo(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60              { return "just now" }
        let m = s / 60
        if m < 60              { return "\(m)m ago" }
        let h = m / 60
        if h < 24              { return "\(h)h ago" }
        let d = h / 24
        if d < 7               { return "\(d)d ago" }
        let w = d / 7
        if w < 5               { return "\(w)w ago" }
        let mo = d / 30
        if mo < 12             { return "\(mo)mo ago" }
        return "\(d / 365)y ago"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title row
            HStack(alignment: .top, spacing: 12) {
                Text(note.title)
                    .font(.duoCardTitle)
                    .foregroundColor(.textPri)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Status tag
                if isCooking {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.65)
                            .tint(.brandAmber)
                        Text("Cooking")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.brandAmber)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.brandAmber.opacity(0.12))
                    .clipShape(Capsule())
                } else {
                    Text(isAnalyzed ? "Analyzed" : "New")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isAnalyzed ? .brandGreen : .brand)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background((isAnalyzed ? Color.brandGreen : Color.brand).opacity(0.12))
                        .clipShape(Capsule())
                }
            }

            // Meta row — live step title while cooking, the usual facts after
            HStack(spacing: 10) {
                if let cookingStepTitle {
                    Text(cookingStepTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.brandAmber)

                    Spacer()

                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.textSec.opacity(0.3))
                } else {
                    Label(viewModel.formatDuration(note.duration), systemImage: "waveform")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSec)

                    Text("·")
                        .foregroundColor(.textSec.opacity(0.4))
                        .font(.system(size: 14))

                    Text(timeAgo(note.createdAt))
                        .font(.system(size: 12))
                        .foregroundColor(.textSec)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color.textSec.opacity(0.3))
                }
            }

        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .duoCard(padding: 0)
    }
}

#Preview {
    NavigationStack {
        NotesListView()
    }
    .environmentObject(NavigationCoordinator())
}
