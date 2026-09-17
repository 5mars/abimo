//
//  NotificationScheduler.swift
//  Abimo
//
//  Every local nudge the app schedules, in one place. Each carries a
//  DeepRoute so a tap lands somewhere useful, and each escalates in sass
//  the longer it goes unanswered — the copy pools were written that way
//  all along; now they are actually sent.
//
//  Budget check (iOS caps pending requests at 64): 6 inactivity + 1 streak
//  + up to 3 per committed action + up to 3 per untasted idea + milestones
//  stays comfortably under.
//

import Foundation
import UserNotifications

@MainActor
class NotificationScheduler {
    static let shared = NotificationScheduler()
    private let service = NotificationService.shared
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - App Lifecycle

    func onBackground() {
        scheduleInactivityCycle()
        Task { await scheduleStreakAtRisk() }
    }

    func onForeground() {
        service.cancelNotifications(withPrefix: "inactivity-")
        service.cancelNotification(id: "streak-risk")
    }

    // MARK: - Inactivity Cycle (1 / 3 / 7 / 14 / 30 / 60 days)

    private func scheduleInactivityCycle() {
        guard defaults.bool(forKey: "notif_inactivity") else { return }
        let day: TimeInterval = 24 * 60 * 60

        let ladder: [(id: String, delayDays: Double, message: NotificationMessage, route: DeepRoute)] = [
            ("inactivity-1d",  1,  NotificationCopy.message(for: .inactivity, sass: .playful),   .record),
            ("inactivity-3d",  3,  NotificationCopy.message(for: .inactivity, sass: .sassy),     .record),
            ("inactivity-7d",  7,  NotificationCopy.message(for: .inactivity, sass: .guiltTrip), .record),
            ("inactivity-14d", 14, NotificationCopy.message(for: .longAbsence(days: 14), sass: .sassy),     .actions),
            ("inactivity-30d", 30, NotificationCopy.message(for: .longAbsence(days: 30), sass: .guiltTrip), .actions),
            ("inactivity-60d", 60, NotificationCopy.message(for: .longAbsence(days: 60), sass: .guiltTrip), .record),
        ]
        for step in ladder {
            service.scheduleNotification(
                id: step.id,
                title: step.message.title,
                body: step.message.body,
                delay: step.delayDays * day,
                route: step.route,
                kind: "inactivity"
            )
        }
    }

    // MARK: - Streak At Risk

    /// Only fires when there is an actual streak on the line — a user with
    /// no streak (or one already extended today) hears nothing at 8pm. A
    /// longer streak earns a sharper poke.
    private func scheduleStreakAtRisk() async {
        guard defaults.bool(forKey: "notif_streak") else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour < 20 else { return }

        let dates = await CompletionStore.shared.activityDates()
        let atRisk = ActionPlanViewModel.streakEndingYesterday(completionDates: dates)
        guard atRisk >= 2 else { return }

        let sass: SassLevel = atRisk >= 14 ? .guiltTrip : (atRisk >= 7 ? .sassy : .playful)
        let msg = NotificationCopy.message(for: .streakAtRisk, sass: sass)
        service.scheduleNotificationAtHour(
            id: "streak-risk",
            title: msg.title,
            body: msg.body,
            hour: 20,
            minute: 0,
            route: .actions,
            kind: "streak"
        )
    }

    // MARK: - Action Nudge (24h playful → 72h sassy → 7d guilt trip)

    func scheduleActionNudge(actionId: UUID, actionText: String, planId: UUID? = nil, analysisId: UUID? = nil) {
        guard defaults.bool(forKey: "notif_action_nudge") else { return }
        let route: DeepRoute = (planId != nil && analysisId != nil)
            ? .plan(planId: planId!, analysisId: analysisId!)
            : .actions
        let ladder: [(suffix: String, hours: Double, sass: SassLevel)] = [
            ("", 24, .playful), ("-2", 72, .sassy), ("-3", 168, .guiltTrip),
        ]
        for step in ladder {
            let msg = NotificationCopy.message(for: .incompleteAction, sass: step.sass, context: actionText)
            service.scheduleNotification(
                id: "action-nudge-\(actionId.uuidString)\(step.suffix)",
                title: msg.title,
                body: msg.body,
                delay: step.hours * 60 * 60,
                route: route,
                kind: "action"
            )
        }
    }

    func cancelActionNudge(actionId: UUID) {
        service.cancelNotifications(withPrefix: "action-nudge-\(actionId.uuidString)")
    }

    // MARK: - Idea Nudge (same ladder)

    func scheduleIdeaNudge(noteId: UUID, noteTitle: String) {
        guard defaults.bool(forKey: "notif_idea_nudge") else { return }
        let ladder: [(suffix: String, hours: Double, sass: SassLevel)] = [
            ("", 24, .playful), ("-2", 72, .sassy), ("-3", 168, .guiltTrip),
        ]
        for step in ladder {
            let msg = NotificationCopy.message(for: .unanalyzedIdea, sass: step.sass, context: noteTitle)
            service.scheduleNotification(
                id: "idea-nudge-\(noteId.uuidString)\(step.suffix)",
                title: msg.title,
                body: msg.body,
                delay: step.hours * 60 * 60,
                route: .note(noteId),
                kind: "idea"
            )
        }
    }

    func cancelIdeaNudge(noteId: UUID) {
        service.cancelNotifications(withPrefix: "idea-nudge-\(noteId.uuidString)")
    }

    // MARK: - Streak Milestone

    func sendStreakMilestone(days: Int) {
        guard defaults.bool(forKey: "notif_streak") else { return }
        let msg = NotificationCopy.message(for: .streakMilestone(days: days), sass: .playful)
        service.scheduleNotification(
            id: "streak-milestone-\(days)",
            title: msg.title,
            body: msg.body,
            delay: 1,
            route: .actions,
            kind: "streak"
        )
    }
}
