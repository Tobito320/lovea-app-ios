import XCTest
@testable import Lovea

/// Block 13: drawing together (Z-13.1 to Z-13.3). Two histories stand for the two phones.
@MainActor
final class GemeinsamZeichnenTests: XCTestCase {
    private let rot = RGBAColor(red: 1, green: 0, blue: 0)
    private let blau = RGBAColor(red: 0, green: 0, blue: 1)

    private func strich(_ id: String, _ layer: UUID, _ von: CGPoint, _ bis: CGPoint, _ farbe: RGBAColor) -> LiveStrich {
        LiveStrich(
            zeichnungId: "z", strichId: id, ebene: layer, settings: TestGPU.settings(size: 8, color: farbe),
            punkte: TestGPU.line(from: von, to: bis).map { StrokeInput(location: $0) },
            spiegel: nil, auswahl: false, anfang: true, ende: true
        )
    }

    /// Draws the stroke on the canvas like a finger does, then hands it to the history as an own step.
    private func eigen(_ verlauf: GemeinsamVerlauf, _ strich: LiveStrich) throws -> String {
        let inputs = strich.eingaben
        let layer = try XCTUnwrap(UUID(uuidString: strich.ebene))
        verlauf.engine.beginStroke(inputs[0], settings: try XCTUnwrap(strich.pinsel), layerID: layer)
        verlauf.engine.continueStroke(Array(inputs.dropFirst()), predicted: [])
        verlauf.engine.endStroke()
        return try XCTUnwrap(verlauf.eigene(.strich(strich), offen: true)?.id)
    }

    private func nurStriche(_ document: ArtworkDocument, _ striche: [LiveStrich]) async throws -> [UInt8] {
        let engine = try await TestGPU.engine(document)
        for strich in striche { strich.anwenden(auf: engine, autor: "x") }
        return await TestGPU.bytes(engine, document.layers[0].id)
    }

    // MARK: Z-13.2

    func testUndoTakesBackOnlyOwnStrokeAndKeepsThePartnerStroke() async throws {
        let document = TestGPU.document()
        let layer = document.layers[0].id
        // They cross at (32, 32): the undo has to put B back where A was underneath.
        let a = strich("a", layer, CGPoint(x: 4, y: 32), CGPoint(x: 60, y: 32), rot)
        let b = strich("b", layer, CGPoint(x: 32, y: 4), CGPoint(x: 32, y: 60), blau)

        // Ahmed's phone: A draws, B arrives, A undoes.
        let ahmed = GemeinsamVerlauf(engine: try await TestGPU.engine(document), ich: "ahmed", basis: 0)
        let aID = try eigen(ahmed, a)
        ahmed.empfangen(id: aID, seq: 1, von: "ahmed", aktion: .strich(a), texturen: [:])
        ahmed.empfangen(id: "b", seq: 2, von: "annika", aktion: .strich(b), texturen: [:])
        XCTAssertEqual(ahmed.rueckgaengig(), aID)

        // Annika's phone: A arrives, B draws, A's undo arrives.
        let annika = GemeinsamVerlauf(engine: try await TestGPU.engine(document), ich: "annika", basis: 0)
        annika.empfangen(id: aID, seq: 1, von: "ahmed", aktion: .strich(a), texturen: [:])
        let bID = try eigen(annika, b)
        annika.empfangen(id: bID, seq: 2, von: "annika", aktion: .strich(b), texturen: [:])
        XCTAssertFalse(annika.umschalten(bID, aus: true, von: "ahmed"), "only the author undoes a step")
        XCTAssertTrue(annika.umschalten(aID, aus: true, von: "ahmed"))

        let nurB = try await nurStriche(document, [b])
        let beiAhmed = await TestGPU.bytes(ahmed.engine, layer)
        let beiAnnika = await TestGPU.bytes(annika.engine, layer)
        XCTAssertEqual(beiAhmed, nurB, "only B is left on Ahmed's phone")
        XCTAssertEqual(beiAnnika, nurB, "and on Annika's")
        XCTAssertEqual(TestGPU.pixel(beiAhmed, width: 64, x: 12, y: 32)[3], 0, "A is gone")
        let kreuzung = TestGPU.pixel(beiAhmed, width: 64, x: 32, y: 32)
        XCTAssertEqual(kreuzung[0], 0, "no red left under B")
        XCTAssertGreaterThan(kreuzung[2], 200, "B is whole where A was")
        XCTAssertGreaterThan(TestGPU.pixel(beiAhmed, width: 64, x: 32, y: 12)[2], 200)
        XCTAssertFalse(ahmed.kannRueckgaengig, "B is not Ahmed's to undo")

        // Redo puts A back at its place in the order, under B, on both phones.
        XCTAssertEqual(ahmed.wiederholen(), aID)
        XCTAssertTrue(annika.umschalten(aID, aus: false, von: "ahmed"))
        let beide = try await nurStriche(document, [a, b])
        let ahmedWieder = await TestGPU.bytes(ahmed.engine, layer)
        let annikaWieder = await TestGPU.bytes(annika.engine, layer)
        XCTAssertEqual(ahmedWieder, beide)
        XCTAssertEqual(annikaWieder, beide)
    }

    // MARK: Z-13.1

    func testConcurrentStrokesEndUpInServerOrderOnBothPhones() async throws {
        let document = TestGPU.document()
        let layer = document.layers[0].id
        let a = strich("a", layer, CGPoint(x: 4, y: 32), CGPoint(x: 60, y: 32), rot)
        let b = strich("b", layer, CGPoint(x: 32, y: 4), CGPoint(x: 32, y: 60), blau)

        // Both draw at once. The server puts B (seq 1) before A (seq 2), so on Ahmed's phone B has to
        // slide under his own unconfirmed A.
        let ahmed = GemeinsamVerlauf(engine: try await TestGPU.engine(document), ich: "ahmed", basis: 0)
        let aID = try eigen(ahmed, a)
        ahmed.empfangen(id: "b", seq: 1, von: "annika", aktion: .strich(b), texturen: [:])
        ahmed.empfangen(id: aID, seq: 2, von: "ahmed", aktion: .strich(a), texturen: [:])

        let annika = GemeinsamVerlauf(engine: try await TestGPU.engine(document), ich: "annika", basis: 0)
        let bID = try eigen(annika, b)
        annika.empfangen(id: bID, seq: 1, von: "annika", aktion: .strich(b), texturen: [:])
        annika.empfangen(id: aID, seq: 2, von: "ahmed", aktion: .strich(a), texturen: [:])

        let erwartet = try await nurStriche(document, [b, a])
        let beiAhmed = await TestGPU.bytes(ahmed.engine, layer)
        let beiAnnika = await TestGPU.bytes(annika.engine, layer)
        XCTAssertEqual(beiAhmed, erwartet)
        XCTAssertEqual(beiAnnika, erwartet)
        XCTAssertGreaterThan(TestGPU.pixel(beiAhmed, width: 64, x: 32, y: 32)[0], 200, "A (seq 2) is on top")
        XCTAssertEqual(ahmed.basis, 2)
        XCTAssertTrue(ahmed.offeneIDs.isEmpty)
    }

    // MARK: Z-13.3

    func testLayerLockedForPartnerRejectsTheirOps() async throws {
        let document = TestGPU.document()
        let layer = document.layers[0].id
        let engine = try await TestGPU.engine(document)
        let verlauf = GemeinsamVerlauf(engine: engine, ich: "ahmed", basis: 0)
        engine.updateDocument { $0.layers[0].gesperrtVon = "ahmed" }
        let sperre = verlauf.eigeneSchritte(offen: true)
        XCTAssertEqual(sperre.count, 1)
        guard case let .ebenen(aenderung)? = sperre.first?.aktion else { return XCTFail("the lock travels as a layer op") }
        XCTAssertEqual(aenderung.geaendert.map(\.gesperrtVon), ["ahmed"])
        verlauf.empfangen(id: sperre[0].id, seq: 1, von: "ahmed", aktion: sperre[0].aktion, texturen: [:])

        verlauf.empfangen(id: "b", seq: 2, von: "annika",
                          aktion: .strich(strich("b", layer, CGPoint(x: 32, y: 4), CGPoint(x: 32, y: 60), blau)), texturen: [:])
        var entsperren = engine.document.layers
        entsperren[0].gesperrtVon = nil
        verlauf.empfangen(id: "u", seq: 3, von: "annika",
                          aktion: .ebenen(EbenenAenderung(von: engine.document.layers, zu: entsperren)), texturen: [:])
        let leer = await TestGPU.bytes(engine, layer)
        XCTAssertFalse(leer.contains { $0 != 0 }, "the partner's stroke doesn't land")
        XCTAssertEqual(engine.document.layers[0].gesperrtVon, "ahmed", "and she can't unlock it")

        verlauf.empfangen(id: "c", seq: 4, von: "ahmed",
                          aktion: .strich(strich("c", layer, CGPoint(x: 4, y: 32), CGPoint(x: 60, y: 32), rot)), texturen: [:])
        let bytes = await TestGPU.bytes(engine, layer)
        XCTAssertTrue(bytes.contains { $0 != 0 }, "own strokes still land")
    }

    // MARK: Layer diff

    func testLayerDiffKeepsThePartnersLayerChanges() throws {
        let a = ArtworkLayer.paint(name: "A")
        let b = ArtworkLayer.paint(name: "B")
        let c = ArtworkLayer.paint(name: "C")
        var b2 = b
        b2.name = "B2"
        let n = ArtworkLayer.paint(name: "N")
        let aenderung = EbenenAenderung(von: [a, b, c], zu: [c, b2, n, a])
        var gleich = [a, b, c]
        aenderung.anwenden(auf: &gleich)
        XCTAssertEqual(gleich, [c, b2, n, a])

        // Meanwhile the partner deleted A and added X on top: both changes stay.
        let x = ArtworkLayer.paint(name: "X")
        var partner = [b, c, x]
        aenderung.anwenden(auf: &partner)
        XCTAssertEqual(partner.map(\.name), ["C", "B2", "N", "X"])

        // Merge down: two layers out, one in their place.
        let unten = ArtworkLayer.paint(name: "Hintergrund")
        let zusammen = ArtworkLayer.paint(name: "A")
        var ebenen = [unten, a, b]
        EbenenAenderung(von: ebenen, zu: [unten, zusammen]).anwenden(auf: &ebenen)
        XCTAssertEqual(ebenen, [unten, zusammen])

        // Template: image at the bottom, paint on top, through JSON.
        let bild = ArtworkLayer.image(name: "Schablone")
        let oben = ArtworkLayer.paint(name: "Zeichnen")
        let vorlage = ZeichnungAktion.ebenen(EbenenAenderung(von: [a], zu: [bild, a, oben]))
        let zurueck = try JSONDecoder().decode(ZeichnungAktion.self, from: JSONEncoder().encode(vorlage))
        XCTAssertEqual(zurueck, vorlage)
        guard case let .ebenen(geladen) = zurueck else { return XCTFail("layer op") }
        var einfach = [a]
        geladen.anwenden(auf: &einfach)
        XCTAssertEqual(einfach, [bild, a, oben])
        XCTAssertTrue(EbenenAenderung(von: [a, b], zu: [a, b]).istLeer)
    }
}
