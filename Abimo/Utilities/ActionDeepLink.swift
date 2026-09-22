//
//  ActionDeepLink.swift
//  Abimo
//
//  Turns a micro-action into the thing that opens when the founder taps
//  "do it": an SMS with the template pre-filled, a Google search, a mailto,
//  or the post URL. Shared by the step sheet and the picker.
//

import Foundation

enum ActionDeepLink {

    static func resolvedType(for action: MicroAction) -> String {
        action.actionType ?? inferType(for: action)
    }

    static func url(for action: MicroAction) -> URL? {
        switch resolvedType(for: action) {
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
        case "post", "link":
            if let scheme = action.deepLinkData?.urlScheme, !scheme.isEmpty { return URL(string: scheme) }
            return nil
        default:
            return nil
        }
    }

    static func icon(for action: MicroAction) -> String {
        switch resolvedType(for: action) {
        case "message": return "message.fill"
        case "search":  return "safari.fill"
        case "email":   return "envelope.fill"
        case "post":    return "square.and.arrow.up.fill"
        case "link":    return "safari.fill"
        default:        return "arrow.up.right"
        }
    }

    /// Button copy for the deep-link CTA.
    static func label(for action: MicroAction) -> String {
        switch resolvedType(for: action) {
        case "message": return "Send message"
        case "search":  return "Search now"
        case "email":   return "Send email"
        case "post":    return "Post now"
        case "link":    return "Open it"
        default:        return "Do it now"
        }
    }

    /// Short noun for the step's kind — the "Message" in "10 min · Message".
    static func typeLabel(for action: MicroAction) -> String {
        switch resolvedType(for: action) {
        case "message": return "Message"
        case "search":  return "Research"
        case "email":   return "Email"
        case "post":    return "Post"
        case "link":    return "Open"
        default:        return "Task"
        }
    }

    private static func inferType(for action: MicroAction) -> String {
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
}
