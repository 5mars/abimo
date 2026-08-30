//
//  HapticEngine.swift
//  Abimo
//

import UIKit

enum HapticEngine {
    // MARK: - Pre-prepared generators (static let = lazy init on first access)

    private static let impactLight   = UIImpactFeedbackGenerator(style: .light)
    private static let impactMedium  = UIImpactFeedbackGenerator(style: .medium)
    private static let impactHeavy   = UIImpactFeedbackGenerator(style: .heavy)
    private static let impactRigid   = UIImpactFeedbackGenerator(style: .rigid)
    private static let impactSoft    = UIImpactFeedbackGenerator(style: .soft)
    private static let notification  = UINotificationFeedbackGenerator()
    private static let selectionGen  = UISelectionFeedbackGenerator()

    // MARK: - Prepare

    /// Call from a view's .onAppear to pre-warm the Taptic Engine.
    /// Safe to call multiple times — generators stay prepared.
    static func prepare() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        impactRigid.prepare()
        impactSoft.prepare()
        notification.prepare()
        selectionGen.prepare()
    }

    // MARK: - Fire

    /// General impact haptic. Default style: .medium.
    static func impact(style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .heavy:
            impactHeavy.impactOccurred()
        case .rigid:
            impactRigid.impactOccurred()
        case .soft:
            impactSoft.impactOccurred()
        default:
            impactMedium.impactOccurred()
        }
    }

    /// Success notification haptic — use for action completion.
    static func success() {
        notification.notificationOccurred(.success)
    }

    /// Light selection haptic — use for toggles and selections.
    static func selection() {
        selectionGen.selectionChanged()
    }
}
