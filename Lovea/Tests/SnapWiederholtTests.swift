import UIKit
import XCTest
@testable import Lovea

/// Snap replays (one updated notice line) and gallery picks as snaps.
@MainActor
final class SnapWiederholtTests: XCTestCase {
    private func replay(_ opID: String, anzahl: Int, seq: Int?) -> Op {
        Op(id: opID, seq: seq, art: "snap.wiederholt", von: .annika, zeit: Date(), d: Data(#"{"id":"s1","anzahl":\#(anzahl)}"#.utf8))
    }

    func testEineZeileMitDerNeuestenAnzahl() {
        let modell = ChatModell(registrieren: false)
        modell.anwenden([replay("o1", anzahl: 1, seq: nil)])
        XCTAssertEqual(modell.nachrichten.compactMap(\.system), ["Annika hat den Snap wiederholt"])

        modell.anwenden([replay("o2", anzahl: 2, seq: nil)])
        modell.anwenden([replay("o1", anzahl: 1, seq: 5)]) // late echo of the first replay
        XCTAssertEqual(modell.nachrichten.compactMap(\.system), ["Annika hat den Snap 2-mal wiederholt"], "one line, count never goes back")

        modell.anwenden([replay("o2", anzahl: 2, seq: 6)])
        XCTAssertEqual(modell.nachrichten.count, 1)
        XCTAssertEqual(modell.nachrichten.first?.seq, 6)
    }

    func testGalerieVideoGehtVor() {
        let url = URL(fileURLWithPath: "/tmp/snap.mov")
        guard case .video(let gewaehlt)? = SnapGalerie.inhalt(videoURL: url, bildDaten: Data()) else { return XCTFail("video expected") }
        XCTAssertEqual(gewaehlt, url)
    }

    func testGalerieFotoAusDaten() {
        let png = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).pngData { kontext in
            UIColor.red.setFill()
            kontext.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        guard case .foto? = SnapGalerie.inhalt(videoURL: nil, bildDaten: png) else { return XCTFail("photo expected") }
    }

    func testGalerieOhneBrauchbareDatenIstNil() {
        XCTAssertNil(SnapGalerie.inhalt(videoURL: nil, bildDaten: Data([1, 2, 3])))
        XCTAssertNil(SnapGalerie.inhalt(videoURL: nil, bildDaten: nil))
    }
}
