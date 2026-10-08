import SwiftUI
import XCTest
@testable import Lovea

/// p69: the profile's top part (scene + zone strip) against the room the screen gives it, and the tabs under
/// it. Pure numbers and lists, no drawing. The numbers are the geometry height the profile gets: the screen
/// without the bottom safe area and tab bar (the status bar stays in, the profile reaches under it).
@MainActor
final class ProfilLayoutTests: XCTestCase {
    private typealias L = ProfilLayout

    /// (name, width, height of the profile's room, status bar). Phones: iOS 26 runs on the iPhone 11 and newer.
    private let iPhones26: [(String, CGFloat, CGFloat, CGFloat)] = [
        ("iPhone 11 Pro / 12 mini / 13 mini", 375, 812 - 83, 50),
        ("iPhone 11 / XR", 414, 896 - 83, 48),
        ("iPhone 12 / 13 / 14", 390, 844 - 83, 47),
        ("iPhone 15 / 16", 393, 852 - 83, 59),
        ("iPhone 16 Pro / 17 Pro", 402, 874 - 83, 62),
        ("iPhone Pro Max", 430, 932 - 83, 59),
        ("iPhone 16 / 17 Pro Max", 440, 956 - 83, 62),
    ]
    /// Too small for fixed scene and strip: the whole profile scrolls as one.
    private let kleine: [(String, CGFloat, CGFloat, CGFloat)] = [
        ("iPhone SE", 375, 667 - 49, 20),
        ("iPad Fenster klein", 700, 500, 24),
    ]
    private let iPads: [(String, CGFloat, CGFloat, CGFloat)] = [
        ("iPad hoch", 820, 1180, 24),
        ("iPad quer", 1180, 820, 24),
    ]

    func testPhonesHabenGenugPlatzFuerSzeneUndLeiste() {
        for (name, b, h, oben) in iPhones26 {
            let s = L.szene(breite: b, hoehe: h, oben: oben)
            XCTAssertTrue(s.klebt, "\(name): unten \(s.unten)")
            XCTAssertGreaterThanOrEqual(s.unten, L.unterMinimum, name)
            XCTAssertLessThanOrEqual(s.breite, b, name)
        }
    }

    func testKleineGeraeteRollenAllesAlsEins() {
        for (name, b, h, oben) in kleine {
            let s = L.szene(breite: b, hoehe: h, oben: oben)
            XCTAssertFalse(s.klebt, "\(name): unten \(s.unten)")
        }
    }

    func testIPadBekommtKeineRiesenSzene() {
        for (name, b, h, oben) in iPads {
            let s = L.szene(breite: b, hoehe: h, oben: oben)
            XCTAssertEqual(s.breite, L.maxSzeneBreite, name)
            XCTAssertEqual(s.hoehe, oben + ProfilPanoramaLayout.szeneHoehe(breite: L.maxSzeneBreite), accuracy: 0.001, name)
            XCTAssertTrue(s.klebt, "\(name): unten \(s.unten)")
        }
    }

    func testBreiteWirdBeiMaximumGekappt() {
        XCTAssertEqual(L.szene(breite: 429, hoehe: 800, oben: 47).breite, 429)
        XCTAssertEqual(L.szene(breite: 431, hoehe: 800, oben: 47).breite, L.maxSzeneBreite)
        XCTAssertEqual(L.szene(breite: 5000, hoehe: 800, oben: 47).breite, L.maxSzeneBreite)
    }

    func testUntenRechnetDieZonenLeisteMit() {
        // The old test left the strip out of the sum and so promised the lower part 36 to 44 pt too much.
        let s = L.szene(breite: 390, hoehe: 761, oben: 47)
        XCTAssertEqual(s.hoehe, 47 + 430, accuracy: 0.001)
        XCTAssertEqual(s.unten, 761 - (47 + 430) - L.leistenHoehe, accuracy: 0.001)
    }

    func testBreiteNullStuerztNichtAb() {
        let s = L.szene(breite: 0, hoehe: 0, oben: 0)
        XCTAssertEqual(s.breite, 0)
        XCTAssertEqual(s.hoehe, 0)
        XCTAssertFalse(s.klebt)
        XCTAssertFalse(L.szene(breite: -10, hoehe: 800, oben: 47).breite < 0)
    }

    /// The tab bar of iOS 26 folds away while the lower part scrolls and the profile's room grows by up to
    /// `tabLeistenSpiel`. A device that is "whole scroll" at rest but "fixed" once the bar is folded away
    /// would swap its layout under the finger. None may lie in that band.
    func testKeinGeraetKipptBeimEinklappenDerTabLeiste() {
        for (name, b, h, oben) in iPhones26 + kleine + iPads {
            let s = L.szene(breite: b, hoehe: h, oben: oben)
            let eingeklappt = L.szene(breite: b, hoehe: h + L.tabLeistenSpiel, oben: oben)
            XCTAssertEqual(s.klebt, eingeklappt.klebt, "\(name): kippt zwischen \(s.unten) und \(eingeklappt.unten)")
        }
    }

    /// The cause of "the profile is buggy when long": the old layout fixed a scene as wide as the screen plus a
    /// 36 pt strip and gave the rest, a long list of cards, what was left. Counted with the old numbers.
    func testAlteAufteilungLiessDemInhaltKaumPlatz() {
        func alterPlatz(_ b: CGFloat, _ h: CGFloat, _ oben: CGFloat) -> CGFloat {
            h - oben - ProfilPanoramaLayout.szeneHoehe(breite: b) - 36
        }
        for (name, b, h, oben) in iPhones26 + kleine {
            XCTAssertLessThan(alterPlatz(b, h, oben), 300, "\(name): ein Bildschirm voll Karten in einem Streifen von \(alterPlatz(b, h, oben)) pt")
        }
        let quer = iPads[1]
        XCTAssertLessThanOrEqual(alterPlatz(quer.1, quer.2, quer.3), 0, "iPad quer: gar kein Platz fuer die Karten")
    }

    // MARK: Tabs

    private func abschnitt(_ id: String, _ reiter: ProfilReiter, titel: String? = nil, sichtbar: Bool = true) -> ProfilAbschnitt {
        ProfilAbschnitt(id, reiter, titel: titel, sichtbar: sichtbar) { EmptyView() }
    }

    func testLeereReiterWerdenNichtGezeichnet() {
        let a = [abschnitt("a", .zimmer), abschnitt("b", .wir, sichtbar: false), abschnitt("c", .quests)]
        XCTAssertEqual(ProfilReiterLogik.sichtbar(a), [.zimmer, .quests])
        XCTAssertEqual(ProfilReiterLogik.sichtbar([]), [])
    }

    func testReiterBleibenInFesterReihenfolge() {
        let a = [abschnitt("q", .quests), abschnitt("e", .erinnerungen), abschnitt("w", .wir), abschnitt("z", .zimmer)]
        XCTAssertEqual(ProfilReiterLogik.sichtbar(a), [.zimmer, .wir, .erinnerungen, .quests])
    }

    func testGewaehlterReiterFaelltAufDenErstenZurueck() {
        let sichtbar: [ProfilReiter] = [.wir, .quests]
        XCTAssertEqual(ProfilReiterLogik.gewaehlt(.quests, unter: sichtbar), .quests)
        XCTAssertEqual(ProfilReiterLogik.gewaehlt(.zimmer, unter: sichtbar), .wir, "der gewaehlte ist weg")
        XCTAssertEqual(ProfilReiterLogik.gewaehlt(nil, unter: sichtbar), .wir)
        XCTAssertNil(ProfilReiterLogik.gewaehlt(.wir, unter: []))
    }

    func testNurAbschnitteDesReitersMitInhaltKommenDran() {
        let a = [abschnitt("a", .zimmer), abschnitt("b", .zimmer, sichtbar: false), abschnitt("c", .wir)]
        XCTAssertEqual(ProfilReiterLogik.abschnitte(a, in: .zimmer).map(\.id), ["a"])
        XCTAssertEqual(ProfilReiterLogik.abschnitte(a, in: .wir).map(\.id), ["c"])
        XCTAssertEqual(ProfilReiterLogik.abschnitte(a, in: nil).map(\.id), [])
    }

    func testKartenStartenZuUndNurEineAlleineStartetOffen() {
        let zwei = [abschnitt("a", .wir, titel: "A"), abschnitt("b", .wir, titel: "B")]
        XCTAssertFalse(ProfilReiterLogik.startOffen(zwei[0], in: zwei))
        XCTAssertFalse(ProfilReiterLogik.startOffen(zwei[1], in: zwei))
        let eine = [abschnitt("leiste", .wir), abschnitt("a", .wir, titel: "A")]
        XCTAssertTrue(ProfilReiterLogik.startOffen(eine[1], in: eine), "die einzige Karte des Reiters")
        XCTAssertFalse(ProfilReiterLogik.startOffen(eine[0], in: eine), "eine Leiste ohne Titel ist keine Karte")
    }

    func testReiterLeisteBrauchtEineAuswahl() {
        XCTAssertFalse(ProfilReiterLogik.zeigtLeiste([]))
        XCTAssertFalse(ProfilReiterLogik.zeigtLeiste([.zimmer]))
        XCTAssertTrue(ProfilReiterLogik.zeigtLeiste([.zimmer, .wir]))
    }

    // MARK: Tippflaechen und Schrift

    func testTippflaechenSindMindestens44Pt() {
        XCTAssertGreaterThanOrEqual(L.tippMinimum, 44)
        XCTAssertGreaterThanOrEqual(L.leistenHoehe, 44, "Zonen-Leiste unter der Szene")
        XCTAssertGreaterThanOrEqual(L.reiterHoehe, 44, "Reiter-Leiste")
    }

    func testLeistenSchriftWaechstBisXXXLarge() {
        XCTAssertEqual(L.leistenSchrift.upperBound, .xxxLarge)
        XCTAssertTrue(L.leistenSchrift.contains(.large))
        XCTAssertFalse(L.leistenSchrift.contains(.accessibility1))
    }
}
