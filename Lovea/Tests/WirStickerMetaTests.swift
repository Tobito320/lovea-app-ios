import XCTest
@testable import Lovea

final class WirStickerMetaTests: XCTestCase {
    /// Jeder Sticker aus `MitgelieferteSticker.alle` braucht Metadaten, sonst zeigt "Alle" Lücken.
    func testJederStickerHatMetadaten() {
        for name in MitgelieferteSticker.alle {
            XCTAssertNotNil(WirStickerMeta.wer(name), "Kein wer für \(name)")
            XCTAssertFalse(WirStickerMeta.kontext(name).isEmpty, "Kein Kontext für \(name)")
        }
    }

    /// Jeder Kontext in `alleKontexte` trägt mindestens einen Sticker (keine leeren Chips).
    func testAlleKontexteHabenMindestensEinenSticker() {
        for kontext in WirStickerMeta.alleKontexte {
            let treffer = MitgelieferteSticker.alle.filter { WirStickerMeta.kontext($0).contains(kontext) }
            XCTAssertFalse(treffer.isEmpty, "Kontext \(kontext) hat keinen Sticker")
        }
    }

    /// Jeder Tab-Kontext (`kontexte(fuer:)`) trägt mindestens einen Sticker mit genau diesem `wer`.
    func testKontexteFuerWerHabenMindestensEinenPassendenSticker() {
        for wer in WirWer.allCases {
            for kontext in WirStickerMeta.kontexte(fuer: wer) {
                let treffer = MitgelieferteSticker.alle.filter { WirStickerMeta.wer($0) == wer && WirStickerMeta.kontext($0).contains(kontext) }
                XCTAssertFalse(treffer.isEmpty, "Kontext \(kontext) hat keinen Sticker für \(wer)")
            }
        }
    }
}

final class WirStickerFilterTests: XCTestCase {
    private let namen = ["wir-gym", "wir-annika-rosen", "wir-schlafen-gehen", "wir-essen"]

    func testFilterNachTab() {
        XCTAssertEqual(WirStickerFilter.gefiltert(namen, wer: .annika, kontext: nil), ["wir-annika-rosen"])
        XCTAssertEqual(WirStickerFilter.gefiltert(namen, wer: .beide, kontext: nil), ["wir-gym"])
        XCTAssertEqual(WirStickerFilter.gefiltert(namen, wer: .ahmed, kontext: nil), ["wir-schlafen-gehen", "wir-essen"])
    }

    func testFilterNachKontextInnerhalbTab() {
        XCTAssertEqual(WirStickerFilter.gefiltert(namen, wer: .ahmed, kontext: "Schlaf"), ["wir-schlafen-gehen"])
        XCTAssertEqual(WirStickerFilter.gefiltert(namen, wer: .ahmed, kontext: "Essen"), ["wir-essen"])
    }

    func testFilterKombiniertTabUndKontext() {
        XCTAssertEqual(WirStickerFilter.gefiltert(namen, wer: .ahmed, kontext: "Schlaf"), ["wir-schlafen-gehen"])
        XCTAssertTrue(WirStickerFilter.gefiltert(namen, wer: .annika, kontext: "Schlaf").isEmpty)
    }

    func testUnbekannterNameFaelltRaus() {
        XCTAssertTrue(WirStickerFilter.gefiltert(["kein-metadaten-sticker"], wer: .ahmed, kontext: nil).isEmpty)
        XCTAssertTrue(WirStickerFilter.gefiltert(["kein-metadaten-sticker"], wer: .beide, kontext: nil).isEmpty)
    }
}
