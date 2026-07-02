//
//  Duo3D.swift
//  Abimo
//
//  Duolingo-style "3D" depth layer: chunky faces sitting on a solid darker
//  bottom edge that visually depresses on press. Depth = affordance — only
//  tappable things get an edge; informational cards stay flat.
//
//  Modifier order is load-bearing: the face background attaches BEFORE
//  .offset (so it depresses with the label), the edge background attaches
//  AFTER .offset (so it stays put and the face sinks onto it).
//

import SwiftUI

// MARK: - Tokens

enum DuoTokens {
    enum Radius {
        static let card: CGFloat = 24
        static let button: CGFloat = 16
        static let inset: CGFloat = 12
        static let chip: CGFloat = 10
    }
    enum Edge {
        static let button: CGFloat = 4
        static let card: CGFloat = 3
        static let node: CGFloat = 5
    }
}

// MARK: - Press haptic helper

/// Fires a light selection haptic the moment a 3D control depresses.
private struct PressHaptic: ViewModifier {
    let isPressed: Bool
    func body(content: Content) -> some View {
        content.onChange(of: isPressed) { _, pressed in
            if pressed { HapticEngine.selection() }
        }
    }
}

// MARK: - Duo3DButtonStyle (rounded-rect, solid fill)

/// The composed view is `edgeHeight` taller than the label frame — callers
/// keep their `.frame(height:)` on the label.
struct Duo3DButtonStyle: ButtonStyle {
    var fill: Color = .brand
    var edge: Color = .brandDark
    var cornerRadius: CGFloat = DuoTokens.Radius.button
    var edgeHeight: CGFloat = DuoTokens.Edge.button

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .background(shape.fill(fill))
            .offset(y: configuration.isPressed ? edgeHeight : 0)
            .background(shape.fill(edge).offset(y: edgeHeight))
            .padding(.bottom, edgeHeight)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .modifier(PressHaptic(isPressed: configuration.isPressed))
    }
}

// MARK: - Duo3DGradientButtonStyle (gradient face, used by GradientButton)

struct Duo3DGradientButtonStyle: ButtonStyle {
    var fill: LinearGradient
    var edge: Color = .brandDark
    var cornerRadius: CGFloat = DuoTokens.Radius.button
    var edgeHeight: CGFloat = DuoTokens.Edge.button

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .background(shape.fill(fill))
            .offset(y: configuration.isPressed ? edgeHeight : 0)
            .background(shape.fill(edge).offset(y: edgeHeight))
            .padding(.bottom, edgeHeight)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .modifier(PressHaptic(isPressed: configuration.isPressed))
    }
}

// MARK: - Duo3DCircleButtonStyle (journey nodes, round buttons)

struct Duo3DCircleButtonStyle: ButtonStyle {
    var fill: Color = .brand
    var edge: Color = .brandDark
    var edgeHeight: CGFloat = DuoTokens.Edge.node

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(Circle().fill(fill))
            .offset(y: configuration.isPressed ? edgeHeight : 0)
            .background(Circle().fill(edge).offset(y: edgeHeight))
            .padding(.bottom, edgeHeight)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .modifier(PressHaptic(isPressed: configuration.isPressed))
    }
}

// MARK: - Secondary button style (white face, grey edge, brand text)

/// THE one secondary button style: white face, warm-grey border + edge.
struct Duo3DSecondaryButtonStyle: ButtonStyle {
    var cornerRadius: CGFloat = DuoTokens.Radius.button
    var edgeHeight: CGFloat = DuoTokens.Edge.button

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .background(shape.fill(Color.white))
            .overlay(shape.strokeBorder(Color.cardEdge, lineWidth: 2))
            .offset(y: configuration.isPressed ? edgeHeight : 0)
            .background(shape.fill(Color.cardEdge).offset(y: edgeHeight))
            .padding(.bottom, edgeHeight)
            .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
            .modifier(PressHaptic(isPressed: configuration.isPressed))
    }
}

// MARK: - duoCard (tappable cards)

/// White card with a 2pt warm-grey border and a solid 3pt bottom edge.
/// For TAPPABLE cards only — informational cards keep the flat cardStyle().
/// Pair with DuoCardButtonStyle on the wrapping Button for the depress.
struct DuoCardModifier: ViewModifier {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = DuoTokens.Radius.card
    var edgeHeight: CGFloat = DuoTokens.Edge.card
    var isPressed: Bool = false

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .padding(padding)
            .background(shape.fill(Color.white))
            .overlay(shape.strokeBorder(Color.cardEdge, lineWidth: 2))
            .offset(y: isPressed ? edgeHeight : 0)
            .background(shape.fill(Color.cardEdge).offset(y: edgeHeight))
            .padding(.bottom, edgeHeight)
            .animation(.easeOut(duration: 0.08), value: isPressed)
    }
}

/// Wrap a duoCard's content Button in this style: it forwards the pressed
/// state into the card chrome so the whole card sinks onto its edge.
struct DuoCardButtonStyle: ButtonStyle {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = DuoTokens.Radius.card
    var edgeHeight: CGFloat = DuoTokens.Edge.card

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .modifier(DuoCardModifier(
                padding: padding,
                cornerRadius: cornerRadius,
                edgeHeight: edgeHeight,
                isPressed: configuration.isPressed
            ))
            .modifier(PressHaptic(isPressed: configuration.isPressed))
    }
}

extension View {
    /// Static (non-pressing) duoCard chrome — for tappable cards where the
    /// press is handled elsewhere, or decorative depth on interactive rows.
    func duoCard(padding: CGFloat = 20) -> some View {
        modifier(DuoCardModifier(padding: padding))
    }
}
