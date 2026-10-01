import XCTest
@testable import Lovea

final class TabWischLogikTests: XCTestCase {
    private let breite: CGFloat = 400

    func testWeiterWischNachLinksIstNaechsterTab() {
        XCTAssertEqual(
            TabWischLogik.richtung(dx: -100, dy: 0, startX: 200, breite: breite),
            .naechsterTab
        )
    }

    func testWeiterWischNachRechtsIstVorherigerTab() {
        XCTAssertEqual(
            TabWischLogik.richtung(dx: 100, dy: 0, startX: 200, breite: breite),
            .vorherigerTab
        )
    }

    func testZuKurzReagiertNicht() {
        XCTAssertNil(TabWischLogik.richtung(dx: 40, dy: 0, startX: 200, breite: breite))
    }

    func testZuSchraegReagiertNicht() {
        // |dx| > 60, aber nicht klar horizontal (|dx| <= 2|dy|) — z. B. ein Scroll.
        XCTAssertNil(TabWischLogik.richtung(dx: 70, dy: 50, startX: 200, breite: breite))
    }

    func testStartAmLinkenRandReagiertNicht() {
        // Das ist das System-Zurück-Wischen, nicht der Tab-Wechsel.
        XCTAssertNil(TabWischLogik.richtung(dx: 100, dy: 0, startX: 10, breite: breite))
    }

    func testStartAmRechtenRandReagiertNicht() {
        XCTAssertNil(TabWischLogik.richtung(dx: -100, dy: 0, startX: 390, breite: breite))
    }

    func testGenauAnDerRandgrenzeReagiertNoch() {
        XCTAssertEqual(
            TabWischLogik.richtung(dx: -100, dy: 0, startX: 31, breite: breite),
            .naechsterTab
        )
    }

    func testGenauAnDerMindeststreckeReagiertNochNicht() {
        XCTAssertNil(TabWischLogik.richtung(dx: 60, dy: 0, startX: 200, breite: breite))
    }
}
