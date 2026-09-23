import Foundation
import Security

/// Storage behind `Schluesselbund`, injectable so tests can use an in-memory stub
/// instead of the real Keychain.
protocol SchluesselbundSpeicher: Sendable {
    func lesen(dienst: String) -> String?
    func schreiben(_ wert: String, dienst: String)
}

/// Real Keychain storage (`Security`, generic password).
struct SicherheitsSpeicher: SchluesselbundSpeicher {
    func lesen(dienst: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func schreiben(_ wert: String, dienst: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: dienst,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = Data(wert.utf8)
        // The app can cold-launch in the background (location/push modes) while the
        // phone is locked, so the value must stay readable after first unlock.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}

/// Get/set of a single String value in the Keychain for the service "lovea.person".
struct Schluesselbund: Sendable {
    private static let dienst = "lovea.person"

    static let shared = Schluesselbund()

    private let speicher: SchluesselbundSpeicher

    init(speicher: SchluesselbundSpeicher = SicherheitsSpeicher()) {
        self.speicher = speicher
    }

    func get() -> String? { speicher.lesen(dienst: Self.dienst) }
    func set(_ wert: String) { speicher.schreiben(wert, dienst: Self.dienst) }
}
