import UIKit
import UserNotifications

extension Notification.Name {
    /// Posted with the push address of this phone as a hex string.
    static let pushTokenReceived = Notification.Name("de.babranyi.familyplanner.pushTokenReceived")
    /// Posted when the person taps a push notification: the bell should open.
    static let openSuggestions = Notification.Name("de.babranyi.familyplanner.openSuggestions")
}

/// Remembers a tap on a notification that arrived before the screen was ready (cold start).
enum PushState {
    static var openSuggestionsRequested = false
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02x", $0) }.joined()
        NotificationCenter.default.post(name: .pushTokenReceived, object: token)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Push is optional: the app works without it, so there is nothing to show.
    }

    /// Show the banner even while the app is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        PushState.openSuggestionsRequested = true
        NotificationCenter.default.post(name: .openSuggestions, object: nil)
        completionHandler()
    }
}

@MainActor
enum PushPermission {
    /// Asks for permission (only the first time) and registers for push. Does nothing in UI tests.
    static func request() async {
        guard !ProcessInfo.processInfo.arguments.contains("-uitesting") else { return }
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { UIApplication.shared.registerForRemoteNotifications() }
    }
}
