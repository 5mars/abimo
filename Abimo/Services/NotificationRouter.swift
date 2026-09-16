//
//  NotificationRouter.swift
//  Abimo
//
//  The app's UNUserNotificationCenterDelegate. Two jobs: keep scheduled
//  nudges from banner-ing over the app while it's open, and turn a tap on
//  a notification into a DeepRoute the root view navigates to — with the
//  open attributed in analytics, which was impossible before (taps just
//  landed on whatever tab was last selected).
//

import Foundation
import Combine
import UserNotifications

@MainActor
final class NotificationRouter: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationRouter()

    /// Consumed by MainContentView: set on tap, cleared once navigated.
    @Published var pendingRoute: DeepRoute?

    private override init() { super.init() }

    /// Must run before the app finishes launching — AbimoApp.init.
    func install() {
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // Our own nudges are about coming back; if the user is already here,
        // showing them is noise. (Pipeline-finished notifications are only
        // scheduled while backgrounded, so this never hides one that matters.)
        []
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let request = response.notification.request
        let userInfo = request.content.userInfo
        let routeString = userInfo["route"] as? String
        let route = routeString.flatMap(DeepRoute.init(encoded:))
        let kind = (userInfo["kind"] as? String) ?? request.identifier.split(separator: "-").first.map(String.init) ?? "unknown"
        let id = request.identifier

        await MainActor.run {
            AnalyticsService.shared.log(.notificationOpened(id: id, kind: kind))
            // A tap with no route still means "open the app" — land on Actions,
            // the surface with something to do.
            self.pendingRoute = route ?? .actions
        }
    }
}
