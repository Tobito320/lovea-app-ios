import UIKit
import XCTest
@testable import Lovea

final class HabitLogikTests: XCTestCase {

    // MARK: - Hilfen

    private func op(_ art: String, _ json: String, von: Person = .ahmed, seq: Int?, id: String = UUID().uuidString, zeit: String = "2026-09-23") -> Op {
        Op(id: id, seq: seq, art: art, von: von, zeit: Datum.datum(zeit), d: Data(json.utf8))
    }

    private func setzen(_ art: String, _ datum: String, _ wert: Int, von: Person = .ahmed, seq: Int?, id: String = UUID().uuidString) -> Op {
        op("habit.setzen", #"{"art":"\#(art)","datum":"\#(datum)","wert":\#(wert)}"#, von: von, seq: seq, id: id, zeit: datum)
    }

    private func gefaltet(_ ops: [Op]) -> HabitFaltung {
        var faltung = HabitFaltung()
        for op in ops { faltung.anwenden(op) }
        return faltung
    }

    private func eigene(_ id: String, name: String = "Lesen", fuer: String = "beide", haeufigkeit: String = #"{"typ":"taeglich"}"#) -> String {
        #"{"id":"\#(id)","name":"\#(name)","symbol":"book.fill","farbe":"indigo","zaehlen":false,"haeufigkeit":\#(haeufigkeit),"fuer":"\#(fuer)"}"#
    }

    /// Days `tage` done (wert 1).
    private func erledigt(_ tage: [String], wert: Int = 1) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: tage.map { ($0, wert) })
    }

    private func habit(_ haeufigkeit: Haeufigkeit, zaehlen: Bool = false, tagesziel: Int? = nil) -> Habit {
        Habit(id: "h-test", name: "Test", symbol: "star.fill", farbe: "amber", zaehlen: zaehlen, tagesziel: tagesziel, haeufigkeit: haeufigkeit, fuer: "beide")
    }

    // MARK: - Review-Fokus 1: alte Gym- und Wasser-Daten

    /// Die 80 FitX-Tage (`fitx:<datum>`), alte App-Ops, Widget-Ops (derselbe Body wie
    /// `WidgetPendingOpsMerge`) und Wasser landen im generischen Speicher auf genau denselben Tagen
    /// wie in der alten Gym-/Wasser-Faltung.
    func testFitxUndAlteOpsErgebenDieselbenTage() {
        let ops = [
            setzen("gym", "2026-01-07", 1, seq: 100, id: "fitx:2026-01-07"),
            setzen("gym", "2026-09-21", 1, seq: 180, id: "fitx:2026-09-21"),
            setzen("gym", "2026-09-22", 1, seq: 300),                         // App-Kreis
            setzen("gym", "2026-09-22", 0, seq: 310),                         // wieder weg
            setzen("gym", "2026-09-23", 1, seq: nil, id: "widget-1"),         // Widget-Warteschlange
            setzen("gym", "2026-09-23", 1, von: .annika, seq: 320),
            setzen("wasser", "2026-09-23", 5, seq: 330),
            setzen("wasser", "2026-09-23", 6, seq: 329),                      // älter, kommt später an
            setzen("h-lesen", "2026-09-23", 1, seq: 340),                     // eigene Habit bleibt getrennt
        ]
        // Alte Faltung: HealthFaltung nach `art` getrennt, wie HealthModell bis Runde 2.
        var altGym: [Person: [String: TagesEintrag<Int>]] = [:]
        var altWasser: [Person: [String: TagesEintrag<Int>]] = [:]
        for op in ops {
            guard let d = op.daten(HabitSetzenD.self) else { continue }
            let eintrag = TagesEintrag(seq: op.seq, von: op.von, datum: d.datum, gesendetAm: Datum.text(op.zeit), wert: d.wert, id: op.id)
            if d.art == "gym" { HealthFaltung.aufnehmen(&altGym, eintrag) } else if d.art == "wasser" { HealthFaltung.aufnehmen(&altWasser, eintrag) }
        }
        let neu = gefaltet(ops)
        for person in Person.allCases {
            XCTAssertEqual(neu.werte["gym"]?[person]?.mapValues(\.wert), altGym[person]?.mapValues(\.wert), "Gym \(person)")
            XCTAssertEqual(neu.werte["wasser"]?[person]?.mapValues(\.wert), altWasser[person]?.mapValues(\.wert), "Wasser \(person)")
        }
        let gym = neu.werte["gym"]?[.ahmed]?.mapValues(\.wert) ?? [:]
        XCTAssertTrue(HabitLogik.erledigt(.gym, wert: gym["2026-01-07"] ?? 0, ziel: 3), "erster FitX-Tag")
        XCTAssertTrue(HabitLogik.erledigt(.gym, wert: gym["2026-09-21"] ?? 0, ziel: 3), "letzter FitX-Tag")
        XCTAssertFalse(HabitLogik.erledigt(.gym, wert: gym["2026-09-22"] ?? 0, ziel: 3), "zurückgenommen")
        XCTAssertTrue(HabitLogik.erledigt(.gym, wert: gym["2026-09-23"] ?? 0, ziel: 3), "Widget-Haken")
        XCTAssertEqual(neu.werte["wasser"]?[.ahmed]?["2026-09-23"]?.wert, 5)
        XCTAssertNil(neu.werte["gym"]?[.ahmed]?["2026-09-24"])
        XCTAssertEqual(neu.werte["h-lesen"]?[.ahmed]?["2026-09-23"]?.wert, 1)
    }

    func testGymUndWasserSindImmerDaUndFest() {
        let faltung = gefaltet([op("habit.aendern", eigene("gym", name: "Umbenannt"), seq: 5)])
        let habits = faltung.habits(ich: .ahmed)
        XCTAssertEqual(habits["gym"], .gym, "eingebaut: keine Op ändert Gym")
        XCTAssertEqual(habits["wasser"], .wasser)
        XCTAssertEqual(faltung.sichtbar(fuer: .annika).map(\.id), ["gym", "wasser"])
    }

    // MARK: - Faltung der Definitionen

    func testAendernHoechsteSeqGewinnt() {
        let id = "h-1"
        let ops = [
            op("habit.anlegen", eigene(id, name: "A"), seq: 5),
            op("habit.aendern", eigene(id, name: "C"), von: .annika, seq: 9),
            op("habit.aendern", eigene(id, name: "B"), seq: 7), // älter, kommt zuletzt an
        ]
        let habit = gefaltet(ops).habits(ich: .ahmed)[id]
        XCTAssertEqual(habit?.name, "C")
        XCTAssertEqual(habit?.von, "annika", "von der gewinnenden Op")
        XCTAssertEqual(gefaltet(ops.reversed()).habits(ich: .ahmed)[id]?.name, "C", "Reihenfolge egal")
    }

    func testEchoDerEigenenOpBekommtSeq() {
        let id = "h-1"
        var faltung = HabitFaltung()
        faltung.anwenden(op("habit.aendern", eigene(id, name: "Neu"), seq: nil, id: "eigen"))
        faltung.anwenden(op("habit.aendern", eigene(id, name: "Neu"), seq: 20, id: "eigen"))
        faltung.anwenden(op("habit.aendern", eigene(id, name: "Partner"), von: .annika, seq: 21))
        XCTAssertEqual(faltung.habits(ich: .ahmed)[id]?.name, "Partner", "bestätigtes Echo ist nicht mehr 'neueste'")
    }

    func testIchHabitNurFuerDenErsteller() {
        let faltung = gefaltet([op("habit.anlegen", eigene("h-geheim", fuer: "ich"), von: .annika, seq: 3)])
        XCTAssertTrue(faltung.sichtbar(fuer: .annika).contains { $0.id == "h-geheim" })
        XCTAssertFalse(faltung.sichtbar(fuer: .ahmed).contains { $0.id == "h-geheim" })
    }

    func testAusgeblendetBehaeltHistorieUndGiltNurFuerDenAbsender() {
        var faltung = gefaltet([
            op("habit.anlegen", eigene("h-1"), seq: 1),
            setzen("h-1", "2026-09-20", 1, seq: 2),
            op("habit.ausblenden", #"{"id":"h-1","aus":true}"#, seq: 3),
            op("habit.ausblenden", #"{"id":"gym","aus":true}"#, von: .annika, seq: 4),
        ])
        XCTAssertFalse(faltung.sichtbar(fuer: .ahmed).contains { $0.id == "h-1" })
        XCTAssertEqual(faltung.habits(ich: .ahmed)["h-1"]?.ausgeblendet, true)
        XCTAssertEqual(faltung.werte["h-1"]?[.ahmed]?["2026-09-20"]?.wert, 1, "Historie bleibt")
        XCTAssertTrue(faltung.sichtbar(fuer: .annika).contains { $0.id == "h-1" }, "Annika hat nichts ausgeblendet")
        XCTAssertFalse(faltung.sichtbar(fuer: .annika).contains { $0.id == "gym" })
        XCTAssertTrue(faltung.sichtbar(fuer: .ahmed).contains { $0.id == "gym" }, "Annika nimmt Ahmed sein Gym nicht weg")

        faltung.anwenden(op("habit.ausblenden", #"{"id":"h-1","aus":false}"#, seq: 5))
        XCTAssertTrue(faltung.sichtbar(fuer: .ahmed).contains { $0.id == "h-1" }, "wieder eingeblendet")
    }

    func testSichtbarSortiertGymWasserDannNachAnlage() {
        let faltung = gefaltet([
            op("habit.anlegen", eigene("h-b", name: "Zweite"), seq: 20),
            op("habit.anlegen", eigene("h-a", name: "Erste"), seq: 10),
            op("habit.aendern", eigene("h-a", name: "Erste neu"), seq: 30),
        ])
        XCTAssertEqual(faltung.sichtbar(fuer: .ahmed).map(\.id), ["gym", "wasser", "h-a", "h-b"])
    }

    // MARK: - JSON

    func testHabitJSONOhneVonUndAusgeblendet() throws {
        var habit = Habit(id: "h-1", name: "Lesen", symbol: "book.fill", farbe: "indigo", zaehlen: true, tagesziel: 20, haeufigkeit: .tage([1, 3, 5]), fuer: "ich")
        habit.von = "ahmed"
        habit.ausgeblendet = true
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: try JSONEncoder().encode(habit)) as? [String: Any])
        XCTAssertNil(json["von"])
        XCTAssertNil(json["ausgeblendet"])
        XCTAssertEqual(json["tagesziel"] as? Int, 20)
        let haeufigkeit = try XCTUnwrap(json["haeufigkeit"] as? [String: Any])
        XCTAssertEqual(haeufigkeit["typ"] as? String, "tage")
        XCTAssertEqual(haeufigkeit["tage"] as? [Int], [1, 3, 5])

        let zurueck = try JSONDecoder().decode(Habit.self, from: try JSONEncoder().encode(habit))
        XCTAssertEqual(zurueck.haeufigkeit, .tage([1, 3, 5]))
        XCTAssertNil(zurueck.von)
        XCTAssertFalse(zurueck.ausgeblendet)
    }

    func testHaeufigkeitJSON() throws {
        func lesen(_ json: String) throws -> Haeufigkeit { try JSONDecoder().decode(Haeufigkeit.self, from: Data(json.utf8)) }
        XCTAssertEqual(try lesen(#"{"typ":"taeglich"}"#), .taeglich)
        XCTAssertEqual(try lesen(#"{"typ":"proWoche","anzahl":4}"#), .proWoche(4))
        XCTAssertEqual(try lesen(#"{"typ":"tage","tage":[2,4]}"#), .tage([2, 4]))
        XCTAssertEqual(try lesen(#"{"typ":"alleZweiTage"}"#), .taeglich, "unbekannt aus einem neueren Build: nicht wegwerfen")
        let text = String(decoding: try JSONEncoder().encode(Haeufigkeit.proWoche(2)), as: UTF8.self)
        XCTAssertTrue(text.contains(#""typ":"proWoche""#) && text.contains(#""anzahl":2"#), text)
    }

    // MARK: - Erledigt

    func testZaehlHabitErledigtAbZiel() {
        XCTAssertFalse(HabitLogik.erledigt(.wasser, wert: 7, ziel: 8))
        XCTAssertTrue(HabitLogik.erledigt(.wasser, wert: 8, ziel: 8))
        XCTAssertTrue(HabitLogik.erledigt(.wasser, wert: 5, ziel: 5), "ziel.wasser überschreibt die 8")
        XCTAssertFalse(HabitLogik.erledigt(.wasser, wert: 7, ziel: nil), "ohne Einstellung gilt tagesziel 8")
        let eigene = habit(.taeglich, zaehlen: true, tagesziel: 3)
        XCTAssertFalse(HabitLogik.erledigt(eigene, wert: 2, ziel: nil))
        XCTAssertTrue(HabitLogik.erledigt(eigene, wert: 3, ziel: nil))
        XCTAssertEqual(HabitLogik.anteil(.wasser, wert: 4, ziel: 8), 0.5)
        XCTAssertEqual(HabitLogik.anteil(.wasser, wert: 12, ziel: 8), 1)
        XCTAssertEqual(HabitLogik.anteil(.gym, wert: 1, ziel: 3), 1)
    }

    // MARK: - Serien (Spec 3.3)

    func testSerieTaeglichUndHeuteOffenBrichtNicht() {
        let h = habit(.taeglich)
        let werte = erledigt(["2026-09-19", "2026-09-20", "2026-09-21", "2026-09-22"])
        XCTAssertEqual(HabitLogik.serie(h, werte: werte, ziel: nil, heute: "2026-09-23"), 4, "heute noch offen")
        var mitHeute = werte
        mitHeute["2026-09-23"] = 1
        XCTAssertEqual(HabitLogik.serie(h, werte: mitHeute, ziel: nil, heute: "2026-09-23"), 5)
        XCTAssertEqual(HabitLogik.serie(h, werte: werte, ziel: nil, heute: "2026-09-24"), 0, "gestern verpasst")
        var luecke = werte
        luecke["2026-09-20"] = nil
        XCTAssertEqual(HabitLogik.serie(h, werte: luecke, ziel: nil, heute: "2026-09-23"), 2)
        XCTAssertEqual(HabitLogik.besteSerie(h, werte: luecke, ziel: nil, heute: "2026-09-23"), 2)
        XCTAssertEqual(HabitLogik.besteSerie(h, werte: werte, ziel: nil, heute: "2026-09-23"), 4)
    }

    /// "x pro Woche" zählt Wochen am Stück mit erreichtem Ziel, über Wochengrenzen; die laufende
    /// Woche zählt erst ab Ziel, bricht vorher aber nichts. Gym-Ziel kommt aus `ziel.gym`.
    func testSerieProWocheUeberWochengrenzen() {
        let werte = erledigt([
            "2026-08-31", "2026-09-02", "2026-09-04",   // KW 36: 3
            "2026-09-07", "2026-09-08", "2026-09-13",   // KW 37: 3 (inkl. Sonntag)
            "2026-09-14", "2026-09-16", "2026-09-17",   // KW 38: 3
            "2026-09-21",                               // KW 39 (läuft): 1
        ])
        XCTAssertEqual(HabitLogik.serie(.gym, werte: werte, ziel: 3, heute: "2026-09-23"), 3, "laufende Woche offen")
        var fertig = werte
        fertig["2026-09-22"] = 1
        fertig["2026-09-23"] = 1
        XCTAssertEqual(HabitLogik.serie(.gym, werte: fertig, ziel: 3, heute: "2026-09-23"), 4)
        XCTAssertEqual(HabitLogik.serie(.gym, werte: werte, ziel: 4, heute: "2026-09-23"), 0, "Ziel 4 in keiner Woche")
        XCTAssertEqual(HabitLogik.serie(.gym, werte: werte, ziel: 3, heute: "2026-09-28"), 0, "KW 39 mit 1 Tag abgeschlossen")
        XCTAssertEqual(HabitLogik.besteSerie(.gym, werte: werte, ziel: 3, heute: "2026-09-28"), 3)
    }

    func testSerieFesteTage() {
        let h = habit(.tage([1, 3, 5])) // Mo, Mi, Fr
        let werte = erledigt(["2026-09-16", "2026-09-18", "2026-09-21", "2026-09-22", "2026-09-23"]) // Mi, Fr, Mo, Di (kein Soll-Tag), Mi
        XCTAssertEqual(HabitLogik.serie(h, werte: werte, ziel: nil, heute: "2026-09-25"), 4, "Fr heute offen; Di zählt nicht mit")
        XCTAssertEqual(HabitLogik.serie(h, werte: werte, ziel: nil, heute: "2026-09-26"), 0, "Fr verpasst")
        var ohneMo = werte
        ohneMo["2026-09-21"] = nil
        XCTAssertEqual(HabitLogik.serie(h, werte: ohneMo, ziel: nil, heute: "2026-09-24"), 1, "nur Mi, der Mo davor fehlt")
    }

    func testZaehlHabitSerieAbZiel() {
        let werte = ["2026-09-21": 8, "2026-09-22": 9, "2026-09-23": 3]
        XCTAssertEqual(HabitLogik.serie(.wasser, werte: werte, ziel: 8, heute: "2026-09-23"), 2, "heute erst 3 von 8: offen")
        XCTAssertEqual(HabitLogik.serie(.wasser, werte: werte, ziel: 3, heute: "2026-09-23"), 3)
    }

    /// Europe/Berlin, Zeitumstellung am 25.10.2026 (Sonntag): Tage und Wochen bleiben ganz.
    func testSerieUndWocheUeberDieZeitumstellung() {
        let taeglich = habit(.taeglich)
        let tage = erledigt(["2026-10-24", "2026-10-25", "2026-10-26"])
        XCTAssertEqual(HabitLogik.serie(taeglich, werte: tage, ziel: nil, heute: "2026-10-26"), 3)
        XCTAssertEqual(HabitLogik.wochenTage(heute: "2026-10-25"), ["2026-10-19", "2026-10-20", "2026-10-21", "2026-10-22", "2026-10-23", "2026-10-24", "2026-10-25"])
        XCTAssertEqual(HabitLogik.wochenTage(heute: "2026-10-26").first, "2026-10-26")
        let wochen = erledigt(["2026-10-20", "2026-10-22", "2026-10-25", "2026-10-26", "2026-10-28", "2026-10-30"])
        XCTAssertEqual(HabitLogik.serie(.gym, werte: wochen, ziel: 3, heute: "2026-11-01"), 2, "KW 43 und KW 44")
    }

    func testQuote30() {
        let h = habit(.taeglich)
        let heute = "2026-09-30"
        let alle = erledigt((0..<30).map { Datum.addTage(heute, -$0) })
        XCTAssertEqual(HabitLogik.quote30(h, werte: alle, ziel: nil, heute: heute), 1)
        var ohneHeute = alle
        ohneHeute[heute] = nil
        XCTAssertEqual(HabitLogik.quote30(h, werte: ohneHeute, ziel: nil, heute: heute), 1, "heute offen zählt nicht dagegen")
        XCTAssertEqual(HabitLogik.quote30(h, werte: [:], ziel: nil, heute: heute), 0)
        let zwoelf = erledigt((0..<12).map { Datum.addTage(heute, -$0 * 2) })
        XCTAssertEqual(HabitLogik.quote30(.gym, werte: zwoelf, ziel: 3, heute: heute), 12 / (3 * 30 / 7.0), accuracy: 0.0001)
    }

    // MARK: - Texte und Symbole

    func testHaeufigkeitText() {
        XCTAssertEqual(HabitLogik.haeufigkeitText(.gym, ziel: 3), "3 Tage/Woche")
        XCTAssertEqual(HabitLogik.haeufigkeitText(.gym, ziel: 1), "1 Tag/Woche")
        XCTAssertEqual(HabitLogik.haeufigkeitText(.wasser, ziel: 8), "jeden Tag")
        XCTAssertEqual(HabitLogik.haeufigkeitText(habit(.tage([5, 1, 3])), ziel: nil), "Mo, Mi, Fr")
        XCTAssertEqual(HabitLogik.haeufigkeitText(habit(.tage(Array(1...7))), ziel: nil), "jeden Tag")
    }

    func testVierzigSymboleGibtEsWirklich() {
        XCTAssertEqual(HabitSymbole.alle.count, 40)
        XCTAssertEqual(Set(HabitSymbole.alle).count, 40)
        for name in HabitSymbole.alle { XCTAssertNotNil(UIImage(systemName: name), name) }
        XCTAssertTrue(HabitSymbole.alle.contains(Habit.gym.symbol))
        XCTAssertTrue(HabitSymbole.alle.contains(Habit.wasser.symbol))
    }
}
