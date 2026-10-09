import XCTest
@testable import Lovea

@MainActor
final class StudioTests: XCTestCase {
    private func frisch() -> StudioGedaechtnis {
        let name = "studio-test-\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return StudioGedaechtnis(defaults: UserDefaults(suiteName: name)!)
    }

    // MARK: Öffnungslogik

    func testFitxIstImmerOffen() {
        for tag in 1...7 {
            for minute in [0, 5 * 60, 12 * 60, 23 * 60 + 59] {
                XCTAssertTrue(GymOeffnung.istOffen(.fitxHagenMitte, wochentag: tag, minute: minute))
            }
            XCTAssertNil(GymOeffnung.warnung(.fitxHagenMitte, wochentag: tag, start: 0, dauer: 45))
        }
    }

    func testAbsolutFitMoBisFrAb8() {
        XCTAssertFalse(GymOeffnung.istOffen(.absolutFit, wochentag: 1, minute: 7 * 60 + 59))
        XCTAssertTrue(GymOeffnung.istOffen(.absolutFit, wochentag: 1, minute: 8 * 60))
        XCTAssertTrue(GymOeffnung.istOffen(.absolutFit, wochentag: 5, minute: 21 * 60 + 59))
        XCTAssertFalse(GymOeffnung.istOffen(.absolutFit, wochentag: 5, minute: 22 * 60))
    }

    func testAbsolutFitWochenendeAb9() {
        for tag in [6, 7] {
            XCTAssertFalse(GymOeffnung.istOffen(.absolutFit, wochentag: tag, minute: 8 * 60 + 59))
            XCTAssertTrue(GymOeffnung.istOffen(.absolutFit, wochentag: tag, minute: 9 * 60))
            XCTAssertFalse(GymOeffnung.istOffen(.absolutFit, wochentag: tag, minute: 18 * 60))
        }
    }

    func testSlotGrenzen() {
        // bündig am Anfang ok, eine Minute davor nicht
        XCTAssertNil(GymOeffnung.warnung(.absolutFit, wochentag: 2, start: 8 * 60, dauer: 45))
        XCTAssertEqual(GymOeffnung.warnung(.absolutFit, wochentag: 2, start: 8 * 60 - 1, dauer: 45)?.grund, .vorOeffnung(von: 8 * 60))
        // bündig am Ende ok, eine Minute darüber nicht
        XCTAssertNil(GymOeffnung.warnung(.absolutFit, wochentag: 2, start: 22 * 60 - 45, dauer: 45))
        XCTAssertEqual(GymOeffnung.warnung(.absolutFit, wochentag: 2, start: 22 * 60 - 44, dauer: 45)?.grund, .nachSchluss(bis: 22 * 60))
    }

    func testAhmedSlot5UhrAbsolutFitWarntNurDort() {
        let tage = [1, 3, 6]
        let abs = GymOeffnung.warnungen(.absolutFit, wochentage: tage, start: 5 * 60, dauer: 45)
        XCTAssertEqual(abs.map(\.wochentag), [1, 3, 6])
        XCTAssertTrue(GymOeffnung.warnungen(.fitxHagenMitte, wochentage: tage, start: 5 * 60, dauer: 45).isEmpty)
    }

    func testOhneUhrzeitKeineWarnung() {
        XCTAssertTrue(GymOeffnung.warnungen(.absolutFit, wochentage: [1, 2], start: nil, dauer: 45).isEmpty)
    }

    func testWarnungNurWennSlotVorOeffnung() {
        // 08:30 Mo-Fr ok, Sa vor 09:00 nicht
        let w = GymOeffnung.warnungen(.absolutFit, wochentage: [1, 6, 7], start: 8 * 60 + 30, dauer: 45)
        XCTAssertEqual(w.map(\.wochentag), [6, 7])
    }

    func testZeilenFasstGleicheGruendeZusammen() {
        let w = GymOeffnung.warnungen(.absolutFit, wochentage: [1, 2, 6, 7], start: 5 * 60, dauer: 45)
        XCTAssertEqual(GymOeffnung.zeilen(w), ["Mo, Di: öffnet erst um 08:00", "Sa, So: öffnet erst um 09:00"])
    }

    func testUngueltigeWochentageIgnoriert() {
        XCTAssertTrue(GymOeffnung.warnungen(.absolutFit, wochentage: [0, 8], start: 5 * 60, dauer: 45).isEmpty)
    }

    // MARK: Profil

    func testStandardJePerson() {
        let g = frisch()
        XCTAssertEqual(g.studio(.ahmed), .fitxHagenMitte)
        XCTAssertEqual(g.studio(.annika), .absolutFit)
        XCTAssertEqual(g.profil(.ahmed).slotStart, 5 * 60)
        XCTAssertEqual(g.profil(.ahmed).dauer, 45)
        XCTAssertNil(g.profil(.annika).slotStart)
    }

    func testWahlBleibtNachNeustartUndIstJePerson() {
        let name = "studio-test-\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        let d = UserDefaults(suiteName: name)!
        let a = StudioGedaechtnis(defaults: d)
        var p = a.profil(.annika)
        p.studio = .fitxHagenMitte
        p.slotStart = 7 * 60
        a.setzen(p, .annika)
        let b = StudioGedaechtnis(defaults: d)
        XCTAssertEqual(b.studio(.annika), .fitxHagenMitte)
        XCTAssertEqual(b.profil(.annika).slotStart, 7 * 60)
        XCTAssertEqual(b.studio(.ahmed), .fitxHagenMitte)
        XCTAssertEqual(b.profil(.ahmed).slotStart, 5 * 60)
    }

    func testEinstellWerteHaengenAmGewaehltenStudio() {
        let einstell = EinstellGedaechtnis(defaults: UserDefaults(suiteName: "studio-einstell-\(UUID().uuidString)")!)
        einstell.setzen(EinstellWerte(bankstufe: 3), .ahmed, .fitxHagenMitte, uebung: "schraeg")
        let g = frisch()
        XCTAssertEqual(einstell.werte(.ahmed, g.studio(.ahmed), uebung: "schraeg")?.bankstufe, 3)
        var p = g.profil(.ahmed)
        p.studio = .absolutFit
        g.setzen(p, .ahmed)
        XCTAssertNil(einstell.werte(.ahmed, g.studio(.ahmed), uebung: "schraeg"))
        p.studio = .fitxHagenMitte
        g.setzen(p, .ahmed)
        XCTAssertEqual(einstell.werte(.ahmed, g.studio(.ahmed), uebung: "schraeg")?.bankstufe, 3)
    }

    func testNotizSchluesselJeStudio() {
        XCTAssertNotEqual(GymStudio.fitxHagenMitte.notizSchluessel, GymStudio.absolutFit.notizSchluessel)
    }
}
