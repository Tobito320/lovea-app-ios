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
        // I-7: HealthKit observers + background delivery must exist on EVERY launch, including a
        // background relaunch that never connects a scene. Keychain item is AfterFirstUnlock, so it
        // is readable in a locked background launch too.
        if let person = Schluesselbund.shared.get().flatMap(Person.init(rawValue:)) {
            AppStart.falten(person)
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        Raum.shared.geraetRegistrieren(hex)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}

    /// Silent push: connect and wait for a real catch-up (not just fire `start()` and return
    /// immediately — iOS can suspend the app again before anything was actually fetched).
    /// `userInfo["art"] == "karte.offen"` starts live location via `Raum.shared.onKarteOffen`,
    /// which the Karte/Orte block sets — the exact payload keys (`art`/`an`) aren't confirmed
    /// against a server push yet, see the note on `Raum.onKarteOffen`.
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        if let art = userInfo["art"] as? String, art == "karte.offen" {
            let an = (userInfo["an"] as? Bool) ?? true
            Raum.shared.onKarteOffen?(an)
        }
        await Raum.shared.nachholenBisFertig()
        return .newData
    }

    // The system calls UNUserNotificationCenterDelegate off the main thread — nonisolated
    // avoids a MainActor executor mismatch here.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    // Completion-handler form, completed on the main thread: the async variant hands the
    // system's completion back on a background executor, which crashed on tapping a notification.
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let fertig = AbschlussBox(completionHandler)
        DispatchQueue.main.async {
            MainActor.assumeIsolated { Raum.shared.start() }
            fertig.aufrufen()
        }
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

/// The notification completion handler isn't `Sendable`; it is only ever called once, on main.
private struct AbschlussBox: @unchecked Sendable {
    let aufrufen: () -> Void
    init(_ f: @escaping () -> Void) { aufrufen = f }
}
