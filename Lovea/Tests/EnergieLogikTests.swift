import XCTest
@testable import Lovea

/// Teil 5: pure `EnergieLogik` only, no `Op`s and no singletons.
final class EnergieLogikTests: XCTestCase {

    private func eingabe(
        naechte: [Int?] = [450, 450, 450],
        wasser: Int = 6, wasserZiel: Int = 8, stunde: Int = 16,
        schritteGestern: Int? = 9000,
        trainingstag: Bool = true, ruhetag: Bool = false, planLeer: Bool = false,
        gymInFolge: Int = 0, heuteSchonGym: Bool = false
    ) -> EnergieEingabe {
        EnergieEingabe(
            naechte: naechte, wasser: wasser, wasserZiel: wasserZiel, stunde: stunde,
            schritteGestern: schritteGestern, trainingstag: trainingstag, ruhetag: ruhetag,
            planLeer: planLeer, gymInFolge: gymInFolge, heuteSchonGym: heuteSchonGym
        )
    }

    private func uhr(_ tag: String, _ stunde: Int, _ minute: Int) -> Date {
        Datum.kalender.date(bySettingHour: stunde, minute: minute, second: 0, of: Datum.datum(tag))!
    }

    // MARK: - rat()

    func testGuterSchlafUndWasserGibtHoch() {
        let rat = EnergieLogik.rat(eingabe(naechte: [480, 480, 480]))
        XCTAssertEqual(rat.stufe, .hoch)
        XCTAssertEqual(rat.gym, "Gym ja")
        XCTAssertEqual(rat.cardio, 15)
    }

    func testWenigSchritteGesternGibtMehrCardio() {
        let rat = EnergieLogik.rat(eingabe(naechte: [480, 480, 480], schritteGestern: 5000))
        XCTAssertEqual(rat.stufe, .hoch)
        XCTAssertEqual(rat.cardio, 30)
    }

    func testKurzeLetzteNachtUndKuerzererSchnittGibtNiedrig() {
        let rat = EnergieLogik.rat(eingabe(naechte: [330, 360, 390]))
        XCTAssertEqual(rat.stufe, .niedrig)
        XCTAssertEqual(rat.gym, "Heute besser kein Gym")
        XCTAssertEqual(rat.cardio, 0)
        XCTAssertTrue(rat.gruende.contains { $0.contains("nur") })
        XCTAssertTrue(rat.gruende.contains { $0.contains("kürzer") })
    }

    func testMittlererSchlafGibtMittel() {
        let rat = EnergieLogik.rat(eingabe(naechte: [390, 390, 390]))
        XCTAssertEqual(rat.punkte, 60)
        XCTAssertEqual(rat.stufe, .mittel)
        XCTAssertEqual(rat.gym, "Gym ja, etwas leichter")
        XCTAssertEqual(rat.cardio, 15)
    }

    func testRuhetagUnabhaengigVomLevel() {
        XCTAssertEqual(EnergieLogik.rat(eingabe(naechte: [480, 480, 480], ruhetag: true)).gym, "Ruhetag laut Plan")
        XCTAssertEqual(EnergieLogik.rat(eingabe(naechte: [330, 360, 390], ruhetag: true)).gym, "Ruhetag laut Plan")
    }

    func testHeuteSchonGymSchlaegtAllesAndere() {
        XCTAssertEqual(EnergieLogik.rat(eingabe(heuteSchonGym: true)).gym, "Gym heute erledigt")
        XCTAssertEqual(EnergieLogik.rat(eingabe(ruhetag: true, heuteSchonGym: true)).gym, "Gym heute erledigt")
    }

    func testKeinTrainingstagMitPlanGibtKeinGymGeplant() {
        XCTAssertEqual(EnergieLogik.rat(eingabe(trainingstag: false, planLeer: false)).gym, "Kein Gym geplant")
    }

    func testLeererPlanGibtNormaleEmpfehlung() {
        let rat = EnergieLogik.rat(eingabe(trainingstag: false, planLeer: true))
        XCTAssertNotEqual(rat.gym, "Kein Gym geplant")
        XCTAssertEqual(rat.gym, "Gym ja")
    }

    func testOhneSchlafdatenIstNeutral() {
        let rat = EnergieLogik.rat(eingabe(naechte: [nil, nil, nil]))
        XCTAssertTrue(rat.gruende.contains { $0.contains("Keine Schlafdaten") })
        XCTAssertNotEqual(rat.stufe, .niedrig)
    }

    func testDreiTageAmStueckMachtGymLeichterAuchBeiGutemSchlaf() {
        let rat = EnergieLogik.rat(eingabe(naechte: [480, 480, 480], gymInFolge: 3))
        XCTAssertEqual(rat.gym, "Gym ja, etwas leichter")
        XCTAssertTrue(rat.gruende.contains { $0.contains("am Stück") })
    }

    // MARK: - wasserSoll

    func testWasserSoll() {
        XCTAssertEqual(EnergieLogik.wasserSoll(ziel: 8, stunde: 7), 0)
        XCTAssertEqual(EnergieLogik.wasserSoll(ziel: 8, stunde: 15), 4)
        XCTAssertEqual(EnergieLogik.wasserSoll(ziel: 8, stunde: 23), 8)
    }

    // MARK: - wasserZeiten

    func testWasserZeitenAusStufigenWerten() {
        let neun = uhr("2026-09-23", 9, 0)
        let zwoelf = uhr("2026-09-23", 12, 0)
        let dreizehn = uhr("2026-09-23", 13, 0)
        let sortiert = EnergieLogik.wasserZeiten([(zeit: neun, wert: 1), (zeit: zwoelf, wert: 3), (zeit: dreizehn, wert: 2)])
        XCTAssertEqual(sortiert, [neun, zwoelf])
        let unsortiert = EnergieLogik.wasserZeiten([(zeit: dreizehn, wert: 2), (zeit: neun, wert: 1), (zeit: zwoelf, wert: 3)])
        XCTAssertEqual(unsortiert, [neun, zwoelf])
    }

    // MARK: - imBett

    func testImBettUeberMitternacht() {
        let z = SchlafZeitenD(datum: "2026-09-23", bett: uhr("2026-09-23", 23, 30), auf: uhr("2026-09-23", 7, 0))
        XCTAssertEqual(EnergieLogik.imBett(z), 450)
    }

    func testImBettAmSelbenTag() {
        let z = SchlafZeitenD(datum: "2026-09-23", bett: uhr("2026-09-23", 0, 30), auf: uhr("2026-09-23", 7, 0))
        XCTAssertEqual(EnergieLogik.imBett(z), 390)
    }

    // MARK: - inFolge

    func testInFolgeDreiTage() {
        let tage: Set<String> = ["2026-09-20", "2026-09-21", "2026-09-22"]
        XCTAssertEqual(EnergieLogik.inFolge(heute: "2026-09-23") { tage.contains($0) }, 3)
    }

    func testInFolgeMitLuecke() {
        let tage: Set<String> = ["2026-09-22"] // nur gestern, Lücke am Tag davor
        XCTAssertEqual(EnergieLogik.inFolge(heute: "2026-09-23") { tage.contains($0) }, 1)
    }
}
