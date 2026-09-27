import Foundation

/// Automatische Schlaferkennung und Schlafziel (Teil 6). Reine Logik, kein HealthKit/CoreMotion, kein
/// `Raum` — `HealthModell` ist der einzige Aufrufer.
///
/// `SchlafLogik` ist schon vergeben (`Figuren/FigurZustand.swift`: die Anwesenheits-Zustandsmaschine
/// aus "Gute Nacht"/Bewegung fürs Partner-Zeichen). Diese Erweiterung nutzt trotzdem denselben Namen,
/// weil die Aufgabe genau den vorgibt — mit `zustand`/`guteNachtSeit`/`partnerZustandAbgelaufen` hat
/// sie nichts zu tun.
extension SchlafLogik {
    // MARK: - Quelle je Nacht

    enum Quelle: String, Sendable, Equatable {
        case eingetragen
        case appleWatch = "Apple Watch"
        case iphoneSchlafenszeit = "iPhone Schlafenszeit"
        case geschaetzt = "geschätzt (Bewegung)"
    }

    // MARK: - a) Eigener Eintrag gewinnt immer (Korrektur)

    /// `eintrag` ist `EnergieLogik.imBett(...)` einer vorhandenen `SchlafZeitenD`, `nil` nur wenn nie
    /// angefasst. 0 (gelöscht: gleiche Bett-/Aufsteh-Zeit) gewinnt auch — sperrt die automatischen
    /// Quellen, statt durchzufallen. Sonst würde ein gelöschter, aber weiter erkannter Automatik-Wert
    /// sofort wieder auftauchen und "Löschen" täte nichts.
    static func minuten(eintrag: Int?, automatik: Int?) -> Int? {
        guard let eintrag else { return automatik }
        return eintrag > 0 ? eintrag : nil
    }

    static func quelle(eintrag: Int?, automatikQuelle: String?) -> String? {
        guard let eintrag else { return automatikQuelle }
        return eintrag > 0 ? Quelle.eingetragen.rawValue : nil
    }

    // MARK: - b/c) Watch vor iPhone-Schlafenszeit

    /// b) Watch (alle asleep-Werte) vor c) iPhone-Schlafenszeit (inBed) vor d) Bewegungs-Schätzung.
    /// Alle drei schon über `HealthLogik.schlafNacht`/`bewegungsSchaetzung` gegen Lücken gerechnet
    /// (Summe der Spannen, nicht Ende minus Anfang) — hier nur noch die Rangfolge plus Quelle-Label.
    static func automatikVorrang(
        watch: (minuten: Int, von: Date, bis: Date)?,
        iphone: (minuten: Int, von: Date, bis: Date)?,
        geschaetzt: (minuten: Int, von: Date, bis: Date)?
    ) -> (minuten: Int, von: Date, bis: Date, quelle: Quelle)? {
        if let w = watch { return (w.minuten, w.von, w.bis, .appleWatch) }
        if let i = iphone { return (i.minuten, i.von, i.bis, .iphoneSchlafenszeit) }
        if let g = geschaetzt { return (g.minuten, g.von, g.bis, .geschaetzt) }
        return nil
    }

    /// c) "Im Bett": exakt dieselbe Zusammenfassung wie für Watch-Werte (`HealthLogik.schlafNacht`) —
    /// Lücken (Handy nachts benutzt) fallen schon dort raus, weil nicht berührende Intervalle als
    /// eigene Spannen bleiben und nur ihre eigene Dauer beitragen, nie Ende-minus-Anfang.
    static func imBettSchaetzung(_ intervalle: [HealthLogik.SchlafIntervall], tag: String) -> (minuten: Int, von: Date, bis: Date)? {
        HealthLogik.schlafNacht(intervalle, tag: tag)
    }

    // MARK: - d) Bewegungs-Schätzung (CoreMotion, wenn a–c nichts liefern)

    enum Konfidenz: Int, Sendable, Comparable {
        case niedrig, mittel, hoch
        static func < (a: Konfidenz, b: Konfidenz) -> Bool { a.rawValue < b.rawValue }
    }

    struct Aktivitaet: Sendable {
        var zeit: Date
        var stationaer: Bool
        var konfidenz: Konfidenz
        init(zeit: Date, stationaer: Bool, konfidenz: Konfidenz) {
            self.zeit = zeit
            self.stationaer = stationaer
            self.konfidenz = konfidenz
        }
    }

    /// Segmente zwischen den Aktivitäts-Zeitpunkten (Ende = nächster Zeitpunkt, beim letzten
    /// `fensterEnde`). Ein ruhiges Segment (stationär, Konfidenz mittel/hoch) zählt immer als Schlaf.
    /// Ein unruhiges Segment zählt nur, wenn es kurz ist (unter 10 min) UND in der Zeit keine Schritte
    /// fielen — ein kurzer Toilettengang MIT Schritten fällt raus (die Minuten zählen nicht), ein
    /// 20-min-Wachliegen auch, weil es allein durch die Länge die 10-Minuten-Schwelle reißt.
    static func ruheIntervalle(_ aktivitaeten: [Aktivitaet], schritte: [HealthLogik.SchlafIntervall], fensterEnde: Date) -> [HealthLogik.SchlafIntervall] {
        let sortiert = aktivitaeten.sorted { $0.zeit < $1.zeit }
        var ergebnis: [HealthLogik.SchlafIntervall] = []
        for i in sortiert.indices {
            let von = sortiert[i].zeit
            let bis = i + 1 < sortiert.count ? sortiert[i + 1].zeit : fensterEnde
            guard bis > von else { continue }
            let ruhig = sortiert[i].stationaer && sortiert[i].konfidenz >= .mittel
            let kurzOhneSchritte = bis.timeIntervalSince(von) < 600 && !schritte.contains { $0.von < bis && $0.bis > von }
            guard ruhig || kurzOhneSchritte else { continue }
            ergebnis.append(HealthLogik.SchlafIntervall(von: von, bis: bis))
        }
        return ergebnis
    }

    /// Eigene Blockbildung wie `HealthLogik.schlafNacht`, aber mit 10 statt 180 Minuten Toleranz:
    /// eine Bewegungsschätzung ist unsicherer als echte Schlafphasen, ein längeres Wachliegen zählt
    /// hier schon als eigener Abschnitt der Nacht. Abschnitte mit höchstens 60 min Wachzeit dazwischen
    /// gehören zur selben Nacht und werden zusammengezählt, die Wachzeit selbst zählt nicht
    /// (Ahmed, 27.09.: 4 Uhr aufwachen, 15 min am Handy, das darf nicht als Schlaf zählen).
    /// Nur Blöcke, die vor 6 Uhr des Aufwach-Tags ANFANGEN, sind Nacht-Kandidaten — sonst würde z. B.
    /// ein Handy, das ab 9 Uhr stundenlang ruhig auf dem Schreibtisch liegt, als (womöglich größerer)
    /// zweiter Teil derselben Nacht durchgehen. Ein früher Kandidat kann trotzdem bis weit nach 6 Uhr
    /// dauern (`bis == tag` reicht dafür).
    static func bewegungsSchaetzung(_ aktivitaeten: [Aktivitaet], schritte: [HealthLogik.SchlafIntervall], fensterEnde: Date, tag: String) -> (minuten: Int, von: Date, bis: Date)? {
        guard !aktivitaeten.isEmpty else { return nil }
        let intervalle = ruheIntervalle(aktivitaeten, schritte: schritte, fensterEnde: fensterEnde).sorted { $0.von < $1.von }
        guard !intervalle.isEmpty else { return nil }
        var bloecke: [[HealthLogik.SchlafIntervall]] = []
        var blockEnde = Date.distantPast
        for intervall in intervalle {
            if bloecke.isEmpty || intervall.von.timeIntervalSince(blockEnde) > 600 {
                bloecke.append([intervall])
            } else {
                bloecke[bloecke.count - 1].append(intervall)
            }
            blockEnde = max(blockEnde, intervall.bis)
        }
        let sechsUhr = Calendar.berlin.date(byAdding: .hour, value: 6, to: Calendar.berlin.startOfDay(for: Datum.datum(tag))) ?? .distantFuture
        let kandidaten = bloecke
            .compactMap { HealthLogik.schlafZusammenfassen($0) }
            .filter { Datum.text($0.bis) == tag && $0.von < sechsUhr }
        guard let haupt = kandidaten.max(by: { $0.minuten < $1.minuten }) else { return nil }
        var von = haupt.von, bis = haupt.bis, minuten = haupt.minuten
        var erweitert = true
        while erweitert {
            erweitert = false
            for k in kandidaten {
                if k.von >= bis && k.von.timeIntervalSince(bis) <= 3600 {
                    bis = k.bis
                    minuten += k.minuten
                    erweitert = true
                } else if k.bis <= von && von.timeIntervalSince(k.bis) <= 3600 {
                    von = k.von
                    minuten += k.minuten
                    erweitert = true
                }
            }
        }
        return (minuten, von, bis)
    }

    // MARK: - Schlafziel mit flexiblen Tagen

    /// Bitmaske wie bei den Food-Zielen (`ErnaehrungsZiele.istExtraTag`): Montag = Bit 0 … Sonntag = Bit 6.
    static func istExtraTag(_ extraTage: Int, _ wochentag: Int) -> Bool { extraTage & (1 << (wochentag - 1)) != 0 }

    /// Ziel-Minuten für einen Wochentag: Basis, an den `extraTage`-Tagen plus `extraMinuten` (nie unter 0).
    static func ziel(basis: Int, extraMinuten: Int, extraTage: Int, wochentag: Int) -> Int {
        istExtraTag(extraTage, wochentag) ? max(0, basis + extraMinuten) : basis
    }
}
