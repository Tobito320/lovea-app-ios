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

    // MARK: - Watch vor Punktesystem

    /// Unter 3 h ist es keine Nacht (Handy kurz aus, am Schreibtisch still, Mittagsschlaf): so ein
    /// Block wird nie als Nachtschlaf gezählt (Ahmed, 05.10.: 40 min um 22 Uhr, Handy war nur aus).
    static let mindestNacht = 180

    /// Die Watch schreibt echte Schlafphasen und gewinnt. Ohne Watch zählt das Punktesystem (`SchlafPunkte.swift`).
    static func automatikVorrang(
        watch: (minuten: Int, von: Date, bis: Date)?,
        punkte: PunkteErgebnis?
    ) -> (minuten: Int, von: Date, bis: Date, quelle: String)? {
        if let w = watch { return (w.minuten, w.von, w.bis, Quelle.appleWatch.rawValue) }
        guard let punkte, let n = punkte.nacht else { return nil }
        return (n.minuten, n.von, n.bis, punkte.quelle)
    }

    // MARK: - Bewegung (CoreMotion)

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

    // MARK: - Schlafziel mit flexiblen Tagen

    /// Bitmaske wie bei den Food-Zielen (`ErnaehrungsZiele.istExtraTag`): Montag = Bit 0 … Sonntag = Bit 6.
    static func istExtraTag(_ extraTage: Int, _ wochentag: Int) -> Bool { extraTage & (1 << (wochentag - 1)) != 0 }

    /// Ziel-Minuten für einen Wochentag: Basis, an den `extraTage`-Tagen plus `extraMinuten` (nie unter 0).
    static func ziel(basis: Int, extraMinuten: Int, extraTage: Int, wochentag: Int) -> Int {
        istExtraTag(extraTage, wochentag) ? max(0, basis + extraMinuten) : basis
    }
}
