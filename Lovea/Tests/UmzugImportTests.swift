import XCTest
@testable import Lovea

/// Pure mapping tests (Z-11.2). `UmzugImport` itself needs `Raum`/network/disk, so it is only
/// covered indirectly; `UmzugMapping` and the `Decodable` shapes carry all the old-web-app ->
/// app translation logic.
@MainActor
final class UmzugImportTests: XCTestCase {
    func testGalerieOpDecodesTheExactShapeUmzugMjsEmits() throws {
        // Matches server/umzug.mjs's `galerie/` case: op(..., "umzug.galerie", person, ...,
        // { id, name: d.name, format: d.format, papier: d.papier, ebenen }).
        let json = """
        {
          "name": "Herbst",
          "format": "4-3",
          "papier": "weiss",
          "ebenen": [
            {"medienId": "umzug-galerie-ahmed-x-ebene0", "name": "Skizze", "deckkraft": 0.5,
             "modus": "multiply", "clip": true, "schuetzt": true, "sichtbar": false},
            {"medienId": "umzug-galerie-ahmed-x-ebene1"}
          ]
        }
        """
        let d = try JSONDecoder().decode(GalerieOp.self, from: Data(json.utf8))
        XCTAssertEqual(d.name, "Herbst")
        XCTAssertEqual(UmzugMapping.format(d.format), .landscape4x3)
        XCTAssertEqual(UmzugMapping.background(d.papier), .white)
        XCTAssertEqual(d.ebenen.count, 2)

        let voll = UmzugMapping.layer(d.ebenen[0], index: 0)
        XCTAssertEqual(voll.kind, .image)
        XCTAssertEqual(voll.name, "Skizze")
        XCTAssertEqual(voll.opacity, 0.5)
        XCTAssertEqual(voll.blendMode, .multiply)
        XCTAssertTrue(voll.clipping)
        XCTAssertTrue(voll.isLocked)
        XCTAssertFalse(voll.isVisible)
        XCTAssertTrue(voll.contentFile.hasPrefix("image-"))

        // A layer row missing every optional key (JSON.stringify drops `undefined`) falls back
        // to studio.js's own layer defaults (ebeneNeu, line 107-108).
        let minimal = UmzugMapping.layer(d.ebenen[1], index: 1)
        XCTAssertEqual(minimal.name, "Ebene 2")
        XCTAssertEqual(minimal.opacity, 1)
        XCTAssertEqual(minimal.blendMode, .normal)
        XCTAssertFalse(minimal.clipping)
        XCTAssertFalse(minimal.isLocked)
        XCTAssertTrue(minimal.isVisible)
    }

    func testAufkleberOpDecodesTheExactShapeUmzugMjsEmits() throws {
        // server/umzug.mjs: op(..., "umzug.aufkleber", person, ..., { id, name: d.name, medienId: mId }).
        let json = #"{"id":"herz","name":"Herz","medienId":"umzug-aufkleber-ahmed-herz"}"#
        let d = try JSONDecoder().decode(AufkleberOp.self, from: Data(json.utf8))
        XCTAssertEqual(d.medienId, "umzug-aufkleber-ahmed-herz")
    }

    func testLayerClampsOpacityToUnitRange() {
        let zuHoch = GalerieOp.Ebene(medienId: "m", name: nil, deckkraft: 1.4, modus: nil, clip: nil, schuetzt: nil, sichtbar: nil)
        XCTAssertEqual(UmzugMapping.layer(zuHoch, index: 0).opacity, 1)

        let negativ = GalerieOp.Ebene(medienId: "m", name: nil, deckkraft: -0.2, modus: nil, clip: nil, schuetzt: nil, sichtbar: nil)
        XCTAssertEqual(UmzugMapping.layer(negativ, index: 0).opacity, 0)
    }

    func testBlendModeMapsCanvasCompositeOperations() {
        XCTAssertEqual(UmzugMapping.blendMode("source-over"), .normal)
        XCTAssertEqual(UmzugMapping.blendMode("multiply"), .multiply)
        XCTAssertEqual(UmzugMapping.blendMode("screen"), .screen)
        XCTAssertEqual(UmzugMapping.blendMode("overlay"), .overlay)
        XCTAssertEqual(UmzugMapping.blendMode("darken"), .darken)
        XCTAssertEqual(UmzugMapping.blendMode("lighten"), .lighten)
        XCTAssertEqual(UmzugMapping.blendMode("lighter"), .add)
        XCTAssertEqual(UmzugMapping.blendMode("soft-light"), .softLight)
    }

    func testBlendModeFallsBackForModesWithoutAnExactMatch() {
        // LayerBlendMode has no color-burn/color-dodge case -- nearest direction wins.
        XCTAssertEqual(UmzugMapping.blendMode("color-burn"), .darken)
        XCTAssertEqual(UmzugMapping.blendMode("color-dodge"), .lighten)
        XCTAssertEqual(UmzugMapping.blendMode("unbekannt"), .normal)
    }

    func testFormatMapsOldFormatIds() {
        XCTAssertEqual(UmzugMapping.format("quadrat"), .square)
        XCTAssertEqual(UmzugMapping.format("4-3"), .landscape4x3)
        XCTAssertEqual(UmzugMapping.format("3-4"), .portrait3x4)
        XCTAssertEqual(UmzugMapping.format("16-9"), .landscape16x9)
        XCTAssertEqual(UmzugMapping.format("9-16"), .portrait9x16)
        XCTAssertEqual(UmzugMapping.format("a4"), .a4)
    }

    func testFormatFallsBackLikeTheOldApp() {
        // web/studio.js: formatVon(id) => FORMATE.find(...) ?? FORMATE[1] (== "4-3").
        XCTAssertEqual(UmzugMapping.format("unbekannt"), .landscape4x3)
        XCTAssertEqual(UmzugMapping.format(nil), .landscape4x3)
    }

    func testBackgroundMapsOldPaperIds() {
        XCTAssertEqual(UmzugMapping.background("weiss"), .white)
        XCTAssertEqual(UmzugMapping.background("transparent"), .transparent)
        XCTAssertEqual(UmzugMapping.background("dunkel"), .dark)
    }

    func testBackgroundFallsBackLikeTheOldApp() {
        // web/studio.js: papierVon(id) => PAPIERE.find(...) ?? PAPIERE[0] (== "dunkel").
        XCTAssertEqual(UmzugMapping.background("unbekannt"), .dark)
        XCTAssertEqual(UmzugMapping.background(nil), .dark)
    }
}
