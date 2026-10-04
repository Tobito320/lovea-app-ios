import XCTest
@testable import Lovea

@MainActor
final class EinstellungTests: XCTestCase {
    private let liste = EinstellHinweise.laden(Bundle(for: EinstellGedaechtnis.self))

    private func frischesGedaechtnis() -> EinstellGedaechtnis {
        let name = "einstellung-test-\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return EinstellGedaechtnis(defaults: UserDefaults(suiteName: name)!)
    }

    func testHinweiseDateiIstImBundle() {
        XCTAssertGreaterThanOrEqual(liste.count, 8)
    }

    func testSchraegbankHatLehne15Bis30UndFitxStufe3Unsicher() throws {
        let h = try XCTUnwrap(EinstellHinweise.finden(name: "Schrägbankdrücken mit Kurzhanteln", in: liste))
        XCTAssertTrue(h.einstellung.contains("15 bis 30 Grad"))
        XCTAssertTrue(h.einstellung.contains("45 Grad"))
        XCTAssertTrue(h.einstellung.contains("Wasserwaage"))
        let tipp = try XCTUnwrap(h.tipps(fuer: .fitxHagenMitte).first)
        XCTAssertTrue(tipp.text.contains("Stufe 3"))
        XCTAssertTrue(tipp.unsicher)
        XCTAssertTrue(h.tipps(fuer: .absolutFit).isEmpty)
    }

    func testSchraegbankFlachbankUndCurlsWerdenGetrennt() throws {
        let schraeg = try XCTUnwrap(EinstellHinweise.finden(name: "Schrägbankdrücken mit Langhantel", in: liste))
        let flach = try XCTUnwrap(EinstellHinweise.finden(name: "Bankdrücken mit Langhantel", in: liste))
        XCTAssertNotEqual(schraeg, flach)
        XCTAssertNil(EinstellHinweise.finden(name: "Curls einarmig stehend über der Schrägbank mit Kurzhantel", in: liste))
    }

    func testSchraegbankMaschineIstUnsicher() throws {
        let h = try XCTUnwrap(EinstellHinweise.finden(name: "Schrägbankdrücken an der Maschine", in: liste))
        XCTAssertTrue(h.unsicher)
    }

    func testAufrechtesRudernUndDonkeyBekommenKeinenGeraeteHinweis() {
        XCTAssertNil(EinstellHinweise.finden(name: "Aufrechtes Rudern mit Langhantel", in: liste))
        XCTAssertNil(EinstellHinweise.finden(name: "Donkey-Wadenheben an der Maschine", in: liste))
        XCTAssertNotNil(EinstellHinweise.finden(name: "Wadenheben sitzend an der Maschine", in: liste))
    }

    func testGeraeteUebungenHabenHinweise() {
        for name in ["Beinpresse 45°", "Latzug am Kabelzug", "Beinstrecker an der Maschine", "Beinbeuger liegend an der Maschine", "Brustpresse an der Maschine", "Schulterdrücken an der Maschine"] {
            XCTAssertNotNil(EinstellHinweise.finden(name: name, in: liste), name)
        }
    }

    func testUnbekannteUebungOhneAbsturz() {
        XCTAssertNil(EinstellHinweise.finden(name: "Xyz Unbekannt", in: liste))
        XCTAssertNil(EinstellHinweise.finden(name: "", in: liste))
        XCTAssertNil(EinstellHinweise.finden(name: "Bankdrücken", in: []))
    }

    func testStudioStandardJePerson() {
        XCTAssertEqual(GymStudio.standard(.ahmed), .fitxHagenMitte)
        XCTAssertEqual(GymStudio.standard(.annika), .absolutFit)
        XCTAssertEqual(GymStudio.fitxHagenMitte.name, "FitX Hagen Mitte")
        XCTAssertEqual(GymStudio.absolutFit.name, "Absolut Fit")
    }

    func testGedaechtnisSpeichertLaedtUndUeberschreibt() {
        let name = "einstellung-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        let g = EinstellGedaechtnis(defaults: defaults)
        XCTAssertNil(g.werte(.ahmed, .fitxHagenMitte, uebung: "3TZduzM"))

        g.setzen(EinstellWerte(bankstufe: 3, sitzhoehe: 4, polster: nil, notiz: "Lehne flach"), .ahmed, .fitxHagenMitte, uebung: "3TZduzM")
        let neu = EinstellGedaechtnis(defaults: defaults)
        XCTAssertEqual(neu.werte(.ahmed, .fitxHagenMitte, uebung: "3TZduzM"), EinstellWerte(bankstufe: 3, sitzhoehe: 4, polster: nil, notiz: "Lehne flach"))

        neu.setzen(EinstellWerte(bankstufe: 2), .ahmed, .fitxHagenMitte, uebung: "3TZduzM")
        XCTAssertEqual(EinstellGedaechtnis(defaults: defaults).werte(.ahmed, .fitxHagenMitte, uebung: "3TZduzM")?.bankstufe, 2)
        XCTAssertNil(EinstellGedaechtnis(defaults: defaults).werte(.ahmed, .fitxHagenMitte, uebung: "3TZduzM")?.sitzhoehe)
    }

    func testGedaechtnisTrenntPersonStudioUndUebung() {
        let g = frischesGedaechtnis()
        g.setzen(EinstellWerte(bankstufe: 3), .ahmed, .fitxHagenMitte, uebung: "a")
        XCTAssertNil(g.werte(.annika, .fitxHagenMitte, uebung: "a"))
        XCTAssertNil(g.werte(.ahmed, .absolutFit, uebung: "a"))
        XCTAssertNil(g.werte(.ahmed, .fitxHagenMitte, uebung: "b"))
        XCTAssertEqual(g.werte(.ahmed, .fitxHagenMitte, uebung: "a")?.bankstufe, 3)
    }

    func testLeereWerteLoeschenDenEintrag() {
        let g = frischesGedaechtnis()
        g.setzen(EinstellWerte(polster: 2), .annika, .absolutFit, uebung: "a")
        g.setzen(EinstellWerte(notiz: "  "), .annika, .absolutFit, uebung: "a")
        XCTAssertNil(g.werte(.annika, .absolutFit, uebung: "a"))
    }

    func testUebungsSchluesselNimmtIdOderNamen() {
        let katalog = PlanUebung(id: "p", uebung: "3TZduzM", name: nil, saetze: [], minuten: nil)
        let eigen = PlanUebung(id: "q", uebung: PlanUebung.eigen, name: "Mein Gerät", saetze: [], minuten: nil)
        XCTAssertEqual(EinstellGedaechtnis.uebungsSchluessel(katalog), "3TZduzM")
        XCTAssertEqual(EinstellGedaechtnis.uebungsSchluessel(eigen), "Mein Gerät")
    }
}
