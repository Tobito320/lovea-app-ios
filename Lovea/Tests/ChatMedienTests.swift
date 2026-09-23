import CoreGraphics
import XCTest
@testable import Lovea

/// Pure-helper tests for Block 5 (Z-5.1–Z-5.4) — no `Raum`/network, matching common.md's
/// "Tests only for pure logic" rule. UI (PhotosPicker, AVAudioRecorder/Player, Vision) is untestable
/// without a device/simulator and is out of scope here.
final class ChatMedienTests: XCTestCase {

    // MARK: - Wellenform (Z-5.2 waveform downsampling)

    func testWellenformDownsampleClampsToTarget() {
        let roh = (0..<400).map { Float(-160 + $0 % 50) } // fake dB samples
        let ergebnis = Wellenform.downsample(roh, ziel: 64)
        XCTAssertEqual(ergebnis.count, 64)
        for wert in ergebnis { XCTAssertTrue((0...1).contains(wert), "normalized values must stay 0...1") }
    }

    func testWellenformDownsamplePassesThroughShortInput() {
        let roh: [Float] = [-160, -80, -30, -10, 0]
        let ergebnis = Wellenform.downsample(roh, ziel: 64)
        XCTAssertEqual(ergebnis.count, roh.count, "fewer samples than the target bucket count stay as-is")
        XCTAssertEqual(ergebnis.last, 1, "0 dB (loudest) normalizes to 1")
        XCTAssertEqual(ergebnis.first, 0, "-160 dB (silence) floors to 0")
    }

    func testWellenformDownsampleEmptyIsEmpty() {
        XCTAssertEqual(Wellenform.downsample([]), [])
    }

    // MARK: - MedienKodierung.skaliert (Z-5.1 video scale-down)

    func testSkaliertCapsLongEdgeKeepingAspect() {
        let ergebnis = MedienKodierung.skaliert(CGSize(width: 3840, height: 2160), langeKante: 1280)
        XCTAssertEqual(ergebnis.width, 1280)
        XCTAssertEqual(ergebnis.height, 720, accuracy: 2)
    }

    func testSkaliertLeavesSmallerThanTargetUnscaled() {
        let ergebnis = MedienKodierung.skaliert(CGSize(width: 640, height: 480), langeKante: 1280)
        XCTAssertEqual(ergebnis.width, 640)
        XCTAssertEqual(ergebnis.height, 480)
    }

    func testSkaliertRoundsToEvenPixels() {
        let ergebnis = MedienKodierung.skaliert(CGSize(width: 1281, height: 721), langeKante: 1280)
        XCTAssertEqual(Int(ergebnis.width) % 2, 0)
        XCTAssertEqual(Int(ergebnis.height) % 2, 0)
    }

    // MARK: - MedienNachrichtView.bildGroesse (Z-26.3 bubble sizing)

    func testBildGroesseFitsNormalAspectWithinBounds() {
        let g = MedienNachrichtView.bildGroesse(breite: 1600, hoehe: 1200, maxBreite: 300)
        XCTAssertEqual(g.width, 300)
        XCTAssertEqual(g.height, 225, accuracy: 0.5)
    }

    func testBildGroesseCapsHeightAtMax() {
        let g = MedienNachrichtView.bildGroesse(breite: 900, hoehe: 1600, maxBreite: 300)
        XCTAssertEqual(g.height, 320)
        XCTAssertLessThanOrEqual(g.width, 300)
    }

    func testBildGroesseFloorsShortSideForExtremeTallRatio() {
        let g = MedienNachrichtView.bildGroesse(breite: 200, hoehe: 3000, maxBreite: 300)
        XCTAssertEqual(g.height, 320, "capped at maxHoehe")
        XCTAssertEqual(g.width, 140, "floored at minSeite rather than shrinking to a sliver")
    }

    func testBildGroesseFloorsShortSideForExtremeWideRatio() {
        let g = MedienNachrichtView.bildGroesse(breite: 3000, hoehe: 200, maxBreite: 300)
        XCTAssertEqual(g.width, 300, "capped at maxBreite")
        XCTAssertEqual(g.height, 140, "floored at minSeite rather than shrinking to a sliver")
    }

    func testBildGroesseFallsBackForMissingDimensions() {
        let g = MedienNachrichtView.bildGroesse(breite: 0, hoehe: 0, maxBreite: 300)
        XCTAssertEqual(g, CGSize(width: 300, height: 320))
    }

    // MARK: - KlipyClient.parse (Z-5.3 GIF search/trends JSON)

    func testKlipyParseExtractsMdFileURL() {
        let json = """
        {"result":true,"data":{"data":[
            {"id":"a1","file":{"hd":{"gif":{"url":"https://x/hd.gif","width":480,"height":270}},
                                "md":{"gif":{"url":"https://x/md.gif","width":320,"height":180}},
                                "sm":{"gif":{"url":"https://x/sm.gif","width":160,"height":90}}}}
        ]}}
        """.data(using: .utf8)!
        let gifs = KlipyClient.parse(json)
        XCTAssertEqual(gifs.count, 1)
        XCTAssertEqual(gifs[0].id, "a1")
        XCTAssertEqual(gifs[0].url, "https://x/md.gif", "prefers md over hd/sm")
        XCTAssertEqual(gifs[0].breite, 320)
        XCTAssertEqual(gifs[0].hoehe, 180)
    }

    func testKlipyParseFallsBackToSmWhenMdMissing() {
        let json = """
        {"data":{"data":[{"id":"b2","file":{"sm":{"gif":{"url":"https://x/sm.gif","width":160,"height":90}}}}]}}
        """.data(using: .utf8)!
        XCTAssertEqual(KlipyClient.parse(json).first?.url, "https://x/sm.gif")
    }

    func testKlipyParseSkipsEntriesWithoutURL() {
        let json = """
        {"data":{"data":[{"id":"c3","file":{"md":{"gif":{"width":10,"height":10}}}}]}}
        """.data(using: .utf8)!
        XCTAssertTrue(KlipyClient.parse(json).isEmpty)
    }

    func testKlipyParseHandlesGarbageWithoutCrashing() {
        XCTAssertEqual(KlipyClient.parse(Data("not json".utf8)), [])
    }

    // MARK: - ChatModell: medium.abschrift fold (Z-5.2)

    @MainActor
    func testAbschriftWirdGefaltet() {
        let modell = ChatModell(registrieren: false)
        struct P: Encodable { let id: String; let text: String }
        let op = Op.neu("medium.abschrift", P(id: "med1", text: "Hallo Annika"), von: .ahmed)
        modell.anwenden([op])
        XCTAssertEqual(modell.abschriften["med1"], "Hallo Annika")
    }

    @MainActor
    func testAbschriftUeberschreibtVorherige() {
        let modell = ChatModell(registrieren: false)
        struct P: Encodable { let id: String; let text: String }
        modell.anwenden([Op.neu("medium.abschrift", P(id: "med1", text: "erste"), von: .ahmed)])
        modell.anwenden([Op.neu("medium.abschrift", P(id: "med1", text: "zweite"), von: .ahmed)])
        XCTAssertEqual(modell.abschriften["med1"], "zweite")
    }

    // MARK: - ChatEinstellungen: favoriten fold (Z-5.3)

    @MainActor
    func testFavoritenWerdenProPersonGefaltet() {
        let modell = ChatEinstellungen(registrieren: false)
        let liste = [ChatEinstellungen.FavoritEintrag(art: .gif, wert: "https://x/a.gif", breite: 100, hoehe: 100)]
        let op = Op.neu("einstellung.setzen", EinstellungPayload(schluessel: "favoriten", wert: liste), von: .annika)
        modell.anwenden([op])
        XCTAssertEqual(modell.favoriten(.annika), liste)
        XCTAssertEqual(modell.favoriten(.ahmed), [], "favorites are per person")
    }

    @MainActor
    func testUnbekannterSchluesselWirdIgnoriert() {
        let modell = ChatEinstellungen(registrieren: false)
        // Z-34.1: the old per-person `hintergrund` is just another unknown key now.
        modell.anwenden([
            Op.neu("einstellung.setzen", EinstellungPayload(schluessel: "flamme", wert: "🔥"), von: .ahmed),
            Op.neu("einstellung.setzen", EinstellungPayload(schluessel: "hintergrund", wert: ["art": "foto", "medienId": "med9"]), von: .ahmed),
        ])
        XCTAssertEqual(modell.favoriten(.ahmed), [])
    }
}
