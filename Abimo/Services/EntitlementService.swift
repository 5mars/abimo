//
//  EntitlementService.swift
//  Abimo
//
//  StoreKit 2 layer for Abimo Plus. Singleton like MascotDirector — views
//  observe it directly. Premium is derived from Transaction.currentEntitlements
//  (verified, unrevoked), which StoreKit keeps available offline — no cache.
//

import Foundation
import Combine
import StoreKit
import UIKit

@MainActor
final class EntitlementService: ObservableObject {
    static let shared = EntitlementService()

    enum ProductID {
        static let monthly = "com.mars.Abimo.plus.monthly"
        static let yearly  = "com.mars.Abimo.plus.yearly"
        static let all: Set<String> = [monthly, yearly]
    }

    /// Free tier: max ACTIVE ideas — deleting one frees a slot.
    static let freeIdeaLimit = 3

    @Published private(set) var isPremium = false
    @Published private(set) var products: [Product] = []   // sorted monthly-first
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var purchaseInFlight = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    private init() {
        // Listener must be alive before any purchase can occur (Apple guidance);
        // it also catches renewals, refunds, and Ask-to-Buy approvals.
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                    await self?.refreshEntitlement()
                }
            }
        }
        Task {
            await refreshEntitlement()
            await loadProducts()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Entitlement

    func refreshEntitlement() async {
        var premium = false
        for await entitlement in Transaction.currentEntitlements {
            // Only verified, unrevoked transactions count — never trust .unverified.
            if case .verified(let transaction) = entitlement,
               ProductID.all.contains(transaction.productID),
               transaction.revocationDate == nil {
                premium = true
                break
            }
        }
        isPremium = premium
    }

    // MARK: - Products

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: ProductID.all)
            products = loaded.sorted { $0.price < $1.price }
            if !loaded.isEmpty { lastError = nil }
        } catch {
            lastError = "Couldn't load plans: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase / restore

    /// Returns true only when the purchase verified successfully.
    /// Cancelled and pending (Ask to Buy) resolve false without an error.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        guard !purchaseInFlight else { return false }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            guard let scene = activeScene else { return false }
            let result = try await product.purchase(confirmIn: scene)
            switch result {
            case .success(.verified(let transaction)):
                await transaction.finish()
                await refreshEntitlement()
                return true
            case .success(.unverified):
                lastError = "That purchase couldn't be verified. Try Restore Purchases."
                return false
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlement()
        } catch {
            lastError = "Restore failed: \(error.localizedDescription)"
        }
    }

    private var activeScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
    }
}

// MARK: - Premium roadmap
//
// Future Plus gates (documented only — not implemented this round):
// - SWOT re-runs / action-plan regenerations: each costs an OpenAI edge-function
//   call; first run on every idea stays free — that's the hook.
// - Deeper analyses: competitor scan, market-size estimate, harsher
//   "second opinion" critic mode as Plus-only pipeline stages.
// - Mascot personality packs: alternate MascotVoice pools + mood art sets.
// - Longer recordings, batch import, PDF pitch-sheet export.
// - Server-side cap enforcement (security backstop before scale): voice_notes
//   BEFORE INSERT trigger / RLS WITH CHECK against a profiles.is_premium flag,
//   synced via App Store Server Notifications v2 → Supabase edge function.
