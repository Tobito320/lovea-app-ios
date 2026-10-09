import XCTest
@testable import Lovea

/// Design 27.09.2026 ("Galerie-Sync: ein Profil, alle Geräte"). Pure decision logic as
/// `nonisolated static func` (no `Raum`/network needed), plus the mandatory regression against the
/// echo loop: applying a remote stand must not re-mark it dirty.
@MainActor
final class GalerieSyncTests: XCTestCase {

    // MARK: - Anwenden-Entscheidung

    func testEntscheidungAppliesWhenMissingLocally() {
        let jetzt = Date()
        XCTAssertEqual(
            GalerieSync.entscheidung(eingehendUpdatedAt: jetzt, lokalUpdatedAt: nil, offenInStudio: false),
            .anwenden
        )
    }

    func testEntscheidungAppliesWhenStrictlyNewer() {
        let alt = Date()
        let neu = alt.addingTimeInterval(1)
        XCTAssertEqual(
            GalerieSync.entscheidung(eingehendUpdatedAt: neu, lokalUpdatedAt: alt, offenInStudio: false),
            .anwenden
        )
    }

    func testEntscheidungSkipsOwnEchoWithEqualUpdatedAt() {
        let stand = Date()
        XCTAssertEqual(
            GalerieSync.entscheidung(eingehendUpdatedAt: stand, lokalUpdatedAt: stand, offenInStudio: false),
            .ueberspringen
        )
    }

    func testEntscheidungSkipsWhenOlder() {
        let neu = Date()
        let alt = neu.addingTimeInterval(-1)
        XCTAssertEqual(
            GalerieSync.entscheidung(eingehendUpdatedAt: alt, lokalUpdatedAt: neu, offenInStudio: false),
            .ueberspringen
        )
    }

    func testEntscheidungDefersWhenOpenInStudioRegardlessOfFreshness() {
        let neu = Date()
        let alt = neu.addingTimeInterval(-1)
        XCTAssertEqual(
            GalerieSync.entscheidung(eingehendUpdatedAt: neu, lokalUpdatedAt: alt, offenInStudio: true),
            .zurueckstellen
        )
        // Even "missing locally" defers -- an open Studio for this id can only mean it exists.
        XCTAssertEqual(
            GalerieSync.entscheidung(eingehendUpdatedAt: neu, lokalUpdatedAt: nil, offenInStudio: true),
            .zurueckstellen
        )
    }

    // MARK: - Duplikat-Erkennung (alter Umzugs-Import, ein Gerät pro eigene UUID)

    func testDeletionBlocksOlderAndEqualStandsButNotNewerOnes() {
        let geloescht = Date(timeIntervalSince1970: 1_000)
        XCTAssertTrue(GalerieSync.vonLoeschungUeberholt(geloeschtAm: geloescht, updatedAt: Date(timeIntervalSince1970: 900)))
        XCTAssertTrue(GalerieSync.vonLoeschungUeberholt(geloeschtAm: geloescht, updatedAt: geloescht))
        XCTAssertFalse(GalerieSync.vonLoeschungUeberholt(geloeschtAm: geloescht, updatedAt: Date(timeIntervalSince1970: 1_100)))
        XCTAssertFalse(GalerieSync.vonLoeschungUeberholt(geloeschtAm: nil, updatedAt: geloescht))
    }

    func testDuplikatErkennungMatchesOnNameAndExactLayerHashSet() {
        XCTAssertTrue(GalerieSync.istDuplikat(
            lokalerName: "Herbst", lokaleHashes: ["a", "b"],
            eingehenderName: "Herbst", eingehendeHashes: ["a", "b"]
        ))
    }

    func testDuplikatErkennungFailsOnDifferentName() {
        XCTAssertFalse(GalerieSync.istDuplikat(
            lokalerName: "Herbst", lokaleHashes: ["a", "b"],
            eingehenderName: "Winter", eingehendeHashes: ["a", "b"]
        ))
    }

    func testDuplikatErkennungFailsOnDifferentHashes() {
        XCTAssertFalse(GalerieSync.istDuplikat(
            lokalerName: "Herbst", lokaleHashes: ["a", "b"],
            eingehenderName: "Herbst", eingehendeHashes: ["a", "c"]
        ))
    }

    func testDuplikatErkennungFailsWhenIncomingHasNoHashes() {
        XCTAssertFalse(GalerieSync.istDuplikat(
            lokalerName: "Herbst", lokaleHashes: [], eingehenderName: "Herbst", eingehendeHashes: []
        ))
    }

    // MARK: - Medien-ID

    func testMedienIdIsContentAddressedAndPersonPrefixed() {
        let bytes = Data("pixel".utf8)
        let ahmedId = GalerieSync.medienId(person: .ahmed, bytes: bytes)
        let annikaId = GalerieSync.medienId(person: .annika, bytes: bytes)
        XCTAssertTrue(ahmedId.hasPrefix("galerie-ahmed-"))
        XCTAssertTrue(annikaId.hasPrefix("galerie-annika-"))
        XCTAssertNotEqual(ahmedId, annikaId, "same bytes, different profile -> different id")
        XCTAssertEqual(GalerieSync.medienId(person: .ahmed, bytes: bytes), ahmedId, "same bytes -> same id every time")
    }

    func testHashSuffixRoundTripsThroughMedienId() {
        let bytes = Data("pixel".utf8)
        let id = GalerieSync.medienId(person: .annika, bytes: bytes)
        XCTAssertEqual(GalerieSync.hashSuffix(id), GalerieSync.hashHex(bytes))
    }

    func testHashSuffixIsNilForUnrelatedIds() {
        XCTAssertNil(GalerieSync.hashSuffix("umzug-galerie-ahmed-x-ebene0"))
    }

    // MARK: - Pflicht-Test: kein Endlosloop

    /// The regression the design calls out by name: applying a remote stand must leave nothing
    /// dirty and must not re-trigger a send -- otherwise every incoming stand would immediately be
    /// re-uploaded to the very device it came from.
    func testAppliedRemoteStandLeavesNothingDirty() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("GalerieSyncTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = ArtworkLibrary(rootURL: root)
        let sync = GalerieSync(library: library)

        var dokument = ArtworkDocument.new(
            name: "Ferngeladen", projectID: nil, format: .square, width: 512, height: 512, background: .white
        )
        dokument.id = UUID()
        dokument.updatedAt = Date()
        let layer = try XCTUnwrap(dokument.layers.first)

        await sync.schreiben(dokument, dateien: [layer.contentFile: Data("pixel-bytes".utf8), "vorschau.jpg": Data("preview-bytes".utf8)])

        await library.waitForWrites()
        XCTAssertEqual(library.document(dokument.id)?.name, "Ferngeladen")
        XCTAssertEqual(library.layerAsset(fileName: layer.contentFile, artworkID: dokument.id), Data("pixel-bytes".utf8))
        XCTAssertFalse(sync.istSchmutzig(dokument.id), "the raw write must never mark its own artwork dirty again")
    }
}
