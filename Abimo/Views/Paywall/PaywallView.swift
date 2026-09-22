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
        case fullAnalysis   // tapped locked tasting notes / market intel / evidence receipt
        case nextChapter    // finished a plan, wants the next 5-7 steps
        case retaste        // did the work, wants the critic to re-judge
        case dailyCap       // free daily AI budget spent

        var mascotLine: String {
            switch self {
            case .ideaCap:      return "Stable's full. Time to go pro."
            case .general:      return "Fine. Here's the whole menu."
            case .fullAnalysis: return "You got the free sample. The full tasting menu is Plus."
            case .nextChapter:  return "Chapter one, cleared. Chapter two is behind the Plus gate."
            case .retaste:      return "You did the work. Want me to re-judge? That's a Plus table."
            case .dailyCap:     return "Free stable closes after three tastings. Plus keeps the gate open."
            }
        }

        var subtitle: String {
            switch self {
            case .ideaCap:      return "Free stables hold 3 ideas. Yours is packed."
            case .general:      return "The first taste is free. Plus is what happens after you do the work."
            case .fullAnalysis: return "Every point, every detail, every market stat — no blur."
            case .nextChapter:  return "Plus builds the next chapter from what you learned."
            case .retaste:      return "Re-score after the work and watch the number move."
            case .dailyCap:     return "Six tastings a day instead of three, every day."
            }
        }

        var analyticsName: String {
            switch self {
            case .ideaCap:      return "idea_cap"
            case .general:      return "general"
            case .fullAnalysis: return "full_analysis"
            case .nextChapter:  return "next_chapter"
            case .retaste:      return "retaste"
            case .dailyCap:     return "daily_cap"
            }
        }
    }

    let context: Context

    @ObservedObject private var entitlements = EntitlementService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var selectedProductID = EntitlementService.ProductID.yearly
    @State private var trialEligible: [String: Bool] = [:]
    @State private var openedAt = Date()
    @State private var purchased = false

    var body: some View {
        ZStack {
            Color.appBg.ignoresSafeArea()
                .onAppear {
                    openedAt = Date()
                    AnalyticsService.shared.log(.paywallShown(context: context.analyticsName))
                }
                .onDisappear {
                    // Both the X and a swipe-down land here; a purchase dismisses too,
                    // so only the no-purchase exits count as a dismissal.
                    guard !purchased, !entitlements.isPremium else { return }
                    AnalyticsService.shared.log(.paywallDismissed(
                        context: context.analyticsName,
                        selectedProductId: selectedProductID,
                        secondsOpen: Int(Date().timeIntervalSince(openedAt)),
                        sawTrialCTA: selectedHasEligibleTrial
                    ))
                }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    closeRow

                    mascotHeader
                        .padding(.top, 4)
                        .cardEntrance(delay: 0.05)

                    Spacer().frame(height: 12)

                    Group {
                        Text("Abimo Plus")
                            .font(.duoScreenTitle)
                            .foregroundColor(.textPri)

                        Text(context.subtitle)
                            .font(.duoBody)
                            .foregroundColor(.textSec)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                            .padding(.horizontal, 32)
                    }
                    .cardEntrance(delay: 0.10)

                    Spacer().frame(height: 24)

                    benefitsPanel
                        .padding(.horizontal, 24)
                        .cardEntrance(delay: 0.15)

                    Spacer().frame(height: 20)

                    plansSection
                        .padding(.horizontal, 24)
                        .cardEntrance(delay: 0.20)

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
                        VStack(spacing: 8) {
                            GradientButton(
                                title: ctaTitle,
                                isLoading: entitlements.purchaseInFlight
                            ) {
                                buySelected()
                            }
                            if let terms = trialTerms {
                                Text(terms)
                                    .font(.duoCaption)
                                    .foregroundColor(.textSec)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding(.horizontal, 24)
                        .cardEntrance(delay: 0.25)
                    }

                    Spacer().frame(height: 20)

                    footer
                        .padding(.horizontal, 24)

                    Spacer().frame(height: 32)
                }
                // Pin to the viewport width so nothing can pan sideways.
                .containerRelativeFrame(.horizontal)
            }
        }
        .onChange(of: entitlements.isPremium) { _, premium in
            if premium { dismiss() }
        }
        .task {
            if entitlements.products.isEmpty {
                await entitlements.loadProducts()
            }
            // Apple allows one intro offer per subscription group per user —
            // ask StoreKit, don't assume.
            for product in entitlements.products {
                if let sub = product.subscription {
                    trialEligible[product.id] = await sub.isEligibleForIntroOffer
                }
            }
        }
    }

    // MARK: - Trial-aware CTA

    private var selectedProduct: Product? {
        entitlements.products.first { $0.id == selectedProductID }
    }

    private var selectedHasEligibleTrial: Bool {
        guard let product = selectedProduct, hasFreeTrial(product) else { return false }
        return trialEligible[product.id] ?? false
    }

    private var ctaTitle: String {
        guard selectedHasEligibleTrial, let days = trialDays(selectedProduct) else { return "Unlock Abimo Plus" }
        return "Start \(days)-day free trial"
    }

    /// Price and period stay visible under a trial CTA (App Review 3.1.2).
    private var trialTerms: String? {
        guard selectedHasEligibleTrial, let product = selectedProduct else { return nil }
        let period = product.id == EntitlementService.ProductID.yearly ? "year" : "month"
        return "then \(product.displayPrice)/\(period) · cancel anytime"
    }

    private func trialDays(_ product: Product?) -> Int? {
        guard let offer = product?.subscription?.introductoryOffer, offer.paymentMode == .freeTrial else { return nil }
        let p = offer.period
        switch p.unit {
        case .day:   return p.value
        case .week:  return p.value * 7
        case .month: return p.value * 30
        case .year:  return p.value * 365
        @unknown default: return nil
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
            MascotView(mood: .sassy, size: 110)
            MascotSpeechLine(line: context.mascotLine, arrowOffsetY: 26)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 28)
    }

    // MARK: - Benefits

    private var benefitsPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            benefitRow("book.pages.fill", "Next chapters",
                       "Finish a plan, get the next 5-7 steps built from what you learned")
            benefitRow("arrow.clockwise", "Re-taste after the work",
                       "The critic re-scores with your results as evidence. Watch the number move.")
            benefitRow("doc.text.magnifyingglass", "Full evidence",
                       "Every tasting note, market stat, and the receipt behind the score")
            benefitRow("flame.fill", "Unlimited stalls, more gallop",
                       "No 3-idea cap, and double the daily tastings")
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
            AnalyticsService.shared.log(.paywallPlanSelected(productId: product.id))
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
                     destination: URL(string: "https://abimo.ca/privacy/")!)
            }
            .font(.duoCaption)
            .foregroundColor(.textSec)
        }
    }

    // MARK: - Actions

    private func buySelected() {
        guard let product = entitlements.products.first(where: { $0.id == selectedProductID })
                ?? entitlements.products.first else { return }
        AnalyticsService.shared.log(.purchaseInitiated(productId: product.id))
        Task {
            if await entitlements.purchase(product) {
                purchased = true
                HapticEngine.success()
                dismiss()
            }
        }
    }
}

#Preview {
    PaywallView(context: .ideaCap)
}
