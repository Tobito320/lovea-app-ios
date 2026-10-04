import SwiftUI
import XCTest
@testable import Lovea

@MainActor
private final class TestSpeicher: ZyklusSpeicher {
    var quelle: ZyklusQuelle = .echt
    var tage: [String: ZyklusTag] = [:]
    var einstellung = ZyklusEinstellung()
    func setze(_ tag: ZyklusTag) {
        if tag.istLeer { tage[tag.id] = nil } else { tage[tag.id] = tag }
    }
}

@MainActor
final class ZyklusEintragTests: XCTestCase {
    func testLeererEntwurfIstLeererTag() {
        XCTAssertTrue(ZyklusEintragEntwurf(id: "2026-10-04").tag.istLeer)
    }

    func testRundreiseTagEntwurfTag() {
        let tag = ZyklusTag(id: "2026-10-04", blutung: .mittel, symptome: [.akne, .kraempfe], stimmung: [.ruhig],
                            ausfluss: .cremig, temperatur: 36.55, eisprungTest: .positiv, schwangerschaftsTest: .negativ,
                            sex: .geschuetzt, pille: false, wasserMl: 1500, schlafMin: 450, gewicht: 58.5, notiz: "Süß")
        XCTAssertEqual(ZyklusEintragEntwurf(id: tag.id, tag: tag).tag, tag)
    }

    func testKommaUndPunktGeltenGleich() {
        XCTAssertEqual(ZyklusEintragEntwurf.zahl("36,6"), 36.6)
        XCTAssertEqual(ZyklusEintragEntwurf.zahl(" 36.6 "), 36.6)
        XCTAssertNil(ZyklusEintragEntwurf.zahl(""))
        XCTAssertNil(ZyklusEintragEntwurf.zahl("abc"))
        XCTAssertNil(ZyklusEintragEntwurf.zahl("0"))
        XCTAssertNil(ZyklusEintragEntwurf.zahl("-3"))
    }

    func testZahlText() {
        XCTAssertEqual(ZyklusEintragEntwurf.text(36.6, stellen: 2), "36,6")
        XCTAssertEqual(ZyklusEintragEntwurf.text(58, stellen: 1), "58")
        XCTAssertEqual(ZyklusEintragEntwurf.text(nil, stellen: 1), "")
    }

    func testNotizNurLeerzeichenWirdNil() {
        var entwurf = ZyklusEintragEntwurf(id: "2026-10-04")
        entwurf.notiz = "  \n "
        XCTAssertNil(entwurf.tag.notiz)
        XCTAssertTrue(entwurf.tag.istLeer)
    }

    func testSchritt() {
        XCTAssertEqual(ZyklusEintragEntwurf.schritt(nil, delta: 250, grenze: 6000), 250)
        XCTAssertNil(ZyklusEintragEntwurf.schritt(250, delta: -250, grenze: 6000))
        XCTAssertNil(ZyklusEintragEntwurf.schritt(nil, delta: -250, grenze: 6000))
        XCTAssertEqual(ZyklusEintragEntwurf.schritt(5900, delta: 250, grenze: 6000), 6000)
    }

    func testFertigSchreibtInSpeicher() {
        let speicher = TestSpeicher()
        var entwurf = ZyklusEintragEntwurf(id: "2026-10-04", tag: speicher.tage["2026-10-04"])
        entwurf.symptome = [.kopfschmerzen]
        entwurf.speichern(in: speicher)
        XCTAssertEqual(speicher.tage["2026-10-04"]?.symptome, [.kopfschmerzen])
    }

    func testAbbrechenLaesstSpeicherUnveraendert() {
        let speicher = TestSpeicher()
        speicher.setze(ZyklusTag(id: "2026-10-04", blutung: .leicht))
        var entwurf = ZyklusEintragEntwurf(id: "2026-10-04", tag: speicher.tage["2026-10-04"])
        entwurf.blutung = .stark
        XCTAssertEqual(speicher.tage["2026-10-04"]?.blutung, .leicht)
    }

    func testLeerenEntferntTag() {
        let speicher = TestSpeicher()
        speicher.setze(ZyklusTag(id: "2026-10-04", blutung: .leicht))
        var entwurf = ZyklusEintragEntwurf(id: "2026-10-04", tag: speicher.tage["2026-10-04"])
        entwurf.blutung = nil
        entwurf.speichern(in: speicher)
        XCTAssertNil(speicher.tage["2026-10-04"])
    }

    func testRenderTafelEintragBlatt() {
        let gefuellt = ZyklusEintragEntwurf(id: "2026-10-04", tag: ZyklusTag(
            id: "2026-10-04", blutung: .leicht, symptome: [.kraempfe, .muedigkeit], stimmung: [.ruhig],
            ausfluss: .cremig, temperatur: 36.6, pille: true, wasserMl: 1500, schlafMin: 450, gewicht: 58.5, notiz: "Warmer Tee hat gut getan."))
        func zelle(_ titel: String, _ entwurf: ZyklusEintragEntwurf, _ schema: ColorScheme) -> (titel: String, ansicht: AnyView) {
            let ansicht = ZStack {
                ZyklusHintergrund(deko: false)
                ZyklusEintragInhalt(entwurf: .constant(entwurf), datum: "2026-10-04", fuerBild: true)
            }
            .frame(width: 380)
            .environment(\.colorScheme, schema)
            return (titel, AnyView(ansicht))
        }
        RenderTafel.speichern("zyklus-eintrag-blatt", spalten: 3, zellen: [
            zelle("leer, hell", ZyklusEintragEntwurf(id: "2026-10-04"), .light),
            zelle("gefüllt, hell", gefuellt, .light),
            zelle("gefüllt, dunkel", gefuellt, .dark),
        ])
    }
}
