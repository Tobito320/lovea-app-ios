import AppIntents

/// Kurzbefehle-Aktion "Schlaf-Signal melden". Einmal in der Kurzbefehle-App unter "Automation" anlegen
/// (Ladegerät verbunden/getrennt, Fokus Schlafen an/aus, Wecker gestoppt, Heim-WLAN verbunden/getrennt).
/// Das iPhone führt die Automation von selbst aus, die App läuft dafür nicht im Hintergrund: kein Akku.
enum SchlafEreignis: String, AppEnum {
    case ladenAn, ladenAus, fokusAn, fokusAus, weckerAus, daheimAn, daheimAus

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Schlaf-Ereignis")
    static let caseDisplayRepresentations: [SchlafEreignis: DisplayRepresentation] = [
        .ladenAn: DisplayRepresentation(title: "Ladegerät verbunden"),
        .ladenAus: DisplayRepresentation(title: "Ladegerät getrennt"),
        .fokusAn: DisplayRepresentation(title: "Fokus Schlafen an"),
        .fokusAus: DisplayRepresentation(title: "Fokus Schlafen aus"),
        .weckerAus: DisplayRepresentation(title: "Wecker gestoppt"),
        .daheimAn: DisplayRepresentation(title: "Heim-WLAN verbunden"),
        .daheimAus: DisplayRepresentation(title: "Heim-WLAN getrennt"),
    ]

    /// Art und Richtung für das Signal-Protokoll (`SchlafSignale`).
    var signal: (art: String, an: Bool) {
        switch self {
        case .ladenAn: ("laden", true)
        case .ladenAus: ("laden", false)
        case .fokusAn: ("fokus", true)
        case .fokusAus: ("fokus", false)
        case .weckerAus: ("wecker", true)
        case .daheimAn: ("daheim", true)
        case .daheimAus: ("daheim", false)
        }
    }
}

struct SchlafSignalIntent: AppIntent {
    static let title: LocalizedStringResource = "Schlaf-Signal melden"
    static let description = IntentDescription("Sagt Lovea, was mit dem Handy passiert ist, damit die Schlaf-Erkennung genauer wird.")
    static let openAppWhenRun = false

    @Parameter(title: "Ereignis")
    var ereignis: SchlafEreignis

    func perform() async throws -> some IntentResult {
        let s = ereignis.signal
        SchlafSignale.aufzeichnen(art: s.art, an: s.an)
        return .result()
    }
}
