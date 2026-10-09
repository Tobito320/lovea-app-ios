import Foundation

/// Unser Zimmer, Welle 2, Worker E: die reine Logik der Erinnerungs-Dinge. Alles auf Tagestexten
/// ("yyyy-MM-dd", Berlin), ohne Uhr und ohne Speicher, damit die Tests fest bleiben. Nichts stirbt,
/// nichts mahnt: fehlende Tage lassen ein Ding nur ruhig stehen.

// MARK: - 3 Pfotenabdruecke

enum PfotenLogik {
    /// Die Dinge, die beide heute angetippt haben, stabil sortiert.
    static func gemeinsam(_ a: Set<String>, _ b: Set<String>) -> [String] {
        a.intersection(b).sorted()
    }

    /// Der Tagesstand einer Person. Ein neuer Tag beginnt leer.
    struct TippTag: Codable, Equatable {
        var tag: String
        var dinge: [String]
    }

    static func merken(_ alt: TippTag?, ding: String, heute: String) -> TippTag {
        guard let alt, alt.tag == heute else { return TippTag(tag: heute, dinge: [ding]) }
        guard !alt.dinge.contains(ding) else { return alt }
        return TippTag(tag: heute, dinge: alt.dinge + [ding])
    }

    static func menge(_ tag: TippTag?, heute: String) -> Set<String> {
        guard let tag, tag.tag == heute else { return [] }
        return Set(tag.dinge)
    }
}

// MARK: - 4 Liebesschloesser

enum LiebesSchloesserLogik {
    struct Schloss: Equatable, Identifiable {
        /// 1 = erster gemeinsamer Monat.
        let nummer: Int
        /// Der eingravierte Tag, "yyyy-MM-dd".
        let tag: String
        var id: Int { nummer }
    }

    /// Mehr hängen nicht am Fenster; die neuesten sieht man, die älteren zählt eine Zahl.
    static let hoechstens = 12

    /// Ein Schloss je vollem gemeinsamen Monat seit `start` (kurze Monate rücken auf ihr Ende).
    static func alle(start: String, heute: String) -> [Schloss] {
        let von = Datum.datum(start)
        var liste: [Schloss] = []
        var n = 1
        while n <= 1200, let d = Datum.kalender.date(byAdding: .month, value: n, to: von) {
            let tag = Datum.text(d)
            guard tag <= heute else { break }
            liste.append(Schloss(nummer: n, tag: tag))
            n += 1
        }
        return liste
    }

    /// Was am Fenster hängt (die neuesten) und wie viele ältere dahinter liegen.
    static func sichtbar(_ alle: [Schloss]) -> (schloesser: [Schloss], aeltere: Int) {
        let teil = Array(alle.suffix(hoechstens))
        return (teil, alle.count - teil.count)
    }

    /// "26.09.2026" aus "2026-09-26".
    static func gravur(_ tag: String) -> String {
        let t = tag.split(separator: "-")
        guard t.count == 3 else { return tag }
        return "\(t[2]).\(t[1]).\(t[0])"
    }
}

// MARK: - 5 Schneekugel

struct SchneekugelKarte: Codable, Equatable {
    var ort: String
    var tag: String
    var text: String

    static func standard(start: String) -> SchneekugelKarte {
        SchneekugelKarte(ort: "Dort, wo wir uns getroffen haben", tag: start, text: "")
    }
}

enum SchneekugelLogik {
    /// Karte nach dem Bearbeiten: leere Felder fallen auf den Standard zurück, Längen sind begrenzt.
    static func bereinigt(_ k: SchneekugelKarte, start: String) -> SchneekugelKarte {
        let std = SchneekugelKarte.standard(start: start)
        let ort = String(k.ort.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        let text = String(k.text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(240))
        return SchneekugelKarte(ort: ort.isEmpty ? std.ort : ort, tag: k.tag.isEmpty ? std.tag : k.tag, text: text)
    }

    /// Wie viele Flocken fallen: nichts in Ruhe, nach Schütteln viele, bei Bewegungsreduzierung wenige.
    static func flocken(geschuettelt: Bool, reduzieren: Bool) -> Int {
        guard geschuettelt else { return 0 }
        return reduzieren ? 6 : 28
    }

    /// Wie lange der Schnee fällt, in Sekunden.
    static let dauer: TimeInterval = 6
}

// MARK: - 7 Balkon-Garten

enum BalkonGartenLogik {
    static let hoechstens = 12

    /// Gemeinsam geschaffte Aufgaben: jeder Tag je Art ("Gemeinsam Woche" / "Gemeinsam Monat") zählt einmal,
    /// auch wenn beide Personen den Eintrag haben.
    static func anzahl(eintraege: [(datum: String, grund: String)]) -> Int {
        Set(eintraege
            .filter { $0.grund == "Gemeinsam Woche" || $0.grund == "Gemeinsam Monat" }
            .map { "\($0.datum)|\($0.grund)" }).count
    }

    struct Blume: Equatable, Identifiable {
        let nummer: Int
        /// 0...1 über die Breite des Kastens.
        let x: Double
        /// 0.45...1, Stängelhöhe.
        let hoehe: Double
        /// Farbindex 0..<4.
        let farbe: Int
        var id: Int { nummer }
    }

    /// Anzahl zu fester Anordnung (gleiche Anzahl, gleiches Bild), gedeckelt auf `hoechstens`.
    static func layout(anzahl: Int) -> [Blume] {
        let n = min(max(anzahl, 0), hoechstens)
        return (0..<n).map { i in
            let x = (Double(i) + 0.5) / Double(hoechstens)
            let hoehe = 0.45 + 0.55 * Double((i * 5) % 7) / 6
            return Blume(nummer: i, x: x, hoehe: hoehe, farbe: (i * 3) % 4)
        }
    }
}

// MARK: - 9 Polaroid-Wand

enum PolaroidWandLogik {
    /// Dauer der Entwicklung von Weiß zum Bild.
    static let entwicklung: TimeInterval = 5

    /// Das Foto der Woche: das neueste aus der Woche von `heute`, sonst das neueste überhaupt.
    static func wahl(_ fotos: [ZimmerPolaroid], heute: String) -> ZimmerPolaroid? {
        let montag = Datum.montagDerWoche(heute)
        let diese = fotos.filter { Datum.montagDerWoche(Datum.text($0.zeit)) == montag }
        return (diese.isEmpty ? fotos : diese).max { $0.zeit < $1.zeit }
    }

    /// 0 = ganz weiß, 1 = fertig. `vergangen` ab dem ersten Sehen.
    static func fortschritt(vergangen: TimeInterval) -> Double {
        guard vergangen > 0 else { return 0 }
        return min(1, vergangen / entwicklung)
    }

    /// Entwickelt wird nur beim ersten Sehen dieses Fotos.
    static func entwickelt(foto: String, gesehen: Set<String>) -> Bool { !gesehen.contains(foto) }
}

// MARK: - 16 Katze waechst

enum KatzenWachstumLogik {
    /// Serien-Tage, ab denen eine Stufe beginnt.
    static let schwellen = [0, 7, 30, 100]
    static let stufenNamen = ["Kätzchen", "Jungkatze", "Katze", "Große Katze"]

    /// Eine Kunst und die Serie, ab der sie dazukommt.
    static let kuenste: [(ab: Int, name: String)] = [
        (3, "Sitz"), (14, "Pfötchen"), (30, "Rolle"), (60, "Purzelbaum"), (100, "Tanzen")
    ]

    static func stufe(serie: Int) -> Int {
        schwellen.lastIndex { serie >= $0 } ?? 0
    }

    static func stufenName(serie: Int) -> String { stufenNamen[stufe(serie: serie)] }

    static func kunststuecke(serie: Int) -> [String] {
        kuenste.filter { serie >= $0.ab }.map(\.name)
    }

    /// Die nächste Kunst und wie viele Tage dahin fehlen; nil, wenn alle da sind.
    static func naechste(serie: Int) -> (name: String, fehlen: Int)? {
        kuenste.first { serie < $0.ab }.map { ($0.name, $0.ab - serie) }
    }

    /// Größe zwischen 0.7 und 1.15.
    static func skala(serie: Int) -> Double {
        [0.7, 0.85, 1.0, 1.15][stufe(serie: serie)]
    }

    /// Die längste Serie der beiden: die Katze verliert nichts, nur weil einer fehlt.
    static func serie(_ serien: [Person: Int]) -> Int { serien.values.max() ?? 0 }

    static let namensGrenze = 16

    static func name(_ roh: String) -> String {
        String(roh.trimmingCharacters(in: .whitespacesAndNewlines).prefix(namensGrenze))
    }
}

// MARK: - 19 Erinnerungs-Kisten

struct ErinnerungsKiste: Codable, Equatable, Identifiable {
    var id: String
    var titel: String
    /// Ab diesem Tag lässt sich die Kiste öffnen.
    var tag: String
    var notiz: String
    var von: String
}

enum ErinnerungsKistenLogik {
    static let hoechstens = 8

    static func gesperrt(_ k: ErinnerungsKiste, heute: String) -> Bool { heute < k.tag }

    static func tageBis(_ k: ErinnerungsKiste, heute: String) -> Int {
        max(0, Datum.tageZwischen(heute, k.tag))
    }

    static func hinzufuegen(_ liste: [ErinnerungsKiste], titel: String, tag: String, notiz: String, von: Person,
                            id: String = UUID().uuidString) -> [ErinnerungsKiste] {
        let t = String(titel.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        guard !t.isEmpty, liste.count < hoechstens, !liste.contains(where: { $0.id == id }) else { return liste }
        let n = String(notiz.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
        return liste + [ErinnerungsKiste(id: id, titel: t, tag: tag, notiz: n, von: von.rawValue)]
    }

    /// Kisten, die offen sind und deren Aufschließen noch nicht gezeigt wurde.
    static func neuOffen(_ liste: [ErinnerungsKiste], gesehen: Set<String>, heute: String) -> [ErinnerungsKiste] {
        liste.filter { !gesperrt($0, heute: heute) && !gesehen.contains($0.id) }
    }

    /// Nach Datum sortiert: bald fällige zuerst.
    static func sortiert(_ liste: [ErinnerungsKiste]) -> [ErinnerungsKiste] {
        liste.sorted { ($0.tag, $0.id) < ($1.tag, $1.id) }
    }
}
