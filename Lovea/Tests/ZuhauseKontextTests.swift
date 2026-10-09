import XCTest
@testable import Lovea

/// Kontextszenen: Gym geteilt, beide weg, sonst unveraendert.
final class ZuhauseKontextTests: XCTestCase {
    func testBeideDaheimBleibtNormal() {
        XCTAssertEqual(ZuhauseKontext.bestimme(ahmed: .zuhause, annika: nil), .daheim)
        XCTAssertEqual(ZuhauseKontext.bestimme(ahmed: nil, annika: nil), .daheim)
    }

    func testEinerImGymTeiltDasBild() {
        XCTAssertEqual(ZuhauseKontext.bestimme(ahmed: .gym, annika: .zuhause), .gymGeteilt(daheim: .annika, weg: .ahmed))
        XCTAssertEqual(ZuhauseKontext.bestimme(ahmed: nil, annika: .gym), .gymGeteilt(daheim: .ahmed, weg: .annika))
    }

    func testEinerInDerArbeitAendertDenRaumNicht() {
        XCTAssertEqual(ZuhauseKontext.bestimme(ahmed: .zuhause, annika: .arbeit), .daheim)
    }

    func testBeideWegLeererRaumMitNotiz() {
        XCTAssertEqual(ZuhauseKontext.bestimme(ahmed: .gym, annika: .arbeit), .beideWeg(notiz: "Ahmed im Gym, Annika in der Arbeit"))
        XCTAssertEqual(ZuhauseKontext.bestimme(ahmed: .gym, annika: .arbeit).abwesende, [.ahmed, .annika])
    }

    @MainActor func testGymAusschnittLiegtImmerRechtsInnerhalbDerWelt() {
        let r = ZuhauseKontext.gymAusschnitt
        XCTAssertGreaterThanOrEqual(r.minX, ProfilSlots.weltBreite / 2)
        XCTAssertLessThanOrEqual(r.maxX, ProfilSlots.weltBreite - ZimmerPlatzLogik.weltRand)
        XCTAssertGreaterThanOrEqual(r.minY, ZimmerPlatzLogik.weltRand)
        XCTAssertLessThanOrEqual(r.maxY, ProfilSlots.hoehe - ZimmerPlatzLogik.weltRand)
    }
}
