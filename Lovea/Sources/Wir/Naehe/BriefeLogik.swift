import Foundation
import Observation

/// Ein "Öffne, wenn ..."-Brief. Absender ist `von`, Empfängerin ist `von.partner`.
struct Brief: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var titel: String
    var text: String
    /// Optionale Sprachaufnahme (Medien-ID) mit Länge und Pegel für die Wellenform.
    var sprache: String?
    var dauer: Double?
    var pegel: [Float]?
    var von: Person
    var zeit: Date
}

/// `brief.geoeffnet`: kommt von der Empfängerin. Die erste Öffnung zählt.
struct BriefGeoeffnetD: Codable, Hashable, Sendable { var id: String }

struct BriefeStand: Sendable, Equatable {
    var briefe: [String: Brief] = [:]
    var geoeffnet: [String: Date] = [:]
}

enum BriefeLogik {
    static let artNeu = "brief.neu"
    static let artGeoeffnet = "brief.geoeffnet"
    static let arten: Set<String> = [artNeu, artGeoeffnet]

    /// Vorschläge für den Titel. Der eigene Titel wird mit "Öffne, wenn ..." davor gebaut.
    static let vorschlaege = [
        "du Angst hast, dass ich dich nicht mehr will",
        "du mich vermisst",
        "du nicht schlafen kannst",
        "du traurig bist",
        "du stolz auf dich sein solltest",
    ]

    /// "Öffne, wenn ..." genau einmal vorne, egal ob der Nutzer es schon getippt hat.
    static func titel(fuer eingabe: String) -> String? {
        var t = eingabe.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return nil }
        for praefix in ["Öffne, wenn", "Öffne wenn", "öffne, wenn", "öffne wenn"] where t.hasPrefix(praefix) {
            t = String(t.dropFirst(praefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }
        guard !t.isEmpty else { return nil }
        return "Öffne, wenn \(t)"
    }

    /// Reine Faltung: reihenfolgeunabhängig und idempotent (doppelte Ops schaden nicht).
    static func anwenden(_ ops: [Op], auf start: BriefeStand = BriefeStand()) -> BriefeStand {
        var z = start
        for op in ops {
            switch op.art {
            case artNeu:
                guard let b = op.daten(BriefNeuD.self) else { continue }
                z.briefe[b.id] = Brief(id: b.id, titel: b.titel, text: b.text, sprache: b.sprache, dauer: b.dauer, pegel: b.pegel, von: op.von, zeit: op.zeit)
            case artGeoeffnet:
                // Kommt von der Empfängerin (`oeffnen` sendet nur dort). Die früheste Öffnung zählt.
                guard let d = op.daten(BriefGeoeffnetD.self) else { continue }
                z.geoeffnet[d.id] = min(z.geoeffnet[d.id] ?? op.zeit, op.zeit)
            default:
                break
            }
        }
        return z
    }

    /// Wann die Empfängerin den Brief geöffnet hat, sonst nil.
    static func geoeffnetAm(_ brief: Brief, _ stand: BriefeStand) -> Date? { stand.geoeffnet[brief.id] }

    /// Für mich: an mich gerichtet, ungeöffnete zuerst, dann neueste zuerst.
    static func erhalten(_ stand: BriefeStand, ich: Person) -> [Brief] {
        stand.briefe.values.filter { $0.von != ich }.sorted { a, b in
            let ua = stand.geoeffnet[a.id] == nil, ub = stand.geoeffnet[b.id] == nil
            if ua != ub { return ua }
            return a.zeit != b.zeit ? a.zeit > b.zeit : a.id < b.id
        }
    }

    static func geschrieben(_ stand: BriefeStand, ich: Person) -> [Brief] {
        stand.briefe.values.filter { $0.von == ich }.sorted { a, b in
            a.zeit != b.zeit ? a.zeit > b.zeit : a.id < b.id
        }
    }

    static func ungeoeffnet(_ stand: BriefeStand, ich: Person) -> Int {
        stand.briefe.values.filter { $0.von != ich && stand.geoeffnet[$0.id] == nil }.count
    }
}

private struct BriefNeuD: Codable {
    var id: String
    var titel: String
    var text: String
    var sprache: String?
    var dauer: Double?
    var pegel: [Float]?
}

/// Stand der Briefe. Gespeichert wird im Op-Log, `Raum.beobachtenStapel` spielt beim Start alles ein.
@MainActor @Observable
final class BriefeSpeicher {
    static let shared = BriefeSpeicher()

    private(set) var stand = BriefeStand()

    @ObservationIgnored private let wer: () -> Person?
    @ObservationIgnored private let senden: (Op) -> Void

    init(ich: @escaping () -> Person?, senden: @escaping (Op) -> Void) {
        self.wer = ich
        self.senden = senden
    }

    private convenience init() {
        self.init(ich: { Raum.shared.ich }, senden: { Raum.shared.einreihen($0) })
        Raum.shared.beobachtenStapel(BriefeLogik.arten) { [weak self] ops in self?.einarbeiten(ops) }
    }

    func einarbeiten(_ ops: [Op]) { stand = BriefeLogik.anwenden(ops, auf: stand) }

    var ich: Person? { wer() }
    var erhalten: [Brief] { wer().map { BriefeLogik.erhalten(stand, ich: $0) } ?? [] }
    var geschrieben: [Brief] { wer().map { BriefeLogik.geschrieben(stand, ich: $0) } ?? [] }
    var ungeoeffnet: Int { wer().map { BriefeLogik.ungeoeffnet(stand, ich: $0) } ?? 0 }

    /// Neuer Brief. Leerer Titel oder Text (ohne Sprache): nil. `frei`: der Titel steht so da, ohne "Öffne, wenn" (Liebesbrief im Zimmer).
    @discardableResult
    func schreiben(titel: String, text: String, sprache: String? = nil, dauer: Double? = nil, pegel: [Float]? = nil, frei: Bool = false) -> Brief? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let name: String? = frei ? titel.trimmingCharacters(in: .whitespacesAndNewlines) : BriefeLogik.titel(fuer: titel)
        guard let titel = name, !titel.isEmpty, !t.isEmpty || sprache != nil, let ich = wer() else { return nil }
        let op = Op.neu(BriefeLogik.artNeu, BriefNeuD(id: "brief-" + UUID().uuidString, titel: titel, text: t, sprache: sprache, dauer: dauer, pegel: pegel), von: ich)
        stand = BriefeLogik.anwenden([op], auf: stand)
        senden(op)
        return stand.briefe[op.daten(BriefNeuD.self)?.id ?? ""]
    }

    /// Die Empfängerin öffnet den Umschlag. Mehrfach öffnen sendet nichts mehr.
    func oeffnen(_ brief: Brief) {
        guard let ich = wer(), brief.von != ich, stand.geoeffnet[brief.id] == nil else { return }
        let op = Op.neu(BriefeLogik.artGeoeffnet, BriefGeoeffnetD(id: brief.id), von: ich)
        stand = BriefeLogik.anwenden([op], auf: stand)
        senden(op)
    }
}
