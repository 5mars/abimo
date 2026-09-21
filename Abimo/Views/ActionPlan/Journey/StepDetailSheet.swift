//
//  StepDetailSheet.swift
//  Abimo
//
//  Bottom sheet for one step — replaces the bubble that used to cover the
//  next node. Everything needed to DO the step (deep link, template, done
//  criteria) and to log how it went: "I did it" or "Tried, didn't work"
//  with an optional note. The sheet only records intent; the parent runs
//  the completion after dismissal so it never overlaps the congrats sheet.
//

import SwiftUI

struct StepDetailSheet: View {
    let action: MicroAction
    let state: NodeState
    let chapter: JourneyChapter?
    /// The same kawaii icon the node wears on the path.
    var iconName: String = NodeIconCatalog.icons(for: .steps)[0]
    let xpPreview: Int
    let onComplete: (_ outcome: String, _ note: String?) -> Void
    let onUndo: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var loggingFailure = false
    @State private var note = ""
    @FocusState private var noteFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                if let chapter {
                    HStack(spacing: 5) {
                        Image(systemName: chapter.kind.icon)
                            .font(.system(size: 10, weight: .bold))
                        Text(chapter.title)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(chapter.kind.color)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(chapter.kind.color.opacity(0.12)))
                }

                HStack(alignment: .top, spacing: 12) {
                    Image(iconName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                    Text(action.text)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.textPri)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 6) {
                    chip("\(action.timeEstimateMinutes) min")
                    chip(ActionDeepLink.typeLabel(for: action))
                    if state != .done {
                        chip("+\(xpPreview) XP", tint: .brandAmberDark, fill: Color.brandAmber.opacity(0.18))
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("DONE WHEN")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.textSec)
                    Text(action.doneCriteria)
                        .font(.duoBody)
                        .foregroundColor(.textPri)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if state != .done, let url = ActionDeepLink.url(for: action) {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: ActionDeepLink.icon(for: action))
                                .font(.system(size: 14, weight: .semibold))
                            Text(ActionDeepLink.label(for: action))
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                    }
                    .buttonStyle(Duo3DGradientButtonStyle(fill: .record))
                }

                if let template = action.template, !template.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(template)
                            .font(.system(size: 14))
                            .foregroundColor(.textPri)
                            .lineSpacing(3)
                            .textSelection(.enabled)
                        Button {
                            UIPasteboard.general.string = template
                            HapticEngine.selection()
                            AnimationPolicy.animate(.spring(response: 0.25, dampingFraction: 0.7)) { copied = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                AnimationPolicy.animate(.default) { copied = false }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 12, weight: .medium))
                                Text(copied ? "Copied!" : "Copy template")
                                    .font(.duoLabel)
                            }
                            .foregroundColor(copied ? .brandGreen : .brand)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(Duo3DSecondaryButtonStyle(cornerRadius: DuoTokens.Radius.chip, edgeHeight: 2))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .duoInset(padding: 14)
                }

                completionArea
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(Color.journeyBg)
    }

    // MARK: - Completion

    @ViewBuilder
    private var completionArea: some View {
        switch state {
        case .done:
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: action.completionOutcome == "didnt_work" ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundColor(action.completionOutcome == "didnt_work" ? .brandAmber : .brandGreen)
                    Text(doneLine)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.textPri)
                }
                if let n = action.completionNote, !n.isEmpty {
                    Text(n)
                        .font(.system(size: 13))
                        .italic()
                        .foregroundColor(.textSec)
                }
                Button {
                    onUndo()
                    dismiss()
                } label: {
                    Text("Undo")
                        .font(.duoLabel)
                        .foregroundColor(.textSec)
                        .padding(.vertical, 6)
                }
                .buttonStyle(DuoPressStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .duoInset(padding: 14)

        case .next, .locked:
            VStack(spacing: 10) {
                Button {
                    onComplete("did_it", nil)
                    dismiss()
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("I did it")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                }
                .buttonStyle(Duo3DGradientButtonStyle(
                    fill: LinearGradient(colors: [.brandGreen, .brandGreen], startPoint: .top, endPoint: .bottom),
                    edge: .brandGreenDark
                ))

                if loggingFailure {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("What happened? (optional)", text: $note, axis: .vertical)
                            .font(.system(size: 14))
                            .lineLimit(2...4)
                            .focused($noteFocused)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: DuoTokens.Radius.chip, style: .continuous)
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: DuoTokens.Radius.chip, style: .continuous)
                                    .strokeBorder(Color.cardEdge, lineWidth: 1.5)
                            )
                        Button {
                            onComplete("didnt_work", note)
                            dismiss()
                        } label: {
                            Text("Log it — still counts")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                        }
                        .buttonStyle(Duo3DGradientButtonStyle(
                            fill: LinearGradient(colors: [.brandAmber, .brandAmber], startPoint: .top, endPoint: .bottom),
                            edge: .brandAmberDark
                        ))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    Button {
                        AnimationPolicy.animate(.spring(response: 0.3, dampingFraction: 0.75)) {
                            loggingFailure = true
                        }
                        noteFocused = true
                    } label: {
                        Text("Tried, didn't work")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.textSec)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                    }
                    .buttonStyle(DuoPressStyle())
                }
            }
        }
    }

    private var doneLine: String {
        var s = "Done"
        if let d = action.completedAt {
            s += " \(Self.dayLabel(for: d)) at \(d.formatted(date: .omitted, time: .shortened))"
        }
        switch action.completionOutcome {
        case "didnt_work": s += " · Tried, didn't work"
        case "did_it":     s += " · Did it"
        default:           break
        }
        return s
    }

    private func chip(_ text: String, tint: Color = .textSec, fill: Color = Color.black.opacity(0.05)) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(fill))
    }
}

extension StepDetailSheet {
    /// "today" / "yesterday" / "Tue" — the human day a step was finished.
    static func dayLabel(for date: Date, calendar: Calendar = .current, now: Date = Date()) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated))
    }
}
