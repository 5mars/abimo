//
//  PaywallView.swift
//  Abimo
//
//  The Abimo Plus paywall sheet. All prices come from StoreKit products —
//  never hardcoded — so the .storekit config and App Store Connect stay
//  the single source of truth.
//

import SwiftUI
import StoreKit

struct PaywallView: View {
    enum Context {
        case ideaCap        // hit the free 3-idea limit
        case general        // browsing from Kitchen pill / Profile
        case fullAnalysis   // tapped locked tasting notes / market intel

        var mascotLine: String {
            switch self {
            case .ideaCap:      return "Kitchen's full. Time to go pro."
            case .general:      return "Fine. Here's the whole menu."
            case .fullAnalysis: return "You got the free sample. The full tasting menu is Plus."
            }
        }

        var subtitle: String {
            switch self {
            case .ideaCap:      return "Free kitchens hold 3 ideas. Yours is packed."
            case .general:      return "Every idea deserves a spot on the stove."
            case .fullAnalysis: return "Every point, every detail, every market stat — no blur."
            }
        }
    }

    let context: Context

    @ObservedObject private var entitlements = EntitlementService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID = EntitlementService.ProductID.yearly

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    closeRow

                    mascotHeader
                        .padding(.top, 4)

                    Spacer().frame(height: 12)

                    Text("Abimo Plus")
                        .font(.duoScreenTitle)
                        .foregroundColor(.textPri)

                    Text(context.subtitle)
                        .font(.duoBody)
                        .foregroundColor(.textSec)
                        .multilineTextAlignment(.center)
                        .padding(.top, 6)
                        .padding(.horizontal, 32)

                    Spacer().frame(height: 24)

                    benefitsPanel
                        .padding(.horizontal, 24)

                    Spacer().frame(height: 20)

                    plansSection
                        .padding(.horizontal, 24)

                    if let error = entitlements.lastError {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(.brand)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.top, 12)
                    }

                    Spacer().frame(height: 20)

                    if !entitlements.products.isEmpty {
                        GradientButton(
                            title: "Unlock Abimo Plus",
                            isLoading: entitlements.purchaseInFlight
                        ) {
                            buySelected()
                        }
                        .padding(.horizontal, 24)
                    }

                    Spacer().frame(height: 20)

                    footer
                        .padding(.horizontal, 24)

                    Spacer().frame(height: 32)
                }
            }
        }
        .onChange(of: entitlements.isPremium) { _, premium in
            if premium { dismiss() }
        }
        .task {
            if entitlements.products.isEmpty {
                await entitlements.loadProducts()
            }
        }
    }

    // MARK: - Header

    private var closeRow: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.textSec)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Color.lockedFace))
            }
            .buttonStyle(DuoPressStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var mascotHeader: some View {
        HStack(alignment: .center, spacing: 4) {
            Image(MascotMood.sassy.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 110, height: 110)
            MascotSpeechLine(line: context.mascotLine, arrowOffsetY: 26)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Benefits

    private var benefitsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow("infinity", "Unlimited idea slots",
                       "Record as many ideas as your brain produces")
            benefitRow("fork.knife", "Every idea gets the full treatment",
                       "Taste test, verdict, and action plan on all of them")
            benefitRow("doc.text.magnifyingglass", "Full tasting notes",
                       "Every strength, weakness, and market stat — deep-dive included")
            benefitRow("sparkles", "First in line for new critic features",
                       "Deeper analyses and new mascot moods land here first")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .duoPanel()
    }

    private func benefitRow(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.brandGreen)
                .frame(width: 26, height: 26)
                .background(Circle().fill(Color.brandGreen.opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.duoCardTitle)
                    .foregroundColor(.textPri)
                Text(detail)
                    .font(.system(size: 13))
                    .foregroundColor(.textSec)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Plans

    @ViewBuilder
    private var plansSection: some View {
        if entitlements.products.isEmpty {
            if entitlements.isLoadingProducts {
                MascotLoadingView(mode: .inline, text: "Fetching the menu…")
                    .frame(height: 200)
            } else {
                VStack(spacing: 12) {
                    Text("The menu didn't load.")
                        .font(.duoBody)
                        .foregroundColor(.textSec)
                    Button {
                        Task { await entitlements.loadProducts() }
                    } label: {
                        Text("Try again")
                            .font(.duoLabel)
                            .foregroundColor(.brand)
                            .frame(width: 160)
                            .frame(height: 40)
                    }
                    .buttonStyle(Duo3DSecondaryButtonStyle())
                }
                .padding(.vertical, 24)
            }
        } else {
            VStack(spacing: 12) {
                ForEach(entitlements.products, id: \.id) { product in
                    planCard(product)
                }
            }
        }
    }

    private func planCard(_ product: Product) -> some View {
        let isSelected = product.id == selectedProductID
        let isYearly = product.id == EntitlementService.ProductID.yearly

        return Button {
            selectedProductID = product.id
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(isSelected ? .brand : .cardEdge)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(isYearly ? "Yearly" : "Monthly")
                            .font(.duoCardTitle)
                            .foregroundColor(.textPri)
                        if isYearly, let savings = yearlySavingsPercent {
                            Text("SAVE \(savings)%")
                                .font(.system(size: 10, weight: .heavy))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.brandGreen))
                        }
                    }
                    Text(planDetail(for: product, isYearly: isYearly))
                        .font(.system(size: 13))
                        .foregroundColor(.textSec)
                }

                Spacer()

                Text(product.displayPrice)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.textPri)
            }
        }
        .buttonStyle(DuoCardButtonStyle(padding: 16))
        .overlay(
            RoundedRectangle(cornerRadius: DuoTokens.Radius.card, style: .continuous)
                .strokeBorder(isSelected ? Color.brand : Color.clear, lineWidth: 2.5)
                .padding(.bottom, DuoTokens.Edge.card)
        )
        .animation(.easeOut(duration: 0.15), value: isSelected)
    }

    private func planDetail(for product: Product, isYearly: Bool) -> String {
        if isYearly {
            var parts: [String] = []
            if let perMonth = yearlyPerMonthDisplay(product) {
                parts.append("\(perMonth)/month")
            }
            if hasFreeTrial(product) {
                parts.append("free trial included")
            }
            return parts.isEmpty ? "Billed once a year" : parts.joined(separator: " · ")
        }
        return "Billed monthly"
    }

    // MARK: - Price math (from real products, never hardcoded)

    private var yearlySavingsPercent: Int? {
        guard
            let monthly = entitlements.products.first(where: { $0.id == EntitlementService.ProductID.monthly }),
            let yearly = entitlements.products.first(where: { $0.id == EntitlementService.ProductID.yearly })
        else { return nil }
        let monthlyYearCost = NSDecimalNumber(decimal: monthly.price).doubleValue * 12
        let yearlyCost = NSDecimalNumber(decimal: yearly.price).doubleValue
        guard monthlyYearCost > 0, yearlyCost < monthlyYearCost else { return nil }
        return Int(((monthlyYearCost - yearlyCost) / monthlyYearCost * 100).rounded())
    }

    private func yearlyPerMonthDisplay(_ product: Product) -> String? {
        let perMonth = product.price / 12
        return perMonth.formatted(product.priceFormatStyle)
    }

    private func hasFreeTrial(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 14) {
            Button {
                Task { await entitlements.restore() }
            } label: {
                Text("Restore Purchases")
                    .font(.duoLabel)
                    .foregroundColor(.textSec)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
            }
            .buttonStyle(Duo3DSecondaryButtonStyle())

            Text("Subscriptions renew automatically until cancelled in Settings at least 24 hours before the period ends.")
                .font(.duoCaption)
                .foregroundColor(.textSec.opacity(0.8))
                .multilineTextAlignment(.center)

            HStack(spacing: 20) {
                Link("Terms of Use",
                     destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                Link("Privacy Policy",
                     destination: URL(string: "https://abimo.app/privacy")!)
            }
            .font(.duoCaption)
            .foregroundColor(.textSec)
        }
    }

    // MARK: - Actions

    private func buySelected() {
        guard let product = entitlements.products.first(where: { $0.id == selectedProductID })
                ?? entitlements.products.first else { return }
        Task {
            if await entitlements.purchase(product) {
                HapticEngine.success()
                dismiss()
            }
        }
    }
}

#Preview {
    PaywallView(context: .ideaCap)
}
