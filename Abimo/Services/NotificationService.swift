//
//  NotificationService.swift
//  Abimo
//

import Foundation
import Combine
import UserNotifications
import UIKit

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var isAuthorized = false

    private let center = UNUserNotificationCenter.current()

    private init() {
        Task { await checkAuthorizationStatus() }
    }

    // MARK: - Permission

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            return granted
        } catch {
            return false
        }
    }

    func checkAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Scheduling

    func scheduleNotification(
        id: String,
        title: String,
        body: String,
        delay: TimeInterval,
        attachMascot: Bool = true
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if attachMascot, let attachment = mascotAttachment() {
            content.attachments = [attachment]
        }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, delay), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request)
    }

    func scheduleNotificationAtHour(
        id: String,
        title: String,
        body: String,
        hour: Int,
        minute: Int = 0,
        attachMascot: Bool = true
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if attachMascot, let attachment = mascotAttachment() {
            content.attachments = [attachment]
        }

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request)
    }

    // MARK: - Cancellation

    func cancelNotification(id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func cancelNotifications(withPrefix prefix: String) {
        Task {
            let requests = await center.pendingNotificationRequests()
            let ids = requests.filter { $0.identifier.hasPrefix(prefix) }.map { $0.identifier }
            if !ids.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: ids)
            }
        }
    }

    func cancelAllNotifications() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Mascot Attachment

    private func mascotAttachment() -> UNNotificationAttachment? {
        guard let image = UIImage(named: "MascotNeutral"),
              let data = image.pngData() else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("mascot-notification-\(UUID().uuidString).png")

        do {
            try data.write(to: fileURL)
            return try UNNotificationAttachment(identifier: "mascot", url: fileURL)
        } catch {
            return nil
        }
    }
}
