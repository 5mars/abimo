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

    // Brand palette — bold saturated colors on pure white (Duolingo-style)
    static let brand        = Color(hex: "FF5252")  // Punchy coral
    static let brandLight   = Color(hex: "FF7B70")  // Gradient endpoint
    static let brandAmber   = Color(hex: "FFB800")  // Bold amber
    static let brandGreen   = Color(hex: "2EC46F")  // Bold green
    static let brandBlue    = Color(hex: "3B82F6")  // Bold blue

    // Surfaces
    static let appBg               = Color.white
    static let cardBg              = Color.white            // White card (alias)
    static let cardSurface         = Color.white            // White card
    static let cardSurfaceElevated = Color.white            // White elevated card
    static let textPri             = Color(hex: "3C3C43")  // Soft charcoal
    static let textSec             = Color(hex: "AFAFB4")  // Medium gray

    // Tinted light card surfaces (cooler, tuned for pure white)
    static let cardDarkBlue   = Color(hex: "EDF4FE")  // Light blue tint
    static let cardDarkTeal   = Color(hex: "EAF9F1")  // Light green tint
    static let cardDarkOrange = Color(hex: "FFF6E3")  // Light amber tint
    static let cardDarkRed    = Color(hex: "FFEFEF")  // Light coral tint
    static let cardDarkMint   = Color(hex: "F2FBF7")  // Pale mint hero surface

    // Duo3D darker-edge variants (bottom edges of 3D buttons/nodes/cards)
    static let brandDark       = Color(hex: "E03E3E")  // edge for brand FF5252
    static let brandGreenDark  = Color(hex: "25A65C")  // edge for brandGreen 2EC46F
    static let brandAmberDark  = Color(hex: "DB9E00")  // edge for brandAmber FFB800
    static let brandBlueDark   = Color(hex: "2563EB")  // edge for brandBlue 3B82F6
    static let cardEdge        = Color(hex: "E5E5E5")  // grey — white-card borders/edges
    static let lockedFace      = Color(hex: "EBEBEB")  // locked node face / disabled button
    static let lockedEdge      = Color(hex: "CDCDCD")  // locked node edge

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
    // SWOT quadrant gradients — S=green, W=coral, O=blue, T=amber
    static let swotStrength = LinearGradient(
        colors: [Color(hex: "2EC46F"), Color(hex: "5AD68F")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let swotWeakness = LinearGradient(
        colors: [Color(hex: "FF5252"), Color(hex: "FF7B70")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let swotOpportunity = LinearGradient(
        colors: [Color(hex: "3B82F6"), Color(hex: "6FA5F9")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let swotThreat = LinearGradient(
        colors: [Color(hex: "FFB800"), Color(hex: "FFCB3D")],
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
                withAnimation(.spring(response: 0.5, dampingFraction: 0.78).delay(delay)) {
                    appeared = true
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
