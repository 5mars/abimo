//
//  NodeBubbleView.swift
//  Abimo
//

import SwiftUI

// Bubble shapes live in Views/Components/BubbleShapes.swift (shared with
// the mascot speech bubble).

// MARK: - NodeBubbleView

struct NodeBubbleView: View {
    let action: MicroAction
    let state: NodeState
    let arrowOffset: CGFloat
    let onComplete: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Action name — primary element
            Text(action.text)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(state == .locked ? .textSec : .textPri)
                .fixedSize(horizontal: false, vertical: true)

            // Meta line: time estimate + done criteria
            if state == .active {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(action.timeEstimateMinutes) min")
                        .font(.system(size: 12, weight: .semibold))
                    Text("·")
                    Text(action.doneCriteria)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                .foregroundColor(.textSec)
            }

            // State-driven content
            stateContent
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)  // width set by the parent (JourneyLayout-derived)
        .background(
            TopArrowBubbleShape(arrowOffset: arrowOffset)
                .fill(Color.white)
                .shadow(color: Color.textPri.opacity(0.12), radius: 12, x: 0, y: 4)
        )
        .overlay(
            TopArrowBubbleShape(arrowOffset: arrowOffset)
                .stroke(Color.cardEdge, lineWidth: 2)
        )
        .scaleEffect(isVisible ? 1.0 : 0.01, anchor: .top)
        .opacity(isVisible ? 1.0 : 0.0)
        .onAppear {
            HapticEngine.impact(style: .light)
            AnimationPolicy.animate(.spring(response: 0.3, dampingFraction: 0.6)) {
                isVisible = true
            }
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private var stateContent: some View {
        switch state {
        case .active:
            // Duolingo-style: consistent full-width stacked buttons,
            // clear hierarchy — do the thing, grab the template, check it off.
            VStack(spacing: 10) {
                if let url = buildDeepLink() {
                    Button {
                        UIApplication.shared.open(url)
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: deepLinkIcon)
                                .font(.system(size: 14, weight: .semibold))
                            Text(deepLinkLabel)
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                    }
                    .buttonStyle(Duo3DGradientButtonStyle(fill: .record))
                }

                if let template = action.template, !template.isEmpty {
                    Button {
                        UIPasteboard.general.string = template
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            copied = true
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation { copied = false }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                            Text(copied ? "Copied!" : "Copy template")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .foregroundColor(copied ? .brandGreen : .brand)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                    }
                    .buttonStyle(Duo3DSecondaryButtonStyle())
                }

                Button(action: onComplete) {
                    HStack(spacing: 7) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                        Text("Mark Complete")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(Duo3DGradientButtonStyle(
                    fill: LinearGradient(colors: [.brandGreen, .brandGreen], startPoint: .top, endPoint: .bottom),
                    edge: .brandGreenDark
                ))
            }
            .padding(.top, 4)

        case .completed:
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.brandGreen)
                Text("Completed")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.brandGreen)
            }
            .padding(.top, 2)

        case .locked:
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSec.opacity(0.6))
                Text("Finish the current step to unlock")
                    .font(.system(size: 13))
                    .foregroundColor(.textSec)
                    .lineLimit(2)
            }
            .padding(.top, 2)
        }
    }

    // MARK: - Deep Link Helpers

    private func buildDeepLink() -> URL? {
        let type = action.actionType ?? inferActionType()

        switch type {
        case "message":
            let body = action.deepLinkData?.body ?? action.template ?? ""
            guard let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return URL(string: "sms:&body=\(encoded)")
        case "search":
            let query = action.deepLinkData?.query ?? action.template ?? ""
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return URL(string: "https://www.google.com/search?q=\(encoded)")
        case "email":
            let body = action.deepLinkData?.body ?? action.template ?? ""
            let subject = action.deepLinkData?.subject ?? ""
            guard let bodyEncoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let subjectEncoded = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
            return URL(string: "mailto:?subject=\(subjectEncoded)&body=\(bodyEncoded)")
        case "post":
            if let scheme = action.deepLinkData?.urlScheme {
                return URL(string: scheme)
            }
            return nil
        default:
            return nil
        }
    }

    private func inferActionType() -> String {
        guard let template = action.template?.lowercased() else { return "generic" }
        let text = action.text.lowercased()
        if text.contains("message") || text.contains("ask") || text.contains("text") ||
           template.contains("hey ") || template.contains("quick question") { return "message" }
        if text.contains("search") || text.contains("google") ||
           template.contains("alternatives") || template.contains("pricing") { return "search" }
        if text.contains("email") || template.contains("subject:") { return "email" }
        if text.contains("post") || text.contains("reddit") || text.contains("twitter") { return "post" }
        return "generic"
    }

    private var deepLinkIcon: String {
        let type = action.actionType ?? inferActionType()
        switch type {
        case "message": return "message.fill"
        case "search": return "safari.fill"
        case "email": return "envelope.fill"
        case "post": return "square.and.arrow.up.fill"
        default: return "arrow.up.right"
        }
    }

    private var deepLinkLabel: String {
        let type = action.actionType ?? inferActionType()
        switch type {
        case "message": return "Send message"
        case "search": return "Search now"
        case "email": return "Send email"
        case "post": return "Post now"
        default: return "Do it now"
        }
    }
}

// MARK: - Preview

#Preview {
    let activeAction = MicroAction(
        id: UUID(), actionPlanId: UUID(),
        text: "Review and revise the first draft of your proposal",
        doneCriteria: "Proposal revised", timeEstimateMinutes: 30,
        priority: 1, quadrant: nil, template: "Here's a draft template for your proposal revision...",
        actionType: "write", deepLinkData: nil,
        isCompleted: false, completedAt: nil,
        isCommitted: false, committedAt: nil,
        scheduledFor: nil, completionOutcome: nil, completionNote: nil,
        createdAt: Date()
    )

    let completedAction = MicroAction(
        id: UUID(), actionPlanId: UUID(),
        text: "Send email to team",
        doneCriteria: "Email sent", timeEstimateMinutes: 5,
        priority: 2, quadrant: nil, template: nil,
        actionType: "email", deepLinkData: nil,
        isCompleted: true, completedAt: Date(),
        isCommitted: false, committedAt: nil,
        scheduledFor: nil, completionOutcome: nil, completionNote: nil,
        createdAt: Date()
    )

    let lockedAction = MicroAction(
        id: UUID(), actionPlanId: UUID(),
        text: "Post update to LinkedIn",
        doneCriteria: "Post published", timeEstimateMinutes: 10,
        priority: 3, quadrant: nil, template: nil,
        actionType: "post", deepLinkData: nil,
        isCompleted: false, completedAt: nil,
        isCommitted: false, committedAt: nil,
        scheduledFor: nil, completionOutcome: nil, completionNote: nil,
        createdAt: Date()
    )

    VStack(spacing: 24) {
        NodeBubbleView(action: activeAction, state: .active, arrowOffset: 150,
                       onComplete: {}, onDismiss: {})
        NodeBubbleView(action: completedAction, state: .completed, arrowOffset: 150,
                       onComplete: {}, onDismiss: {})
        NodeBubbleView(action: lockedAction, state: .locked, arrowOffset: 150,
                       onComplete: {}, onDismiss: {})
    }
    .padding()
    .background(Color.appBg)
}
