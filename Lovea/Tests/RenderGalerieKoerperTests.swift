import SwiftUI
import XCTest
@testable import Lovea

/// Beispieldaten für die Tests und die Tafel: ein kleiner Katalog und eine Woche mit Training.
/// Freitag, 25.09.2026, 18:00. Nicht actor-isoliert, damit `Beispiel.lies` als `katalog:` taugt.
private enum Beispiel {
    static func u(_ name: String, _ muskel: String, _ neben: [String] = [], koerper: String = "Brust") -> Uebung {
        Uebung(id: name, name: name, en: name, muskel: muskel, koerper: koerper, geraet: "", neben: neben)
    }

    static let katalog: [String: Uebung] = Dictionary(uniqueKeysWithValues: [
        u("Bankdrücken Langhantel", "Brust", ["Trizeps", "Schultern"]),
        u("Kabelturm Fliegende von unten", "obere Brust"),
        u("Bizeps-Curls Kurzhantel", "Bizeps", koerper: "Arme"),
        u("Preacher Curls", "Bizeps", koerper: "Arme"),
        u("Kniebeuge", "Quadrizeps", ["Po", "Beinbeuger"], koerper: "Beine"),
        u("Beinstrecker", "Quadrizeps", koerper: "Beine"),
        u("Beinbeuger liegend", "Beinbeuger", koerper: "Beine"),
        u("Wadenheben stehend", "Waden", koerper: "Beine"),
        u("Hip Thrust", "Po", koerper: "Beine"),
        u("Latzug eng", "Latissimus", koerper: "Rücken"),
        u("Laufband", "Herz-Kreislauf", koerper: "Cardio"),
    ].map { ($0.id, $0) })

    static func lies(_ id: String) -> Uebung? { katalog[id] }

    static let jetzt = Datum.datum("2026-09-25").addingTimeInterval(18 * 3600)

    static func satz(_ paare: [(Double, Int)]) -> [PlanSatz] {
        paare.map { PlanSatz(wdh: $0.1, kg: $0.0, failure: false) }
    }

    static func session(_ id: String, tag: String?, _ datum: String, _ laeufe: [(String, [PlanSatz])]) -> GymSession {
        let start = Datum.datum(datum).addingTimeInterval(10 * 3600)
        let runden = laeufe.map { UebungsLauf(plan: $0.0, uebung: $0.0, start: nil, ende: start, fertig: true, saetze: $0.1) }
        return GymSession(id: id, tag: tag, start: start, ende: start.addingTimeInterval(3600), laeufe: runden)
    }

    static let ahmedOben = session("a1", tag: "oben", "2026-09-21", [
        ("Bankdrücken Langhantel", satz([(60, 8), (65, 8), (62.5, 7), (60, 8)])),
        ("Kabelturm Fliegende von unten", satz([(15, 12), (17.5, 12), (20, 12)])),
        ("Bizeps-Curls Kurzhantel", satz([(12, 12), (14, 10), (14, 9)])),
        ("Preacher Curls", satz([(25, 10), (25, 10), (25, 10)])),
    ])
    static let ahmedBeine = session("a2", tag: "beine", "2026-09-23", [
        ("Kniebeuge", satz([(80, 8), (85, 6), (85, 6), (80, 7)])),
        ("Beinstrecker", satz([(45, 12), (50, 10), (50, 9)])),
        ("Beinbeuger liegend", satz([(35, 12), (35, 11), (35, 10)])),
        ("Wadenheben stehend", satz([(60, 15), (60, 14), (60, 13), (60, 12)])),
    ])
    static let ahmedAlt = session("a0", tag: "oben", "2026-08-31", [("Bankdrücken Langhantel", satz([(57.5, 8), (57.5, 8), (57.5, 7)]))])
    static let annikaMo = session("n1", tag: "beine", "2026-09-21", [
        ("Hip Thrust", satz([(50, 12), (55, 10), (55, 10)])),
        ("Beinstrecker", satz([(25, 12), (25, 12), (30, 9)])),
        ("Latzug eng", satz([(30, 12), (30, 11), (30, 10)])),
    ])

    static let alle: [Person: [GymSession]] = [.ahmed: [ahmedBeine, ahmedOben, ahmedAlt], .annika: [annikaMo]]

    static func plan(_ tage: [(String, [Int], [String])]) -> TrainingsPlan {
        TrainingsPlan(tage: tage.map { name, wochentage, uebungen in
            TrainingsTag(id: name.lowercased(), name: name, wochentage: wochentage, uebungen: uebungen.compactMap { lies($0).map(PlanUebung.neu) })
        })
    }

    static let ahmedPlan = plan([
        ("Oben", [1, 5], ["Bankdrücken Langhantel", "Kabelturm Fliegende von unten"]),
        ("Beine", [3, 7], ["Kniebeuge", "Beinstrecker"]),
    ])
    static let annikaPlan = plan([("Po und Beine", [6], ["Hip Thrust", "Beinstrecker", "Beinbeuger liegend"])])

    static func daten(_ p: Person, plan: TrainingsPlan, ziele: @escaping (String) -> Int? = { _ in nil }) -> KoerperDaten {
        KoerperDaten.bauen(person: p, sessions: alle, plan: plan, wert: ziele, jetzt: jetzt, katalog: lies)
    }

    /// Annikas Befragung: Beine, Rücken, Schulter, Brust, Bizeps.
    static func annikaZiele(_ schluessel: String) -> Int? {
        let raenge = ["beine": 1, "ruecken": 2, "schulter": 3, "brust": 4, "bizeps": 5]
        if schluessel.hasPrefix("ziel.prio.") { return raenge[String(schluessel.dropFirst(10))] ?? 0 }
        if schluessel.hasPrefix("ziel.saetze.") { return 10 }
        return nil
    }
}

/// Rechenteile und Render-Tafel des Tabs Körper (`KoerperView`, `KoerperBlatt`).
@MainActor
final class RenderGalerieKoerperTests: XCTestCase {
    private typealias Zelle = (titel: String, ansicht: AnyView)

    // MARK: Urteil, Erholung, Legende

    func testUrteil() {
        func alle(_ e: Int) -> [MuskelTeil: Int] { Dictionary(uniqueKeysWithValues: MuskelTeil.allCases.map { ($0, e) }) }
        XCTAssertEqual(KoerperLogik.urteil([:]).titel, "Frisch wie ein Salat")
        var beine = alle(100)
        for t in MuskelTeil.allCases where t.gruppe == .beine { beine[t] = 40 }
        XCTAssertEqual(KoerperLogik.urteil(beine).titel, "Oben frisch, unten Pudding")
        for t in MuskelTeil.allCases where t.gruppe == .beine { beine[t] = 75 }
        XCTAssertEqual(KoerperLogik.urteil(beine).titel, "Fast startklar")
        XCTAssertEqual(KoerperLogik.urteil(beine).satz, "Beine sind bei 75 %. Morgen ist alles wieder grün.")
        var schulter = alle(100)
        schulter[.sSeitlich] = 20
        schulter[.sVorne] = 20
        schulter[.sHinten] = 20
        XCTAssertEqual(KoerperLogik.urteil(schulter).titel, "Muskelkater-Modus")
    }

    func testGruppenErholungFehlendeTeileSindErholt() {
        XCTAssertEqual(KoerperLogik.gruppenErholung([:], .beine), 100)
        XCTAssertEqual(KoerperLogik.gruppenErholung([.beQuads: 50], .beine), 90)
    }

    func testLegende() {
        let zeilen = KoerperLogik.legende([.sSeitlich: 40, .beQuads: 75], reihenfolge: [.schulter, .brust, .beine])
        XCTAssertEqual(zeilen.map(\.wort), ["Erholt", "Fast erholt", "Müde"])
        XCTAssertEqual(zeilen[0].eintraege, ["Brust"])
        XCTAssertEqual(zeilen[1].eintraege, ["Quadrizeps 75 %"])
        XCTAssertEqual(zeilen[2].eintraege, ["Schulter seitlich 40 %"])
        XCTAssertEqual(KoerperLogik.legende([:], reihenfolge: MuskelGruppe.allCases).map(\.wort), ["Erholt"])
    }

    // MARK: Ziele

    func testAnnikaOhneZielHatKeineZiele() {
        let z = KoerperZiele.lesen(person: .annika) { _ in nil }
        XCTAssertTrue(z.leer)
        XCTAssertTrue(z.prio.isEmpty)
        XCTAssertEqual(z.reihenfolge, MuskelGruppe.allCases)
    }

    func testAhmedOhneZielNimmtStandardPrio() {
        let z = KoerperZiele.lesen(person: .ahmed) { _ in nil }
        XCTAssertEqual(z.prio, MuskelGruppe.standardPrio)
        XCTAssertEqual(z.saetze[.schulter], 16)
        XCTAssertEqual(z.saetze[.nacken], 12)
        XCTAssertEqual(z.saetze[.beine], 8)
        XCTAssertEqual(Array(z.reihenfolge.prefix(5)), MuskelGruppe.standardPrio)
    }

    func testRangNullIstKeinePrio() {
        let alleNull = KoerperZiele.lesen(person: .ahmed) { $0.hasPrefix("ziel.prio.") ? 0 : nil }
        XCTAssertEqual(alleNull.prio, MuskelGruppe.standardPrio)
        let z = KoerperZiele.lesen(person: .annika, wert: Beispiel.annikaZiele)
        XCTAssertEqual(z.prio, [.beine, .ruecken, .schulter, .brust, .bizeps])
        XCTAssertEqual(z.saetze[.trizeps], 10)
        XCTAssertFalse(z.leer)
        let nurSaetze = KoerperZiele.lesen(person: .annika) { $0 == "ziel.saetze.beine" ? 14 : nil }
        XCTAssertFalse(nurSaetze.leer)
        XCTAssertEqual(nurSaetze.saetze[.beine], 14)
    }

    // MARK: Doppelte Progression

    func testNaechstesMal() {
        let oben = Beispiel.satz([(20, 12), (20, 12), (20, 12)])
        XCTAssertEqual(KoerperLogik.naechstesMal(oben), .init(kg: 22.5, wdh: 8, mehrGewicht: true))
        let einer = Beispiel.satz([(25, 10), (25, 11), (25, 10)])
        XCTAssertEqual(KoerperLogik.naechstesMal(einer), .init(kg: 25, wdh: 11, mehrGewicht: false))
        let gemischt = Beispiel.satz([(60, 8), (65, 8), (62.5, 7)])
        XCTAssertEqual(KoerperLogik.naechstesMal(gemischt), .init(kg: 65, wdh: 9, mehrGewicht: false))
        let koerper = [PlanSatz(wdh: 10, kg: nil, failure: false), PlanSatz(wdh: 9, kg: nil, failure: false)]
        XCTAssertEqual(KoerperLogik.naechstesMal(koerper), .init(kg: nil, wdh: 10, mehrGewicht: false))
        XCTAssertNil(KoerperLogik.naechstesMal([]))
    }

    func testVorschlagText() {
        XCTAssertEqual(KoerperLogik.vorschlagText(.init(kg: 25, wdh: 11, mehrGewicht: false)), "25 kg × 11. Bei 12 in jedem Satz: 27,5 kg.")
        XCTAssertEqual(KoerperLogik.vorschlagText(.init(kg: 22.5, wdh: 8, mehrGewicht: true)), "Alle Sätze bei 12. Nächstes Mal 22,5 kg × 8.")
        XCTAssertEqual(KoerperLogik.satzText(PlanSatz(wdh: 8, kg: 62.5, failure: false)), "62,5 × 8")
    }

    // MARK: Woche, Bilanz, nächstes Training

    func testWocheBilanzUndPausen() {
        let w = Beispiel.daten(.ahmed, plan: Beispiel.ahmedPlan).streifen
        XCTAssertEqual(w.tage.map(\.kuerzel), ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"])
        XCTAssertEqual(w.tage.map(\.fertig), [true, false, true, false, false, false, false])
        XCTAssertEqual(w.tage[0].personen, [.ahmed, .annika])
        XCTAssertEqual(w.tage[4].heute, true)
        XCTAssertEqual(w.tage[4].planBuchstabe, "O")
        XCTAssertEqual(w.tage[6].planBuchstabe, "B")
        XCTAssertNil(w.tage[0].planBuchstabe)
        XCTAssertEqual(w.bilanz, "Beine 1 von 2 · Oberkörper 1 von 2 · 2 Pausen")
    }

    func testAnnikasWocheZeigtIhreEinheitNichtAhmeds() {
        let w = Beispiel.daten(.annika, plan: Beispiel.annikaPlan).streifen
        XCTAssertEqual(w.tage.map(\.fertig), [true, false, false, false, false, false, false])
        XCTAssertEqual(w.beine, 1)
        XCTAssertEqual(w.oben, 0)
    }

    func testLeereDatenSindEinladend() {
        let d = KoerperDaten.bauen(person: .ahmed, sessions: [:], plan: .leer, wert: { _ in nil }, jetzt: Beispiel.jetzt, katalog: Beispiel.lies)
        XCTAssertTrue(d.streifen.bilanz.hasPrefix("Noch kein Training geplant"))
        XCTAssertNil(d.naechstes)
        XCTAssertEqual(d.urteil.titel, "Frisch wie ein Salat")
        XCTAssertEqual(d.saetze(.brust), 0)
        XCTAssertEqual(d.wort(.brust), "erholt")
        XCTAssertTrue(d.gruppen[.brust]?.uebungen.isEmpty == true)
    }

    func testNaechstesTraining() {
        let d = Beispiel.daten(.ahmed, plan: Beispiel.ahmedPlan)
        XCTAssertEqual(d.naechstes?.titel, "Oben")
        XCTAssertEqual(d.naechstes?.meta, "Heute, 25.9. · 2 Übungen · 6 Sätze · etwa 25 min")
        let ohne = KoerperLogik.naechstes(plan: Beispiel.ahmedPlan, heute: "2026-09-25", heuteFertig: true, faellig: [], katalog: Beispiel.lies)
        XCTAssertEqual(ohne?.titel, "Beine")
        XCTAssertEqual(ohne?.meta.hasPrefix("Sonntag, 27.9."), true)
        XCTAssertNil(KoerperLogik.naechstes(plan: .leer, heute: "2026-09-25", heuteFertig: false, faellig: [], katalog: Beispiel.lies))
    }

    func testArtVonCardioUndUnbekanntemIstNil() {
        XCTAssertNil(KoerperLogik.art(teile: []))
        XCTAssertNil(KoerperLogik.haupt(Beispiel.u("Laufband", "Herz-Kreislauf", koerper: "Cardio")))
        XCTAssertEqual(KoerperLogik.art(teile: [.beQuads, .bePo, .bUnten]), .beine)
        XCTAssertEqual(KoerperLogik.art(teile: [.beQuads, .bUnten]), .oben)
    }

    // MARK: Gruppen und Partner

    func testGruppeZaehltMonatUndInsgesamt() {
        let brust = Beispiel.daten(.ahmed, plan: Beispiel.ahmedPlan).gruppen[.brust]
        XCTAssertEqual(brust?.monat, 1)
        XCTAssertEqual(brust?.gesamt, 2)
        let bank = brust?.uebungen.first { $0.id == "Bankdrücken Langhantel" }
        XCTAssertEqual(bank?.gesamt, 2)
        XCTAssertEqual(bank?.monat, 1)
        XCTAssertEqual(bank?.verlauf.map(\.tag), ["Mo 21.9.", "Mo 31.8."])
        XCTAssertEqual(bank?.verlauf.first?.saetze, "60 × 8 · 65 × 8 · 62,5 × 7 · 60 × 8")
        XCTAssertEqual(bank?.vorschlag, .init(kg: 65, wdh: 9, mehrGewicht: false))
    }

    func testPartnerDatenBleibenGetrennt() {
        let ahmed = Beispiel.daten(.ahmed, plan: Beispiel.ahmedPlan)
        let annika = Beispiel.daten(.annika, plan: Beispiel.annikaPlan)
        XCTAssertGreaterThan(ahmed.saetze(.brust), 0)
        XCTAssertEqual(annika.saetze(.brust), 0)
        XCTAssertGreaterThan(annika.saetze(.beine), 0)
        XCTAssertTrue(annika.gruppen[.brust]?.uebungen.isEmpty == true)
    }

    // MARK: Tafeln

    func testKoerperTafeln() {
        tafel(.ahmed) {
            let daten = Beispiel.daten(.ahmed, plan: Beispiel.ahmedPlan)
            return [
                zelle("Ahmed, Seite", AnyView(KoerperInhalt(daten: daten, animiert: false))),
                zelle("Blatt Brust, Bankdrücken offen", AnyView(KoerperBlatt(daten: daten, gruppe: .brust, teil: .bUnten, animiert: false))),
                zelle("Blatt Beine", AnyView(KoerperBlatt(daten: daten, gruppe: .beine, animiert: false, offen: ["Kniebeuge"]))),
            ]
        }
        tafel(.annika) {
            let ohne = Beispiel.daten(.annika, plan: Beispiel.annikaPlan)
            let mit = Beispiel.daten(.annika, plan: Beispiel.annikaPlan, ziele: Beispiel.annikaZiele)
            return [
                zelle("Annika ohne Ziele", AnyView(KoerperInhalt(daten: ohne, animiert: false))),
                zelle("Annika mit Zielen", AnyView(KoerperInhalt(daten: mit, animiert: false))),
                zelle("Blatt Beine, Po", AnyView(KoerperBlatt(daten: mit, gruppe: .beine, teil: .bePo, animiert: false))),
            ]
        }
    }

    /// Eine Tafel pro Person: `KopfFigur` zeichnet alle außer `Raum.shared.ich` ausgewaschen (offline).
    private func tafel(_ person: Person, _ zellen: () -> [Zelle]) {
        let vorher = Raum.shared.ich
        Raum.shared.ich = person
        defer { Raum.shared.ich = vorher }
        RenderTafel.speichern("koerper-\(person.rawValue)", spalten: 3, zellen: zellen())
    }

    private func zelle(_ titel: String, _ ansicht: AnyView) -> Zelle {
        (titel, AnyView(ansicht
            .frame(width: 358, alignment: .topLeading)
            .padding(16)
            .background(Color.black)
            .environment(\.colorScheme, .dark)))
    }
}
