import Foundation

// Health-Coach, Ebene 1: reine Regeln ohne KI und ohne Netz. Aus den eigenen Zahlen der Person wird eine kurze
// Liste `CoachKarte`. Dazu die reine Verlaufs-Logik für den Chat. Nichts hier liest Modelle oder die Uhr, alles
// kommt über `CoachEingabe`. Der Lader dazu steht in `CoachModell.swift`.
//
// Leitplanken (Plan "Lovea – Health-Coach"): nie ein Kalorien-Defizit empfehlen, nie unter die Untergrenze,
// Lücken im Essens-Log nie als echte Aufnahme behandeln, keine Streaks, ruhiger Ton, kein Lob und kein Alarm
// beim Gewicht.

// MARK: - Karten

struct CoachKarte: Equatable, Identifiable, Sendable {
    enum Art: String, Sendable { case sicherheit, essenLog, training, steigerung, protein, schritte, gewicht }

    let art: Art
    let titel: String
    let text: String
    var id: String { art.rawValue }
}

/// Eine Muskelgruppe der Woche: gemachte Sätze (Mitarbeit zählt halb) gegen das Satzziel.
struct CoachGruppe: Equatable, Sendable {
    let name: String
    let saetze: Double
    let ziel: Int
    /// Aus `KoerperLogik.faellig` (unter der Hälfte des Wochenziels), damit die Regel nur einmal existiert.
    let faellig: Bool
}

/// Eine zuletzt trainierte Übung samt Vorschlag aus `KoerperLogik.naechstesMal` (doppelte Progression).
struct CoachUebung: Equatable, Sendable {
    let name: String
    let vorschlag: KoerperLogik.Vorschlag
}

struct CoachEingabe: Equatable, Sendable {
    /// "YYYY-MM-DD". Heute zählt in keinem Schnitt mit, der Tag ist noch nicht vorbei.
    var heute: String
    /// 0 = Mann, 1 = Frau (`ErnaehrungsZiele.geschlecht`).
    var geschlecht = 0
    /// Nur dann ist das Proteinziel ein echtes Ziel und kein Schätzwert aus dem Gewicht.
    var zieleEingerichtet = false
    var proteinZiel = 0
    /// Summe je Tag, nur Tage mit Einträgen.
    var essenKcal: [String: Double] = [:]
    var essenProtein: [String: Double] = [:]
    /// Zehntel kg je Tag (`Habit.gewicht`).
    var gewicht: [String: Int] = [:]
    var schritte: [String: Int] = [:]
    var schrittZiel = 0
    var gruppen: [CoachGruppe] = []
    /// Neueste zuerst.
    var uebungen: [CoachUebung] = []
}

/// Was das Essens-Log der letzten 14 Tage hergibt. Nur Tage mit echtem Essen zählen als geloggt.
struct CoachEssenStand: Equatable, Sendable {
    let geloggteTage: Int
    let kcalSchnitt: Double?
    let proteinSchnitt: Double?
    /// Weniger als 10 von 14 Tagen: der Schnitt ist keine echte Aufnahme.
    let lueckig: Bool
    /// Schnitt unter der Untergrenze, aber nur bei brauchbarem Log: wer selten trackt, hat keine Aufnahme, die man bewerten könnte.
    let sehrWenig: Bool
}

enum CoachRegeln {
    static let untergrenzeFrau = 1200
    static let untergrenzeMann = 1500
    static let fensterTage = 14
    static let mindestTageImLog = 10
    /// Ein Tag mit nur Kaffee (Koffein-Kachel schreibt einen Tagebuch-Eintrag, rund 4 kcal) ist kein geloggter Tag.
    static let mindestKcalProLogTag = 200.0

    static let schnellfragen = ["Tagesbericht", "Wie läuft mein Training?", "Was soll ich heute essen?"]

    /// Dieselbe Grenze wie in `ErnaehrungLogik.kalorienziel` (dort ein lokales `let minimum`, Ernaehrung.swift).
    static func untergrenze(geschlecht: Int) -> Int { geschlecht == 1 ? untergrenzeFrau : untergrenzeMann }

    /// "YYYY-MM-DD". `Datum.datum` stürzt bei allem anderen ab, deshalb prüft die Karte Schlüssel von außen vorher.
    static func istTag(_ text: String) -> Bool {
        let zeichen = Array(text)
        guard zeichen.count == 10 else { return false }
        return zeichen.enumerated().allSatisfy { stelle, c in
            stelle == 4 || stelle == 7 ? c == "-" : (c.isASCII && c.isNumber)
        }
    }

    // MARK: Essen

    static func essenStand(_ e: CoachEingabe) -> CoachEssenStand {
        let tage = (1...fensterTage).map { Datum.addTage(e.heute, -$0) }.filter { (e.essenKcal[$0] ?? 0) >= mindestKcalProLogTag }
        guard !tage.isEmpty else {
            return CoachEssenStand(geloggteTage: 0, kcalSchnitt: nil, proteinSchnitt: nil, lueckig: true, sehrWenig: false)
        }
        let n = Double(tage.count)
        let kcal = tage.reduce(0.0) { $0 + (e.essenKcal[$1] ?? 0) } / n
        let protein = tage.reduce(0.0) { $0 + (e.essenProtein[$1] ?? 0) } / n
        return CoachEssenStand(
            geloggteTage: tage.count, kcalSchnitt: kcal, proteinSchnitt: protein,
            lueckig: tage.count < mindestTageImLog,
            sehrWenig: tage.count >= mindestTageImLog && kcal < Double(untergrenze(geschlecht: e.geschlecht)))
    }

    // MARK: Karten

    /// Reihenfolge = Wichtigkeit. Leer, wenn nichts zu sagen ist.
    static func karten(_ e: CoachEingabe) -> [CoachKarte] {
        let essen = essenStand(e)
        var liste: [CoachKarte] = []
        if essen.sehrWenig, let kcal = essen.kcalSchnitt {
            liste.append(sicherheitsKarte(kcal: kcal, geschlecht: e.geschlecht))
        } else if essen.geloggteTage > 0 && essen.lueckig {
            liste.append(essenLogKarte(essen))
        }
        if let k = trainingKarte(e) { liste.append(k) }
        if let k = steigerungsKarte(e) { liste.append(k) }
        if !essen.sehrWenig && !essen.lueckig, let k = proteinKarte(e, essen) { liste.append(k) }
        if let k = schritteKarte(e) { liste.append(k) }
        if !essen.sehrWenig, let k = gewichtKarte(e) { liste.append(k) }
        return liste
    }

    private static func sicherheitsKarte(kcal: Double, geschlecht: Int) -> CoachKarte {
        let schnitt = HealthText.zahl(Int(kcal.rounded()))
        let grenze = HealthText.zahl(untergrenze(geschlecht: geschlecht))
        return CoachKarte(
            art: .sicherheit, titel: "Essen im Log",
            text: "Im Log liegst du im Schnitt bei etwa \(schnitt) kcal am Tag, unter \(grenze). Vielleicht fehlt nur Essen im Log. "
                + "Wenn du wirklich so wenig isst: bitte nicht weiter kürzen. Sprich dann mit einer Ärztin, einem Arzt oder einer Beratungsstelle. "
                + "Du musst das nicht allein klären.")
    }

    private static func essenLogKarte(_ essen: CoachEssenStand) -> CoachKarte {
        CoachKarte(
            art: .essenLog, titel: "Essens-Log",
            text: "Im Log sind \(essen.geloggteTage) von \(fensterTage) Tagen. Was fehlt, rechne ich nicht als echte Aufnahme. Du musst nichts nachtragen.")
    }

    /// Erst ab Donnerstag, vorher steht am Wochenanfang fast jede Gruppe unter der Hälfte.
    private static func trainingKarte(_ e: CoachEingabe) -> CoachKarte? {
        guard Datum.wochentag(e.heute) >= 4 else { return nil }
        let offen = e.gruppen.filter { $0.faellig && $0.ziel > 0 }.prefix(2)
        guard !offen.isEmpty else { return nil }
        let zeilen = offen.map { "\($0.name) \(TrainingLogik.kgText($0.saetze)) von \($0.ziel) Sätzen" }.joined(separator: ", ")
        return CoachKarte(art: .training, titel: "Wochensätze", text: "Diese Woche bisher: \(zeilen). Bis Sonntag ist noch Zeit.")
    }

    /// Die Übungen, bei denen die Steigerungsregel Mehrgewicht sagt, zuerst; höchstens zwei Zeilen.
    private static func steigerungsKarte(_ e: CoachEingabe) -> CoachKarte? {
        let bereit = e.uebungen.filter(\.vorschlag.mehrGewicht)
        let rest = e.uebungen.filter { !$0.vorschlag.mehrGewicht }
        let auswahl = (bereit + rest).prefix(2)
        guard !auswahl.isEmpty else { return nil }
        let text = auswahl.map { "\($0.name): \(KoerperLogik.vorschlagText($0.vorschlag))" }.joined(separator: "\n")
        return CoachKarte(art: .steigerung, titel: "Nächstes Mal", text: text)
    }

    private static func proteinKarte(_ e: CoachEingabe, _ essen: CoachEssenStand) -> CoachKarte? {
        guard e.zieleEingerichtet, e.proteinZiel > 0, let schnitt = essen.proteinSchnitt,
              schnitt < Double(e.proteinZiel) * 0.85 else { return nil }
        return CoachKarte(
            art: .protein, titel: "Protein",
            text: "Im Log liegst du bei etwa \(HealthText.zahl(Int(schnitt.rounded()))) g Protein am Tag, dein Ziel ist \(e.proteinZiel) g. "
                + "Eine proteinreiche Mahlzeit mehr, zum Beispiel Quark, Skyr oder Eier, schließt die Lücke.")
    }

    private static func schritteKarte(_ e: CoachEingabe) -> CoachKarte? {
        guard e.schrittZiel > 0 else { return nil }
        let werte = (1...7).compactMap { e.schritte[Datum.addTage(e.heute, -$0)] }.filter { $0 > 0 }
        guard werte.count >= 3 else { return nil }
        let schnitt = werte.reduce(0, +) / werte.count
        guard Double(schnitt) < Double(e.schrittZiel) * 0.7 else { return nil }
        return CoachKarte(
            art: .schritte, titel: "Schritte",
            text: "In den letzten Tagen lagst du im Schnitt bei \(HealthText.zahl(schnitt)) Schritten, dein Ziel ist \(HealthText.zahl(e.schrittZiel)). "
                + "Ein Spaziergang mehr in der Woche ist ein guter Anfang.")
    }

    /// Nur Zahlen, kein Lob und kein Alarm. Schnitt der 7 Tage bis zum letzten Eintrag (`GewichtLogik.berechnet`),
    /// daneben die Woche davor. Ein letzter Eintrag, der älter als 10 Tage ist, sagt nichts mehr über jetzt.
    private static func gewichtKarte(_ e: CoachEingabe) -> CoachKarte? {
        let gueltig = e.gewicht.filter { $0.value > 0 && istTag($0.key) }
        guard let neuester = gueltig.keys.max(), Datum.tageZwischen(neuester, e.heute) <= 10 else { return nil }
        let ab = Datum.addTage(neuester, -6)
        guard gueltig.filter({ $0.key >= ab }).count >= 2, let jetzt = GewichtLogik.berechnet(gueltig) else { return nil }
        var text = "Schnitt der letzten 7 Tage: \(GewichtText.anzeige(jetzt))."
        let davorEnde = Datum.addTage(neuester, -7)
        let davor = gueltig.filter { $0.key <= davorEnde && $0.key >= Datum.addTage(neuester, -13) }
        if davor.count >= 2, let frueher = GewichtLogik.berechnet(davor) {
            text += " Woche davor: \(GewichtText.anzeige(frueher))."
        }
        text += " Einzelne Tage schwanken, der Schnitt zählt."
        return CoachKarte(art: .gewicht, titel: "Gewicht", text: text)
    }
}

// MARK: - Verlauf

struct CoachNachricht: Identifiable, Equatable, Sendable {
    enum Rolle: String, Sendable { case du, coach }

    let id: String
    let rolle: Rolle
    let text: String
    let zeit: Date
    var seq: Int? = nil
    /// Nur auf dem Gerät entstanden (gerade gesendete Frage, HTTP-Antwort), noch ohne Op vom Server.
    var lokal = false
}

private struct CoachNachrichtD: Decodable {
    let rolle: String
    let text: String
    let tag: String?
}

extension CoachNachricht {
    /// Op `coach.nachricht` `{ rolle: "du" | "coach", text, tag }`. `rolle` und `tag` bewusst weich gelesen,
    /// damit eine kleine Abweichung des Servers keine Nachricht verschluckt. Alles außer "du" zeigt sich als Coach.
    static func aus(_ op: Op) -> CoachNachricht? {
        guard op.art == "coach.nachricht", let d = op.daten(CoachNachrichtD.self),
              !d.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return CoachNachricht(id: op.id, rolle: d.rolle == "du" ? .du : .coach, text: d.text, zeit: op.zeit, seq: op.seq)
    }
}

enum CoachVerlauf {
    /// Uhren von Handy und Server können abweichen; eine Op gilt für einen lokalen Eintrag nur, wenn sie
    /// nicht früher als dieser (minus Toleranz) entstanden ist. So frisst eine alte gleiche Frage keine neue.
    static let zeitToleranz: TimeInterval = 120

    private static func gleich(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespacesAndNewlines) == b.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Zeit, dann Server-Reihenfolge (`seq`), dann "du" vor "coach".
    static func sortieren(_ liste: [CoachNachricht]) -> [CoachNachricht] {
        liste.sorted { a, b in
            if a.zeit != b.zeit { return a.zeit < b.zeit }
            if let x = a.seq, let y = b.seq, x != y { return x < y }
            if a.rolle != b.rolle { return a.rolle == .du }
            return a.id < b.id
        }
    }

    /// Server-Ops plus lokale Einträge. Jeder lokale Eintrag verschwindet, sobald eine noch nicht vergebene Op
    /// mit gleicher Rolle und gleichem Text passt (je Op höchstens ein Eintrag, damit eine wiederholte
    /// Schnellfrage nicht verschluckt wird). Die lokalen Einträge selbst bleiben unverändert und werden bei
    /// jedem Aufruf neu zugeordnet.
    static func zusammenfuehren(ops: [CoachNachricht], lokal: [CoachNachricht]) -> [CoachNachricht] {
        let vomServer = sortieren(ops)
        var vergeben: Set<String> = []
        var offen: [CoachNachricht] = []
        for eintrag in lokal.sorted(by: { $0.zeit < $1.zeit }) {
            let grenze = eintrag.zeit.addingTimeInterval(-zeitToleranz)
            let treffer = vomServer.first {
                !vergeben.contains($0.id) && $0.rolle == eintrag.rolle && gleich($0.text, eintrag.text) && $0.zeit >= grenze
            }
            if let treffer { vergeben.insert(treffer.id) } else { offen.append(eintrag) }
        }
        return sortieren(vomServer + offen)
    }

    /// "Verlauf ausblenden": nur was nach dem Zeitpunkt entstanden ist, bleibt sichtbar.
    static func sichtbar(_ liste: [CoachNachricht], ausgeblendetBis: Date?) -> [CoachNachricht] {
        guard let grenze = ausgeblendetBis else { return liste }
        return liste.filter { $0.zeit > grenze }
    }
}

// MARK: - Fehler

enum CoachFehler: Equatable, Sendable {
    case nichtEingerichtet, tageslimit, netz, server

    /// Statuscode der Antwort von `POST coach/frage`; 0 = keine Antwort. 2xx ist kein Fehler.
    static func aus(status: Int) -> CoachFehler? {
        if (200..<300).contains(status) { return nil }
        if status == 503 { return .nichtEingerichtet }
        if status == 429 { return .tageslimit }
        if status == 0 { return .netz }
        return .server
    }

    var text: String {
        switch self {
        case .nichtEingerichtet: "Coach noch nicht eingerichtet. Das fehlt auf dem Server, nicht bei dir."
        case .tageslimit: "Tageslimit erreicht. Morgen geht es weiter."
        case .netz: "Keine Verbindung. Dein Text steht noch im Feld."
        case .server: "Der Coach antwortet gerade nicht. Dein Text steht noch im Feld."
        }
    }
}
