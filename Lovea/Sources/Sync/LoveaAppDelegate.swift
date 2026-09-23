import Intents
import UIKit
import UserNotifications

/// Registers for push, forwards the device token to `Raum`, and reacts to silent pushes.
/// `requestAuthorization` (asking the user for permission) is the app shell's call — this
/// class only wires the plumbing once permission exists.
final class LoveaAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        let namen = ["chat", "snap", "geste", "kalender", "orte", "zeichnen", "spiele"]
        let kategorien = Set(namen.map { UNNotificationCategory(identifier: $0, actions: [], intentIdentifiers: [], options: []) })
        UNUserNotificationCenter.current().setNotificationCategories(kategorien)
        application.registerForRemoteNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Raum.shared.geraetRegistrieren(hex)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    /// Silent push: reconnect (and catch up) even if the app was suspended.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        Raum.shared.start()
        return .newData
    }

    // The system calls UNUserNotificationCenterDelegate off the main thread — nonisolated
    // avoids a MainActor executor mismatch here.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { Raum.shared.start() }
    }

    /// Communication-notification donation so chat messages show the sender's figure image
    /// and name in the notification, per Z-2.5. Called by the chat block after `nachricht.neu`.
    static func spendeNachricht(von: Person, text: String, bild: UIImage?) {
        let handle = INPersonHandle(value: von.rawValue, type: .unknown)
        let avatar = bild?.pngData().map { INImage(imageData: $0) }
        let sender = INPerson(
            personHandle: handle,
            nameComponents: nil,
            displayName: von.name,
            image: avatar,
            contactIdentifier: nil,
            customIdentifier: von.rawValue
        )
        let intent = INSendMessageIntent(
            recipients: nil,
            outgoingMessageType: .outgoingMessageText,
            content: text,
            speakableGroupName: nil,
            conversationIdentifier: "lovea",
            serviceName: nil,
            sender: sender,
            attachments: nil
        )
        let interaction = INInteraction(intent: intent, response: nil)
        interaction.direction = .incoming
        interaction.donate(completion: nil)
    }
}
