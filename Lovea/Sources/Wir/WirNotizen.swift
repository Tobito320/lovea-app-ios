import Foundation
import Observation

/// Eine geteilte Notiz von Ahmed und Annika. Ganzes Objekt je Op `wir.notiz`, last-writer-wins nach
/// `geaendert`. Löschen ist nur das Flag `geloescht` (wie bei `DateIdee`).
struct WirNotiz: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var text: String
    var geloescht: Bool
    var geaendert: Date
    var von: Person

    init(id: String, text: String, geloescht: Bool = false, geaendert: Date, von: Person) {
        self.id = id
        self.text = text
        self.geloescht = geloescht
        self.geaendert = geaendert
        self.von = von
    }
}

enum WirNotizLogik {
    static let art = "wir.notiz"

    /// Die neuere Fassung gewinnt, bei gleichem Zeitstempel die später angewendete.
    static func zusammenfuehren(_ notizen: inout [String: WirNotiz], _ neu: WirNotiz) {
        if let alt = notizen[neu.id], alt.geaendert > neu.geaendert { return }
        notizen[neu.id] = neu
    }

    static func anwenden(_ ops: [Op], auf start: [String: WirNotiz] = [:]) -> [String: WirNotiz] {
        var z = start
        for op in ops where op.art == art {
            if let notiz = op.daten(WirNotiz.self) { zusammenfuehren(&z, notiz) }
        }
        return z
    }

    /// Ohne gelöschte, neueste zuerst.
    static func sichtbar(_ notizen: [String: WirNotiz]) -> [WirNotiz] {
        notizen.values.filter { !$0.geloescht }.sorted { a, b in
            a.geaendert != b.geaendert ? a.geaendert > b.geaendert : a.id < b.id
        }
    }

    /// Der Zeitstempel liegt immer hinter dem alten, auch wenn die Uhr zurückgeht.
    static func geaendert(_ notiz: WirNotiz, von: Person, jetzt: Date, _ aenderung: (inout WirNotiz) -> Void) -> WirNotiz {
        var neu = notiz
        aenderung(&neu)
        neu.geaendert = max(jetzt, notiz.geaendert.addingTimeInterval(0.001))
        neu.von = von
        return neu
    }
}

/// Stand der geteilten Notizen. Gespeichert wird im Op-Log, `Raum.beobachtenStapel` spielt beim Start alles ein.
@MainActor @Observable
final class WirNotizSpeicher {
    static let shared = WirNotizSpeicher()

    private(set) var stand: [String: WirNotiz] = [:]
    var notizen: [WirNotiz] { WirNotizLogik.sichtbar(stand) }

    @ObservationIgnored private let wer: () -> Person?
    @ObservationIgnored private let senden: (Op) -> Void
    @ObservationIgnored private let jetzt: () -> Date

    init(ich: @escaping () -> Person?, senden: @escaping (Op) -> Void, jetzt: @escaping () -> Date = Date.init) {
        self.wer = ich
        self.senden = senden
        self.jetzt = jetzt
    }

    private convenience init() {
        self.init(ich: { Raum.shared.ich }, senden: { Raum.shared.einreihen($0) })
        Raum.shared.beobachtenStapel([WirNotizLogik.art]) { [weak self] ops in self?.einarbeiten(ops) }
    }

    func einarbeiten(_ ops: [Op]) { stand = WirNotizLogik.anwenden(ops, auf: stand) }

    /// Neue Notiz. Leerer Text: nil.
    @discardableResult
    func anlegen(_ text: String) -> WirNotiz? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty, let ich = wer() else { return nil }
        let notiz = WirNotiz(id: "notiz-" + UUID().uuidString, text: t, geaendert: jetzt(), von: ich)
        uebernehmen(notiz)
        return notiz
    }

    func aendern(_ id: String, text: String) {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let alt = stand[id], !t.isEmpty, t != alt.text, let ich = wer() else { return }
        uebernehmen(WirNotizLogik.geaendert(alt, von: ich, jetzt: jetzt()) { $0.text = t })
    }

    func loeschen(_ id: String) {
        guard let alt = stand[id], !alt.geloescht, let ich = wer() else { return }
        uebernehmen(WirNotizLogik.geaendert(alt, von: ich, jetzt: jetzt()) { $0.geloescht = true })
    }

    private func uebernehmen(_ notiz: WirNotiz) {
        guard let ich = wer() else { return }
        WirNotizLogik.zusammenfuehren(&stand, notiz)
        senden(Op.neu(WirNotizLogik.art, notiz, von: ich))
    }
}
