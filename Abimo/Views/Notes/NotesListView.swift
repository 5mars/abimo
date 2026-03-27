//
//  NotesListView.swift
//  Abimo
//

import SwiftUI

struct NotesListView: View {
    @EnvironmentObject var coordinator: NavigationCoordinator
    @StateObject private var viewModel = NotesViewModel()
    @State private var confirmingDeleteNote: VoiceNote? = nil

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
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let error = viewModel.errorMessage { Text(error) }
        }
        .task { await viewModel.fetchNotes() }
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
        MascotLoadingView(mode: .inline, text: "Setting up the lab...")
    }

    // MARK: - Empty State

    private var labEmptyView: some View {
        VStack(spacing: 20) {
            Text("🧪")
                .font(.system(size: 56))

            Text("The Lab is empty")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.textPri)

            Text("Record your first idea and drop it\ninto the lab for analysis")
                .font(.system(size: 15))
                .foregroundColor(.textSec)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
        }
        .padding(.horizontal, 40)
    }

    // MARK: - Idea List

    private var ideaList: some View {
        List {
            // Lab header
            Section {
                LabHeaderView(count: viewModel.notes.count)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .cardEntrance(delay: 0.0)
            }

            // Ideas section
            Section {
                ForEach(viewModel.notes) { note in
                    NavigationLink(destination: NoteDetailView(note: note)) {
                        IdeaCardView(note: note, viewModel: viewModel)
                    }
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
            } header: {
                HStack {
                    Text("On the bench")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.textSec)
                        .textCase(nil)
                    Spacer()
                    Text("\(viewModel.notes.count) idea\(viewModel.notes.count == 1 ? "" : "s")")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.textSec.opacity(0.7))
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 2)
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

    private var tagline: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "morning grind, let's get it" }
        if hour < 17 { return "ideas don't test themselves" }
        return "late night experiments hit different"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("The Lab")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundColor(.textPri)
            Text(tagline)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSec)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }
}

// MARK: - Idea Card

struct IdeaCardView: View {
    let note: VoiceNote
    let viewModel: NotesViewModel

    private var isAnalyzed: Bool { note.analysisId != nil }

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
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Status tag
                Text(isAnalyzed ? "Analyzed" : "Fresh idea")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isAnalyzed ? .brandGreen : .brand)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background((isAnalyzed ? Color.brandGreen : Color.brand).opacity(0.12))
                    .clipShape(Capsule())
            }

            // Meta row
            HStack(spacing: 10) {
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
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.white)
        .cornerRadius(20)
    }
}

#Preview {
    NavigationStack {
        NotesListView()
    }
    .environmentObject(NavigationCoordinator())
}
