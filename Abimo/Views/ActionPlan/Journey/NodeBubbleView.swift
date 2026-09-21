//
//  NodeBubbleView.swift
//  Abimo
//
//  The small bubble that drops out of a tapped node (Duolingo's lesson
//  popover): title, minutes, XP, and the one or two things you can do with
//  this step. It is an overlay, never a presentation, so it can never fight
//  the step sheet or the congrats sheet for the presentation slot.
//

import SwiftUI

struct NodeBubbleView: View {
    let action: MicroAction
    let state: NodeState
    let chapterKind: JourneyChapterKind
    let xpPreview: Int
    /// Where the tail points, in the bubble's own x coordinates.
    let tailX: CGFloat
    let onAction: (NodeBubbleAction) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(action.text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.textPri)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                if state == .done {
                    Text(doneLine)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSec)
                } else if state == .locked {
                    Label("Finish the lit step first · \(action.timeEstimateMinutes) min", systemImage: "lock.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSec)
                } else {
                    Text("\(action.timeEstimateMinutes) min · \(ActionDeepLink.typeLabel(for: action))")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.textSec)
                    Text("+\(xpPreview) XP")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.brandAmberDark)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.brandAmber.opacity(0.18)))
                }
                Spacer(minLength: 0)
            }

            let actions = NodeBubbleModel.actions(for: state)
            if !actions.isEmpty {
                HStack(spacing: 10) {
                    ForEach(actions, id: \.self) { item in
                        button(for: item)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 14 + 8)   // + arrow height
        .padding(.bottom, 14)
        .background(
            TopArrowBubbleShape(arrowOffset: tailX)
                .fill(Color.white)
                .overlay(TopArrowBubbleShape(arrowOffset: tailX).stroke(Color.cardEdge, lineWidth: 2))
        )
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func button(for item: NodeBubbleAction) -> some View {
        switch item {
        case .start:
            Button { onAction(.start) } label: {
                Text("Start")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(Duo3DButtonStyle(fill: chapterKind.color, edge: chapterKind.edgeColor, cornerRadius: 12, edgeHeight: 3))
        case .undo:
            textButton("Undo") { onAction(.undo) }
        case .details:
            textButton("Details") { onAction(.details) }
        }
    }

    private func textButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(chapterKind.color)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
        }
        .buttonStyle(DuoPressStyle())
    }

    private var doneLine: String {
        var s = "Done"
        if let d = action.completedAt { s += " \(StepDetailSheet.dayLabel(for: d))" }
        s += action.completionOutcome == "didnt_work" ? " · Didn't work" : " · Did it"
        return s
    }
}
