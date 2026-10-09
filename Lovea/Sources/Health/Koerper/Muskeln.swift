import Foundation

/// Muscle groups and parts of the Körper tab. Names as in `design/erholung/erholung.html` (`GRUPPEN`).
enum MuskelGruppe: String, CaseIterable, Sendable {
    case schulter, unterarme, nacken, ruecken, brust, bizeps, trizeps, bauch, beine

    var name: String {
        switch self {
        case .schulter: "Schulter"
        case .unterarme: "Unterarme"
        case .nacken: "Nacken"
        case .ruecken: "Rücken"
        case .brust: "Brust"
        case .bizeps: "Bizeps"
        case .trizeps: "Trizeps"
        case .bauch: "Bauch"
        case .beine: "Beine"
        }
    }

    static let standardPrio: [MuskelGruppe] = [.schulter, .unterarme, .nacken, .ruecken, .brust]
}

enum MuskelTeil: String, CaseIterable, Sendable {
    case sVorne, sSeitlich, sHinten, uSpeiche, uBeuger, uStrecker, nVorne, nHinten,
         rTrapezOben, rTrapezUnten, rOben, rLat, rUnten, bOben, bUnten, biLang, biKurz,
         triLang, triSeitlich, triMittel, baGerade, baSeitlich, beQuads, beAdd, bePo, beBeuger, beWaden

    var gruppe: MuskelGruppe {
        switch self {
        case .sVorne, .sSeitlich, .sHinten: .schulter
        case .uSpeiche, .uBeuger, .uStrecker: .unterarme
        case .nVorne, .nHinten: .nacken
        case .rTrapezOben, .rTrapezUnten, .rOben, .rLat, .rUnten: .ruecken
        case .bOben, .bUnten: .brust
        case .biLang, .biKurz: .bizeps
        case .triLang, .triSeitlich, .triMittel: .trizeps
        case .baGerade, .baSeitlich: .bauch
        case .beQuads, .beAdd, .bePo, .beBeuger, .beWaden: .beine
        }
    }

    var name: String {
        switch self {
        case .sVorne, .nVorne: "vorne"
        case .sSeitlich: "seitlich"
        case .sHinten, .nHinten: "hinten"
        case .uSpeiche: "Oberseite"
        case .uBeuger: "Beuger"
        case .uStrecker: "Strecker"
        case .rTrapezOben: "Trapez oben"
        case .rTrapezUnten: "Trapez Mitte und unten"
        case .rOben: "Oberer Rücken"
        case .rLat: "Latissimus"
        case .rUnten: "Unterer Rücken"
        case .bOben: "oben"
        case .bUnten: "Mitte und unten"
        case .biLang, .triLang: "langer Kopf"
        case .biKurz: "kurzer Kopf"
        case .triSeitlich: "seitlicher Kopf"
        case .triMittel: "mittlerer Kopf"
        case .baGerade: "gerade"
        case .baSeitlich: "schräg"
        case .beQuads: "Quadrizeps"
        case .beAdd: "Adduktoren"
        case .bePo: "Po"
        case .beBeuger: "Beinbeuger"
        case .beWaden: "Waden"
        }
    }

    /// Big parts need twice as long to recover.
    var gross: Bool { [.beQuads, .beBeuger, .bePo, .rLat, .bUnten, .rUnten].contains(self) }
}

enum ErholungsStufe: Sendable { case erholt, fast, muede }

/// Pure muscle logic: catalog exercise to parts, weekly sets, recovery. No state.
enum MuskelLogik {
    private static let standard: [String: MuskelTeil] = [
        "Schultern": .sVorne, "hintere Schulter": .sHinten, "Rotatorenmanschette": .sHinten,
        "Unterarme": .uBeuger, "Griffkraft": .uBeuger, "Handgelenkbeuger": .uBeuger, "Handgelenkstrecker": .uStrecker,
        "Kopfwender": .nVorne, "Schulterblattheber": .nHinten,
        "Trapez": .rTrapezOben, "oberer Rücken": .rOben, "Rautenmuskel": .rOben, "Rücken": .rOben,
        "Latissimus": .rLat, "Rückenstrecker": .rUnten, "unterer Rücken": .rUnten,
        "Brust": .bUnten, "obere Brust": .bOben,
        "Bizeps": .biLang, "Oberarmmuskel": .biLang, "Trizeps": .triSeitlich,
        "Bauch": .baGerade, "Rumpf": .baGerade, "unterer Bauch": .baGerade, "Hüftbeuger": .baGerade,
        "seitlicher Bauch": .baSeitlich, "Sägemuskel": .baSeitlich,
        "Quadrizeps": .beQuads, "Adduktoren": .beAdd, "Leiste": .beAdd, "Oberschenkel innen": .beAdd,
        "Po": .bePo, "Abduktoren": .bePo, "Beinbeuger": .beBeuger,
        "Waden": .beWaden, "Schollenmuskel": .beWaden, "Schienbein": .beWaden,
    ] // ponytail: "Herz-Kreislauf", "Füße", "Hände", "Sprunggelenk(e)", "Handgelenke" fehlen absichtlich

    /// Direct part first (factor 1), then helping muscles (0,5), each part once. Cardio and own
    /// exercises give [].
    static func teile(_ u: Uebung) -> [(teil: MuskelTeil, faktor: Double)] {
        guard !u.istCardio else { return [] }
        var liste: [(teil: MuskelTeil, faktor: Double)] = []
        if let t = direkt(u.muskel, "\(u.name) \(u.en)".lowercased()) { liste.append((t, 1)) }
        for n in u.neben {
            if let t = standard[n], !liste.contains(where: { $0.teil == t }) { liste.append((t, 0.5)) }
        }
        return liste
    }

    /// The muscle's standard part, or a part picked by a word in the (lowercased) name.
    // ponytail: "hinter" der Vorlage ist hier "hintere", sonst wird "Nackendrücken hinter dem Kopf" zur hinteren Schulter.
    private static func direkt(_ muskel: String, _ text: String) -> MuskelTeil? {
        func hat(_ woerter: String...) -> Bool { woerter.contains { text.contains($0) } }
        switch muskel {
        case "Schultern":
            if hat("face pull", "reverse", "hintere", "vorgebeugt") { return .sHinten }
            return hat("seit") ? .sSeitlich : .sVorne
        case "Unterarme":
            if hat("hammer") { return .uSpeiche }
            return hat("reverse", "strecke") ? .uStrecker : .uBeuger
        case "Trapez": return hat("face pull", "rudern") ? .rTrapezUnten : .rTrapezOben
        case "Brust": return hat("schräg", "incline", "oben") ? .bOben : .bUnten
        case "Bizeps": return hat("preacher", "scott", "konzentration") ? .biKurz : .biLang
        case "Trizeps": return hat("über kopf", "überkopf", "overhead", "french") ? .triLang : .triSeitlich
        default: return standard[muskel]
        }
    }

    /// Finished sets per part in one session, neighbours at their factor.
    private static func saetze(_ s: GymSession, _ katalog: (String) -> Uebung?) -> [MuskelTeil: Double] {
        var summe: [MuskelTeil: Double] = [:]
        for lauf in s.laeufe where lauf.fertig {
            guard let u = katalog(lauf.uebung), let n = lauf.saetze?.count, n > 0 else { continue }
            for (teil, faktor) in teile(u) { summe[teil, default: 0] += faktor * Double(n) }
        }
        return summe
    }

    /// Sets per part in the week (Mo to So, `Datum.wochentag`, Berlin) of `datum`. A session counts
    /// by its start. Empty input gives [:].
    static func wochenSaetze(_ sessions: [GymSession], woche datum: String,
                             katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [MuskelTeil: Double] {
        let montag = Datum.montagDerWoche(datum)
        var summe: [MuskelTeil: Double] = [:]
        for s in sessions where Datum.montagDerWoche(Datum.text(s.start)) == montag {
            summe.merge(saetze(s, katalog), uniquingKeysWith: +)
        }
        return summe
    }

    /// One person's week: `TrainingFaltung.sessions(_:)` already separates the people.
    static func wochenSaetze(_ faltung: TrainingFaltung, person: Person, woche datum: String,
                             katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [MuskelTeil: Double] {
        wochenSaetze(faltung.sessions(person), woche: datum, katalog: katalog)
    }

    /// 0...100 per part, from the last session that hit it. Parts without a session are missing
    /// (read them as 100). Big parts need 60 h, small ones 30 h, +8 % per set over 3.
    static func erholung(_ sessions: [GymSession], jetzt: Date,
                         katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> [MuskelTeil: Int] {
        var letzte: [MuskelTeil: (zeit: Date, saetze: Double)] = [:]
        for s in sessions {
            let zeit = s.ende ?? s.start
            for (teil, n) in saetze(s, katalog) where zeit > (letzte[teil]?.zeit ?? .distantPast) { letzte[teil] = (zeit, n) }
        }
        return letzte.reduce(into: [MuskelTeil: Int]()) { ergebnis, eintrag in
            let stunden = max(0, jetzt.timeIntervalSince(eintrag.value.zeit) / 3600)
            let noetig = (eintrag.key.gross ? 60.0 : 30.0) * (1 + 0.08 * max(0, eintrag.value.saetze - 3))
            ergebnis[eintrag.key] = min(100, Int(stunden * 100 / noetig))
        }
    }

    static func stufe(_ prozent: Int) -> ErholungsStufe {
        prozent >= 90 ? .erholt : prozent >= 50 ? .fast : .muede
    }

    /// Weekly set goal: 16 for priority shoulder and back, 12 for other priorities, 8 for the rest.
    static func standardZiel(_ g: MuskelGruppe, prio: Bool) -> Int {
        prio ? (g == .schulter || g == .ruecken ? 16 : 12) : 8
    }
}
