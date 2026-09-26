import SwiftUI

// MARK: - Rechnen

/// Die reine Rechnung des Tabs Körper: Urteil, Wochenstreifen, Bilanz, Ziele, Übungsverlauf, nächstes
/// Gewicht. Kein Modell, kein Zustand. Regeln wie in `design/erholung/erholung.html`.
enum KoerperLogik {
    enum Art: Sendable {
        case beine, oben
        var kuerzel: String { self == .beine ? "B" : "O" }
    }

    /// Mittelwert der Teile einer Gruppe, ein Teil ohne Eintrag gilt als erholt (100).
    static func gruppenErholung(_ erholung: [MuskelTeil: Int], _ g: MuskelGruppe) -> Int {
        let teile = MuskelTeil.allCases.filter { $0.gruppe == g }
        let summe = teile.reduce(0) { $0 + (erholung[$1] ?? 100) }
        return Int((Double(summe) / Double(teile.count)).rounded())
    }

    /// Titel und Satz der Figuren-Karte (`urteil()` im Entwurf). "Oben" heißt: Schulter, Rücken, Brust,
    /// Bizeps und Trizeps alle bei 90 % oder mehr.
    static func urteil(_ erholung: [MuskelTeil: Int]) -> (titel: String, satz: String) {
        let beine = gruppenErholung(erholung, .beine)
        let obenGruppen: [MuskelGruppe] = [.schulter, .ruecken, .brust, .bizeps, .trizeps]
        let oben = obenGruppen.allSatisfy { gruppenErholung(erholung, $0) >= 90 }
        if beine < 60 && oben { return ("Oben frisch, unten Pudding", "Beine brauchen noch etwa einen Tag. Oben ist alles bereit.") }
        if beine < 90 && oben { return ("Fast startklar", "Beine sind bei \(beine) %. Morgen ist alles wieder grün.") }
        if oben { return ("Frisch wie ein Salat", "Alles erholt. Heute geht alles.") }
        return ("Muskelkater-Modus", "Gönn dir heute Pause oder etwas Leichtes.")
    }

    /// "Schulter seitlich", "Brust oben", aber "Quadrizeps" und "Latissimus" stehen für sich.
    static func teilName(_ t: MuskelTeil) -> String {
        t.name.first?.isLowercase == true ? "\(t.gruppe.name) \(t.name)" : t.name
    }

    // MARK: Legende

    struct LegendeZeile: Equatable, Sendable {
        let stufe: ErholungsStufe
        let wort: String
        let eintraege: [String]
    }

    /// Pro Farbe eine Zeile. Erholt: die Gruppen, in denen alles bei 90 % oder mehr ist. Fast erholt
    /// und müde: die einzelnen Teile mit ihrem Prozentwert. Leere Zeilen fehlen.
    static func legende(_ erholung: [MuskelTeil: Int], reihenfolge: [MuskelGruppe]) -> [LegendeZeile] {
        var erholt: [String] = []
        var fast: [String] = []
        var muede: [String] = []
        for g in reihenfolge {
            let offen = MuskelTeil.allCases.filter { $0.gruppe == g && (erholung[$0] ?? 100) < 90 }
            if offen.isEmpty { erholt.append(g.name) }
            for t in offen {
                let e = erholung[t] ?? 100
                let zeile = "\(teilName(t)) \(e) %"
                if MuskelLogik.stufe(e) == .muede { muede.append(zeile) } else { fast.append(zeile) }
            }
        }
        return [
            LegendeZeile(stufe: .erholt, wort: "Erholt", eintraege: erholt),
            LegendeZeile(stufe: .fast, wort: "Fast erholt", eintraege: fast),
            LegendeZeile(stufe: .muede, wort: "Müde", eintraege: muede),
        ].filter { !$0.eintraege.isEmpty }
    }

    // MARK: Training als Oberkörper oder Beine

    /// Beine, wenn mehr als die Hälfte der Haupt-Teile Beine sind, sonst Oberkörper. Ohne Teile nil.
    static func art(teile: [MuskelTeil]) -> Art? {
        guard !teile.isEmpty else { return nil }
        return teile.filter { $0.gruppe == .beine }.count * 2 > teile.count ? .beine : .oben
    }

    static func haupt(_ u: Uebung) -> MuskelTeil? { MuskelLogik.teile(u).first { $0.faktor == 1 }?.teil }

    static func art(_ tag: TrainingsTag, katalog: (String) -> Uebung?) -> Art? {
        art(teile: tag.uebungen.compactMap { katalog($0.uebung).flatMap(haupt) })
    }

    /// Nach den fertigen Übungen, ohne Übungen nach dem Plan-Tag der Session.
    static func art(_ s: GymSession, plan: TrainingsPlan, katalog: (String) -> Uebung?) -> Art? {
        let teile = s.laeufe.filter(\.fertig).compactMap { katalog($0.uebung).flatMap(haupt) }
        return art(teile: teile) ?? plan.tage.first { $0.id == s.tag }.flatMap { art($0, katalog: katalog) }
    }

    // MARK: Ziele

    static func faellig(prio: [MuskelGruppe], ziele: KoerperZiele, woche: [MuskelTeil: Double]) -> [MuskelGruppe] {
        prio.filter { g in
            let ziel = Double(ziele.saetze[g] ?? 0)
            let gemacht = MuskelTeil.allCases.filter { $0.gruppe == g }.reduce(0.0) { $0 + (woche[$1] ?? 0) }
            return ziel > 0 && gemacht < ziel * 0.5
        }
    }

    // MARK: Nächstes Training

    /// Der nächste Plan-Tag ab heute (heute nur, wenn noch nichts gemacht ist). Ohne Plan nil.
    static func naechstes(plan: TrainingsPlan, heute: String, heuteFertig: Bool, faellig: [MuskelGruppe],
                          katalog: (String) -> Uebung?) -> KoerperNaechstes? {
        for i in (heuteFertig ? 1 : 0)...7 {
            let datum = Datum.addTage(heute, i)
            guard let tag = TrainingLogik.tag(plan, datum: datum), !tag.uebungen.isEmpty else { continue }
            let saetze = tag.uebungen.reduce(0) { $0 + $1.saetze.count }
            let cardio = tag.uebungen.compactMap(\.minuten).reduce(0, +)
            let minuten = (saetze * 4 + cardio + 4) / 5 * 5 // ponytail: 4 min pro Satz, auf 5 gerundet
            let wann = i == 0 ? "Heute" : i == 1 ? "Morgen" : TrainingLogik.wochentagName[Datum.wochentag(datum) - 1]
            var meta = ["\(wann), \(tagMonat(datum))", "\(tag.uebungen.count) \(tag.uebungen.count == 1 ? "Übung" : "Übungen")"]
            if saetze > 0 { meta.append("\(saetze) Sätze") }
            meta.append("etwa \(minuten) min")
            var chips = faellig.map(\.name)
            if chips.isEmpty {
                for g in tag.uebungen.compactMap({ katalog($0.uebung).flatMap(haupt)?.gruppe.name }) where !chips.contains(g) { chips.append(g) }
            }
            return KoerperNaechstes(titel: tag.name, meta: meta.joined(separator: " · "), chips: Array(chips.prefix(3)))
        }
        return nil
    }

    /// "2026-09-26" -> "26.9.".
    static func tagMonat(_ datum: String) -> String {
        "\(Int(datum.suffix(2)) ?? 0).\(Int(datum.dropFirst(5).prefix(2)) ?? 0)."
    }

    /// "Mo 22.9.".
    static func tagKurz(_ datum: String) -> String {
        "\(HabitLogik.wochentagKuerzel[Datum.wochentag(datum) - 1]) \(tagMonat(datum))"
    }

    // MARK: Doppelte Progression

    struct Vorschlag: Equatable, Sendable {
        let kg: Double?
        let wdh: Int
        let mehrGewicht: Bool
    }

    /// Alle Sätze am oberen Ende: +2,5 kg und zurück auf `start` Wiederholungen. Sonst gleiches Gewicht
    /// und eine Wiederholung mehr als der schwächste Satz. Ohne Gewicht (Körpergewicht) gibt es nur
    /// Wiederholungen. Leer: nil.
    // ponytail: das obere Ende ist fest 12, der Plan speichert keinen Wiederholungsbereich. Später pro Übung.
    static func naechstesMal(_ saetze: [PlanSatz], oben: Int = 12, start: Int = 8) -> Vorschlag? {
        guard !saetze.isEmpty else { return nil }
        let kg = saetze.compactMap(\.kg).max()
        let arbeit = saetze.filter { $0.kg == kg }
        let schwach = arbeit.map(\.wdh).min() ?? 0
        if schwach >= oben { return Vorschlag(kg: kg.map { $0 + 2.5 }, wdh: kg == nil ? oben : start, mehrGewicht: true) }
        return Vorschlag(kg: kg, wdh: schwach + 1, mehrGewicht: false)
    }

    static func vorschlagText(_ v: Vorschlag, oben: Int = 12) -> String {
        guard let kg = v.kg else {
            return v.mehrGewicht ? "Alle Sätze bei \(oben). Nimm Zusatzgewicht." : "\(v.wdh) Wiederholungen. Bei \(oben) in jedem Satz: Zusatzgewicht."
        }
        if v.mehrGewicht { return "Alle Sätze bei \(oben). Nächstes Mal \(TrainingLogik.kgText(kg)) kg × \(v.wdh)." }
        return "\(TrainingLogik.kgText(kg)) kg × \(v.wdh). Bei \(oben) in jedem Satz: \(TrainingLogik.kgText(kg + 2.5)) kg."
    }

    /// 3,5 und 12.
    static func komma(_ d: Double) -> String { TrainingLogik.kgText(d) }

    /// "60 × 8", ohne Gewicht "12 Wdh".
    static func satzText(_ s: PlanSatz) -> String {
        s.kg.map { "\(TrainingLogik.kgText($0)) × \(s.wdh)" } ?? "\(s.wdh) Wdh"
    }

    // MARK: Übungen einer Gruppe

    struct VerlaufZeile: Sendable {
        let tag: String
        let saetze: String
    }

    struct UebungsZeile: Identifiable, Sendable {
        let id: String
        let name: String
        let teil: MuskelTeil
        let monat: Int
        let gesamt: Int
        /// Neueste zuerst, höchstens 3: Tag und Sätze.
        let verlauf: [VerlaufZeile]
        let vorschlag: Vorschlag?
    }

    struct GruppenDaten: Sendable {
        let monat: Int
        let gesamt: Int
        let uebungen: [UebungsZeile]
    }

    /// Fertige Übungen mit Sätzen, deren Haupt-Teil in `g` liegt. Cardio und eigene Übungen zählen nicht.
    /// "Monat" ist der Kalendermonat von `jetzt`, gezählt in Einheiten (Sessions).
    static func gruppe(_ g: MuskelGruppe, sessions: [GymSession], jetzt: Date, katalog: (String) -> Uebung?) -> GruppenDaten {
        let monatKey = Datum.text(jetzt).prefix(7)
        var nachUebung: [String: (u: Uebung, teil: MuskelTeil, laeufe: [(start: Date, saetze: [PlanSatz])])] = [:]
        var alle: Set<String> = []
        var imMonat: Set<String> = []
        for s in sessions.sorted(by: { $0.start > $1.start }) {
            for lauf in s.laeufe where lauf.fertig {
                guard let gemacht = lauf.saetze, !gemacht.isEmpty, let u = katalog(lauf.uebung),
                      let teil = haupt(u), teil.gruppe == g else { continue }
                alle.insert(s.id)
                if Datum.text(s.start).prefix(7) == monatKey { imMonat.insert(s.id) }
                nachUebung[u.id, default: (u, teil, [])].laeufe.append((s.start, gemacht))
            }
        }
        let zeilen = nachUebung.values.map { e -> UebungsZeile in
            let heuteMonat = e.laeufe.filter { Datum.text($0.start).prefix(7) == monatKey }.count
            let verlauf = e.laeufe.prefix(3).map { VerlaufZeile(tag: tagKurz(Datum.text($0.start)), saetze: $0.saetze.map(satzText).joined(separator: " · ")) }
            return UebungsZeile(id: e.u.id, name: e.u.name, teil: e.teil, monat: heuteMonat, gesamt: e.laeufe.count,
                                verlauf: verlauf, vorschlag: e.laeufe.first.flatMap { naechstesMal($0.saetze) })
        }
        return GruppenDaten(monat: imMonat.count, gesamt: alle.count, uebungen: zeilen.sorted { $0.gesamt != $1.gesamt ? $0.gesamt > $1.gesamt : $0.name < $1.name })
    }
}

/// Satzziele und Reihenfolge einer Person. `saetze` ist leer, solange Annika noch keine Ziele hat.
struct KoerperZiele: Sendable {
    let prio: [MuskelGruppe]
    let saetze: [MuskelGruppe: Int]

    /// `wert` liest `ziel.prio.<gruppe>` (Rang 1 bis 5, 0 oder nil = keine Prio) und `ziel.saetze.<gruppe>`.
    /// Ohne Prio gilt `MuskelGruppe.standardPrio`. Nur Annika ohne jedes Ziel bekommt gar keine, dann
    /// zeigt die Seite "Ziele festlegen".
    static func lesen(person: Person, wert: (String) -> Int?) -> KoerperZiele {
        let raenge = MuskelGruppe.allCases.filter { (wert("ziel.prio.\($0.rawValue)") ?? 0) > 0 }
            .sorted { (wert("ziel.prio.\($0.rawValue)") ?? 0) < (wert("ziel.prio.\($1.rawValue)") ?? 0) }
        let gesetzt = MuskelGruppe.allCases.compactMap { g in wert("ziel.saetze.\(g.rawValue)").map { (g, $0) } }
        if raenge.isEmpty && gesetzt.isEmpty && person == .annika { return KoerperZiele(prio: [], saetze: [:]) }
        let prio = raenge.isEmpty ? MuskelGruppe.standardPrio : raenge
        let eigene = Dictionary(uniqueKeysWithValues: gesetzt)
        let saetze = Dictionary(uniqueKeysWithValues: MuskelGruppe.allCases.map {
            ($0, eigene[$0] ?? MuskelLogik.standardZiel($0, prio: prio.contains($0)))
        })
        return KoerperZiele(prio: prio, saetze: saetze)
    }

    var leer: Bool { saetze.isEmpty }

    /// Prio zuerst, dann der Rest in der Reihenfolge der Gruppen.
    var reihenfolge: [MuskelGruppe] { prio + MuskelGruppe.allCases.filter { !prio.contains($0) } }
}

struct KoerperNaechstes: Sendable {
    let titel: String
    let meta: String
    let chips: [String]
}

/// Die sieben Tage der Woche und die Bilanz. Regel für die Bilanz: "von x" sind die Plan-Tage der Woche
/// als Beine oder Oberkörper, "y" die eigenen Einheiten dieser Woche. Eine Pause ist ein vergangener Tag
/// dieser Woche ohne eigene Einheit.
struct KoerperWoche: Sendable {
    struct Tag: Sendable {
        let datum: String
        let kuerzel: String
        let nummer: Int
        let fertig: Bool
        let heute: Bool
        let geplant: KoerperLogik.Art?
        /// Wer an dem Tag trainiert hat, für die Punkte.
        let personen: [Person]

        /// Der Buchstabe O oder B, nur für Tage, die noch kommen.
        var planBuchstabe: String? { fertig ? nil : geplant?.kuerzel }
    }

    let tage: [Tag]
    let beine: Int
    let oben: Int
    let pausen: Int

    var beineGeplant: Int { tage.filter { $0.geplant == .beine }.count }
    var obenGeplant: Int { tage.filter { $0.geplant == .oben }.count }

    var bilanz: String {
        let b = max(beineGeplant, beine), o = max(obenGeplant, oben)
        guard b + o > 0 else { return "Noch kein Training geplant. Im Tab Training legst du deinen Plan an." }
        return "Beine \(beine) von \(b) · Oberkörper \(oben) von \(o) · \(pausen) \(pausen == 1 ? "Pause" : "Pausen")"
    }

    static func bauen(ich: Person, sessions: [Person: [GymSession]], plan: TrainingsPlan, heute: String,
                      katalog: (String) -> Uebung?) -> KoerperWoche {
        let montag = Datum.montagDerWoche(heute)
        let tage = (0..<7).map { i -> Tag in
            let datum = Datum.addTage(montag, i)
            let wer = Person.allCases.filter { p in (sessions[p] ?? []).contains { Datum.text($0.start) == datum } }
            let geplant = plan.tage.first { $0.wochentage.contains(i + 1) }.flatMap { KoerperLogik.art($0, katalog: katalog) }
            return Tag(datum: datum, kuerzel: HabitLogik.wochentagKuerzel[i], nummer: Int(datum.suffix(2)) ?? 0,
                       fertig: wer.contains(ich), heute: datum == heute, geplant: geplant, personen: wer)
        }
        let eigene = (sessions[ich] ?? []).filter { Datum.montagDerWoche(Datum.text($0.start)) == montag }
        let arten = eigene.map { KoerperLogik.art($0, plan: plan, katalog: katalog) }
        return KoerperWoche(tage: tage, beine: arten.filter { $0 == .beine }.count, oben: arten.filter { $0 == .oben }.count,
                            pausen: tage.filter { !$0.fertig && $0.datum < heute }.count)
    }
}

/// Alles, was die Seite und das Blatt zeigen, als Werte. `laden` liest die Modelle, `bauen` rechnet.
struct KoerperDaten: Sendable {
    let person: Person
    let erholung: [MuskelTeil: Int]
    let woche: [MuskelTeil: Double]
    let ziele: KoerperZiele
    let streifen: KoerperWoche
    let naechstes: KoerperNaechstes?
    let gruppen: [MuskelGruppe: KoerperLogik.GruppenDaten]

    @MainActor
    static func laden(_ ich: Person, jetzt: Date = Date()) -> KoerperDaten {
        let training = TrainingModell.shared, health = HealthModell.shared
        let sessions = Dictionary(uniqueKeysWithValues: Person.allCases.map { ($0, training.sessions($0)) })
        return bauen(person: ich, sessions: sessions, plan: training.plan(ich), wert: { health.ziel($0, ich) }, jetzt: jetzt)
    }

    static func bauen(person: Person, sessions: [Person: [GymSession]], plan: TrainingsPlan, wert: (String) -> Int?, jetzt: Date,
                      katalog: (String) -> Uebung? = { UebungsKatalog.nachId[$0] }) -> KoerperDaten {
        let heute = Datum.text(jetzt)
        let eigene = sessions[person] ?? []
        let ziele = KoerperZiele.lesen(person: person, wert: wert)
        let woche = MuskelLogik.wochenSaetze(eigene, woche: heute, katalog: katalog)
        let streifen = KoerperWoche.bauen(ich: person, sessions: sessions, plan: plan, heute: heute, katalog: katalog)
        let faellig = KoerperLogik.faellig(prio: ziele.prio, ziele: ziele, woche: woche)
        return KoerperDaten(
            person: person,
            erholung: MuskelLogik.erholung(eigene, jetzt: jetzt, katalog: katalog),
            woche: woche, ziele: ziele, streifen: streifen,
            naechstes: KoerperLogik.naechstes(plan: plan, heute: heute, heuteFertig: streifen.tage.contains { $0.heute && $0.fertig },
                                             faellig: faellig, katalog: katalog),
            gruppen: Dictionary(uniqueKeysWithValues: MuskelGruppe.allCases.map {
                ($0, KoerperLogik.gruppe($0, sessions: eigene, jetzt: jetzt, katalog: katalog))
            })
        )
    }

    func prozent(_ t: MuskelTeil) -> Int { erholung[t] ?? 100 }
    func prozent(_ g: MuskelGruppe) -> Int { KoerperLogik.gruppenErholung(erholung, g) }

    /// Harte Sätze der Woche in der Gruppe, Mitarbeit zählt halb.
    func saetze(_ g: MuskelGruppe) -> Double {
        MuskelTeil.allCases.filter { $0.gruppe == g }.reduce(0) { $0 + (woche[$1] ?? 0) }
    }

    func stufe(_ g: MuskelGruppe) -> ErholungsStufe { MuskelLogik.stufe(prozent(g)) }

    /// Wort im Feld: Prozent, solange nicht erholt, dann "geschafft" (Ziel erreicht) oder "erholt".
    func wort(_ g: MuskelGruppe) -> String {
        if stufe(g) != .erholt { return "\(prozent(g)) %" }
        guard let ziel = ziele.saetze[g] else { return "erholt" }
        return saetze(g) >= Double(ziel) ? "geschafft" : "erholt"
    }

    var urteil: (titel: String, satz: String) { KoerperLogik.urteil(erholung) }
}

enum KoerperFarbe {
    static let erholt = Color(red: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255)
    static let fast = Color(red: 1, green: 0x7A / 255, blue: 0x59 / 255)
    static let muede = Color.loveaRose
    /// Erholte Muskeln auf der Figur: gedämpftes Grün, wie in der Tafel der Figur.
    static let figurErholt = FigurFarbe(0x3A3A42).mix(FigurFarbe(0x30D158), 0.72).farbe

    static func stufe(_ s: ErholungsStufe) -> Color { s == .erholt ? erholt : s == .fast ? fast : muede }
    static func figur(_ s: ErholungsStufe) -> Color { s == .erholt ? figurErholt : stufe(s) }
}

extension KoerperDaten {
    func farbe(_ t: MuskelTeil) -> Color { KoerperFarbe.figur(MuskelLogik.stufe(prozent(t))) }
}

// MARK: - Seite

/// Ein Tipp auf einen Muskel oder ein Feld.
private struct Auswahl: Identifiable {
    let gruppe: MuskelGruppe
    let teil: MuskelTeil?
    var id: String { "\(gruppe.rawValue)/\(teil?.rawValue ?? "-")" }
}

struct KoerperView: View {
    @State private var auswahl: Auswahl?
    @State private var befragung = false

    var body: some View {
        let ich = Raum.shared.ich ?? .ahmed
        let daten = KoerperDaten.laden(ich)
        NavigationStack {
            ScrollView {
                KoerperInhalt(
                    daten: daten,
                    onGruppe: { auswahl = Auswahl(gruppe: $0, teil: $1) },
                    onZiele: { befragung = true },
                    onTraining: { AppNavigation.shared.tabWunsch = "training" }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("Körper")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Ziele", systemImage: "slider.horizontal.3") { befragung = true }
                }
            }
        }
        .sheet(item: $auswahl) { a in
            ScrollView { KoerperBlatt(daten: daten, gruppe: a.gruppe, teil: a.teil).padding(.horizontal, 18).padding(.top, 22).padding(.bottom, 30) }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $befragung) { ZieleBefragung() }
    }
}

/// Der Inhalt der Seite ohne Scrollen und Navigation, damit die Render-Tafel ihn zeichnen kann.
struct KoerperInhalt: View {
    let daten: KoerperDaten
    var animiert = true
    var onGruppe: (MuskelGruppe, MuskelTeil?) -> Void = { _, _ in }
    var onZiele: () -> Void = {}
    var onTraining: () -> Void = {}

    private var ich: Person { daten.person }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Streifen(woche: daten.streifen)
            Text(daten.streifen.bilanz)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
            figurKarte.padding(.top, 14)
            if daten.ziele.leer { zielKarte.padding(.top, 18) }
            Text("Sätze diese Woche")
                .font(.title3.weight(.semibold))
                .padding(.top, 22)
                .padding(.bottom, 10)
            felder
            if !daten.ziele.leer, let n = daten.naechstes { naechstesKarte(n).padding(.top, 18) }
        }
    }

    // MARK: Figur

    private var figurKarte: some View {
        let urteil = daten.urteil
        return VStack(alignment: .leading, spacing: 4) {
            Text(urteil.titel).font(.title3.weight(.semibold))
            Text(urteil.satz).font(.subheadline).foregroundStyle(.secondary)
            MuskelFigur(person: ich, farbe: { daten.farbe($0) }, onTipp: { onGruppe($0.gruppe, $0) }, animiert: animiert)
                .frame(height: 340)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            legende
        }
        .padding(.init(top: 14, leading: 16, bottom: 16, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var legende: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(KoerperLogik.legende(daten.erholung, reihenfolge: daten.ziele.reihenfolge), id: \.wort) { zeile in
                HStack(alignment: .top, spacing: 8) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(KoerperFarbe.stufe(zeile.stufe))
                        .frame(width: 11, height: 11)
                        .padding(.top, 3)
                    Text("\(Text(zeile.wort + ": ").fontWeight(.semibold).foregroundStyle(.primary))\(zeile.eintraege.joined(separator: ", "))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: Ziele und Felder

    private var zielKarte: some View {
        PushKarte(titel: "Ziele festlegen", meta: "Drei Fragen. Danach füllen sich die Felder bis zu deinen eigenen Zielen.",
                  chips: [], farbe: Color.person(ich), knopf: "Befragung starten", symbol: nil, aktion: onZiele)
    }

    private var felder: some View {
        let reihe = daten.ziele.reihenfolge
        return Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<3, id: \.self) { zeile in
                GridRow {
                    ForEach(0..<3, id: \.self) { spalte in
                        let i = zeile * 3 + spalte
                        Feld(daten: daten, gruppe: reihe[i], nummer: daten.ziele.prio.firstIndex(of: reihe[i]).map { $0 + 1 },
                             index: i, animiert: animiert) { onGruppe(reihe[i], nil) }
                    }
                }
            }
        }
    }

    private func naechstesKarte(_ n: KoerperNaechstes) -> some View {
        PushKarte(titel: n.titel, meta: n.meta, chips: n.chips, farbe: Color.person(ich), knopf: "Training starten",
                  symbol: "play.fill", aktion: onTraining)
    }
}

// MARK: - Teile der Seite

/// Wochenstreifen Mo bis So: grüner Haken, heute Rosé-Ring, O oder B für kommende Plan-Tage, darunter
/// ein Punkt pro Person, die an dem Tag trainiert hat.
private struct Streifen: View {
    let woche: KoerperWoche

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(woche.tage, id: \.datum) { tag in
                VStack(spacing: 5) {
                    Text(tag.kuerzel)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(tag.heute ? Color.primary : Color.secondary)
                    kreis(tag)
                    HStack(spacing: 3) {
                        ForEach(tag.personen, id: \.self) { Circle().fill(Color.person($0)).frame(width: 5, height: 5) }
                    }
                    .frame(height: 5)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label(tag))
            }
        }
        .padding(.top, 12)
    }

    @ViewBuilder private func kreis(_ tag: KoerperWoche.Tag) -> some View {
        ZStack {
            if tag.fertig {
                Circle().fill(KoerperFarbe.erholt)
                Image(systemName: "checkmark").font(.system(size: 15, weight: .heavy)).foregroundStyle(Color(red: 0x06 / 255, green: 0x2A / 255, blue: 0x12 / 255))
            } else if tag.heute {
                Circle().strokeBorder(Color.loveaRose, lineWidth: 2)
                zahlText(tag.nummer, .primary)
            } else if let buchstabe = tag.planBuchstabe {
                Circle().strokeBorder(Color.secondary.opacity(0.45), lineWidth: 1.5)
                Text(buchstabe).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            } else {
                Circle().fill(Color(.tertiarySystemBackground))
                zahlText(tag.nummer, .secondary)
            }
        }
        .frame(width: 36, height: 36)
    }

    private func zahlText(_ n: Int, _ farbe: Color) -> some View {
        Text("\(n)").font(.system(size: 14, weight: .semibold)).monospacedDigit().foregroundStyle(farbe)
    }

    private func label(_ tag: KoerperWoche.Tag) -> String {
        let name = TrainingLogik.wochentagName[Datum.wochentag(tag.datum) - 1]
        var stand = tag.heute ? "heute" : "kein Training"
        if tag.fertig { stand = "Training gemacht" }
        else if tag.planBuchstabe == "B" { stand = "Beine geplant" }
        else if tag.planBuchstabe == "O" { stand = "Oberkörper geplant" }
        return "\(name), \(stand)"
    }
}

/// Eins der 9 Felder: füllt sich in der Erholungsfarbe bis zum Wochenziel.
private struct Feld: View {
    let daten: KoerperDaten
    let gruppe: MuskelGruppe
    let nummer: Int?
    let index: Int
    let animiert: Bool
    let aktion: () -> Void
    @State private var geladen: Bool

    private static let hoehe: CGFloat = 66

    init(daten: KoerperDaten, gruppe: MuskelGruppe, nummer: Int?, index: Int, animiert: Bool, aktion: @escaping () -> Void) {
        self.daten = daten
        self.gruppe = gruppe
        self.nummer = nummer
        self.index = index
        self.animiert = animiert
        self.aktion = aktion
        _geladen = State(initialValue: !animiert)
    }

    private var farbe: Color { KoerperFarbe.stufe(daten.stufe(gruppe)) }
    private var ziel: Int? { daten.ziele.saetze[gruppe] }
    private var label: String {
        let von = ziel.map { " von \($0)" } ?? ""
        return "\(gruppe.name), \(KoerperLogik.komma(daten.saetze(gruppe)))\(von) Sätze, \(daten.wort(gruppe))"
    }
    private var anteil: Double { ziel.map { min(1, daten.saetze(gruppe) / Double($0)) } ?? 0 }

    var body: some View {
        Button(action: aktion) { inhalt }
            .buttonStyle(.federnd)
            .accessibilityLabel(label)
            .onAppear { geladen = true }
    }

    private var inhalt: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(gruppe.name).font(.system(size: 13, weight: .semibold))
                Spacer(minLength: 2)
                if let nummer { Text("\(nummer)").font(.system(size: 11, weight: .semibold)).foregroundStyle(.tertiary) }
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(KoerperLogik.komma(daten.saetze(gruppe))).font(.system(size: 21, weight: .bold)).monospacedDigit()
                Text(ziel.map { "/\($0)" } ?? " Sätze").font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text(daten.wort(gruppe)).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.primary)
        .padding(.init(top: 9, leading: 10, bottom: 8, trailing: 10))
        .frame(maxWidth: .infinity, minHeight: Self.hoehe, maxHeight: Self.hoehe, alignment: .topLeading)
        .background(alignment: .bottom) { pegel }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var pegel: some View {
        Rectangle()
            .fill(farbe.opacity(0.2))
            .overlay(alignment: .top) { if anteil > 0 { Rectangle().fill(farbe).frame(height: 1.5) } }
            .frame(height: Self.hoehe * (geladen ? anteil : 0))
            .animation(Feder.weich.delay(Double(index) * 0.035), value: geladen)
    }
}

/// Karte im PUSH-Stil: Rosé-Verlauf, schmale Versalien, ein heller Knopf. Archivo gibt es nicht,
/// deshalb System schwarz, schmal.
private struct PushKarte: View {
    let titel: String
    let meta: String
    let chips: [String]
    let farbe: Color
    let knopf: String
    let symbol: String?
    let aktion: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titel)
                .font(.system(size: 44, weight: .black, design: .default).width(.compressed))
                .textCase(.uppercase)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(meta).font(.footnote).foregroundStyle(Color(red: 1, green: 0xD3 / 255, blue: 0xDB / 255)).padding(.top, 6)
            if !chips.isEmpty {
                HStack(spacing: 6) {
                    ForEach(chips, id: \.self) { chip in
                        HStack(spacing: 6) {
                            Circle().fill(farbe).frame(width: 7, height: 7)
                            Text(chip).font(.system(size: 12, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1), in: Capsule())
                    }
                }
                .padding(.top, 12)
            }
            Button(action: aktion) {
                HStack(spacing: 8) {
                    if let symbol { Image(systemName: symbol).font(.system(size: 14)) }
                    Text(knopf).font(.system(size: 16, weight: .bold))
                }
                .foregroundStyle(Color(white: 0.07))
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Color(white: 0.96), in: Capsule())
            }
            .buttonStyle(.federnd)
            .padding(.top, 14)
        }
        .padding(.init(top: 16, leading: 16, bottom: 14, trailing: 16))
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(.white)
        .background { hintergrund }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.loveaRose.opacity(0.24), lineWidth: 1) }
    }

    private var hintergrund: some View {
        ZStack {
            Color(.secondarySystemBackground)
            LinearGradient(colors: [Color.loveaRose.opacity(0.2), Color.loveaRose.opacity(0.05)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [Color.loveaRose.opacity(0.34), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
        }
    }
}
