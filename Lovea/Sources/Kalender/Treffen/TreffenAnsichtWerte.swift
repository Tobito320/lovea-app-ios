import Foundation

// Treffen mit Ablauf, Teil 2: Texte und Entscheidungen der Lese- und Bearbeiten-Ansicht als reine
// Funktionen. Kein `Raum`, kein UI.

enum TreffenAnsichtWerte {
    /// „10 Std.", „2 Std. 30 Min.", „45 Min."; nil ohne beide Zeiten oder wenn `bis` nicht nach `von` liegt.
    nonisolated static func dauerText(von: String?, bis: String?) -> String? {
        guard let v = Datum.minuten(von), let b = Datum.minuten(bis), b > v else { return nil }
        let m = b - v
        if m < 60 { return "\(m) Min." }
        return m % 60 == 0 ? "\(m / 60) Std." : "\(m / 60) Std. \(m % 60) Min."
    }

    /// Zeile unter dem Titel: „12:00 bis 22:00", „ab 12:00", „bis 22:00".
    nonisolated static func zeitKopf(von: String?, bis: String?) -> String? {
        switch (von, bis) {
        case let (v?, b?): "\(v) bis \(b)"
        case let (v?, nil): "ab \(v)"
        case let (nil, b?): "bis \(b)"
        case (nil, nil): nil
        }
    }

    /// Zeitspalte eines Punkts: oben der Beginn, darunter „bis 14:00".
    nonisolated static func zeitSpalte(start: String?, ende: String?) -> (oben: String, unten: String?) {
        (start ?? "–", ende.map { "bis \($0)" })
    }

    /// Ende für „Zum iPhone-Kalender": `bis`, sonst wie bisher zwei Stunden nach dem Beginn.
    nonisolated static func exportEnde(start: Date, bis: Date?) -> Date {
        if let bis, bis > start { return bis }
        return start.addingTimeInterval(2 * 60 * 60)
    }

    /// „Sa 3. Okt." für die Datum-Pille.
    nonisolated static func kurzDatum(_ tag: String) -> String {
        let wochentage = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
        let monate = ["Jan.", "Feb.", "März", "Apr.", "Mai", "Juni", "Juli", "Aug.", "Sept.", "Okt.", "Nov.", "Dez."]
        let teile = Datum.kalender.dateComponents([.day, .month], from: Datum.datum(tag))
        return "\(wochentage[Datum.wochentag(tag) - 1]) \(teile.day ?? 1). \(monate[(teile.month ?? 1) - 1])"
    }

    /// Text im versteckten Block beim Partner. Kein Inhalt, nur die Zeit.
    nonisolated static func verstecktText(ab: Date, gleich: Bool, jetzt: Date) -> String {
        gleich ? "Überraschung, gleich sichtbar" : "Überraschung, sichtbar ab \(TreffenLogik.freigabeText(ab: ab, jetzt: jetzt))"
    }

    /// Hinweis beim Ersteller unter seinem eigenen versteckten Punkt.
    nonisolated static func erstellerHinweis(fuer: Person, ab: Date, jetzt: Date) -> String {
        ab <= jetzt ? "Für \(fuer.name) gleich sichtbar" : "Für \(fuer.name) versteckt bis \(TreffenLogik.freigabeText(ab: ab, jetzt: jetzt))"
    }

    /// Zeile im Editor: ab wann die andere Person den Punkt sieht.
    nonisolated static func sichtbarZeile(_ wahl: FreigabeWahl, datum: String, start: String?, fuer: Person, jetzt: Date) -> String {
        let ab = TreffenLogik.freigabeZeit(wahl, datum: datum, start: start)
        return ab <= jetzt
            ? "\(fuer.name) sieht ihn sofort"
            : "\(fuer.name) sieht ihn ab \(TreffenLogik.freigabeText(ab: ab, jetzt: jetzt))"
    }
}

/// Die vier Wahlen im Editor. „Ein paar Stunden vorher" nimmt noch 1, 2, 3 oder 6 Stunden.
enum FreigabeAuswahl: CaseIterable, Hashable {
    case dreiTage, einTag, amTag, stunden

    static let stundenWahl = [1, 2, 3, 6]

    var titel: String {
        switch self {
        case .dreiTage: "3 Tage vorher"
        case .einTag: "1 Tag vorher"
        case .amTag: "Am selben Tag"
        case .stunden: "Ein paar Stunden vorher"
        }
    }

    nonisolated static func von(_ w: FreigabeWahl) -> FreigabeAuswahl {
        switch w.art {
        case .tage: w.n == 1 ? .einTag : .dreiTage
        case .amTag: .amTag
        case .stunden: .stunden
        }
    }

    nonisolated func wahl(stunden: Int) -> FreigabeWahl {
        switch self {
        case .dreiTage: FreigabeWahl(art: .tage, n: 3)
        case .einTag: FreigabeWahl(art: .tage, n: 1)
        case .amTag: FreigabeWahl(art: .amTag, n: 0)
        case .stunden: FreigabeWahl(art: .stunden, n: stunden)
        }
    }
}

/// Ein Punkt im Bearbeiten-Modus. `gesperrt`: Überraschung des Partners oder Inhalt, der hier fehlt,
/// bleibt eine Zeile ohne Editor.
struct PunktBearbeitung: Equatable, Identifiable {
    var id: String
    var start: String?
    var ende: String?
    var titel = ""
    var notiz = ""
    var ort: PunktOrt?
    var ueberraschung: FreigabeWahl?
    /// Schon öffentlich: nie wieder verstecken.
    var schonSichtbar = false
    var gesperrt = false
    var neu = false

    nonisolated init(neuAm start: String?) {
        id = UUID().uuidString
        self.start = start
        neu = true
    }

    /// `geheim` liefert bei eigenen versteckten Punkten die Wahl des Erstellers.
    nonisolated init(_ p: TreffenPunkt, ansicht: PunktAnsicht, geheim: GeheimPunkt?) {
        id = p.id
        start = p.start
        ende = p.ende
        titel = p.titel ?? ""
        notiz = p.notiz ?? ""
        ort = p.ort
        schonSichtbar = !p.versteckt
        if case .voll = ansicht {
            ueberraschung = p.versteckt ? (geheim?.freigabe ?? FreigabeAuswahl.amTag.wahl(stunden: 3)) : nil
        } else {
            gesperrt = true
        }
    }

    var gueltig: Bool { !titel.trimmingCharacters(in: .whitespaces).isEmpty }

    nonisolated func entwurf(datum: String) -> PunktEntwurf {
        PunktEntwurf(
            id: id, datum: datum, start: start, ende: ende, titel: titel.trimmingCharacters(in: .whitespaces),
            notiz: notiz.trimmingCharacters(in: .whitespacesAndNewlines), ort: ort, ueberraschung: schonSichtbar ? nil : ueberraschung
        )
    }
}

/// Der Treffen-Kopf im Bearbeiten-Modus: Titel und von/bis.
struct TreffenBearbeitung: Equatable {
    var titel: String
    var von: String?
    var bis: String?

    /// Die `treffen.setzen`-Op, falls sich etwas gegenüber `basis` geändert hat. Ein leerer Titel legt
    /// nichts an. `""` nimmt eine gesetzte Zeit zurück, nil ließe sie stehen.
    nonisolated func op(datum: String, seit basis: TreffenBearbeitung) -> TreffenD? {
        let text = titel.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, self != basis else { return nil }
        return TreffenD(
            datum: datum, uhrzeit: von ?? (basis.von == nil ? nil : ""), wasMachenWir: text,
            bis: bis ?? (basis.bis == nil ? nil : "")
        )
    }
}

enum PunktAenderung {
    /// Was „Fertig" sendet: neue und geänderte gültige Punkte, dazu die entfernten Ids. Gesperrte
    /// Zeilen bleiben unberührt.
    nonisolated static func berechnen(ursprung: [PunktBearbeitung], jetzt: [PunktBearbeitung]) -> (speichern: [PunktBearbeitung], loeschen: [String]) {
        let vorher = Dictionary(ursprung.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let speichern = jetzt.filter { !$0.gesperrt && $0.gueltig && vorher[$0.id] != $0 }
        let bleibt = Set(jetzt.map(\.id))
        let loeschen = ursprung.filter { !$0.gesperrt && !bleibt.contains($0.id) }.map(\.id)
        return (speichern, loeschen)
    }
}
