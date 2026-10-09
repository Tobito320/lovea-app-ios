import Foundation

enum ZyklusSpeicherWahl {
    @MainActor private static var geteilt: EchterZyklusSpeicher?

    /// Beide Geräte nutzen den echten Speicher (einmal angelegt). Auf Annikas Gerät schreibt er,
    /// auf Ahmeds Gerät ist er nur lesbar (`nurLesen`): Ahmed sieht Annikas Zyklus.
    @MainActor
    static func fuer(person: Person) -> any ZyklusSpeicher {
        if let s = geteilt { return s }
        let s = EchterZyklusSpeicher.standard()
        geteilt = s
        return s
    }
}
