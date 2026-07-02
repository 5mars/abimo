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

    // Brand palette
    static let brand        = Color(hex: "FF6B6B")  // Coral red
    static let brandLight   = Color(hex: "FF9B9B")  // Light coral
    static let brandPink    = Color(hex: "A855F7")  // Purple (accent)
    static let brandAmber   = Color(hex: "FBBF24")  // Golden yellow
    static let brandGreen   = Color(hex: "34D399")  // Emerald green
    static let brandRed     = Color(hex: "F87171")  // Soft red
    static let brandBlue    = Color(hex: "60A5FA")  // Sky blue
    static let brandOrange  = Color(hex: "FB923C")  // Tangerine

    // Surfaces
    static let appBg               = Color(hex: "FFF5F5")  // Warm rose cream
    static let cardBg              = Color.white            // White card (alias)
    static let cardSurface         = Color.white            // White card
    static let cardSurfaceElevated = Color.white            // White elevated card
    static let textPri             = Color(hex: "1C1C1E")  // Dark charcoal
    static let textSec             = Color(hex: "8E8E93")  // Medium gray

    // Tinted light card surfaces
    static let cardDarkBlue   = Color(hex: "EFF6FF")  // Light blue tint
    static let cardDarkTeal   = Color(hex: "ECFDF5")  // Light green tint
    static let cardDarkPurple = Color(hex: "FAF5FF")  // Light purple tint
    static let cardDarkOrange = Color(hex: "FFF7ED")  // Light orange tint
    static let cardDarkRed    = Color(hex: "FFF1F2")  // Light coral tint

    // Accent colors
    static let accentBlue   = Color(hex: "60A5FA")  // Sky blue — charts, data viz
    static let accentTeal   = Color(hex: "34D399")  // Emerald — positive indicators
    static let accentCoral  = Color(hex: "A855F7")  // Purple — warnings, threats

    // Duo3D darker-edge variants (bottom edges of 3D buttons/nodes/cards)
    static let brandDark       = Color(hex: "E14F4F")  // edge for brand FF6B6B
    static let brandGreenDark  = Color(hex: "1FAE7E")  // edge for brandGreen 34D399
    static let brandAmberDark  = Color(hex: "D99E0B")  // edge for brandAmber FBBF24
    static let brandBlueDark   = Color(hex: "3B82F6")  // edge for brandBlue 60A5FA
    static let brandOrangeDark = Color(hex: "E2761F")  // edge for brandOrange FB923C
    static let brandRedDark    = Color(hex: "DC4C4C")  // edge for brandRed F87171
    static let cardEdge        = Color(hex: "E8E2E0")  // warm grey — white-card borders/edges
    static let lockedFace      = Color(hex: "E5E5E5")  // locked node face / disabled button
    static let lockedEdge      = Color(hex: "CFCFCF")  // locked node edge
    static let cardDarkMint    = Color(hex: "F0FAFA")  // pale mint hero surface
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
    static let swotStrength = LinearGradient(
        colors: [Color(hex: "34D399"), Color(hex: "6EE7B7")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let swotWeakness = LinearGradient(
        colors: [Color(hex: "F87171"), Color(hex: "FF6B6B")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let swotOpportunity = LinearGradient(
        colors: [Color(hex: "60A5FA"), Color(hex: "93C5FD")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
    static let swotThreat = LinearGradient(
        colors: [Color(hex: "FB923C"), Color(hex: "F87171")],
        startPoint: .topLeading, endPoint: .bottomTrailing
    )
}

// MARK: - Card Style Modifiers

extension View {
    /// Standard card — pure white, fully flat
    func cardStyle(padding: CGFloat = 20) -> some View {
        self
            .padding(padding)
            .background(Color.white)
            .cornerRadius(24)
    }

    /// Tinted card — solid tint color, fully flat
    func tintedCard(color: Color, padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(color)
            .cornerRadius(24)
    }

    /// Hero card — solid tinted background, larger padding, fully flat
    func heroCard(color: Color = .cardDarkPurple, padding: CGFloat = 24) -> some View {
        self
            .padding(padding)
            .background(color)
            .cornerRadius(24)
    }
}

// MARK: - AppTextField

struct AppTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var keyboardType: UIKeyboardType = .default

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .focused($isFocused)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .focused($isFocused)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isFocused ? Color.white : Color(hex: "EDEBE8"))
        .cornerRadius(14)
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

// MARK: - PlayfulButtonStyle

struct PlayfulButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: configuration.isPressed)
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
