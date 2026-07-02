//
//  ActionPickerSheet.swift
//  Abimo
//

import SwiftUI

// MARK: - PickerMode

enum PickerMode {
    case firstVisit
    case postCompletion
    case browse
}

// MARK: - ActionPickerSheet

struct ActionPickerSheet: View {
    @ObservedObject var viewModel: ActionPlanViewModel
    @Environment(\.dismiss) private var dismiss

    let mode: PickerMode
    var excludedActionId: UUID? = nil

    @State private var selectedActionId: UUID?
    @State private var expandedActionId: UUID? = nil
    @State private var copiedActionId: UUID? = nil

    // MARK: - Computed

    private var incompleteActions: [MicroAction] {
        viewModel.orderedActions.filter { !$0.isCompleted && $0.id != excludedActionId }
    }

    private var completedActions: [MicroAction] {
        viewModel.orderedActions.filter { $0.isCompleted && $0.id != excludedActionId }
    }

    private var allActions: [MicroAction] {
        viewModel.orderedActions
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Drag handle
            Capsule()
                .fill(Color.textSec.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 8) {
                        Text(headingText)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(.textPri)

                        if case .firstVisit = mode {
                            Text("Choose the action you'll tackle first")
                                .font(.system(size: 14))
                                .foregroundColor(.textSec)
                        }
                    }
                    .padding(.horizontal, 16)

                    // Cards
                    if mode == .browse {
                        // Browse mode: show all actions with expand/collapse
                        if allActions.isEmpty {
                            emptyStateView
                                .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 10) {
                                ForEach(allActions) { action in
                                    pickerCard(action, role: action.isCompleted ? .done : .browse)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    } else {
                        // firstVisit / postCompletion: existing split layout
                        if incompleteActions.isEmpty && completedActions.isEmpty {
                            emptyStateView
                                .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 10) {
                                if incompleteActions.isEmpty {
                                    emptyStateView
                                } else {
                                    ForEach(incompleteActions) { action in
                                        pickerCard(action, role: .pick)
                                    }
                                }

                                ForEach(completedActions) { action in
                                    pickerCard(action, role: .done)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .padding(.bottom, 20)
            }

            // Confirm button (hidden in browse mode — use per-card "Select as next" instead)
            if mode != .browse {
                Button {
                    guard let id = selectedActionId else { return }
                    viewModel.pickAction(id: id)
                    dismiss()
                } label: {
                    Text("Let's go")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(selectedActionId != nil ? .white : .textSec)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                }
                .buttonStyle(Duo3DGradientButtonStyle(
                    fill: selectedActionId != nil
                        ? LinearGradient.record
                        : LinearGradient(colors: [.lockedFace, .lockedFace], startPoint: .top, endPoint: .bottom),
                    edge: selectedActionId != nil ? .brandDark : .lockedFace
                ))
                .disabled(selectedActionId == nil)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: selectedActionId != nil)
            }
        }
        .background(Color.appBg)
    }

    // MARK: - Heading

    private var headingText: String {
        switch mode {
        case .firstVisit: return "Commit to your first step"
        case .postCompletion: return "What's your next move?"
        case .browse: return "All Actions"
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Text("All done!")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.textPri)
            Text("You've completed every action in this plan.")
                .font(.system(size: 14))
                .foregroundColor(.textSec)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
    }

    // MARK: - Picker Card (one renderer for browse / pick / done)

    enum PickerCardRole {
        case browse  // tap to expand details
        case pick    // tap to select as next
        case done    // static, completed
    }

    @ViewBuilder
    private func pickerCard(_ action: MicroAction, role: PickerCardRole) -> some View {
        let isExpanded = expandedActionId == action.id
        let isSelected = selectedActionId == action.id

        VStack(spacing: 0) {
            Button {
                switch role {
                case .browse, .done:
                    AnimationPolicy.animate(.spring(response: 0.3, dampingFraction: 0.7)) {
                        expandedActionId = isExpanded ? nil : action.id
                    }
                case .pick:
                    AnimationPolicy.animate(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedActionId = action.id
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Text(ActionIconMapper.icon(for: action.actionType).emoji)
                        .font(.system(size: 24))

                    Text(action.text)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(action.isCompleted ? .textSec : .textPri)
                        .lineLimit(isExpanded ? nil : 2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    switch role {
                    case .done:
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.brandGreen)
                            .font(.system(size: 20))
                    case .pick:
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.brand)
                                .font(.system(size: 20))
                        }
                    case .browse:
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.textSec)
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded && role != .pick {
                expandedDetail(action)
            }
        }
        .background(Color.white)
        .cornerRadius(DuoTokens.Radius.button)
        .overlay(
            RoundedRectangle(cornerRadius: DuoTokens.Radius.button, style: .continuous)
                .strokeBorder(isSelected ? Color.brand : Color.cardEdge, lineWidth: 2)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
    }

    @ViewBuilder
    private func expandedDetail(_ action: MicroAction) -> some View {
        let isCopied = copiedActionId == action.id

        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(Color.cardEdge)
                .padding(.horizontal, 16)

            // Done criteria
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.textSec)
                    .padding(.top, 2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Done when")
                        .font(.duoCaption)
                        .foregroundColor(.textSec)
                        .textCase(.uppercase)
                    Text(action.doneCriteria)
                        .font(.duoBody)
                        .foregroundColor(.textPri)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)

            // Template block
            if let template = action.template, !template.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text(template)
                        .font(.system(size: 14))
                        .foregroundColor(.textPri)
                        .lineSpacing(3)
                        .textSelection(.enabled)

                    Button {
                        UIPasteboard.general.string = template
                        AnimationPolicy.animate(.spring(response: 0.25, dampingFraction: 0.7)) {
                            copiedActionId = action.id
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            AnimationPolicy.animate(.default) {
                                if copiedActionId == action.id {
                                    copiedActionId = nil
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 12, weight: .medium))
                            Text(isCopied ? "Copied!" : "Copy")
                                .font(.duoLabel)
                        }
                        .foregroundColor(isCopied ? .brandGreen : .brand)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(Duo3DSecondaryButtonStyle(cornerRadius: DuoTokens.Radius.chip, edgeHeight: 2))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .duoInset(padding: 14)
                .padding(.horizontal, 16)
            }

            // Trailing affordance
            if action.isCompleted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                    Text("Completed")
                        .font(.system(size: 15, weight: .bold))
                }
                .foregroundColor(.brandGreen)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.brandGreen.opacity(0.1))
                .cornerRadius(14)
                .padding(.horizontal, 16)
            } else {
                Button {
                    viewModel.pickAction(id: action.id)
                    dismiss()
                } label: {
                    Text("Select as next")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
                .buttonStyle(Duo3DGradientButtonStyle(fill: .record))
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 16)
        .padding(.top, 4)
    }
}
