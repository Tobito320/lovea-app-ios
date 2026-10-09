import AppIntents

/// Der Knopf in der Gym-Live-Aktivität (Sperrbildschirm, Dynamic Island): "Satz starten" oder
/// "Satz fertig", ohne die App zu öffnen. Ein `LiveActivityIntent` läuft im Prozess der App, nicht
/// im Widget. Deshalb steht die Arbeit nicht hier, sondern hinter `ausfuehren`, das die App beim
/// Start setzt (`LoveaAppDelegate`). Im Widget-Prozess bleibt es nil.
struct GymSchrittIntent: LiveActivityIntent {
    static var title: LocalizedStringResource { "Nächster Schritt im Training" }

    @MainActor static var ausfuehren: (@MainActor () async -> Void)?

    func perform() async throws -> some IntentResult {
        let schritt = await MainActor.run { Self.ausfuehren }
        await schritt?()
        return .result()
    }
}
