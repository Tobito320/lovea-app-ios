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

    /// Beginn der Geste: schnelle horizontale Bewegung, nicht am Rand, kein innerer Bereich belegt.
    func testDarfBeginnenBeiHorizontalerBewegung() {
        XCTAssertTrue(TabWischLogik.darfBeginnen(vx: -400, vy: 50, startX: 200, breite: breite, aktiv: true, innenBelegt: false))
    }

    func testDarfNichtBeginnenBeiSenkrechterBewegung() {
        XCTAssertFalse(TabWischLogik.darfBeginnen(vx: -100, vy: 400, startX: 200, breite: breite, aktiv: true, innenBelegt: false))
    }

    func testDarfNichtBeginnenWennInnenBelegt() {
        XCTAssertFalse(TabWischLogik.darfBeginnen(vx: -400, vy: 0, startX: 200, breite: breite, aktiv: true, innenBelegt: true))
    }

    func testDarfNichtBeginnenAmRandOderBeiSchalterAus() {
        XCTAssertFalse(TabWischLogik.darfBeginnen(vx: -400, vy: 0, startX: 10, breite: breite, aktiv: true, innenBelegt: false))
        XCTAssertFalse(TabWischLogik.darfBeginnen(vx: -400, vy: 0, startX: 200, breite: breite, aktiv: false, innenBelegt: false))
    }

    /// Innere Scroll-Fläche: gewinnt nur, wenn sie in Fingerrichtung noch scrollen kann.
    func testScrollFlaecheMitPlatzNachLinksGewinnt() {
        XCTAssertTrue(TabWischLogik.kannHorizontalScrollen(offset: 0, inhalt: 800, sicht: 400, insetLinks: 0, insetRechts: 0, fingerNachLinks: true))
    }

    func testScrollFlaecheAmEndeLaesstTabWechselZu() {
        XCTAssertFalse(TabWischLogik.kannHorizontalScrollen(offset: 400, inhalt: 800, sicht: 400, insetLinks: 0, insetRechts: 0, fingerNachLinks: true))
        XCTAssertTrue(TabWischLogik.kannHorizontalScrollen(offset: 400, inhalt: 800, sicht: 400, insetLinks: 0, insetRechts: 0, fingerNachLinks: false))
    }

    func testScrollFlaecheAmAnfangLaesstVorherigenTabZu() {
        XCTAssertFalse(TabWischLogik.kannHorizontalScrollen(offset: 0, inhalt: 800, sicht: 400, insetLinks: 0, insetRechts: 0, fingerNachLinks: false))
    }

    func testScrollFlaecheOhneUeberstandGewinntNie() {
        XCTAssertFalse(TabWischLogik.kannHorizontalScrollen(offset: 0, inhalt: 400, sicht: 400, insetLinks: 0, insetRechts: 0, fingerNachLinks: true))
        XCTAssertFalse(TabWischLogik.kannHorizontalScrollen(offset: 0, inhalt: 400, sicht: 400, insetLinks: 0, insetRechts: 0, fingerNachLinks: false))
    }

    func testScrollFlaecheMitInsetAmAnfangLaesstVorherigenTabZu() {
        XCTAssertFalse(TabWischLogik.kannHorizontalScrollen(offset: -16, inhalt: 800, sicht: 400, insetLinks: 16, insetRechts: 16, fingerNachLinks: false))
    }

    /// Schalter "Zwischen Tabs wischen" aus: kein Tab-Wechsel, obwohl Strecke und Richtung passen.
    func testSchalterAusReagiertNicht() {
        XCTAssertNil(TabWischLogik.richtung(dx: -100, dy: 0, startX: 200, breite: breite, aktiv: false))
    }

    func testSchalterIstStandardMaessigAn() {
        let defaults = UserDefaults(suiteName: "TabWischLogikTests")!
        defaults.removePersistentDomain(forName: "TabWischLogikTests")
        XCTAssertTrue(TabWischLogik.aktiv(defaults))
        defaults.set(false, forKey: TabWischLogik.schluessel)
        XCTAssertFalse(TabWischLogik.aktiv(defaults))
        defaults.set(true, forKey: TabWischLogik.schluessel)
        XCTAssertTrue(TabWischLogik.aktiv(defaults))
        defaults.removePersistentDomain(forName: "TabWischLogikTests")
    }
}
