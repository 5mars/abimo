//
//  NotificationScheduler.swift
//  Abimo
//

import Foundation

@MainActor
class NotificationScheduler {
    static let shared = NotificationScheduler()
    private let service = NotificationService.shared

    private init() {}

    // MARK: - App Lifecycle

    func onBackground() {
        scheduleInactivityCycle()
        scheduleStreakAtRisk()
    }

    func onForeground() {
        service.cancelNotifications(withPrefix: "inactivity-")
        service.cancelNotification(id: "streak-risk")
    }

    // MARK: - Inactivity Cycle

    private func scheduleInactivityCycle() {
        let msg1 = NotificationCopy.message(for: .inactivity, sass: .playful)
        service.scheduleNotification(
            id: "inactivity-1d",
            title: msg1.title,
            body: msg1.body,
            delay: 24 * 60 * 60
        )

        let msg3 = NotificationCopy.message(for: .inactivity, sass: .sassy)
        service.scheduleNotification(
            id: "inactivity-3d",
            title: msg3.title,
            body: msg3.body,
            delay: 72 * 60 * 60
        )

        let msg7 = NotificationCopy.message(for: .inactivity, sass: .guiltTrip)
        service.scheduleNotification(
            id: "inactivity-7d",
            title: msg7.title,
            body: msg7.body,
            delay: 168 * 60 * 60
        )
    }

    // MARK: - Streak At Risk

    private func scheduleStreakAtRisk() {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour < 20 else { return }

        let msg = NotificationCopy.message(for: .streakAtRisk, sass: .playful)
        service.scheduleNotificationAtHour(
            id: "streak-risk",
            title: msg.title,
            body: msg.body,
            hour: 20,
            minute: 0
        )
    }

    // MARK: - Action Nudge

    func scheduleActionNudge(actionId: UUID, actionText: String) {
        let msg = NotificationCopy.message(for: .incompleteAction, sass: .playful, context: actionText)
        service.scheduleNotification(
            id: "action-nudge-\(actionId.uuidString)",
            title: msg.title,
            body: msg.body,
            delay: 24 * 60 * 60
        )
    }

    func cancelActionNudge(actionId: UUID) {
        service.cancelNotification(id: "action-nudge-\(actionId.uuidString)")
    }

    // MARK: - Idea Nudge

    func scheduleIdeaNudge(noteId: UUID, noteTitle: String) {
        let msg = NotificationCopy.message(for: .unanalyzedIdea, sass: .playful, context: noteTitle)
        service.scheduleNotification(
            id: "idea-nudge-\(noteId.uuidString)",
            title: msg.title,
            body: msg.body,
            delay: 24 * 60 * 60
        )
    }

    func cancelIdeaNudge(noteId: UUID) {
        service.cancelNotification(id: "idea-nudge-\(noteId.uuidString)")
    }

    // MARK: - Streak Milestone

    func sendStreakMilestone(days: Int) {
        let msg = NotificationCopy.message(for: .streakMilestone(days: days), sass: .playful)
        service.scheduleNotification(
            id: "streak-milestone-\(days)",
            title: msg.title,
            body: msg.body,
            delay: 1
        )
    }
}
