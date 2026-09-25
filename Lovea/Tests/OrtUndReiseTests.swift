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
        XCTAssertFalse(gilt(.gym, bewegung: .rad))
    }

    func testZuHauseBleibtBeimHerumlaufen() {
        XCTAssertTrue(gilt(.zuhause, gelaufenNach: 3600))
        XCTAssertFalse(gilt(.zuhause, tempo: 15))
    }

    func testTempoIstReise() {
        XCTAssertEqual(AnwesenheitEingabe.reise(nil, tempo: 25, fixAlter: 20), .faehrt)
        XCTAssertEqual(AnwesenheitEingabe.reise(.laeuft, tempo: 25, fixAlter: 20), .faehrt, "walking through the train")
        XCTAssertEqual(AnwesenheitEingabe.reise(.laeuft, tempo: 25, fixAlter: 600), .laeuft, "an old fast fix says nothing now")
        XCTAssertEqual(AnwesenheitEingabe.reise(nil, tempo: 1.2, fixAlter: 20), nil)
    }

    func testZugNachEinerMinuteSchnell() {
        let t0 = fix
        var z = AnwesenheitEingabe.zug(bisher: false, reist: true, schnell: true, schnellSeit: nil, jetzt: t0)
        XCTAssertFalse(z.zug)
        z = AnwesenheitEingabe.zug(bisher: z.zug, reist: true, schnell: true, schnellSeit: z.schnellSeit, jetzt: t0.addingTimeInterval(61))
        XCTAssertTrue(z.zug)
        // Stays a train through a station stop, ends with the trip.
        z = AnwesenheitEingabe.zug(bisher: z.zug, reist: true, schnell: false, schnellSeit: z.schnellSeit, jetzt: t0.addingTimeInterval(300))
        XCTAssertTrue(z.zug)
        z = AnwesenheitEingabe.zug(bisher: z.zug, reist: false, schnell: false, schnellSeit: z.schnellSeit, jetzt: t0.addingTimeInterval(900))
        XCTAssertFalse(z.zug)
        XCTAssertNil(z.schnellSeit)
        // A car at town speed never becomes a train.
        z = AnwesenheitEingabe.zug(bisher: false, reist: true, schnell: false, schnellSeit: nil, jetzt: t0.addingTimeInterval(3600))
        XCTAssertFalse(z.zug)
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
        XCTAssertEqual(ProfilSzene.fuer(schlaeft: false, partnerSchlaeft: false, ort: "supermarkt", wetterCode: 3, tag: true, stunde: 9, unterwegs: true),
                       .unterwegs(wetter: .wolken, nacht: false))
        XCTAssertEqual(ProfilSzene.fuer(schlaeft: false, partnerSchlaeft: false, ort: "gym", wetterCode: 3, tag: true, stunde: 9, unterwegs: false), .gym)
        XCTAssertTrue(ProfilSzene.istUnterwegs(anzeige: .faehrt, bewegung: nil, tempo: nil, fixAlter: nil))
        XCTAssertTrue(ProfilSzene.istUnterwegs(anzeige: .zug, bewegung: nil, tempo: nil, fixAlter: nil))
        XCTAssertTrue(ProfilSzene.istUnterwegs(anzeige: .offline, bewegung: "faehrt", tempo: nil, fixAlter: 60))
        XCTAssertTrue(ProfilSzene.istUnterwegs(anzeige: .offline, bewegung: nil, tempo: 20, fixAlter: 60))
        XCTAssertFalse(ProfilSzene.istUnterwegs(anzeige: .offline, bewegung: "faehrt", tempo: 20, fixAlter: 900))
        XCTAssertFalse(ProfilSzene.istUnterwegs(anzeige: .supermarkt, bewegung: nil, tempo: 0, fixAlter: 60))
        let szene = ProfilSzene.unterwegs(wetter: .sonne, nacht: false)
        XCTAssertEqual(szene.figur(.imChat), .faehrt)
        XCTAssertEqual(szene.figur(.zug), .zug)
        XCTAssertEqual(szene.figur(.kuss), .kuss)
        XCTAssertEqual(szene.extras(.faehrt, wetterCode: 61, temperatur: 10), [])
    }
}
