//
//  DesignSystem.swift (ContentView.swift)
//  Abimo
//
//  Brand: Coral red primary, warm cream background, white cards
//

import SwiftUI

// MARK: - Brand Colors

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 3:  (r, g, b) = ((int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default: (r, g, b) = (255, 107, 107)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }

    // Brand palette — teal primary with the horse's caramel and gold as
    // accents on cream. Teal is the complement of the mascot's brown, so
    // he pops against every button; no red anywhere (negatives use `danger`).
    static let brand        = Color(hex: "2A9D8F")  // Teal — primary actions, tab selection
    static let brandLight   = Color(hex: "3DB4A5")  // Gradient endpoint
    static let brandAmber   = Color(hex: "E0A526")  // Golden — XP, done nodes, "needs seasoning"
    static let brandGreen   = Color(hex: "7FA86F")  // Sage — success, streaks, "chef's kiss"
    static let brandBlue    = Color(hex: "5B8FD6")  // Sky — "simmering", links
    static let brandOrange  = Color(hex: "D98B4A")  // Verdict-scale orange ("half-baked")
    static let brandCaramel = Color(hex: "C98A50")  // The horse — small warm accents only
    /// The ONE negative colour: errors, fatal flaw, "burnt", delete, trends down.
    static let danger       = Color(hex: "C65D3B")  // Terracotta

    // Surfaces
    static let appBg               = Color(hex: "FFFBF5")  // Warm off-white
    static let journeyBg           = Color(hex: "FBF4E8")  // Light cream — the path and its sheets live here
    static let cardBg              = Color.white            // White card (alias)
    static let cardSurface         = Color.white            // White card
    static let cardSurfaceElevated = Color.white            // White elevated card
    static let textPri             = Color(hex: "2F3634")  // Deep slate — reads black, leans teal
    static let textSec             = Color(hex: "8C918E")  // Cool grey-green
    static let textTertiary        = Color(hex: "C1C6C3")  // Chevrons, dots, decorative glyphs
    static let insetBg             = Color(hex: "F4F0E8")  // duoInset well background

    // Tinted light card surfaces (tuned for the cream ground)
    static let cardDarkBlue   = Color(hex: "E8EFF9")  // Sky tint
    static let cardDarkTeal   = Color(hex: "E3F2EF")  // Teal tint
    static let cardDarkOrange = Color(hex: "FAEFD8")  // Golden tint
    static let cardDarkRed    = Color(hex: "F7E3DA")  // Terracotta tint
    static let cardDarkMint   = Color(hex: "EAF5F2")  // Pale teal hero surface

    // Duo3D darker-edge variants (bottom edges of 3D buttons/nodes/cards)
    static let brandDark       = Color(hex: "1F7A70")  // edge for brand
    static let brandGreenDark  = Color(hex: "5E8752")  // edge for brandGreen
    static let brandAmberDark  = Color(hex: "B8841C")  // edge for brandAmber
    static let brandBlueDark   = Color(hex: "3F6FB5")  // edge for brandBlue
    static let cardEdge        = Color(hex: "E4DED3")  // sand — white-card borders/edges
    static let lockedFace      = Color(hex: "EEEAE2")  // locked node face / disabled button
    static let lockedEdge      = Color(hex: "D3CDC2")  // locked node edge

    // Journey chapters (Duolingo "units") — each chapter owns a colour + edge
    static let chapterPlum       = Color(hex: "8E6BB0")
    static let chapterPlumEdge   = Color(hex: "6F5190")
    static let chapterTeal       = brand
    static let chapterTealEdge   = brandDark
    static let chapterGolden     = brandAmber
    static let chapterGoldenEdge = brandAmberDark
    static let chapterSage       = brandGreen
    static let chapterSageEdge   = brandGreenDark

    // Journey nodes
    static let nodeDone     = brandAmber            // completed step — gold, like a crown
    static let nodeDoneEdge = brandAmberDark
    static let nodeOpenFace = Color(hex: "FBF7F0")  // not-yet step — cream
    static let nodeOpenEdge = Color(hex: "DCD5C8")

}

// MARK: - Brand Gradients

extension LinearGradient {
    static let brand = LinearGradient(
        colors: [.brand, .brandLight],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let record = LinearGradient(
        colors: [.brand, .brand],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    // SWOT quadrant gradients — S=sage, W=terracotta, O=dusty blue, T=golden
    static let swotStrength = LinearGradient(
        colors: [.brandGreen, Color(hex: "9DBF8E")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let swotWeakness = LinearGradient(
        colors: [.danger, Color(hex: "D98366")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let swotOpportunity = LinearGradient(
        colors: [.brandBlue, Color(hex: "8FAACB")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let swotThreat = LinearGradient(
        colors: [.brandAmber, Color(hex: "EBBE5A")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - AppTextField

struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var submitLabel: SubmitLabel = .done

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
            }
        }
        .submitLabel(submitLabel)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: DuoTokens.Radius.button, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DuoTokens.Radius.button, style: .continuous)
                .strokeBorder(isFocused ? Color.brand : Color.cardEdge, lineWidth: 2)
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
        .font(.system(size: 16))
        .foregroundColor(.textPri)
        .tint(Color.brand)
    }
}

// MARK: - Card Entrance Animation

struct CardEntranceModifier: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 22)
            .onAppear {
                // Reduce motion skips the delay too — a staggered fade with
                // no movement still reads as motion on long screens.
                if AnimationPolicy.reduceMotion {
                    appeared = true
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(delay)) {
                        appeared = true
                    }
                }
            }
    }
}

extension View {
    func cardEntrance(delay: Double = 0) -> some View {
        modifier(CardEntranceModifier(delay: delay))
    }
}

// MARK: - GradientButton

struct GradientButton: View {
    enum Size {
        case regular  // 58pt face + 4pt edge = 62 total (previous flat height)
        case compact  // 44pt face + 4pt edge

        var faceHeight: CGFloat {
            switch self {
            case .regular: return 58
            case .compact: return 44
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .regular: return 18
            case .compact: return 15
            }
        }
    }

    let title: String
    var gradient: LinearGradient = .brand
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var cornerRadius: CGFloat = DuoTokens.Radius.button
    var size: Size = .regular
    var edge: Color = .brandDark
    let action: () -> Void

    private var inactive: Bool { isDisabled || isLoading }

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading {
                    ProgressView().tint(inactive ? Color.textSec : .white).scaleEffect(0.9)
                } else {
                    Text(title)
                        .font(.system(size: size.fontSize, weight: .bold))
                        .foregroundColor(isDisabled ? .textSec : .white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: size.faceHeight)
        }
        .buttonStyle(Duo3DGradientButtonStyle(
            fill: isDisabled
                ? LinearGradient(colors: [.lockedFace, .lockedFace], startPoint: .top, endPoint: .bottom)
                : gradient,
            edge: isDisabled ? .lockedFace : edge,  // disabled = flat look (edge matches face), height stays stable
            cornerRadius: cornerRadius
        ))
        .disabled(inactive)
        .animation(.easeOut(duration: 0.2), value: isDisabled)
    }
}

// MARK: - Pulse Ring (recording animation)

struct PulseRing: View {
    let color: Color
    var delay: Double = 0
    @State private var animating = false

    var body: some View {
        Circle()
            .stroke(color, lineWidth: 2)
            .scaleEffect(animating ? 2.4 : 1.0)
            .opacity(animating ? 0 : 0.55)
            .animation(
                .easeOut(duration: 1.6)
                .repeatForever(autoreverses: false)
                .delay(delay),
                value: animating
            )
            .onAppear { animating = true }
    }
}

// MARK: - Waveform Bars (audio level visualization)

struct WaveformBarsView: View {
    let level: Float
    private let barCount = 28

    private func height(for index: Int) -> CGFloat {
        let center = Double(barCount - 1) / 2.0
        let dist = abs(Double(index) - center) / center
        let envelope = 1.0 - pow(dist, 1.5) * 0.65
        let base: CGFloat = 4
        let maxExtra: CGFloat = 56
        return base + maxExtra * CGFloat(level) * CGFloat(envelope)
    }

    var body: some View {
        HStack(spacing: 3.5) {
            ForEach(0..<barCount, id: \.self) { i in
                Capsule()
                    .fill(LinearGradient.record)
                    .frame(width: 3.5, height: height(for: i))
            }
        }
        .frame(height: 72)
        .animation(.spring(response: 0.12, dampingFraction: 0.6), value: level)
    }
}
