//
//  ChapterBriefSheet.swift
//  Abimo
//
//  Four quick questions before the critic writes a Plus chapter, so the
//  steps fit the founder: skill, time, money, goal — plus one optional line
//  in their own words. Prefilled with the last answers; one tap to confirm.
//

import SwiftUI

struct ChapterBriefSheet: View {
    @ObservedObject var viewModel: ActionPlanViewModel
    let chapter: Int
    let onDone: () -> Void

    @State private var brief: ChapterBrief
    @State private var error: String?
    @FocusState private var notesFocused: Bool

    init(viewModel: ActionPlanViewModel, chapter: Int, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.chapter = chapter
        self.onDone = onDone
        _brief = State(initialValue: viewModel.lastBrief)
    }

    private var rung: ChapterLadder.Rung? { ChapterLadder.rung(chapter) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header

                group("How technical are you?", ChapterBrief.TechSkill.allCases, selected: brief.techSkill) { brief.techSkill = $0 }
                group("How much time?", ChapterBrief.Hours.allCases, selected: brief.hoursPerWeek) { brief.hoursPerWeek = $0 }
                group("How much money can this eat?", ChapterBrief.Budget.allCases, selected: brief.budget) { brief.budget = $0 }
                group("What are you in it for?", ChapterBrief.Goal.allCases, selected: brief.goal) { brief.goal = $0 }

                notesField

                if let error {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.danger)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                GradientButton(
                    title: viewModel.isExtending ? "Writing chapter \(chapter)…" : "Write chapter \(chapter)",
                    isLoading: viewModel.isExtending,
                    isDisabled: viewModel.isExtending
                ) {
                    Task { await submit() }
                }
                .padding(.top, 4)

                Text("About a minute. The steps are built from what you did in the earlier chapters and these answers.")
                    .font(.system(size: 12))
                    .foregroundColor(.textSec)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color.journeyBg.ignoresSafeArea())
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(viewModel.isExtending)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: rung?.icon ?? "book.pages.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(rung?.face ?? .brand))
            VStack(alignment: .leading, spacing: 3) {
                Text("CHAPTER \(chapter) OF \(ChapterLadder.maxChapters)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.textSec)
                Text(rung?.title ?? "Next chapter")
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(.textPri)
                if let sub = rung?.subtitle {
                    Text(sub)
                        .font(.system(size: 13))
                        .foregroundColor(.textSec)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func group<Option: Identifiable & Equatable>(
        _ title: String, _ options: [Option], selected: Option, pick: @escaping (Option) -> Void
    ) -> some View where Option: BriefOption {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.textSec)
                .padding(.leading, 4)
            VStack(spacing: 0) {
                ForEach(Array(options.enumerated()), id: \.element.id) { index, option in
                    Button {
                        guard option != selected else { return }
                        HapticEngine.selection()
                        pick(option)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.textPri)
                                Text(option.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundColor(.textSec)
                            }
                            Spacer()
                            Image(systemName: option == selected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(option == selected ? .brandGreen : .textTertiary)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < options.count - 1 {
                        Divider().overlay(Color.cardEdge)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: DuoTokens.Radius.button, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: DuoTokens.Radius.button, style: .continuous).strokeBorder(Color.cardEdge, lineWidth: 1.5))
        }
    }

    private var notesField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ANYTHING THE CRITIC SHOULD KNOW? (OPTIONAL)")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.textSec)
                .padding(.leading, 4)
            TextField("e.g. I already have 40 followers on Instagram", text: Binding(
                get: { brief.notes ?? "" },
                set: { brief.notes = String($0.prefix(ChapterBrief.maxNoteLength)) }
            ), axis: .vertical)
                .lineLimit(2...4)
                .font(.system(size: 14))
                .focused($notesFocused)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: DuoTokens.Radius.chip, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: DuoTokens.Radius.chip, style: .continuous)
                    .strokeBorder(notesFocused ? Color.brand : Color.cardEdge, lineWidth: 1.5))
        }
    }

    private func submit() async {
        error = nil
        notesFocused = false
        var clean = brief
        clean.notes = brief.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        if clean.notes?.isEmpty == true { clean.notes = nil }
        do {
            try await viewModel.submitBrief(clean)
            onDone()
        } catch let err {
            error = ChapterError.from(err).message
        }
    }
}

/// The four brief enums share this so one row renderer serves all of them.
protocol BriefOption { var title: String { get }; var subtitle: String { get } }
extension ChapterBrief.TechSkill: BriefOption {}
extension ChapterBrief.Hours: BriefOption {}
extension ChapterBrief.Budget: BriefOption {}
extension ChapterBrief.Goal: BriefOption {}
