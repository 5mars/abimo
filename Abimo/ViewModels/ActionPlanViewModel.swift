//
//  ActionPlanViewModel.swift
//  Abimo
//

import Foundation
import Combine
import UIKit

// MARK: - CelebrationState

/// Drives all celebration UI in Phase 3. Views are purely reactive to this state.
/// Equatable conformance is required for `.animation(value:)` transitions.
enum CelebrationState: Equatable {
    case idle
    case inlineConfetti(actionId: UUID)   // per-action node burst, auto-clears after 1.5s
    case milestone(count: Int)            // 3, 5, or 7 — banner + heavier confetti, auto-clears after 2.5s
    case streakExtended(days: Int)        // first completion of the day — flame banner, auto-clears after 2.5s
    case planComplete                     // full-screen overlay, user-dismissed via Done button
}

// MARK: - PostCompletionSheet

/// Drives the post-completion sheet state machine. A single `.sheet(item:)` modifier reads from this.
/// Replaces the old `showMomentumPicker` boolean to eliminate sheet presentation race conditions.
enum PostCompletionSheet: Identifiable, Equatable {
    case congrats(actionId: UUID)
    case actionPicker

    var id: String {
        switch self {
        case .congrats(let id): return "congrats-\(id)"
        case .actionPicker: return "actionPicker"
        }
    }
}

@MainActor
class ActionPlanViewModel: ObservableObject {
    @Published var actionPlan: ActionPlan?
    @Published var microActions: [MicroAction] = []
    @Published var activeCommitment: Commitment?
    @Published var nudges: [NudgeMessage] = []
    @Published var isGenerating = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userOrderedIds: [UUID] = []
    @Published var postCompletionSheet: PostCompletionSheet? = nil
    @Published var showActionPicker = false
    @Published var completingActionId: UUID?
    @Published var justCompletedActionId: UUID? = nil
    @Published var celebrationState: CelebrationState = .idle

    private let supabase = SupabaseService.shared
    private let aiService = AIAnalysisService()

    // MARK: - Computed

    var completedCount: Int { microActions.filter(\.isCompleted).count }
    var totalCount: Int { microActions.count }
    var progress: Double { totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0 }

    /// Sum of timeEstimateMinutes for completed actions only (used in plan completion summary).
    var completedMinutes: Int {
        microActions
            .filter(\.isCompleted)
            .reduce(0) { $0 + $1.timeEstimateMinutes }
    }

    /// Returns microActions sorted by user-driven ordering. When no user order is set,
    /// falls back to the original microActions array order.
    var orderedActions: [MicroAction] {
        guard !userOrderedIds.isEmpty else { return microActions }
        let rank = userOrderedIds.enumerated().reduce(into: [UUID: Int]()) {
            $0[$1.element] = $1.offset
        }
        return microActions.sorted {
            let ra = rank[$0.id] ?? (Int.max - $0.priority)
            let rb = rank[$1.id] ?? (Int.max - $1.priority)
            return ra < rb
        }
    }

    var nextRecommendedAction: MicroAction? {
        orderedActions.first(where: { !$0.isCompleted })
    }

    var committedAction: MicroAction? {
        guard let commitment = activeCommitment else { return nil }
        return microActions.first(where: { $0.id == commitment.microActionId })
    }

    // MARK: - Generate Action Plan (one-tap activation energy)

    func generateActionPlan(analysis: SWOTAnalysis, transcriptionText: String, noteTitle: String = "") async {
        isGenerating = true
        errorMessage = nil
        defer { isGenerating = false }

        do {
            let (plan, actions) = try await aiService.generateAndSaveActionPlan(
                analysis: analysis,
                transcriptionText: transcriptionText,
                noteTitle: noteTitle
            )
            actionPlan = plan
            microActions = actions
            showActionPicker = true
        } catch {
            errorMessage = "Failed to generate action plan: \(error.localizedDescription)"
        }
    }

    // MARK: - Load Existing Plan

    func loadActionPlan(analysisId: UUID) async {
        let isFirstLoad = actionPlan == nil
        if isFirstLoad { isLoading = true }
        defer { if isFirstLoad { isLoading = false } }

        do {
            guard let plan = try await supabase.fetchActionPlan(analysisId: analysisId) else { return }
            actionPlan = plan
            microActions = try await supabase.fetchMicroActions(actionPlanId: plan.id)

            if let userId = try await supabase.getCurrentUser()?.id {
                activeCommitment = try await supabase.fetchActiveCommitment(userId: userId)
            }

            computeNudges()
            mergeUserOrder(planId: plan.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Toggle Micro Action

    func toggleMicroAction(id: UUID, isCompleted: Bool) async {
        if isCompleted {
            // Cancel nudge for completed action + streak-risk
            NotificationScheduler.shared.cancelActionNudge(actionId: id)
            NotificationService.shared.cancelNotification(id: "streak-risk")

            // Auto-confirm with default outcome, then show post-completion sheet
            await confirmCompletion(id: id, outcome: "did_it", note: nil)
            completingActionId = id

            // Only show congrats sheet if there are remaining actions (not plan complete)
            let hasRemaining = microActions.contains(where: { !$0.isCompleted && $0.id != id })
            if hasRemaining {
                if postCompletionSheet == nil {
                    postCompletionSheet = .congrats(actionId: id)
                } else {
                    // Previous sheet still animating out — defer one runloop tick
                    DispatchQueue.main.async { [weak self] in
                        self?.postCompletionSheet = .congrats(actionId: id)
                    }
                }
            }
        } else {
            // Unchecking — just toggle directly
            await performToggle(id: id, isCompleted: false)
        }
    }

    /// Confirm completion with reflection data
    func confirmCompletion(id: UUID, outcome: String, note: String?) async {
        if let idx = microActions.firstIndex(where: { $0.id == id }) {
            microActions[idx].isCompleted = true
            microActions[idx].completedAt = Date()
            microActions[idx].completionOutcome = outcome
            microActions[idx].completionNote = note
        }

        justCompletedActionId = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.justCompletedActionId = nil
        }

        // Celebration state (Phase 3)
        evaluateCelebrationState(completedId: id)

        do {
            try await supabase.toggleMicroAction(id: id, isCompleted: true, outcome: outcome, note: note)

            if let commitment = activeCommitment, commitment.microActionId == id {
                try await supabase.updateCommitmentStatus(id: commitment.id, status: "completed", completedAt: Date())
                activeCommitment = nil
            }

            computeNudges()
            await evaluateStreakCelebration()
        } catch {
            if let idx = microActions.firstIndex(where: { $0.id == id }) {
                microActions[idx].isCompleted = false
                microActions[idx].completedAt = nil
                microActions[idx].completionOutcome = nil
                microActions[idx].completionNote = nil
            }
            // The optimistic checkmark just vanished — tell the user why
            celebrationState = .idle
            HapticEngine.impact(style: .heavy)
            errorMessage = "That didn't save — check your connection and try again"
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
                if self?.errorMessage != nil { self?.errorMessage = nil }
            }
        }
    }

    /// Streak across every plan the user has, plus how many completions landed
    /// today — used to detect "first completion of the day" after a save.
    static func streakInfo(completionDates: [Date], calendar: Calendar = .current, now: Date = Date()) -> (streak: Int, completionsToday: Int) {
        let today = calendar.startOfDay(for: now)
        let completionsToday = completionDates.filter { calendar.isDate($0, inSameDayAs: now) }.count
        let days = Set(completionDates.map { calendar.startOfDay(for: $0) })
        guard days.contains(today) else { return (0, completionsToday) }

        var streak = 0
        var check = today
        while days.contains(check) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }
        return (streak, completionsToday)
    }

    /// Fires the streak-extended flame banner (and the dormant streak-milestone
    /// notification) on the first completion of the day. Queued behind whatever
    /// celebration is already on screen; planComplete owns the screen alone.
    private func evaluateStreakCelebration() async {
        guard let userId = try? await supabase.getCurrentUser()?.id,
              let allPlans = try? await supabase.fetchAllActionPlans(userId: userId) else { return }

        var dates: [Date] = []
        for plan in allPlans {
            let actions = (try? await supabase.fetchMicroActions(actionPlanId: plan.id)) ?? []
            dates.append(contentsOf: actions.compactMap(\.completedAt))
        }

        let info = Self.streakInfo(completionDates: dates)
        guard info.completionsToday == 1 else { return }

        if [3, 7, 14, 30].contains(info.streak) {
            NotificationScheduler.shared.sendStreakMilestone(days: info.streak)
        }

        guard info.streak >= 2, celebrationState != .planComplete else { return }

        let delay: TimeInterval
        switch celebrationState {
        case .milestone:       delay = 2.7
        case .inlineConfetti:  delay = 1.7
        default:               delay = 0.3
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, self.celebrationState == .idle else { return }
            self.celebrationState = .streakExtended(days: info.streak)
            HapticEngine.impact(style: .medium)
            SoundEngine.whoosh()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                if case .streakExtended = self?.celebrationState ?? .idle {
                    self?.celebrationState = .idle
                }
            }
        }
    }

    /// Evaluates and sets celebrationState after an action is marked complete.
    /// Checks allDone FIRST to ensure planComplete takes priority over milestone
    /// (critical for 7-action plans where 7th == both milestone and last action).
    func evaluateCelebrationState(completedId: UUID) {
        let newCompletedCount = microActions.filter(\.isCompleted).count
        let allDone = newCompletedCount == microActions.count && !microActions.isEmpty

        if allDone {
            // planComplete takes priority — skip milestone even if count is 3, 5, or 7
            celebrationState = .planComplete
            HapticEngine.success()
            SoundEngine.fanfare()
        } else if [3, 5, 7].contains(newCompletedCount) {
            celebrationState = .milestone(count: newCompletedCount)
            HapticEngine.impact(style: .medium)
            SoundEngine.chime()
            // Auto-clear after 2.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                if self?.celebrationState == .milestone(count: newCompletedCount) {
                    self?.celebrationState = .idle
                }
            }
        } else {
            celebrationState = .inlineConfetti(actionId: completedId)
            HapticEngine.success()
            SoundEngine.pop()
            // Auto-clear after 1.5s
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                if self?.celebrationState == .inlineConfetti(actionId: completedId) {
                    self?.celebrationState = .idle
                }
            }
        }
    }

    private func performToggle(id: UUID, isCompleted: Bool) async {
        if let idx = microActions.firstIndex(where: { $0.id == id }) {
            microActions[idx].isCompleted = isCompleted
            microActions[idx].completedAt = isCompleted ? Date() : nil
        }

        do {
            try await supabase.toggleMicroAction(id: id, isCompleted: isCompleted)
            computeNudges()
        } catch {
            if let idx = microActions.firstIndex(where: { $0.id == id }) {
                microActions[idx].isCompleted = !isCompleted
                microActions[idx].completedAt = nil
            }
        }
    }

    // MARK: - Commitment (mere-measurement)

    func commitToAction(_ action: MicroAction, scheduledFor: Date?) async {
        guard let userId = try? await supabase.getCurrentUser()?.id else { return }

        // Expire any existing active commitment
        if let existing = activeCommitment {
            try? await supabase.updateCommitmentStatus(id: existing.id, status: "skipped")
        }

        let commitment = Commitment(
            id: UUID(),
            userId: userId,
            microActionId: action.id,
            scheduledFor: scheduledFor,
            status: "active",
            completedAt: nil,
            createdAt: Date()
        )

        do {
            try await supabase.createCommitment(commitment)
            try await supabase.commitMicroAction(id: action.id, scheduledFor: scheduledFor)
            activeCommitment = commitment
            HapticEngine.selection()

            if let idx = microActions.firstIndex(where: { $0.id == action.id }) {
                microActions[idx].isCommitted = true
                microActions[idx].committedAt = Date()
                microActions[idx].scheduledFor = scheduledFor
            }

            computeNudges()
        } catch {
            errorMessage = "Failed to save commitment: \(error.localizedDescription)"
        }
    }

    // MARK: - Action Ordering

    func pickAction(id: UUID) {
        var ids = orderedActions.map(\.id)
        ids.removeAll { $0 == id }
        let completedIds = Set(microActions.filter(\.isCompleted).map(\.id))
        let nextIncompleteIdx = ids.firstIndex(where: { !completedIds.contains($0) }) ?? ids.endIndex
        ids.insert(id, at: nextIncompleteIdx)
        userOrderedIds = ids
        saveOrderToUserDefaults()
        showActionPicker = false
        HapticEngine.selection()
        Task { await silentCommit(actionId: id) }

        // Schedule nudge if action not completed within 24h
        if let action = orderedActions.first(where: { $0.id == id }) {
            NotificationScheduler.shared.scheduleActionNudge(actionId: id, actionText: action.text)
        }
    }

    /// Deprecated: In-sheet content swap replaces dismiss+re-present pattern.
    /// PostCompletionSheetContent.advance() handles the transition locally.
    func advanceToActionPicker() { }

    func dismissPostCompletionSheet() {
        postCompletionSheet = nil
    }

    private func silentCommit(actionId: UUID) async {
        guard let action = microActions.first(where: { $0.id == actionId }) else { return }
        if let existing = activeCommitment {
            try? await supabase.updateCommitmentStatus(id: existing.id, status: "skipped")
        }
        await commitToAction(action, scheduledFor: nil)
    }

    // MARK: - Order Persistence

    private let defaults = UserDefaults.standard

    private func userDefaultsKey(for planId: UUID) -> String {
        "actionOrder_\(planId.uuidString)"
    }

    private func loadOrderFromUserDefaults(planId: UUID) -> [UUID]? {
        guard let data = defaults.data(forKey: userDefaultsKey(for: planId)),
              let ids = try? JSONDecoder().decode([UUID].self, from: data) else { return nil }
        return ids
    }

    func saveOrderToUserDefaults() {
        guard let planId = actionPlan?.id else { return }
        guard let data = try? JSONEncoder().encode(userOrderedIds) else { return }
        defaults.set(data, forKey: userDefaultsKey(for: planId))
    }

    func mergeUserOrder(planId: UUID) {
        let fetchedIds = Set(microActions.map(\.id))
        if var stored = loadOrderFromUserDefaults(planId: planId) {
            stored = stored.filter { fetchedIds.contains($0) }
            let storedSet = Set(stored)
            let newIds = microActions
                .filter { !storedSet.contains($0.id) }
                .sorted { $0.priority < $1.priority }
                .map(\.id)
            userOrderedIds = stored + newIds
        }
    }

    // MARK: - Nudge Computation (local)

    func computeNudges() {
        var result: [NudgeMessage] = []

        // Inactivity: no completions in last 2+ days
        let lastCompletion = microActions
            .compactMap(\.completedAt)
            .max()

        if let lastDate = lastCompletion {
            let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            if daysSince >= 2 {
                result.append(NudgeMessage(
                    type: .inactivity,
                    title: "Your idea is waiting",
                    body: "You haven't checked off an action in \(daysSince) days. Pick up where you left off?",
                    actionLabel: "Jump back in",
                    relatedActionId: nextRecommendedAction?.id
                ))
            }
        }

        // Commitment due
        if let commitment = activeCommitment,
           let scheduled = commitment.scheduledFor,
           scheduled <= Date() {
            let action = microActions.first(where: { $0.id == commitment.microActionId })
            result.append(NudgeMessage(
                type: .commitmentDue,
                title: "Time's up!",
                body: "You said you'd: \(action?.text ?? "complete your action")",
                actionLabel: "Mark it done",
                relatedActionId: commitment.microActionId
            ))
        }

        // Milestone
        let totalCompleted = microActions.filter(\.isCompleted).count
        if [3, 5, 7].contains(totalCompleted) && totalCompleted == completedCount {
            result.append(NudgeMessage(
                type: .milestone,
                title: "\(totalCompleted) actions done!",
                body: "You're making real progress on this idea",
                actionLabel: nil,
                relatedActionId: nil
            ))
        }

        nudges = result
    }
}

// MARK: - Actions Tab ViewModel (aggregates all plans)

@MainActor
class ActionsTabViewModel: ObservableObject {
    @Published var plans: [ActionPlan] = []
    @Published var microActionsByPlan: [UUID: [MicroAction]] = [:]
    @Published var activeCommitment: Commitment?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let supabase = SupabaseService.shared

    var nudges: [NudgeMessage] {
        var result: [NudgeMessage] = []

        // Commitment due nudge
        if let commitment = activeCommitment,
           let scheduled = commitment.scheduledFor,
           scheduled <= Date() {
            let action = microActionsByPlan.values
                .flatMap { $0 }
                .first(where: { $0.id == commitment.microActionId })
            result.append(NudgeMessage(
                type: .commitmentDue,
                title: "Time's up!",
                body: "You said you'd: \(action?.text ?? "complete your action")",
                actionLabel: "Mark it done",
                relatedActionId: commitment.microActionId
            ))
        }

        // Inactivity nudge across all plans
        let allActions = microActionsByPlan.values.flatMap { $0 }
        let lastCompletion = allActions.compactMap(\.completedAt).max()
        if let lastDate = lastCompletion, !allActions.allSatisfy(\.isCompleted) {
            let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            if daysSince >= 2 {
                result.append(NudgeMessage(
                    type: .inactivity,
                    title: "Your ideas are waiting",
                    body: "You haven't checked off an action in \(daysSince) days",
                    actionLabel: "Jump back in",
                    relatedActionId: nil
                ))
            }
        }

        return result
    }

    func loadAllPlans() async {
        let isFirstLoad = plans.isEmpty
        if isFirstLoad { isLoading = true }
        defer { if isFirstLoad { isLoading = false } }

        errorMessage = nil

        guard let userId = try? await supabase.getCurrentUser()?.id else {
            errorMessage = "Couldn't load your plans"
            return
        }

        do {
            let fetchedPlans = try await supabase.fetchAllActionPlans(userId: userId)
            var fetchedActions: [UUID: [MicroAction]] = [:]
            for plan in fetchedPlans {
                let actions = try await supabase.fetchMicroActions(actionPlanId: plan.id)
                fetchedActions[plan.id] = actions
            }
            plans = fetchedPlans
            microActionsByPlan = fetchedActions
            activeCommitment = try? await supabase.fetchActiveCommitment(userId: userId)
        } catch {
            errorMessage = "Couldn't load your plans: \(error.localizedDescription)"
        }
    }

    func completedCount(for planId: UUID) -> Int {
        microActionsByPlan[planId]?.filter(\.isCompleted).count ?? 0
    }

    func totalCount(for planId: UUID) -> Int {
        microActionsByPlan[planId]?.count ?? 0
    }

    func progress(for planId: UUID) -> Double {
        let total = totalCount(for: planId)
        guard total > 0 else { return 0 }
        return Double(completedCount(for: planId)) / Double(total)
    }

    func committedActionText(for planId: UUID) -> String? {
        guard let commitment = activeCommitment else { return nil }
        return microActionsByPlan[planId]?
            .first(where: { $0.id == commitment.microActionId })?
            .text
    }

    func committedMicroAction(for planId: UUID) -> MicroAction? {
        guard let commitment = activeCommitment else { return nil }
        return microActionsByPlan[planId]?
            .first(where: { $0.id == commitment.microActionId })
    }

    /// Find which plan contains the committed action
    func committedActionPlanId() -> UUID? {
        guard let commitment = activeCommitment else { return nil }
        for (planId, actions) in microActionsByPlan {
            if actions.contains(where: { $0.id == commitment.microActionId }) {
                return planId
            }
        }
        return nil
    }

    func committedActionAnalysisId() -> UUID? {
        guard let planId = committedActionPlanId() else { return nil }
        return plans.first(where: { $0.id == planId })?.analysisId
    }

    // MARK: - Streak & Week Activity

    var allCompletionDates: [Date] {
        microActionsByPlan.values
            .flatMap { $0 }
            .compactMap(\.completedAt)
    }

    /// Current streak: consecutive days ending today with at least one completion
    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let completionDays = Set(allCompletionDates.map { calendar.startOfDay(for: $0) })

        guard completionDays.contains(today) else { return 0 }

        var streak = 0
        var checkDate = today
        while completionDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    /// 7 bools for Mon–Sun of the current week
    var weekActivity: [Bool] {
        let calendar = Calendar.current
        let today = Date()
        let completionDays = Set(allCompletionDates.map { calendar.startOfDay(for: $0) })

        // Find Monday of this week
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2 // Monday
        guard let monday = calendar.date(from: components) else {
            return Array(repeating: false, count: 7)
        }

        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: monday) else { return false }
            return completionDays.contains(calendar.startOfDay(for: day))
        }
    }

    var totalCompletedThisWeek: Int {
        let calendar = Calendar.current
        let today = Date()
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)
        components.weekday = 2
        guard let monday = calendar.date(from: components) else { return 0 }
        let mondayStart = calendar.startOfDay(for: monday)

        return allCompletionDates.filter { date in
            calendar.startOfDay(for: date) >= mondayStart
        }.count
    }

    var activeCommitmentText: String? {
        guard let commitment = activeCommitment else { return nil }
        return microActionsByPlan.values
            .flatMap { $0 }
            .first(where: { $0.id == commitment.microActionId })?
            .text
    }
}
