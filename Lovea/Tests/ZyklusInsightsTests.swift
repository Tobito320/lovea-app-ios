import SwiftUI
import XCTest
@testable import Lovea

final class ZyklusInsightsTests: XCTestCase {
    private let heute = "2026-10-04"

    private func plus(_ tag: String, _ n: Int) -> String {
        Datum.text(Datum.kalender.date(byAdding: .day, value: n, to: Datum.datum(tag))!)
    }

    private func verlauf(_ laengen: [Int]) -> (tage: [ZyklusTag], letzterStart: String) {
        var start = "2026-01-01"
        var tage = (0..<5).map { ZyklusTag(id: plus(start, $0), blutung: .mittel) }
        for l in laengen {
            start = plus(start, l)
            tage += (0..<5).map { ZyklusTag(id: plus(start, $0), blutung: .mittel) }
        }
        return (tage, start)
    }

    private func insights(_ laengen: [Int], tageNachStart: Int = 3) -> ZyklusInsightsLogik {
        let v = verlauf(laengen)
        return ZyklusInsightsLogik(tage: v.tage, heute: plus(v.letzterStart, tageNachStart))
    }

    private func demo() -> ZyklusInsightsLogik {
        ZyklusInsightsLogik(tage: Array(ZyklusDemoDaten.tage(heute: heute).values), einstellung: ZyklusDemoDaten.einstellung, heute: heute)
    }

    func testLeerHatNichtsUndSagtZuFrueh() {
        let i = ZyklusInsightsLogik(tage: [], heute: heute)
        XCTAssertFalse(i.hatZyklen)
        XCTAssertEqual(i.zyklusVerlauf(), [])
        XCTAssertEqual(i.regelmaessigkeit, .zuWenigDaten)
        XCTAssertEqual(i.temperaturKurve, [])
        XCTAssertEqual(i.auffaelligkeiten, [])
        XCTAssertEqual(i.haeufigsteSymptome(in: .periode), [])
    }

    func testVerlaufBegrenztAufDieLetztenZyklen() {
        let i = insights(Array(repeating: 28, count: 10))
        XCTAssertEqual(i.zyklusVerlauf(maximal: 8).count, 8)
        XCTAssertEqual(i.zyklusVerlauf(maximal: 3), [28, 28, 28])
    }

    func testRegelmaessigkeitStufen() {
        XCTAssertEqual(insights([28, 28]).regelmaessigkeit, .zuWenigDaten)
        XCTAssertEqual(insights([28, 29, 28]).regelmaessigkeit, .sehrRegelmaessig)
        XCTAssertEqual(insights([28, 31, 27]).regelmaessigkeit, .regelmaessig)
        XCTAssertEqual(insights([24, 34, 28]).regelmaessigkeit, .wechselhaft)
    }

    func testAuffaelligkeiten() {
        XCTAssertEqual(insights([24, 22, 20]).auffaelligkeiten.map(\.art), [.sehrKurz])
        XCTAssertEqual(insights([34, 36, 35]).auffaelligkeiten.map(\.art), [.sehrLang])
        XCTAssertEqual(insights([28, 28, 28]).auffaelligkeiten, [])
        let streuung = insights([22, 34, 28]).auffaelligkeiten.map(\.art)
        XCTAssertTrue(streuung.contains(.starkeStreuung))
    }

    func testAusgeblieben() {
        let v = verlauf([28, 28, 28])
        let i = ZyklusInsightsLogik(tage: v.tage, heute: plus(v.letzterStart, 28 + 8))
        XCTAssertEqual(i.auffaelligkeiten.map(\.art), [.ausgeblieben])
        let frueh = ZyklusInsightsLogik(tage: v.tage, heute: plus(v.letzterStart, 28 + 3))
        XCTAssertEqual(frueh.auffaelligkeiten, [])
    }

    func testArztHinweisNenntKeinenErsatz() {
        XCTAssertTrue(ZyklusInsightsLogik.arztHinweis.contains("kein Ersatz für ärztlichen Rat"))
    }

    func testDemoZahlen() {
        let i = demo()
        XCTAssertEqual(i.zyklusVerlauf(), ZyklusDemoDaten.zyklusLaengen)
        XCTAssertEqual(i.mittlereZyklusLaenge, 28)
        XCTAssertEqual(i.streuung, 4)
        XCTAssertEqual(i.mittlerePeriodenLaenge, 5)
        XCTAssertEqual(i.regelmaessigkeit, .regelmaessig)
        XCTAssertEqual(i.auffaelligkeiten, [])
    }

    func testDemoSymptomeUndStimmungJePhase() {
        let i = demo()
        XCTAssertEqual(i.haeufigsteSymptome(in: .periode).first?.wert, .kraempfe)
        XCTAssertEqual(i.haeufigsteStimmung(in: .fruchtbar).first?.wert, .energiegeladen)
        XCTAssertLessThanOrEqual(i.haeufigsteSymptome(in: .luteal, maximal: 2).count, 2)
        let anzahlen = i.haeufigsteSymptome(in: .periode).map(\.anzahl)
        XCTAssertEqual(anzahlen, anzahlen.sorted(by: >))
    }

    func testRangBeiGleichstandNachName() {
        let start = "2026-03-01"
        let tage = [ZyklusTag(id: start, blutung: .mittel, symptome: [.kraempfe, .akne])]
        let i = ZyklusInsightsLogik(tage: tage, heute: start)
        XCTAssertEqual(i.haeufigsteSymptome(in: .periode).map(\.wert), [.akne, .kraempfe])
    }

    func testTemperaturKurveNurLaufenderZyklusAufsteigend() {
        let v = verlauf([28, 28])
        var tage = v.tage
        tage.append(ZyklusTag(id: plus(v.letzterStart, -10), temperatur: 36.3))
        tage.append(ZyklusTag(id: plus(v.letzterStart, 8), temperatur: 36.5))
        tage.append(ZyklusTag(id: plus(v.letzterStart, 6), temperatur: 36.4))
        let i = ZyklusInsightsLogik(tage: tage, heute: plus(v.letzterStart, 10))
        XCTAssertEqual(i.temperaturKurve, [.init(zyklusTag: 7, grad: 36.4), .init(zyklusTag: 9, grad: 36.5)])
    }

    func testDemoTemperaturKurve() {
        let k = demo().temperaturKurve
        XCTAssertEqual(k.count, 5)
        XCTAssertEqual(k.map(\.zyklusTag), k.map(\.zyklusTag).sorted())
    }

    func testWissenFuerJedePhaseVollstaendigOhneEmoji() {
        for p in Phase.allCases {
            let k = ZyklusWissen.karte(fuer: p)
            for text in [k.titel, k.kurz, k.ernaehrung, k.sport, k.schlaf, k.stimmung] {
                XCTAssertFalse(text.isEmpty)
                XCTAssertTrue(text.unicodeScalars.allSatisfy { $0.value < 0x1F000 })
            }
        }
    }
}

/// Render boards for the Zyklus insights with the demo data, light and dark.
@MainActor
final class RenderGalerieZyklusInsightsTests: XCTestCase {
    private func tafel(_ schema: ColorScheme) -> [(titel: String, ansicht: AnyView)] {
        let heute = "2026-10-04"
        let auswertung = ZyklusInsightsLogik(tage: Array(ZyklusDemoDaten.tage(heute: heute).values),
                                             einstellung: ZyklusDemoDaten.einstellung, heute: heute)
        let ansicht = ZyklusInsightsInhalt(auswertung: auswertung, scrollt: false)
            .frame(width: 390)
            .environment(\.colorScheme, schema)
        return [("Insights, \(schema == .light ? "hell" : "dunkel")", AnyView(ansicht))]
    }

    func testInsightsHell() {
        RenderTafel.speichern("zyklus-insights-hell", spalten: 1, zellen: tafel(.light))
    }

    func testInsightsDunkel() {
        RenderTafel.speichern("zyklus-insights-dunkel", spalten: 1, zellen: tafel(.dark))
    }
}
