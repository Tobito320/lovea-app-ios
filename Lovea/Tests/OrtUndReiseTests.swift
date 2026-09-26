import XCTest
@testable import Lovea

/// Brief G bugfix: a place state ends when the person leaves, and travelling wins over places
/// (Ahmed on a train still pushed the "REWE to go" shopping cart).
final class OrtUndReiseTests: XCTestCase {
    private let fix = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func gilt(_ ort: FigurZustand = .supermarkt, tempo: Double? = 0.5, bewegung: FigurZustand? = nil, gelaufenNach: Double? = nil) -> Bool {
        AnwesenheitEingabe.ortGilt(ort, tempo: tempo, bewegung: bewegung, fixZeit: fix, letzteBewegung: gelaufenNach.map { fix.addingTimeInterval($0) })
    }

    func testSupermarktEndetNachVerlassen() {
        XCTAssertTrue(gilt())
        XCTAssertTrue(gilt(gelaufenNach: 120), "walking around inside the store")
        XCTAssertFalse(gilt(gelaufenNach: 200), "walked on more than 3 min after the last fix there")
        XCTAssertFalse(gilt(tempo: 9), "a fix at vehicle speed")
        XCTAssertFalse(gilt(bewegung: .faehrt))
        XCTAssertFalse(gilt(bewegung: .scooter))
        XCTAssertFalse(gilt(bewegung: .zug))
        XCTAssertFalse(gilt(.gym, bewegung: .rad))
    }

    func testZuHauseBleibtBeimHerumlaufen() {
        XCTAssertTrue(gilt(.zuhause, gelaufenNach: 3600))
        XCTAssertFalse(gilt(.zuhause, tempo: 15))
    }

    func testTempoIstReise() {
        // Kein Auto (Runde 4): bis 20 km/h (~5.56 m/s) Scooter für Ahmed, schneller Zug.
        XCTAssertEqual(AnwesenheitEingabe.reise(nil, person: .ahmed, tempo: 4, fixAlter: 20), .scooter)
        XCTAssertEqual(AnwesenheitEingabe.reise(.laeuft, person: .ahmed, tempo: 25, fixAlter: 20), .zug, "walking through the train")
        XCTAssertEqual(AnwesenheitEingabe.reise(.laeuft, person: .ahmed, tempo: 25, fixAlter: 600), .laeuft, "an old fast fix says nothing now")
        XCTAssertEqual(AnwesenheitEingabe.reise(nil, person: .ahmed, tempo: 1.2, fixAlter: 20), nil)
        // Annika hat keinen Scooter: jede Fahrgeschwindigkeit ist Zug.
        XCTAssertEqual(AnwesenheitEingabe.reise(nil, person: .annika, tempo: 4, fixAlter: 20), .zug)
    }

    func testReiseSchlaegtLadenUndChat() {
        var e = FigurEingabe(person: .ahmed)
        e.ort = .supermarkt
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .supermarkt)
        e.bewegung = .faehrt
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .faehrt)
        e.app = .imChat
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .faehrt, "the chat open on the train still shows the trip")
        e.bewegung = .zug
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .zug)
        e.app = nil
        e.bewegung = .faehrt
        e.ort = .fahrschule
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .fahrschule)
    }

    func testAnkunftZuHause() {
        var e = FigurEingabe(person: .ahmed, jetzt: Date(timeIntervalSinceReferenceDate: 800_000_000))
        e.ort = .zuhause
        XCTAssertEqual(FigurZustand.bestimmen(e).haupt, .zuhause)
        XCTAssertTrue(AnwesenheitEingabe.ortGilt(.zuhause, tempo: 0, bewegung: nil, fixZeit: fix, letzteBewegung: nil))
    }

    func testSzeneUnterwegs() {
        // Unterwegs (Runde 4): Scooter zeigt die Straßenszene, Zug das eigene Abteil.
        XCTAssertEqual(ProfilSzene.fuer(schlaeft: false, partnerSchlaeft: false, ort: "supermarkt", wetterCode: 3, tag: true, stunde: 9, unterwegs: .scooter),
                       .unterwegs(wetter: .wolken, nacht: false))
        XCTAssertEqual(ProfilSzene.fuer(schlaeft: false, partnerSchlaeft: false, ort: "supermarkt", wetterCode: 3, tag: true, stunde: 9, unterwegs: .zug),
                       .abteil(wetter: .wolken, nacht: false))
        XCTAssertEqual(ProfilSzene.fuer(schlaeft: false, partnerSchlaeft: false, ort: "gym", wetterCode: 3, tag: true, stunde: 9, unterwegs: nil), .gym)
        XCTAssertTrue(ProfilSzene.istUnterwegs(anzeige: .faehrt, bewegung: nil, tempo: nil, fixAlter: nil))
        XCTAssertTrue(ProfilSzene.istUnterwegs(anzeige: .zug, bewegung: nil, tempo: nil, fixAlter: nil))
        XCTAssertTrue(ProfilSzene.istUnterwegs(anzeige: .scooter, bewegung: nil, tempo: nil, fixAlter: nil))
        XCTAssertTrue(ProfilSzene.istUnterwegs(anzeige: .offline, bewegung: "faehrt", tempo: nil, fixAlter: 60))
        XCTAssertTrue(ProfilSzene.istUnterwegs(anzeige: .offline, bewegung: nil, tempo: 20, fixAlter: 60))
        XCTAssertFalse(ProfilSzene.istUnterwegs(anzeige: .offline, bewegung: "faehrt", tempo: 20, fixAlter: 900))
        XCTAssertFalse(ProfilSzene.istUnterwegs(anzeige: .supermarkt, bewegung: nil, tempo: 0, fixAlter: 60))
        let scooterSzene = ProfilSzene.unterwegs(wetter: .sonne, nacht: false)
        XCTAssertEqual(scooterSzene.figur(.imChat), .scooter)
        XCTAssertEqual(scooterSzene.figur(.kuss), .kuss)
        XCTAssertEqual(scooterSzene.extras(.scooter, wetterCode: 61, temperatur: 10), [])
        let abteil = ProfilSzene.abteil(wetter: .sonne, nacht: false)
        XCTAssertEqual(abteil.figur(.imChat), .zug)
        XCTAssertEqual(abteil.figur(.kuss), .kuss)
        XCTAssertEqual(abteil.extras(.zug, wetterCode: 61, temperatur: 10), [])
    }
}
