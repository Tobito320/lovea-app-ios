import XCTest
@testable import Lovea

final class GymGesteTests: XCTestCase {
    private func uebung(_ en: String, koerper: String, geraet: String = "Körpergewicht") -> Uebung {
        Uebung(id: "test", name: en, en: en, muskel: "", koerper: koerper, geraet: geraet, neben: [])
    }

    func testBankdruecken() {
        XCTAssertEqual(GymGeste.fuer(uebung("barbell bench press", koerper: "Brust", geraet: "Langhantel")), .bank)
    }

    func testPreacher() {
        XCTAssertEqual(GymGeste.fuer(uebung("dumbbell preacher curl", koerper: "Arme", geraet: "Kurzhantel")), .preacher)
    }

    func testBeinKabel() {
        XCTAssertEqual(GymGeste.fuer(uebung("cable kickback", koerper: "Beine", geraet: "Kabelzug")), .beinKabel)
    }

    func testLaufband() {
        XCTAssertEqual(GymGeste.fuer(uebung("treadmill walk", koerper: "Cardio")), .laufband)
    }

    func testKniebeuge() {
        XCTAssertEqual(GymGeste.fuer(uebung("barbell full squat", koerper: "Beine", geraet: "Langhantel")), .kniebeuge)
    }

    func testAusfallschritt() {
        XCTAssertEqual(GymGeste.fuer(uebung("dumbbell lunge", koerper: "Beine", geraet: "Kurzhantel")), .ausfallschritt)
    }

    func testWadenheben() {
        XCTAssertEqual(GymGeste.fuer(uebung("standing calf raise", koerper: "Waden")), .wadenheben)
    }

    func testKeinTreffer() {
        XCTAssertNil(GymGeste.fuer(uebung("crunch", koerper: "Bauch")))
    }

    func testOhneId() {
        XCTAssertNil(GymGeste.fuer(id: nil))
    }

    func testZufallBleibtBeimEigenenSet() {
        let fremd: Set<GymGeste> = Set(GymGeste.annika).subtracting(GymGeste.ahmed)
        for n in 0..<20 {
            let g = GymGeste.zufall(.ahmed, t: Double(n) * GymGeste.slot)
            XCTAssertFalse(fremd.contains(g), "Slot \(n): \(g) gehört nicht zu Ahmeds Liste")
        }
    }

    func testZufallPauseJedenFuenftenSlot() {
        for n in [4, 9, 14, 19] {
            XCTAssertEqual(GymGeste.zufall(.ahmed, t: Double(n) * GymGeste.slot), .pause)
        }
    }

    func testZufallDeterministisch() {
        let a = GymGeste.zufall(.annika, t: 3 * GymGeste.slot)
        let b = GymGeste.zufall(.annika, t: 3 * GymGeste.slot + 5)
        XCTAssertEqual(a, b)
    }

    func testZufallWechseltAb() {
        var gefunden: [GymGeste] = []
        var n = 0
        while gefunden.count < 5 && n < 40 {
            let g = GymGeste.zufall(.ahmed, t: Double(n) * GymGeste.slot)
            if g != .pause { gefunden.append(g) }
            n += 1
        }
        XCTAssertGreaterThanOrEqual(Set(gefunden).count, 3)
    }
}
