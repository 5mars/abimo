//
//  CompletionStore.swift
//  Abimo
//
//  One cached copy of every plan's micro-actions, shared by the four places
//  that previously each ran their own N+1 fetch (plans, then actions per
//  plan): ActionsTabViewModel.loadAllPlans, the post-completion celebration
//  evaluation, MascotDirector's streak-at-risk check, and the streak-at-risk
//  notification scheduler.
//
//  Reads within `maxAge` return the cache; concurrent callers share one
//  in-flight fetch. Writers invalidate after a completion save; loadAllPlans
//  seeds the cache with data it fetched anyway.
//

import Foundation

@MainActor
final class CompletionStore {
    static let shared = CompletionStore()

    private let supabase = SupabaseService.shared
    private var cache: (actionsByPlan: [UUID: [MicroAction]], fetchedAt: Date)?
    private var inFlight: Task<[UUID: [MicroAction]], Never>?

    private init() {}

    nonisolated deinit {}

    /// Every plan's actions, from cache when younger than `maxAge`.
    func actionsByPlan(maxAge: TimeInterval = 60) async -> [UUID: [MicroAction]] {
        if let cache, Date().timeIntervalSince(cache.fetchedAt) < maxAge {
            return cache.actionsByPlan
        }
        if let inFlight {
            return await inFlight.value
        }
        let task = Task { [supabase] () -> [UUID: [MicroAction]] in
            guard let userId = try? await supabase.getCurrentUser()?.id,
                  let plans = try? await supabase.fetchAllActionPlans(userId: userId) else { return [:] }
            var byPlan: [UUID: [MicroAction]] = [:]
            for plan in plans {
                byPlan[plan.id] = (try? await supabase.fetchMicroActions(actionPlanId: plan.id)) ?? []
            }
            return byPlan
        }
        inFlight = task
        let result = await task.value
        inFlight = nil
        cache = (result, Date())
        return result
    }

    /// All completion timestamps across every plan.
    func completionDates(maxAge: TimeInterval = 60) async -> [Date] {
        await actionsByPlan(maxAge: maxAge).values.flatMap { $0 }.compactMap(\.completedAt)
    }

    /// Drop the cache — call after any write that changes completions.
    func invalidate() {
        cache = nil
    }

    /// Feed the cache from a fetch someone else already paid for.
    func seed(_ actionsByPlan: [UUID: [MicroAction]]) {
        cache = (actionsByPlan, Date())
    }
}
