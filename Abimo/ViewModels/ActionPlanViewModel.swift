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
    // The three below are no longer emitted: streak, daily goal and badge
    // land in CompletionRewards (the strip in the congrats sheet). Kept so
    // the enum's shape — and every switch over it — stays stable.
    case streakExtended(days: Int)
    case dailyGoalHit(goalXP: Int)
    case achievementUnlocked(Achievement)
    case planComplete                     // full-screen overlay, user-dismissed via Done button
}

// MARK: - PostCompletionSheet

/// Drives the post-completion sheet state machine. A single `.sheet(item:)` modifier reads from this.
/// Replaces the old `showMomentumPicker` boolean to eliminate sheet presentation race conditions.
enum PostCompletionSheet: Identifiable, Equatable {
    case congrats(actionId: UUID)
    /// The four-question brief the critic needs before writing chapter `chapter`.
    case chapterBrief(chapter: Int)

    var id: String {
        switch self {
        case .congrats(let id): return "congrats-\(id)"
        case .chapterBrief(let chapter): return "brief-\(chapter)"
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
    @Published var postCompletionSheet: PostCompletionSheet? = nil
    @Published var completingActionId: UUID?
    @Published var justCompletedActionId: UUID? = nil
    @Published var celebrationState: CelebrationState = .idle
    /// What the most recent completion earned — shown as one strip in the
    /// congrats / plan-complete sheets instead of stacked banners.
    @Published var lastRewards: CompletionRewards? = nil

    private let supabase = SupabaseService.shared
    private let aiService = AIAnalysisService()

    // Isolated deinits (the default under MainActor default isolation) crash
    // the Swift runtime when the deallocation happens inside a task-local
    // scope — XCTest always sets one, so every unit test that releases this
    // VM aborts the test host. Nothing here needs the main actor to tear down.
    nonisolated deinit {}

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

    /// The plan's own order: chapter part, then the priority the coach gave
    /// each step. Nothing user-driven — the path is linear by design.
    var orderedActions: [MicroAction] {
        microActions.sorted {
            if $0.chapterNumber != $1.chapterNumber { return $0.chapterNumber < $1.chapterNumber }
            return $0.priority < $1.priority
        }
    }

    /// Chapters are a pure projection of orderedActions (see JourneyChapterBuilder).
    var chapters: [JourneyChapter] { JourneyChapterBuilder.build(from: orderedActions) }

    /// Every step in the order it appears on the path — chapter by chapter,
    /// top to bottom. THIS is the order the journey advances in.
    var pathActions: [MicroAction] { chapters.flatMap(\.actions) }

    /// The one lit node: the first unfinished step along the path.
    var nextRecommendedAction: MicroAction? {
        Self.nextStep(in: pathActions)
    }

    /// Pure so it can be tested: first unfinished step, in path order.
    static func nextStep(in path: [MicroAction]) -> MicroAction? {
        path.first(where: { !$0.isCompleted })
    }

    /// How many plan parts exist (1 = original plan only; 2+ after "Next chapter").
    var partCount: Int { microActions.map(\.chapterNumber).max() ?? 1 }

    /// Mirrors _shared/chapters.ts MAX_CHAPTER — the gate card changes after this.
    static var maxChapters: Int { ChapterLadder.maxChapters }
    var isFinalChapterDone: Bool { ChapterLadder.isFinal(partCount) && nextRecommendedAction == nil && !microActions.isEmpty }

    // MARK: - Next chapter (Plus)

    @Published var isExtending = false
    /// Prefill for the brief sheet — the last answers this founder gave.
    @Published var lastBrief: ChapterBrief = .default

    /// Step one of "Next chapter": ask the founder the four questions. The
    /// paywall runs before this is called; the server re-checks Plus anyway.
    func requestNextChapter() async throws {
        guard actionPlan != nil, !isExtending, partCount < Self.maxChapters else { return }
        let chapter = partCount + 1
        AnalyticsService.shared.log(.nextChapterRequested(chapter: chapter))
        if let stored = try? await supabase.fetchLatestChapterBrief() { lastBrief = stored.brief }
        // Hop off any sheet already up (the wrap-up runs full-screen, so this is
        // usually a no-op) and present the brief.
        postCompletionSheet = .chapterBrief(chapter: chapter)
    }

    /// Step two: the brief is in — write the chapter. New steps land as
    /// `open`, the first becomes `next`, and the celebration overlay clears so
    /// the journey is usable again.
    func submitBrief(_ brief: ChapterBrief) async throws {
        guard let plan = actionPlan, !isExtending else { return }
        isExtending = true
        defer { isExtending = false }
        let chapter = partCount + 1
        lastBrief = brief
        AnalyticsService.shared.log(.chapterBriefSubmitted(chapter: chapter, techSkill: brief.techSkill.rawValue))
        do {
            let (written, added) = try await aiService.extendActionPlan(plan, existing: microActions, brief: brief)
            microActions.append(contentsOf: added)
            celebrationState = .idle
            lastRewards = nil
            AnalyticsService.shared.log(.nextChapterGenerated(chapter: written, actions: added.count))
            HapticEngine.success()
        } catch {
            AnalyticsService.shared.log(.nextChapterFailed(chapter: chapter, code: "\(ChapterError.from(error))"))
            throw error
        }
    }

    /// Minutes still on the plate — the "45 min left" in the journey header.
    var remainingMinutes: Int {
        microActions.filter { !$0.isCompleted }.reduce(0) { $0 + $1.timeEstimateMinutes }
    }

    /// Streak and today's XP for the journey header. Sourced from
    /// CompletionStore because ActionsTabViewModel is NOT in the environment
    /// when this screen is pushed from the Kitchen.
    @Published var streak: Int = 0
    @Published var xpToday: Int = 0

    /// What completing the next step is worth right now.
    var nextStepXP: Int { XPEngine.actionXP + (xpToday == 0 ? XPEngine.firstOfDayBonus : 0) }

    func refreshMomentum() async {
        let completions = await CompletionStore.shared.completionDates()
        let activity = await CompletionStore.shared.activityDates()
        streak = Self.streakInfo(completionDates: activity).streak
        xpToday = XPEngine.xpToday(completionDates: completions)
    }

    /// One CTA rule for every door into the journey.
    static func journeyCTA(completed: Int, committed: Bool) -> String {
        completed == 0 && !committed ? "Start your plan" : "Continue your plan"
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
            await refreshMomentum()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Toggle Micro Action

    func toggleMicroAction(id: UUID, isCompleted: Bool) async {
        if isCompleted {
            await completeAction(id: id, outcome: "did_it", note: nil)
        } else {
            // Unchecking — just toggle directly
            lastRewards = nil
            AnalyticsService.shared.log(.actionUncompleted)
            await performToggle(id: id, isCompleted: false)
        }
    }

    /// Completes a step with the founder's own verdict on it — "did_it" or
    /// "didnt_work" — and an optional note. A step that was tried and failed
    /// is still a completed step: it earns the same XP and the same streak
    /// day, and the outcome is shown on the path so the plan reads as a log.
    func completeAction(id: UUID, outcome: String, note: String?) async {
        // First check-off completes the walk-in tour (no-op otherwise)
        WalkInDirector.shared.microActionCompleted()

        // Cancel nudge for completed action + streak-risk
        NotificationScheduler.shared.cancelActionNudge(actionId: id)
        NotificationService.shared.cancelNotification(id: "streak-risk")

        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        await confirmCompletion(id: id, outcome: outcome, note: (trimmed?.isEmpty ?? true) ? nil : trimmed)
        completingActionId = id

        if let action = microActions.first(where: { $0.id == id }) {
            let today = microActions.filter {
                guard let d = $0.completedAt else { return false }
                return Calendar.current.isDateInToday(d)
            }.count
            AnalyticsService.shared.log(.actionCompleted(
                quadrant: action.quadrant ?? "none",
                minutes: action.timeEstimateMinutes,
                outcome: outcome,
                completionsToday: today,
                streak: streak
            ))
        }

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

    /// The streak a user is about to lose: consecutive days ending YESTERDAY,
    /// with nothing completed today yet. Returns 0 if today is already covered
    /// (nothing at risk) or there was no run ending yesterday.
    static func streakEndingYesterday(completionDates: [Date], calendar: Calendar = .current, now: Date = Date()) -> Int {
        let today = calendar.startOfDay(for: now)
        let days = Set(completionDates.map { calendar.startOfDay(for: $0) })
        guard !days.contains(today),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
              days.contains(yesterday) else { return 0 }

        var streak = 0
        var check = yesterday
        while days.contains(check) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }
        return streak
    }

    /// Fires the streak-extended flame banner (and the dormant streak-milestone
    /// notification) on the first completion of the day, then the daily-goal
    /// banner, then any badge earned by this completion — each queued behind
    /// whatever is already on screen; planComplete owns the screen alone.
    private func evaluateStreakCelebration() async {
        // The completion that triggered this just saved — refetch fresh.
        CompletionStore.shared.invalidate()
        let actionsByPlan = await CompletionStore.shared.actionsByPlan()
        guard !actionsByPlan.isEmpty else { return }

        let dates = actionsByPlan.values.flatMap { $0 }.compactMap(\.completedAt)
        let completedPlanCount = actionsByPlan.values
            .filter { !$0.isEmpty && $0.allSatisfy(\.isCompleted) }
            .count

        // Streak counts recordings too; XP and "first completion today" don't.
        let activity = await CompletionStore.shared.activityDates()
        let info = Self.streakInfo(completionDates: dates)
        let activityStreak = Self.streakInfo(completionDates: activity).streak
        streak = activityStreak
        xpToday = XPEngine.xpToday(completionDates: dates)

        if info.completionsToday == 1, [3, 7, 14, 30].contains(activityStreak) {
            NotificationScheduler.shared.sendStreakMilestone(days: activityStreak)
        }
        if info.completionsToday == 1, activityStreak >= 2 {
            AnalyticsService.shared.log(.streakExtended(days: activityStreak, via: "action"))
        }

        // Everything this completion earned goes into ONE receipt (the
        // rewards strip in the congrats sheet) — no banner queue.
        var rewards = lastRewards ?? CompletionRewards(xp: XPEngine.actionXP)
        rewards.firstOfDay = info.completionsToday == 1
        rewards.xp = CompletionRewards.baseXP(firstOfDay: rewards.firstOfDay)
        if info.completionsToday == 1, activityStreak >= 2 {
            rewards.streak = activityStreak
        }

        let goalXP = UserDefaults.standard.object(forKey: DailyGoalTier.storageKey) as? Int
            ?? DailyGoalTier.fallback.rawValue
        if XPEngine.completionCrossesGoal(completionsTodayAfter: info.completionsToday, goal: goalXP) {
            AnalyticsService.shared.log(.dailyGoalHit(tier: DailyGoalTier(storedXP: goalXP).analyticsName))
            rewards.goalHit = goalXP
        }

        // Badges this completion just earned, celebrated where they're
        // earned instead of waiting for a Profile visit. Only the action/
        // streak/XP-derived badges can trigger here — idea-, analysis- and
        // score-based fields are zeroed, which can only delay those badges
        // (the Profile grid still catches them), never unlock them falsely.
        // Same latch key as the grid, so nothing fires twice.
        let context = AchievementContext(
            ideaCount: 0,
            analysisCount: 0,
            completedActionCount: dates.count,
            completedPlanCount: completedPlanCount,
            currentStreak: info.streak,
            bestScore: nil,
            completedActionsByAnalysisId: [:],
            scoresByAnalysisId: [:],
            totalXP: XPEngine.totalXP(completionDates: dates)
        )
        let previous = Achievement.decodeLatch(
            UserDefaults.standard.string(forKey: Achievement.latchStorageKey) ?? ""
        )
        let fresh = Achievement.freshUnlocks(in: context, previous: previous)
        if let badge = fresh.sorted(by: { $0.rawValue < $1.rawValue }).first {
            UserDefaults.standard.set(
                Achievement.encodeLatch(previous.union(fresh)),
                forKey: Achievement.latchStorageKey
            )
            rewards.badge = badge
        }

        lastRewards = rewards
    }

    /// Evaluates and sets celebrationState after an action is marked complete.
    /// Checks allDone FIRST to ensure planComplete takes priority over milestone
    /// (critical for 7-action plans where 7th == both milestone and last action).
    func evaluateCelebrationState(completedId: UUID) {
        let newCompletedCount = microActions.filter(\.isCompleted).count
        let allDone = newCompletedCount == microActions.count && !microActions.isEmpty

        // Start the receipt here (sync) so the milestone is captured even if
        // the streak fetch that enriches it is slow; base XP until then.
        lastRewards = CompletionRewards(
            xp: XPEngine.actionXP,
            milestone: !allDone && [3, 5, 7].contains(newCompletedCount) ? newCompletedCount : nil
        )

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

    func dismissPostCompletionSheet() {
        postCompletionSheet = nil
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
    /// Only the first fetch shows the loading screen; refetches on tab switch
    /// are silent. `plans.isEmpty` is the wrong signal — it stays true forever
    /// on an empty account and would flash the loader on every switch.
    @Published private(set) var hasLoadedOnce = false
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

    /// The founder's ideas — what the daily loop needs to know whether there
    /// is anything raw to taste, and to count recordings toward the streak.
    @Published var notes: [VoiceNote] = []

    /// Completions ∪ recordings — what the streak and week dots read.
    var activityDates: [Date] {
        allCompletionDates + notes.map(\.createdAt)
    }

    func loadAllPlans() async {
        if !hasLoadedOnce { isLoading = true }
        defer {
            isLoading = false
            hasLoadedOnce = true
        }

        errorMessage = nil

        guard let userId = try? await supabase.getCurrentUser()?.id else {
            errorMessage = "Couldn't load your plans"
            return
        }

        notes = (try? await supabase.fetchVoiceNotes()) ?? notes

        do {
            let fetchedPlans = try await supabase.fetchAllActionPlans(userId: userId)
            var fetchedActions: [UUID: [MicroAction]] = [:]
            for plan in fetchedPlans {
                let actions = try await supabase.fetchMicroActions(actionPlanId: plan.id)
                fetchedActions[plan.id] = actions
            }
            plans = fetchedPlans
            microActionsByPlan = fetchedActions
            // This fetch is the freshest view of every plan — share it so
            // the mascot/notification streak checks don't refetch.
            CompletionStore.shared.seed(fetchedActions)
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

    /// Current streak: consecutive days ending today with at least one
    /// completion OR recording.
    var currentStreak: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        let completionDays = Set(activityDates.map { calendar.startOfDay(for: $0) })

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

    /// 7 bools for Mon–Sun of the current week (completions or recordings)
    var weekActivity: [Bool] {
        let calendar = Calendar.current
        let today = Date()
        let completionDays = Set(activityDates.map { calendar.startOfDay(for: $0) })

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
