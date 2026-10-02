import XCTest
@testable import Lovea

/// Die zwei Sicherungen gegen den verschwindenden Strich entscheiden über reine Funktionen, ohne Metal.
final class ZeichenAbsicherungTests: XCTestCase {
    // MARK: Laden

    func testLoadResultIsTakenWhenNothingLanded() {
        XCTAssertTrue(LadeEntscheidung.darfUebernehmen(landungenBeiStart: 3, landungenJetzt: 3, strichLaeuft: false))
    }

    func testLoadResultIsDroppedWhenAStrokeLandedMeanwhile() {
        XCTAssertFalse(LadeEntscheidung.darfUebernehmen(landungenBeiStart: 3, landungenJetzt: 4, strichLaeuft: false))
    }

    func testLoadResultIsDroppedWhileAStrokeRuns() {
        XCTAssertFalse(LadeEntscheidung.darfUebernehmen(landungenBeiStart: 3, landungenJetzt: 3, strichLaeuft: true))
    }

    func testLoadResultIsDroppedWhenBothHappened() {
        XCTAssertFalse(LadeEntscheidung.darfUebernehmen(landungenBeiStart: 0, landungenJetzt: 2, strichLaeuft: true))
    }

    // MARK: Umbau

    private func stand(
        _ id: String, aus: Bool = false, gelandet: Bool = true, sollteLanden: Bool = true
    ) -> UmbauPruefung.Stand {
        UmbauPruefung.Stand(id: id, aus: aus, gelandet: gelandet, sollteLanden: sollteLanden)
    }

    func testNothingLostWhenEveryStrokeStillLanded() {
        let vorher = [stand("a"), stand("b")]
        XCTAssertEqual(UmbauPruefung.verloren(vorher: vorher, nachher: vorher), [])
    }

    func testStrokeThatLandedBeforeAndNotAnymoreIsLost() {
        let vorher = [stand("a"), stand("b")]
        let nachher = [stand("a"), stand("b", gelandet: false)]
        XCTAssertEqual(UmbauPruefung.verloren(vorher: vorher, nachher: nachher), ["b"])
    }

    func testSeveralLostStrokesKeepTheirOrder() {
        let vorher = [stand("a"), stand("b"), stand("c")]
        let nachher = [stand("a", gelandet: false), stand("b"), stand("c", gelandet: false)]
        XCTAssertEqual(UmbauPruefung.verloren(vorher: vorher, nachher: nachher), ["a", "c"])
    }

    func testUndoneStrokeIsNotLost() {
        let vorher = [stand("a")]
        let nachher = [stand("a", aus: true, gelandet: false)]
        XCTAssertEqual(UmbauPruefung.verloren(vorher: vorher, nachher: nachher), [])
    }

    func testStrokeThatNeverLandedIsNotLost() {
        let vorher = [stand("a", gelandet: false)]
        XCTAssertEqual(UmbauPruefung.verloren(vorher: vorher, nachher: vorher), [])
    }

    func testStrokeRefusedByLockOrMissingLayerIsNotLost() {
        let vorher = [stand("a")]
        let nachher = [stand("a", gelandet: false, sollteLanden: false)]
        XCTAssertEqual(UmbauPruefung.verloren(vorher: vorher, nachher: nachher), [])
    }

    func testEntriesAreMatchedByIdNotByPosition() {
        // Ein Partner-Schritt wurde vorn eingefügt: die Reihenfolge ändert sich, "b" ist weiter da.
        let vorher = [stand("a"), stand("b")]
        let nachher = [stand("neu", gelandet: false), stand("a"), stand("b")]
        XCTAssertEqual(UmbauPruefung.verloren(vorher: vorher, nachher: nachher), [])
    }

    func testStrokeThatLeftTheHistoryIsNotLost() {
        // Von `kuerzen` entfernte Einträge sind dauerhaft, kein Verlust.
        XCTAssertEqual(UmbauPruefung.verloren(vorher: [stand("a")], nachher: []), [])
    }

    // MARK: Nachbesserung

    func testNothingLostMeansNothingToDo() {
        for versuch in 0...2 {
            XCTAssertEqual(UmbauPruefung.nachbesserung(verloren: [], versuch: versuch, vollSchonVersucht: false), .fertig)
        }
    }

    func testFirstLossGetsATargetedRebuild() {
        XCTAssertEqual(UmbauPruefung.nachbesserung(verloren: ["a"], versuch: 0, vollSchonVersucht: false), .gezielt)
        XCTAssertEqual(UmbauPruefung.nachbesserung(verloren: ["a"], versuch: 0, vollSchonVersucht: true), .gezielt)
    }

    func testStillLostAfterTheTargetedRebuildRebuildsEverythingOnce() {
        XCTAssertEqual(UmbauPruefung.nachbesserung(verloren: ["a"], versuch: 1, vollSchonVersucht: false), .voll)
    }

    func testFullRebuildHappensOnlyOncePerHistory() {
        XCTAssertEqual(UmbauPruefung.nachbesserung(verloren: ["a"], versuch: 1, vollSchonVersucht: true), .aufgeben)
    }

    func testItGivesUpAfterTheFullRebuild() {
        XCTAssertEqual(UmbauPruefung.nachbesserung(verloren: ["a"], versuch: 2, vollSchonVersucht: true), .aufgeben)
        XCTAssertEqual(UmbauPruefung.nachbesserung(verloren: ["a"], versuch: 2, vollSchonVersucht: false), .aufgeben)
    }
}

/// Die Laden-Sicherung an der echten Engine: das Ladeergebnis darf einen laufenden oder gelandeten Strich nie überschreiben.
@MainActor
final class ZeichenLadeSperreTests: XCTestCase {
    func testInputIsRefusedUntilTheFirstLoadIsDone() async throws {
        let library = TestGPU.library()
        let artwork = library.createArtwork(name: "Laden", projectID: nil, format: .custom, customWidth: 64, customHeight: 64)
        let session = DrawingSession(artworkID: artwork.id, library: library)
        let engine = try XCTUnwrap(session.engine)
        XCTAssertFalse(engine.isLoaded)
        XCTAssertFalse(session.ensureDrawable())
        await engine.loading?.value
        XCTAssertTrue(engine.isLoaded)
        XCTAssertTrue(session.ensureDrawable())
    }

    func testReloadIsTakenWhenNothingHappenedMeanwhile() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let uebernommen = await engine.reload(engine.document)
        XCTAssertTrue(uebernommen)
    }

    func testReloadIsDroppedWhileAStrokeRunsAndTheStrokeLands() async throws {
        let engine = try await TestGPU.engine(TestGPU.document())
        let layerID = engine.activeLayerID
        let inputs = TestGPU.line(from: CGPoint(x: 10, y: 32), to: CGPoint(x: 50, y: 32)).map { StrokeInput(location: $0) }
        engine.beginStroke(inputs[0], settings: TestGPU.settings(), layerID: layerID)
        engine.continueStroke(Array(inputs.dropFirst()), predicted: [])
        let uebernommen = await engine.reload(engine.document)
        XCTAssertFalse(uebernommen)
        XCTAssertTrue(engine.isStroking)
        engine.endStroke()
        let bytes = await TestGPU.bytes(engine, layerID)
        XCTAssertGreaterThan(TestGPU.pixel(bytes, width: 64, x: 30, y: 32)[3], 0)
    }
}
