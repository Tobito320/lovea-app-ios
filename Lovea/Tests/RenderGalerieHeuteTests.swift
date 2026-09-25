import SwiftUI
import XCTest
@testable import Lovea

/// Plan Task 8: Akku-Formel als Test, Render-Tafeln für den Tab Heute mit Beispielwerten.
@MainActor
final class RenderGalerieHeuteTests: XCTestCase {
    // MARK: - Akku

    private func form(schlaf: Int?, wasser: Int, schritte: Int?, erholung: Double) -> Tagesform {
        TagesformLogik.tagesform(schlafMinuten: schlaf, wasser: wasser, wasserZiel: 8, schritte: schritte,
                                 schritteZiel: 10_000, erholung: erholung)
    }

    func testAkkuVollGeladen() {
        let f = form(schlaf: 480, wasser: 8, schritte: 10_000, erholung: 1)
        XCTAssertEqual(f.akku, 100)
        XCTAssertEqual(f.urteil, "Voll geladen")
        XCTAssertEqual(f.satz, "Alles im grünen Bereich. So bleibt es.")
    }

    func testAkkuGewichtung() {
        // Je die Hälfte: 0,5 · (0,4 + 0,2 + 0,15 + 0,25) = 50, Gleichstand bremst der Schlaf.
        let f = form(schlaf: 240, wasser: 4, schritte: 5000, erholung: 0.5)
        XCTAssertEqual(f.akku, 50)
        XCTAssertEqual(f.urteil, "Halb leer")
        XCTAssertTrue(f.satz.hasPrefix("Schlaf bremst"))
    }

    func testAkkuBremstWasser() {
        let f = form(schlaf: 480, wasser: 2, schritte: 10_000, erholung: 1)
        XCTAssertEqual(f.akku, 85)
        XCTAssertEqual(f.satz, "Wasser bremst dich: noch 6 Gläser bis zum Ziel.")
    }

    func testAkkuSparmodusUndGrenzen() {
        let f = form(schlaf: 0, wasser: 0, schritte: 0, erholung: 0)
        XCTAssertEqual(f.akku, 0)
        XCTAssertEqual(f.urteil, "Sparmodus")
        // 70 = Gut geladen: Schlaf voll (40) + Erholung voll (25) + Wasser halb (10) = 75 → schritte 0.
        XCTAssertEqual(form(schlaf: 480, wasser: 4, schritte: 0, erholung: 1).urteil, "Gut geladen")
        // Werte über dem Ziel zählen nicht mehr als das Ziel.
        XCTAssertEqual(form(schlaf: 900, wasser: 20, schritte: 50_000, erholung: 3).akku, 100)
    }

    func testAkkuOhneDatenIstLeer() {
        XCTAssertNil(form(schlaf: nil, wasser: 0, schritte: nil, erholung: 1).akku)
        // Schon ein Glas Wasser reicht für eine Rechnung.
        XCTAssertNotNil(form(schlaf: nil, wasser: 1, schritte: nil, erholung: 1).akku)
    }

    func testErholungMittel() {
        XCTAssertEqual(TagesformLogik.erholungMittel([:]), 1)
        let eins = TagesformLogik.erholungMittel([.bOben: 0])
        XCTAssertEqual(eins, Double(MuskelTeil.allCases.count - 1) / Double(MuskelTeil.allCases.count), accuracy: 0.0001)
    }

    // MARK: - Schlaf gegen Leistung

    private func session(_ tag: String, _ uebung: String, kg: Double, wdh: Int = 5, fertig: Bool = true) -> GymSession {
        let start = Datum.datum(tag).addingTimeInterval(18 * 3600)
        let lauf = UebungsLauf(plan: "p", uebung: uebung, start: nil, ende: start, fertig: fertig,
                               saetze: [PlanSatz(wdh: wdh, kg: kg, failure: false)])
        return GymSession(id: tag, tag: nil, start: start, ende: nil, laeufe: [lauf])
    }

    func testSchlafPunkte() {
        let sessions = [session("2026-09-01", "bank", kg: 80), session("2026-09-03", "bank", kg: 70),
                        session("2026-09-05", "bank", kg: 80), session("2026-09-07", PlanUebung.eigen, kg: 20)]
        let schlaf = ["2026-09-01": 420, "2026-09-03": 300, "2026-09-07": 480]
        let p = SchlafLeistung.punkte(sessions, schlafMinuten: schlaf)
        // 5. ohne Schlafdaten und die eigene Übung fallen weg.
        XCTAssertEqual(p.map(\.id), ["2026-09-01", "2026-09-03"])
        XCTAssertEqual(p[0].stunden, 7, accuracy: 0.0001)
        XCTAssertEqual(p[0].leistung, 100, accuracy: 0.0001)
        XCTAssertEqual(p[1].stunden, 5, accuracy: 0.0001)
        XCTAssertEqual(p[1].leistung, 87.5, accuracy: 0.0001)
    }

    func testSchlafPunkteLeer() {
        XCTAssertTrue(SchlafLeistung.punkte([], schlafMinuten: [:]).isEmpty)
        XCTAssertTrue(SchlafLeistung.punkte([session("2026-09-01", "bank", kg: 80)], schlafMinuten: [:]).isEmpty)
    }

    // MARK: - Tafeln

    private func zelle(_ titel: String, _ ansicht: some View, breite: CGFloat = 360) -> (titel: String, ansicht: AnyView) {
        (titel, AnyView(ansicht.frame(width: breite).padding(8).background(Color.black).environment(\.colorScheme, .dark)))
    }

    func testHeuteTagesformTafel() {
        let faelle: [(String, Tagesform)] = [
            ("voll geladen", form(schlaf: 470, wasser: 8, schritte: 10_400, erholung: 0.95)),
            ("gut geladen", form(schlaf: 420, wasser: 5, schritte: 6400, erholung: 0.8)),
            ("halb leer", form(schlaf: 330, wasser: 3, schritte: 4000, erholung: 0.6)),
            ("sparmodus", form(schlaf: 240, wasser: 1, schritte: 800, erholung: 0.3)),
            ("noch leer", form(schlaf: nil, wasser: 0, schritte: nil, erholung: 1)),
        ]
        RenderTafel.speichern("heute-tagesform", spalten: 2, zellen: faelle.map {
            zelle($0.0, TagesformKarte(person: .ahmed, form: $0.1, animiert: false))
        })
    }

    private func kachel(_ f: TagesForm, _ titel: String, _ wert: String, _ einheit: String, _ q: Double,
                        zusatz: String? = nil, stimmung: Int? = nil) -> FormKachel {
        FormKachel(form: f, titel: titel, wert: wert, einheit: einheit, fuellung: q, zusatz: zusatz, stimmung: stimmung)
    }

    func testHeuteTagTafel() {
        // ponytail: Grid statt LazyVGrid, ImageRenderer zeichnet Lazy-Container nicht sicher.
        let raster = Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                kachel(.schritte, "Schritte", "6.400", "", 0.64, zusatz: "Ziel 10.000")
                kachel(.wasser, "Wasser", "5", "/8 Gl.", 0.62)
                kachel(.schlaf, "Schlaf", "7,1", "/8 h", 0.89)
            }
            GridRow {
                kachel(.habits, "Habits", "3", "/5", 0.6)
                kachel(.stimmung, "Stimmung", "Gut", "", 1, stimmung: 3)
                kachel(.koffein, "Koffein", "2", "Tassen", 0.5)
            }
            GridRow {
                kachel(.protein, "Protein", "offen", "", 0)
                kachel(.gewicht, "Gewicht", "78,4", "kg", 0, zusatz: "−0,3 kg")
                kachel(.training, "Training", "Gym", "", 1)
            }
        }
        RenderTafel.speichern("heute-tag", spalten: 1, zellen: [zelle("dein tag", raster)])
    }

    func testHeuteHinweiseTafel() {
        let punkte = [(5.2, 86.0), (5.6, 88), (5.8, 90), (5.9, 87), (6.3, 95), (6.6, 97), (6.8, 96), (7.0, 99), (7.2, 100),
                      (7.4, 98), (7.6, 101), (7.9, 102), (8.1, 100), (8.4, 103)]
            .enumerated().map { SchlafPunkt(id: "\($0.offset)", stunden: $0.element.0, leistung: $0.element.1) }
        let still = Hinweis(id: "stillstand.bank", art: .stillstand, titel: "Bankdrücken steht still", zahl: "82,5 kg",
                            text: "Seit 3 Einheiten kein Plus bei geschätzten 82,5 kg.",
                            tipp: "3 Wochen lang 3 × 6 mit +2,5 kg, oder eine leichte Woche.",
                            basis: "Geschätztes Maximum nach Epley, bestes Set je Einheit, 5 Einheiten.", fortschritt: nil)
        let schlaf = Hinweis(id: "schlaf", art: .schlaf, titel: "Schlaf bremst dich", zahl: "9 %",
                             text: "Nach kurzen Nächten trainierst du im Schnitt 9 % schwächer.",
                             tipp: "Vor einer kurzen Nacht die Last etwas senken oder einen Satz weglassen.",
                             basis: "Einheiten nach Nächten unter 6 h gegen Einheiten nach mindestens 7 h, je mindestens 4.",
                             fortschritt: nil)
        let wasser = Hinweis(id: "wasser", art: .wasser, titel: "Wenig Wasser beim Training", zahl: "−1,5 Gläser",
                             text: "An Gym-Tagen trinkst du 1,5 Gläser weniger als an Ruhetagen.",
                             tipp: "Eine Flasche mit ins Gym nehmen.", basis: "Mittelwert je mindestens 5 Tage.", fortschritt: nil)
        let vergessen = Hinweis(id: "vergessen.beine", art: .vergessen, titel: "Beine vergessen?", zahl: "9 Tage",
                                text: "Beine hatte seit 9 Tagen keinen Satz.", tipp: "Nimm eine Beinübung in die nächste Einheit.",
                                basis: "Prio-Gruppe ohne Satz seit mindestens 8 Tagen.", fortschritt: nil)
        let gesperrt = Hinweis(id: "gesperrt.koffein", art: .gesperrt, titel: "Koffein gegen Schlaf", zahl: "5/14",
                               text: "Noch 9 Tage, dann vergleiche ich Koffein mit deinem Schlaf.",
                               tipp: "Zähl deinen Kaffee unter Heute mit.", basis: "Braucht 14 Tage mit beiden Werten.",
                               fortschritt: 5.0 / 14)
        RenderTafel.speichern("heute-hinweise", spalten: 2, zellen: [
            zelle("stillstand offen", HinweisKarte(hinweis: still, offen: true) {}),
            zelle("schlaf offen mit diagramm", HinweisKarte(hinweis: schlaf, punkte: punkte, offen: true) {}),
            zelle("wasser zu", HinweisKarte(hinweis: wasser, offen: false) {}),
            zelle("vergessen zu", HinweisKarte(hinweis: vergessen, offen: false) {}),
            zelle("gesperrt", HinweisKarte(hinweis: gesperrt, offen: false) {}),
        ])
    }
}
